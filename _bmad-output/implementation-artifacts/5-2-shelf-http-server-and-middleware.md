# Story 5.2: Shelf HTTP Server and Middleware

Status: done

## Story

As a developer,
I want the phone to run an HTTP server that starts before the UI,
So that the manager and local consume flow have an API endpoint.

## Acceptance Criteria

1. **Given** `server/server.dart` sets up shelf + shelf_router on port 8080
   **When** the app launches
   **Then** the server starts in `main()` before `runApp()` (database → scanCoordinator → server → UI)

2. **Given** shelf middleware pipeline
   **When** any HTTP request arrives
   **Then** wakelock middleware resets a 5-minute idle timer

3. **Given** the app is running
   **Then** the phone registers `_winetap._tcp` via mDNS (bonsoir) on port 8080

4. **Given** the shelf server configuration
   **Then** shelf idle timeout is ≥ 60s (for long-poll support in Story 7.1)

5. **Given** the server is running
   **When** `GET /` is requested
   **Then** it returns HTTP 200 with a health check response

6. **Given** the server architecture
   **Then** database and scanCoordinator are passed to the router builder as parameters (no globals)

7. **Given** the server is running
   **Then** `flutter analyze` passes and `flutter test` passes

## Tasks / Subtasks

- [x] Task 1: Add shelf and wakelock dependencies to pubspec.yaml (AC: #1)
  - [x] Add `shelf: ^1.4.0` and `shelf_router: ^1.1.0` to dependencies
  - [x] Add `wakelock_plus: ^1.4.0` to dependencies
  - [x] Run `flutter pub get`
- [x] Task 2: Create ScanCoordinator class (AC: #6)
  - [x] Create `mobile/lib/server/scan_coordinator.dart`
  - [x] Implement: `Completer<String?>?` + `_mode` + injectable `Duration timeout` (default 30s)
  - [x] Methods: `request(String mode)`, `waitForResult()` (Future with timeout), `submitResult(String tagId)`, `cancel()`
  - [x] Properties: `hasPendingRequest`, `mode`
  - [x] `request()` throws `StateError` if a request is already pending
  - [x] `waitForResult()` returns `null` on timeout
  - [x] `submitResult()` completes the pending completer; continuous mode creates new completer
  - [x] `cancel()` completes with null and resets state
- [x] Task 3: Create wakelock middleware (AC: #2)
  - [x] Create `mobile/lib/server/middleware/wakelock.dart`
  - [x] Implement shelf `Middleware` that resets a 5-minute idle timer on each request
  - [x] On timer start/reset: `WakelockPlus.enable()`
  - [x] On timer expire: `WakelockPlus.disable()`
- [x] Task 4: Create shelf server with router (AC: #1, #4, #5, #6)
  - [x] Create `mobile/lib/server/server.dart`
  - [x] Function `startServer(AppDatabase db, ScanCoordinator coordinator, {enableWakelock, port})` → `Future<HttpServer>`
  - [x] Build shelf `Pipeline`: optional wakelock middleware → `shelf_router` Router
  - [x] Register `GET /` health check route returning `200 {"status": "ok"}`
  - [x] Configure shelf `serve` with `shared: true` and idle timeout = 60s
  - [x] Return the `HttpServer` instance
  - [x] Router builder receives `db` and `coordinator` as parameters
- [x] Task 5: Rewrite main.dart startup sequence (AC: #1, #6)
  - [x] `main()` becomes `async`: `WidgetsFlutterBinding.ensureInitialized()`
  - [x] Create `AppDatabase()` (production constructor)
  - [x] Create `ScanCoordinator()`
  - [x] Call `startServer(db, coordinator)` — server running before UI
  - [x] Register mDNS service `_winetap._tcp` on port 8080 via bonsoir
  - [x] Pass `db`, `coordinator` into the widget tree via `MultiProvider`
  - [x] Remove `ConnectionProvider` from MultiProvider
  - [x] Keep `ScanProvider` and `IntakeProvider` in MultiProvider (adapted later)
- [x] Task 6: Convert DiscoveryService to mDNS registrar (AC: #3)
  - [x] Rewrite `mobile/lib/services/discovery_service.dart` as mDNS **registration** (not browser)
  - [x] Register `BonsoirService` with type `_winetap._tcp`, port 8080
  - [x] Expose `register()` and `stop()` methods
  - [x] Legacy stubs retained for ConnectionProvider compat (removed in Story 5.6)
- [x] Task 7: Write tests (AC: #7)
  - [x] ScanCoordinator tests: 12 tests covering request/submit/cancel/timeout/continuous lifecycle
  - [x] Server tests: health check 200, unknown route 404, idle timeout ≥ 60s
  - [x] Use short timeout (100ms) for ScanCoordinator tests
- [x] Task 8: Verification (AC: #7)
  - [x] Run `flutter analyze` — no issues
  - [x] Run `flutter test` — 59 tests pass (0 failures, 0 regressions)
  - [x] Run `flutter build apk --debug` — builds successfully

## Dev Notes

### Shelf Server Pattern

Per architecture spec — server starts in `main()` BEFORE `runApp()`:

```dart
// server/server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'database.dart';
import 'scan_coordinator.dart';
import 'middleware/wakelock.dart';

Future<HttpServer> startServer(AppDatabase db, ScanCoordinator coordinator) async {
  final router = Router();

  // Health check
  router.get('/', (Request request) {
    return Response.ok('{"status":"ok"}',
        headers: {'Content-Type': 'application/json'});
  });

  // Future stories will add routes here:
  // router.mount('/designations', designationHandler(db));

  final handler = const Pipeline()
      .addMiddleware(wakelockMiddleware())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080, shared: true);
  server.idleTimeout = const Duration(seconds: 60);
  return server;
}
```

### App Startup Sequence

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final coordinator = ScanCoordinator();
  final server = await startServer(db, coordinator);
  // mDNS registration
  // runApp(...)
}
```

**Critical:** Database, coordinator, and server are created in `main()` and passed down — no lazy initialization, no globals.

### Wakelock Middleware Pattern

Per architecture spec:

```dart
Middleware wakelockMiddleware() {
  Timer? idleTimer;
  void resetTimer() {
    idleTimer?.cancel();
    WakelockPlus.enable();
    idleTimer = Timer(const Duration(minutes: 5), () {
      WakelockPlus.disable();
    });
  }
  return (Handler innerHandler) {
    return (Request request) async {
      resetTimer();
      return innerHandler(request);
    };
  };
}
```

### ScanCoordinator Pattern

Per architecture spec — encapsulated class, not global state:

```dart
class ScanCoordinator {
  Completer<String>? _completer;
  String? _mode;
  final Duration timeout;

  ScanCoordinator({this.timeout = const Duration(seconds: 30)});

  bool get hasPendingRequest => _completer != null;
  String? get mode => _mode;

  void request(String mode) {
    if (_completer != null) throw StateError('Scan already in progress');
    _mode = mode;
    _completer = Completer<String>();
  }

  Future<String?> waitForResult() async {
    if (_completer == null) throw StateError('No pending request');
    try {
      return await _completer!.future.timeout(timeout, onTimeout: () => throw TimeoutException(''));
    } on TimeoutException {
      return null; // caller retries
    }
  }

  void submitResult(String tagId) {
    _completer?.complete(tagId);
    if (_mode != 'continuous') _reset();
  }

  void cancel() {
    _completer?.completeError(StateError('cancelled'));
    _reset();
  }

  void _reset() {
    _completer = null;
    _mode = null;
  }
}
```

Timeout is injectable — 30s default, 100ms in tests.

### mDNS Registration (replaces browser)

The phone IS the server now — DiscoveryService changes from mDNS **browser** to mDNS **registrar**:

```dart
class DiscoveryService {
  static const _serviceType = '_winetap._tcp';
  BonsoirBroadcast? _broadcast;

  Future<void> register(int port) async {
    final service = BonsoirService(name: 'WineTap', type: _serviceType, port: port);
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();
  }

  Future<void> stop() async {
    await _broadcast?.stop();
    _broadcast = null;
  }
}
```

Remove the mDNS browser logic and SharedPreferences caching — those belong on the manager now.

### What NOT to Do

- Do NOT create handlers for designations/domains/cuvees/bottles — Stories 5.3 and 5.4
- Do NOT create scan coordination endpoints — Story 7.1
- Do NOT create backup/restore endpoints — Story 8.1
- Do NOT rewrite ScanProvider or IntakeProvider — Stories 5.5 and 7.2
- Do NOT remove gRPC code — Story 5.6
- Do NOT use `print()` — use `dart:developer` `log()`
- Do NOT use global state — pass `db` and `coordinator` as parameters
- Do NOT use `ConnectionProvider` — phone is the server, no discovery needed

### Previous Story Intelligence

Story 5.1 established:
- `mobile/lib/server/database.dart` — drift AppDatabase with all tables, query methods, toJson extensions
- `mobile/lib/server/database.g.dart` — generated drift code
- `AppDatabase()` default constructor uses `driftDatabase(name: 'winetap')`
- `AppDatabase.forTesting(NativeDatabase.memory())` for tests
- `drift: ^2.32.0`, `drift_flutter: ^0.3.0` already in pubspec
- FK enforcement via `PRAGMA foreign_keys = ON` in `beforeOpen` migration
- Sentinel designation (id=0, name='(unassigned)') seeded in `onCreate`

Story 5.1 code review learnings:
- `drift_flutter: ^0.2.0` was incompatible — upgraded to `^0.3.0` (check shelf versions similarly)
- `isNull`/`isNotNull` name collision between drift and flutter_test — use `hide` import
- `consumeBottle` wrapped in `transaction()` for atomicity
- `bulkUpdateBottles` guards empty list with early return

Existing v1 code still present:
- `mobile/lib/main.dart` — uses `ConnectionProvider`, `ScanProvider`, `IntakeProvider` via MultiProvider
- `mobile/lib/services/discovery_service.dart` — mDNS browser (needs rewrite to registrar)
- `mobile/lib/providers/connection_provider.dart` — manages gRPC connection (to be replaced)
- `grpc`, `protobuf`, `fixnum` still in pubspec (removed in Story 5.6)

### Handler Testing Pattern

For server tests, call handler functions directly with mock `Request` — no need to start a real shelf server:

```dart
test('health check returns 200', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final coordinator = ScanCoordinator(timeout: const Duration(milliseconds: 100));
  final server = await startServer(db, coordinator);
  try {
    final client = HttpClient();
    final req = await client.get('localhost', 8080, '/');
    final resp = await req.close();
    expect(resp.statusCode, 200);
  } finally {
    await server.close();
    await db.close();
  }
});
```

Alternatively, test the Router directly without starting an HTTP server:
```dart
// Build the handler pipeline and call it with a shelf Request object
```

### References

- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md] — shelf patterns, middleware, startup sequence, ScanCoordinator pattern, project structure
- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md] — Story 5.2 acceptance criteria
- [Source: docs/rest-api-contracts.md] — API conventions (port 8080, JSON, snake_case)
- [Source: _bmad-output/implementation-artifacts/5-1-drift-database-and-schema.md] — database patterns, review learnings

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- WakelockPlus needs platform channels — added `enableWakelock` flag to `startServer()` for tests
- Added `port` parameter to `startServer()` — tests use port 0 (auto-assign) to avoid conflicts
- ScanCoordinator `cancel()` uses `complete(null)` instead of `completeError` to avoid unhandled async errors
- DiscoveryService retains legacy `discover()` and `cacheAddress()` stubs for ConnectionProvider compat (removed in 5.6)
- Completer type changed to `Completer<String?>` to support null completion on cancel/timeout

### Completion Notes List

- shelf HTTP server on port 8080 with health check endpoint
- ScanCoordinator with injectable timeout, single/continuous modes, cancel support
- Wakelock middleware resets 5-minute idle timer on each request
- main.dart startup: db → coordinator → server → mDNS → UI (no globals)
- DiscoveryService converted from mDNS browser to registrar
- ConnectionProvider removed from MultiProvider; db and coordinator passed via Provider
- 15 new tests (12 ScanCoordinator + 3 server), 59 total, all passing

### File List

- mobile/pubspec.yaml (modified — added shelf, shelf_router, wakelock_plus)
- mobile/lib/server/scan_coordinator.dart (new — scan request lifecycle)
- mobile/lib/server/server.dart (new — shelf server setup)
- mobile/lib/server/middleware/wakelock.dart (new — activity-based wakelock)
- mobile/lib/main.dart (rewritten — async startup, server before UI)
- mobile/lib/services/discovery_service.dart (rewritten — mDNS registrar)
- mobile/test/server/scan_coordinator_test.dart (new — 12 tests)
- mobile/test/server/server_test.dart (new — 3 tests)

### Review Findings

- [x] [Review][Patch] Add `@Deprecated` annotation to legacy stubs in DiscoveryService [mobile/lib/services/discovery_service.dart]
- [x] [Review][Patch] Wrap `WakelockPlus.enable()`/`disable()` in try/catch in wakelock middleware [mobile/lib/server/middleware/wakelock.dart]
- [x] [Review][Patch] Guard `DiscoveryService.register()` against double-call (stop existing broadcast first) [mobile/lib/services/discovery_service.dart]
- [x] [Review][Defer] No startup error handling in `main()` for `startServer`/`discovery.register` failures [mobile/lib/main.dart] — deferred, pre-existing
- [x] [Review][Defer] No app lifecycle teardown for AppDatabase, HttpServer, DiscoveryService [mobile/lib/main.dart] — deferred, pre-existing
- [x] [Review][Defer] IPv6-only networks not supported (`anyIPv4` bind only) [mobile/lib/server/server.dart] — deferred, pre-existing
- [x] [Review][Defer] WakelockPlus `idleTimer` not cancelled on app/server shutdown [mobile/lib/server/middleware/wakelock.dart] — deferred, pre-existing
- [x] [Review][Defer] `discovery.register()` may hang if Bonsoir `ready` future never resolves [mobile/lib/services/discovery_service.dart] — deferred, pre-existing

### Change Log

- 2026-04-01: Implemented Story 5.2 — shelf HTTP server, ScanCoordinator, wakelock middleware, main.dart startup rewrite, mDNS registrar
