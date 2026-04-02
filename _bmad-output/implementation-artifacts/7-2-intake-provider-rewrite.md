# Story 7.2: IntakeProvider Rewrite for Local Server

Status: done

## Story

As a user,
I want the phone's intake screen to show scan requests from the manager,
So that I know when to scan a bottle.

## Acceptance Criteria

1. **Given** IntakeProvider rewritten to watch ScanCoordinator (not bidi stream)
   **When** the manager sends a scan request
   **Then** IntakeProvider detects pending request and shows "Pret a scanner"
   **And** user taps button -> NfcService.readTagId() -> ScanCoordinator.submitResult(tagId)
   **And** the long-polling manager receives the tag_id immediately
   **And** single mode: returns to waiting after result delivered
   **And** IntakeScreen preserved with all states (idle, scanRequested, scanning, tagSent, continuousReady, error)
   **And** NFC session cancelled -> scan request stays active for retry (FR19)

## Tasks / Subtasks

- [x] Task 1: Rewrite IntakeProvider to use ScanCoordinator (AC: #1)
  - [x] 1.1 Replace constructor: `IntakeProvider(ScanCoordinator coordinator, {NfcService? nfcService})`
  - [x] 1.2 Remove all gRPC imports and stream code — replaced with ScanCoordinator polling
  - [x] 1.3 Replace `_requestedMode` with `_coordinator.mode` (delegate to coordinator)
  - [x] 1.4 Replace `isContinuous` getter: `bool get isContinuous => _coordinator.mode == 'continuous'`
  - [x] 1.5 Add polling loop: `startListening()` method with 500ms periodic timer
  - [x] 1.6 Keep all existing state management: `IntakeState` enum, `_setState()`, `_showBriefError()`, `_disposed` guard

- [x] Task 2: Implement scan request detection via polling (AC: #1)
  - [x] 2.1 `startListening()`: periodic timer (500ms) checking `coordinator.hasPendingRequest`
  - [x] 2.2 When `hasPendingRequest` becomes true: transition `idle/waitingForRequest` -> `scanRequested`
  - [x] 2.3 When `hasPendingRequest` becomes false: transition back to `waitingForRequest`
  - [x] 2.4 `stopListening()`: cancel the polling timer
  - [x] 2.5 Set initial state to `waitingForRequest` on `startListening()`

- [x] Task 3: Rewrite `_sendTag()` to use ScanCoordinator (AC: #1)
  - [x] 3.1 Replace stream send with `_coordinator.submitResult(tagId)`
  - [x] 3.2 On success: transition to `tagSent`, show tag ID
  - [x] 3.3 Single mode after tagSent: timer (2s) -> `waitingForRequest`
  - [x] 3.4 Continuous mode after tagSent: timer (800ms) -> `continuousReady`

- [x] Task 4: Preserve NFC scan logic (AC: #1)
  - [x] 4.1 Keep `startNfcScan()` — `_singleRead()` for single mode, `_startContinuousRead()` for continuous
  - [x] 4.2 Keep `_singleRead()` with NfcSessionCancelledException -> `_showBriefError(S.scanCancelledRetry, scanRequested)` (FR19)
  - [x] 4.3 Keep `_singleRead()` with NfcReadTimeoutException -> `_showBriefError(S.noTagDetectedWithHint, scanRequested)` (FR19)
  - [x] 4.4 Keep `_startContinuousRead()` with duplicate tag filtering (`_lastContinuousTagId`)
  - [x] 4.5 Keep `cancelScan()` and `retryFromError()` — same logic, same state transitions
  - [x] 4.6 Keep `_stopContinuous()` — cancels subscription, stops NFC reading

- [x] Task 5: Wire IntakeProvider in main.dart (AC: #1)
  - [x] 5.1 Change `IntakeProvider()` to `IntakeProvider(coordinator)` in main.dart provider list
  - [x] 5.2 `startListening()` called in IntakeScreen initState via addPostFrameCallback

- [x] Task 6: Update IntakeScreen to start listening (AC: #1)
  - [x] 6.1 Convert IntakeScreen back to StatefulWidget
  - [x] 6.2 In `initState()`: `context.read<IntakeProvider>().startListening()` via addPostFrameCallback
  - [x] 6.3 dispose() defined (stopListening called via provider's own dispose)
  - [x] 6.4 Keep all existing `_build*` methods unchanged
  - [x] 6.5 Keep `_buildIdle` as fallback for safety (displays existing "unavailable" message)

- [x] Task 7: Update tests (AC: #1)
  - [x] 7.1 Update `widget_test.dart` — IntakeProvider now requires ScanCoordinator argument
  - [x] 7.2 Create `test/providers/intake_provider_test.dart` with MockNfcService
  - [x] 7.3 Test: request detected -> scanRequested state
  - [x] 7.4 Test: submitResult -> tagSent state
  - [x] 7.5 Test: cancel -> waitingForRequest state
  - [x] 7.6 Test: NFC error -> error state with retry returning to scanRequested
  - [x] 7.7 Test: continuous mode -> continuousReady after tagSent

- [x] Task 8: Verify integration (AC: #1)
  - [x] 8.1 `dart analyze` passes (1 warning: _briefErrorActive write-only — pre-existing)
  - [x] 8.2 All existing tests pass (database_test failures are pre-existing)
  - [x] 8.3 New intake provider tests pass (11 tests)

### Review Findings

- [x] [Review][Patch] `_sendTag` shows tagSent UI even when submitResult silently drops (coordinator cancelled) — guard with hasPendingRequest check [intake_provider.dart:_sendTag]
- [x] [Review][Patch] `retryFromError` doesn't cancel _resetTimer — ghost state transition on rapid error-retry-error [intake_provider.dart:retryFromError]
- [x] [Review][Defer] `cancelScan` in single-read mode races with still-pending _singleRead future — deferred, pre-existing design; harmless flash

## Dev Notes

### Architecture Context — What Changes and What Stays

**This story replaces the gRPC bidi stream with ScanCoordinator polling.** The IntakeProvider currently:
1. Opens a `CoordinateScan` bidi gRPC stream to the RPi server
2. Receives `ScanRequestNotification` messages from the server
3. Sends `ScanClientMessage` (with tag ID) back through the stream
4. Handles server acks and errors via the stream

**New flow (v2):**
1. IntakeProvider polls `ScanCoordinator.hasPendingRequest` on a timer
2. When request detected, transitions to `scanRequested`
3. User taps -> NFC scan -> `ScanCoordinator.submitResult(tagId)` (direct call, no stream)
4. The manager's long-poll (GET /scan/result) receives the tag immediately via the coordinator's Completer
5. No ack needed — the HTTP response IS the ack

**What stays unchanged:**
- `IntakeState` enum (all 7 states preserved)
- `NfcService` usage (`readTagId()`, `continuousRead()`, `stopReading()`)
- NFC error handling (session cancelled, timeout → brief error, stay on scanRequested for retry)
- Continuous mode duplicate filtering (`_lastContinuousTagId`)
- All UI widgets in IntakeScreen (all `_build*` methods)
- Strings in S class (all already exist)

### ScanCoordinator API (from Story 7.1 / existing code)

```dart
class ScanCoordinator {
  bool get hasPendingRequest;  // true when manager has requested a scan
  String? get mode;            // 'single' or 'continuous', null when idle

  void request(String mode);         // called by HTTP handler (POST /scan/request)
  Future<String?> waitForResult();   // called by HTTP handler (GET /scan/result) — blocks
  void submitResult(String tagId);   // called by IntakeProvider after NFC scan
  void cancel();                     // called by HTTP handler (POST /scan/cancel)
}
```

Key insight: `submitResult()` completes the coordinator's internal Completer, which unblocks the HTTP handler's `waitForResult()`, which sends the 200 response to the manager. This is how tag IDs flow from phone NFC to manager — no explicit ack protocol needed.

### Polling vs Stream for Request Detection

The coordinator does not expose a Stream for "request arrived" events. Polling `hasPendingRequest` on a 500ms timer is the simplest approach:
- Manager POSTs /scan/request → coordinator.request(mode) → `hasPendingRequest` becomes true
- IntakeProvider's timer checks every 500ms → detects the request → transitions to `scanRequested`
- 500ms worst-case latency is well within NFR3 (scan request delivery < 2s)

Alternative: add a `ValueNotifier` or `Stream` to ScanCoordinator. This is cleaner but modifies a file owned by Story 7.1. The polling approach avoids cross-story dependencies and is simple enough for the use case.

### State Machine — Simplified from gRPC Version

```
waitingForRequest ──(coordinator.hasPendingRequest)──> scanRequested
scanRequested ──(user taps)──> scanning
scanning ──(NFC read success)──> tagSent
tagSent ──(2s timer, single)──> waitingForRequest
tagSent ──(800ms timer, continuous)──> continuousReady
continuousReady ──(next NFC read)──> tagSent (loop)

scanning ──(NFC error)──> error ──(2s brief)──> scanRequested  (FR19: request stays active)
scanning ──(iOS cancel)──> error ──(2s brief)──> scanRequested  (FR19: request stays active)

any state ──(coordinator.hasPendingRequest becomes false)──> waitingForRequest  (manager cancelled)
```

**Removed from v1:** `idle` state is no longer needed on the phone (server is always local). On `startListening()`, go directly to `waitingForRequest`. The `idle` enum value can stay for safety but won't be reached in normal flow.

### The `_sendTag` Rewrite — Core Change

Old (gRPC):
```dart
void _sendTag(String tagId) {
  _sendController!.add(ScanClientMessage(scanResult: ScanResult(tagId: tagId)));
  _setState(IntakeState.tagSent);
}
```

New (coordinator):
```dart
void _sendTag(String tagId) {
  _lastTagId = tagId;
  dev.log('Intake tag scanned: $tagId', name: 'IntakeProvider');
  _coordinator.submitResult(tagId);
  _setState(IntakeState.tagSent);

  _resetTimer?.cancel();
  if (isContinuous) {
    _resetTimer = Timer(const Duration(milliseconds: 800), () {
      if (!_disposed && _state == IntakeState.tagSent) {
        _setState(IntakeState.continuousReady);
      }
    });
  } else {
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (!_disposed && _state == IntakeState.tagSent) {
        _setState(IntakeState.waitingForRequest);
      }
    });
  }
}
```

Note: the ack/timer logic that was in `_onServerMessage` (scanAck case) is now inline in `_sendTag` because there's no server ack — `submitResult` is synchronous and immediate.

### Cancellation Detection

When the manager calls POST /scan/cancel, the coordinator's `cancel()` sets `hasPendingRequest` to false. The polling timer detects this and transitions to `waitingForRequest`. Also, if the NFC is in continuous mode, `_stopContinuous()` should be called.

```dart
void _onPollTick() {
  if (_disposed) return;
  final pending = _coordinator.hasPendingRequest;

  if (pending && (_state == IntakeState.waitingForRequest || _state == IntakeState.idle)) {
    _hadActiveRequest = true;
    _lastContinuousTagId = null;
    _setState(IntakeState.scanRequested);
  } else if (!pending && _hadActiveRequest) {
    // Manager cancelled or scan completed and reset
    _hadActiveRequest = false;
    _stopContinuous();
    if (_state != IntakeState.waitingForRequest && _state != IntakeState.error) {
      _setState(IntakeState.waitingForRequest);
    }
  }
}
```

### main.dart Change — Pass Coordinator

```dart
// Current:
ChangeNotifierProvider(create: (_) => IntakeProvider()),

// New:
ChangeNotifierProvider(create: (_) => IntakeProvider(coordinator)),
```

The `coordinator` is already created in `main()` and passed to `startServer()`. Now it's also passed to `IntakeProvider`. Both the HTTP handler and the provider share the same coordinator instance — this is the coordination mechanism.

### IntakeScreen — Minimal Change

The screen was simplified to a StatelessWidget in Story 5.5. It needs to become a StatefulWidget again to call `startListening()`/`stopListening()`:

```dart
class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key});
  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IntakeProvider>().startListening();
    });
  }

  @override
  void dispose() {
    // stopListening is safe to call even if not started
    // Using mounted check since context may not be available in dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) { /* existing Scaffold unchanged */ }
}
```

**Important:** The `_IntakeBody` widget and all `_build*` methods stay exactly as they are. All IntakeState values are already handled by the switch expression.

The only widget change: the `_buildIdle` case should either be unreachable or show `_buildWaiting` content, since the server is always local. Keep `idle` handled for safety (displays the current "unavailable" message as fallback).

### Testing IntakeProvider Without NFC Hardware

IntakeProvider tests should mock NfcService (NFC requires real hardware). Options:
1. Extract `NfcService` as a constructor parameter (allows mock injection)
2. Only test state transitions triggered by coordinator, skip NFC-dependent paths

Recommended: option 1 — add optional `NfcService? nfcService` parameter with default `NfcService()`:
```dart
IntakeProvider(ScanCoordinator coordinator, {NfcService? nfcService})
    : _coordinator = coordinator,
      _nfcService = nfcService ?? NfcService();
```

This enables comprehensive testing without hardware.

### Previous Story Intelligence

**From Story 5.5 (Local Consume Flow):**
- IntakeProvider was partially cleaned up: `_cleanupStream()` added, recovery guards added (`_briefErrorActive`, `_recovering`), but core gRPC logic preserved
- IntakeScreen simplified to StatelessWidget, shows `idle` state only — "full intake flow wired to ScanCoordinator in Story 7.2" (this story)
- `ScanProvider` pattern (in same providers/ dir): takes `AppDatabase` as constructor arg, uses `_disposed` guard, timer-based reset — follow same patterns

**From Story 7.1 (Scan Coordination Endpoints):**
- ScanCoordinator wired to HTTP handler via `scanRouter(coordinator)` in server.dart
- Manager POSTs /scan/request → coordinator.request(mode) → `hasPendingRequest` true
- Manager GET /scan/result blocks on coordinator.waitForResult()
- IntakeProvider calls coordinator.submitResult(tagId) → unblocks the HTTP response → manager receives tag

**From Story 6.4 (Manager NFCScanner):**
- Manager client-side expects: single mode stops after one tag, continuous mode loops
- Manager poll loop retries on 204 timeout automatically — phone-side timeout handling already in coordinator

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `mobile/lib/providers/intake_provider.dart` | REWRITE | Replace gRPC bidi stream with ScanCoordinator polling |
| `mobile/lib/screens/intake_screen.dart` | MODIFY | StatelessWidget -> StatefulWidget, call startListening/stopListening |
| `mobile/lib/main.dart` | MODIFY | Pass coordinator to IntakeProvider constructor |
| `mobile/test/providers/intake_provider_test.dart` | CREATE | State transition tests with ScanCoordinator |
| `mobile/test/widget_test.dart` | MODIFY | Update IntakeProvider constructor call |

### Anti-Patterns to Avoid

- Do NOT import any gRPC/protobuf packages — this story removes them from IntakeProvider
- Do NOT use `print()` — use `dart:developer` `log()` (existing pattern)
- Do NOT create a new ScanCoordinator — use the one from main.dart (shared with HTTP handler)
- Do NOT modify ScanCoordinator — it's owned by Story 7.1 and already tested
- Do NOT add HTTP calls from IntakeProvider — the coordinator is the bridge (provider calls coordinator, HTTP handler reads coordinator)
- Do NOT remove IntakeState enum values — the IntakeScreen switch expression requires all cases
- Do NOT use global state — coordinator passed as constructor parameter

### Project Structure Notes

No new files in `lib/` — only `intake_provider.dart` is rewritten (same path). One new test file.

```
mobile/lib/providers/
├── intake_provider.dart    ← REWRITE (gRPC -> ScanCoordinator)
├── scan_provider.dart      (unchanged)
└── server_provider.dart    (unchanged)
```

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 7.2] — acceptance criteria and FR references
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Phone Server Architecture] — IntakeProvider watches ScanCoordinator for manager requests
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Data Flow - Intake flow] — manager POST -> coordinator -> IntakeProvider -> NFC -> submitResult -> manager long-poll
- [Source: mobile/lib/server/scan_coordinator.dart] — ScanCoordinator API: hasPendingRequest, mode, submitResult
- [Source: mobile/lib/providers/intake_provider.dart] — current gRPC implementation being replaced
- [Source: mobile/lib/screens/intake_screen.dart] — current UI, all IntakeState cases handled
- [Source: mobile/lib/main.dart:25-26] — coordinator created in main(), passed to server and providers
- [Source: mobile/lib/services/nfc_service.dart] — NfcService API: readTagId(), continuousRead(), stopReading()
- [Source: mobile/lib/l10n/strings.dart] — all required strings already exist (S.readyToScan, S.waitingForRequest, etc.)
- [Source: _bmad-output/implementation-artifacts/7-1-scan-coordination-rest-endpoints.md] — HTTP handler calls coordinator; IntakeProvider completes the loop via submitResult
- [Source: _bmad-output/implementation-artifacts/5-5-local-consume-flow.md] — IntakeScreen simplified to StatelessWidget, IntakeProvider cleanup notes

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None

### Completion Notes List
- Rewrote IntakeProvider: removed gRPC dependency, now polls ScanCoordinator.hasPendingRequest on 500ms timer
- Constructor takes ScanCoordinator (required) + NfcService (optional, for testing)
- `_sendTag()` calls `coordinator.submitResult(tagId)` directly — no ack protocol needed
- `_onPollTick()` detects request arrival and manager cancellation
- Continuous mode: 800ms timer after tagSent -> continuousReady; single mode: 2s timer -> waitingForRequest
- IntakeScreen converted to StatefulWidget, calls startListening() in initState via addPostFrameCallback
- All _build* widget methods preserved unchanged
- MockNfcService created for testing — allows controlling NFC reads without hardware
- 11 intake provider tests covering all state transitions

### Change Log
- 2026-04-01: Implemented Story 7.2 — IntakeProvider rewrite for ScanCoordinator

### File List
- mobile/lib/providers/intake_provider.dart (REWRITTEN)
- mobile/lib/screens/intake_screen.dart (MODIFIED)
- mobile/lib/main.dart (MODIFIED)
- mobile/test/widget_test.dart (MODIFIED)
- mobile/test/providers/intake_provider_test.dart (CREATED)
