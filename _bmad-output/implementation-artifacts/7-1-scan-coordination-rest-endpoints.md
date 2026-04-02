# Story 7.1: Scan Coordination REST Endpoints

Status: done

## Story

As a developer,
I want the phone to serve scan coordination endpoints,
So that the manager can request NFC scans and retrieve results over HTTP.

## Acceptance Criteria

1. **Given** `handlers/scan.dart` and `server/scan_coordinator.dart`
   **When** the manager requests a scan
   **Then** POST /scan/request creates a pending scan with mode (single/continuous), returns 201
   **And** GET /scan/result long-polls: blocks until tag available (200 + tag_id) or timeout (204)
   **And** POST /scan/cancel cancels pending scan, returns 200
   **And** 409 returned if scan already in progress
   **And** 410 returned on GET /scan/result if cancelled during wait
   **And** ScanCoordinator is a class passed as parameter (not global)
   **And** timeout is configurable (30s default, injectable for tests)

## Tasks / Subtasks

- [x] Task 1: Create `handlers/scan.dart` with scan coordination routes (AC: #1)
  - [x] 1.1 Create `scanRouter(ScanCoordinator coordinator)` returning `Router`
  - [x] 1.2 POST `/request` handler: parse `mode` from JSON body, call `coordinator.request(mode)`, return 201 `{"status":"requested","mode":"<mode>"}`; catch `StateError` → 409 `already_exists`
  - [x] 1.3 GET `/result` handler: check `coordinator.hasPendingRequest` (if false → 400); call `coordinator.waitForResult()`; non-null → 200 `{"status":"resolved","tag_id":"<id>"}`; null + `hasPendingRequest` → 204 (timeout); null + `!hasPendingRequest` → 410 `{"status":"cancelled"}`
  - [x] 1.4 POST `/cancel` handler: call `coordinator.cancel()`, return 200 `{"status":"cancelled"}`
  - [x] 1.5 Validate `mode` is `"single"` or `"continuous"` → 400 on invalid value

- [x] Task 2: Wire scan routes into `server.dart` (AC: #1)
  - [x] 2.1 Import `handlers/scan.dart`
  - [x] 2.2 Add `router.mount('/scan', scanRouter(coordinator).call)` after catalog routes
  - [x] 2.3 Verify `coordinator` parameter (already passed to `startServer`) is forwarded

- [x] Task 3: Create `test/server/handlers/scan_test.dart` (AC: #1)
  - [x] 3.1 Setup: ScanCoordinator(timeout: Duration(milliseconds: 100)), call handler directly
  - [x] 3.2 Test POST /scan/request → 201 with mode single
  - [x] 3.3 Test POST /scan/request → 201 with mode continuous
  - [x] 3.4 Test POST /scan/request when scan active → 409
  - [x] 3.5 Test POST /scan/request with invalid mode → 400
  - [x] 3.6 Test GET /scan/result timeout → 204 (use 100ms coordinator timeout)
  - [x] 3.7 Test GET /scan/result with tag submitted → 200 + tag_id (concurrent futures)
  - [x] 3.8 Test GET /scan/result after cancel → 410
  - [x] 3.9 Test GET /scan/result with no pending request → 400
  - [x] 3.10 Test POST /scan/cancel → 200
  - [x] 3.11 Test POST /scan/cancel when no request → 200 (idempotent)

- [x] Task 4: Verify integration (AC: #1)
  - [x] 4.1 `dart analyze` passes
  - [x] 4.2 All existing tests still pass (166 total)
  - [x] 4.3 New scan handler tests pass (11 tests)

### Review Findings

- [x] [Review][Patch] TOCTOU race: wrap `waitForResult()` in try/catch for `StateError` (cancel between guard and await) [scan.dart:39-43]
- [x] [Review][Patch] Add test for non-JSON body on POST /request to exercise catch block [scan_test.dart]
- [x] [Review][Defer] Continuous mode: tag submitted between timeout and next poll is lost — deferred, pre-existing ScanCoordinator design
- [x] [Review][Defer] Request body not size-limited before readAsString — deferred, pre-existing pattern across all handlers

## Dev Notes

### Architecture Context

**ScanCoordinator already exists and is fully tested** (`server/scan_coordinator.dart`, 18 tests in `test/server/scan_coordinator_test.dart`). This story only creates the HTTP handler layer (`handlers/scan.dart`) and wires it into the server.

The coordinator manages the scan lifecycle:
- `request(mode)` → creates pending scan (throws `StateError` if one exists)
- `waitForResult()` → blocks until tag submitted, timeout, or cancel
- `submitResult(tagId)` → completes the pending request (called by IntakeProvider in Story 7.2)
- `cancel()` → cancels pending request

### Distinguishing Timeout vs Cancellation in the Handler

`waitForResult()` returns `null` for both timeout and cancellation. The handler distinguishes them by checking `coordinator.hasPendingRequest` after receiving null:
- **Timeout**: returns null, `hasPendingRequest` is **true** (fresh completer created for retry) → respond **204**
- **Cancellation**: returns null, `hasPendingRequest` is **false** (`_reset()` clears state) → respond **410**

```dart
final result = await coordinator.waitForResult();
if (result != null) {
  return _json(200, {'status': 'resolved', 'tag_id': result});
}
if (coordinator.hasPendingRequest) {
  return Response(204); // timeout — manager retries
}
return _json(410, {'status': 'cancelled'});
```

### Handler Pattern — Follow Existing Conventions

Every handler file in `handlers/` follows the same pattern. Copy from `bottles.dart` or `designations.dart`:

```dart
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../scan_coordinator.dart';

Router scanRouter(ScanCoordinator coordinator) {
  final router = Router();

  // POST /request
  router.post('/request', (Request req) async {
    // ...
  });

  // GET /result
  router.get('/result', (Request req) async {
    // ...
  });

  // POST /cancel
  router.post('/cancel', (Request req) async {
    // ...
  });

  return router;
}

Response _json(int status, Object body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

Response _error(int status, String code, String message) =>
    _json(status, {'error': code, 'message': message});
```

**Key rules:**
- `scanRouter()` takes `ScanCoordinator` as parameter — NOT `AppDatabase` (scan state is ephemeral, not in DB)
- Private `_json` and `_error` helpers per file (each handler file has its own copy — existing pattern)
- Use `dart:developer` `log()` for logging — never `print()`
- JSON body parsing: `jsonDecode(await req.readAsString()) as Map<String, dynamic>`

### REST API Contract (from `docs/rest-api-contracts.md`)

| Method | Path | Request Body | Success | Error Cases |
|--------|------|-------------|---------|-------------|
| POST | /scan/request | `{"mode": "single"}` | 201 `{"status":"requested","mode":"single"}` | 409 `already_exists` (scan in progress) |
| GET | /scan/result | — | 200 `{"status":"resolved","tag_id":"04A32BFF"}` | 204 (timeout), 410 `{"status":"cancelled"}` |
| POST | /scan/cancel | — | 200 `{"status":"cancelled"}` | — (idempotent) |

### Testing Pattern — Long-Poll Requires Concurrent Futures

The GET /scan/result handler blocks (long-polls). Testing requires one Future calling the endpoint while another submits the result:

```dart
test('GET /scan/result returns tag after submit', () async {
  coordinator.request('single');

  // Start long-poll (doesn't complete until result submitted)
  final resultFuture = client.get(Uri.parse('$baseUrl/scan/result'));

  // Brief delay then submit tag
  await Future.delayed(Duration(milliseconds: 10));
  coordinator.submitResult('04AABBCC');

  final response = await resultFuture;
  expect(response.statusCode, 200);
  final body = jsonDecode(response.body);
  expect(body['tag_id'], '04AABBCC');
});
```

Use `ScanCoordinator(timeout: Duration(milliseconds: 100))` in tests so timeout tests complete in ~100ms instead of 30s.

### Wiring Into server.dart — Minimal Change

Only 2 lines added to `server.dart`:

```dart
import 'handlers/scan.dart';  // add import

// After existing catalog routes, before pipeline:
router.mount('/scan', scanRouter(coordinator).call);  // add route
```

The `coordinator` parameter is already accepted by `startServer()` but currently unused. This story connects it.

### Previous Story Intelligence

**From Story 6.4 (Manager NFCScanner Stub):**
- Manager already implements the client side: `RequestScan()` → POST /scan/request, `GetScanResult()` → GET /scan/result (long poll with 35s client timeout), `CancelScan()` → POST /scan/cancel
- Manager expects: 201 on request, 200+tag_id / 204+timeout / 410+cancelled on result, 200 on cancel
- `ErrScanCancelled` sentinel is used on the Go side for 410 responses

**From Story 5.4 (Bottles Handler):**
- Handler pattern: `Router` function taking dependencies, private `_json`/`_error` helpers, `jsonDecode` for body parsing
- Error format: `{"error": "<code>", "message": "<description>"}`
- All existing handlers call drift directly — scan handler calls `ScanCoordinator` instead (no database interaction)

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `mobile/lib/server/handlers/scan.dart` | CREATE | Scan coordination REST handler (3 endpoints) |
| `mobile/lib/server/server.dart` | MODIFY | Mount `/scan` route (2 lines: import + mount) |
| `mobile/test/server/handlers/scan_test.dart` | CREATE | Handler tests (concurrent long-poll pattern) |

### Anti-Patterns to Avoid

- Do NOT import `database.dart` in scan handler — scan state is ephemeral (ScanCoordinator), not persisted
- Do NOT use `print()` — use `dart:developer` `log()` for debug logging
- Do NOT hardcode timeout — ScanCoordinator's timeout is already injectable via constructor
- Do NOT create a new ScanCoordinator in the handler — use the one passed from `startServer()`
- Do NOT add global state — coordinator is passed as parameter, consistent with all other handlers
- Do NOT add a service layer — handler calls coordinator directly (same as catalog handlers calling drift)

### Project Structure Notes

After this story, the handlers directory will be:
```
mobile/lib/server/handlers/
├── bottles.dart
├── completions.dart
├── cuvees.dart
├── designations.dart
├── domains.dart
└── scan.dart          ← NEW
```

Test directory:
```
mobile/test/server/
├── handlers/
│   └── scan_test.dart ← NEW (alongside any existing handler tests)
├── scan_coordinator_test.dart  (existing — 18 tests)
└── server_test.dart            (existing)
```

### References

- [Source: docs/rest-api-contracts.md#Scan Coordination Endpoints] — POST /scan/request, GET /scan/result (long poll), POST /scan/cancel; 200/204/410 semantics
- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 7.1] — acceptance criteria, note on long-poll test pattern
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Scan Coordinator Pattern] — ScanCoordinator class design, Completer + mode + timeout
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Shelf Handler Pattern] — handler conventions: jsonDecode, parameter injection, error format
- [Source: mobile/lib/server/scan_coordinator.dart] — existing ScanCoordinator implementation (fully tested)
- [Source: mobile/lib/server/server.dart] — current server setup, coordinator already accepted but not wired
- [Source: mobile/lib/server/handlers/bottles.dart] — reference handler pattern (_json, _error, Router function)
- [Source: _bmad-output/implementation-artifacts/6-4-manager-nfc-scanner-stub-for-http.md] — manager client-side expectations for these endpoints

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None

### Completion Notes List
- Created scan handler with 3 endpoints (POST /request, GET /result, POST /cancel) following existing handler pattern
- Handler takes ScanCoordinator as parameter (no database interaction), uses private _json/_error helpers
- GET /result distinguishes timeout (204) from cancellation (410) by checking hasPendingRequest after null result
- Wired scan routes into server.dart (import + mount, 2 lines)
- 11 handler tests covering all ACs: request modes, conflict, validation, long-poll timeout, concurrent tag submit, cancel, idempotent cancel
- All 166 tests pass, dart analyze clean

### Change Log
- 2026-04-01: Implemented Story 7.1 — scan coordination REST endpoints

### File List
- mobile/lib/server/handlers/scan.dart (CREATED)
- mobile/lib/server/server.dart (MODIFIED)
- mobile/test/server/handlers/scan_test.dart (CREATED)
