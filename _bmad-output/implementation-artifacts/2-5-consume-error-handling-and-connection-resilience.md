# Story 2.5: Consume Error Handling and Connection Resilience

Status: done

## Story

As a user,
I want clear error messages when something goes wrong during scanning,
So that I know what happened and how to recover.

## Acceptance Criteria

1. **Given** `providers/scan_provider.dart` manages scan state
   **Then** it exposes states: `idle`, `scanning`, `result`, `error`
   **And** error state includes a French message from `l10n/strings.dart`

2. **Given** the server is unreachable during a consume attempt
   **When** the gRPC call fails with `UNAVAILABLE`
   **Then** the screen displays "Serveur injoignable" with "verifiez votre connexion WiFi" (FR25, FR27)

3. **Given** the scanned tag is already associated with a consumed bottle (edge case)
   **When** the server returns `NOT_FOUND` (tag cleared on consumption)
   **Then** "Tag inconnu" is displayed

4. **Given** the NFC read fails (bad angle, timeout)
   **Then** the screen displays "Aucun tag detecte — reessayez" (FR25)
   **And** the user can tap "Scanner" again without restarting the app

5. **Given** the NFC session is cancelled by the user (iOS sheet dismissed)
   **Then** the screen silently returns to idle — no error shown

6. **Given** duplicate reads of the same tag within a single scan session (FR5)
   **Then** only the first read is processed; subsequent reads are silently ignored

7. **Given** the connection drops during a consume flow
   **When** the user was on the confirmation screen (bottle details shown)
   **Then** the confirmation screen remains visible
   **And** tapping "Confirmer" retries the `ConsumeBottle` call when connection recovers
   **Or** shows "Serveur injoignable" if still disconnected

## Tasks / Subtasks

- [x] Task 1: Add gRPC call deadlines (AC: #2, #7, deferred from 2.4)
  - [x] Add 5s `CallOptions(timeout)` to `getBottleByTagId` call
  - [x] Add 5s `CallOptions(timeout)` to `consumeBottle` call
  - [x] `DEADLINE_EXCEEDED` mapped to `S.timeout` ("Delai depasse")
- [x] Task 2: Enhance error messages with recovery guidance (AC: #2, #4)
  - [x] UNAVAILABLE -> `S.serverUnreachableWithHint` ("Serveur injoignable\nVerifiez votre connexion WiFi")
  - [x] NFC timeout -> `S.noTagDetectedWithHint` ("Aucun tag detecte — reessayez")
  - [x] Added `S.serverUnreachableWithHint`, `S.noTagDetectedWithHint`, `S.retryConsume` to strings.dart
- [x] Task 3: Duplicate tag suppression (AC: #6)
  - [x] `_lastScannedTagId` tracked in ScanProvider
  - [x] Reset on `cancel()` and `reset()`
- [x] Task 4: Connection drop during confirmation (AC: #7)
  - [x] `confirmConsume` now accepts retry from error state via `canRetryConsume` getter
  - [x] On gRPC failure during consume: `_bottle` preserved, error state set without clearing bottle
  - [x] Error screen: if `canRetryConsume`, shows "Reessayer la confirmation" -> retries consume; else shows "Scanner" -> full re-scan
  - [x] Bottle details card shown in error state when bottle data available
- [x] Task 5: Verify all existing error paths (AC: #1, #3, #5)
  - [x] AC1: ScanProvider 6-state machine with French error messages — confirmed
  - [x] AC3: NOT_FOUND -> "Tag inconnu" — confirmed
  - [x] AC5: NfcSessionCancelledException -> silent idle — confirmed
- [x] Task 6: Full verification
  - [x] `flutter analyze` — no issues
  - [x] `flutter test` — 10/10 pass
  - [x] `flutter build apk --debug` — builds successfully

### Review Findings

- [x] [Review][Patch] Duplicate suppression fixed — early return + log + reset to idle
- [x] [Review][Patch] `confirmConsume` catch blocks use `_setErrorKeepBottle` helper (respects `_disposed`)
- [x] [Review][Patch] Cancel button added alongside retry in error state when `canRetryConsume` true

## Dev Notes

### Scope: Hardening, Not Rewriting

Story 2.4 already implements the core error handling. This story adds:
1. **gRPC deadlines** — prevent indefinite hangs (deferred from 2.4 review)
2. **Better error messages** — "Serveur injoignable" + WiFi hint per spec
3. **Duplicate tag suppression** — FR5 requirement
4. **Connection drop resilience** — preserve confirmation screen, retry consume

This is NOT about adding `connectivity_plus`, circuit breakers, or offline mode. Those are post-MVP.

### gRPC Deadlines

Add `CallOptions(timeout: Duration(seconds: 5))` to both RPC calls:

```dart
final bottle = await client.getBottleByTagId(
  GetBottleByTagIdRequest(tagId: uid),
  options: CallOptions(timeout: const Duration(seconds: 5)),
);

await client.consumeBottle(
  ConsumeBottleRequest(tagId: _tagId!),
  options: CallOptions(timeout: const Duration(seconds: 5)),
);
```

5s timeout is generous for local network. If exceeded, `DEADLINE_EXCEEDED` maps to `S.timeout`.

### Enhanced Error Messages

Current state concatenates generic strings. Improve with compound messages:

```dart
// strings.dart additions
static const serverUnreachableWithHint = 'Serveur injoignable\nVerifiez votre connexion WiFi';
static const noTagDetectedWithHint = 'Aucun tag detecte — reessayez';
```

Update `_mapGrpcError` to use hint-enhanced messages for `UNAVAILABLE`.

### Duplicate Tag Suppression (FR5)

Track last scanned tag to prevent double-processing:

```dart
String? _lastScannedTagId;

Future<void> startScan(WineTapClient client) async {
  // ... read NFC tag ...
  if (uid == _lastScannedTagId && (_state == ScanState.found || _state == ScanState.consumed)) {
    return; // silently ignore duplicate
  }
  _lastScannedTagId = uid;
  // ... proceed with lookup ...
}
```

Reset on `cancel()` and `reset()`.

### Connection Drop During Confirmation

The key UX requirement: if the user is looking at bottle details (found state) and the WiFi drops, tapping "Confirmer" should not lose the confirmation screen.

```dart
Future<void> confirmConsume(WineTapClient client) async {
  if (_state != ScanState.found || _tagId == null) return;
  _setState(ScanState.consuming);

  try {
    await client.consumeBottle(
      ConsumeBottleRequest(tagId: _tagId!),
      options: CallOptions(timeout: const Duration(seconds: 5)),
    );
    _setState(ScanState.consumed);
  } on GrpcError catch (e) {
    // Keep _bottle populated so retry can show details
    _setError(_mapGrpcError(e));
  }
}
```

The error screen retry button should re-attempt `confirmConsume` (not `startScan`) when bottle details are still available:

```dart
// In ConsumeScreen error state:
if (scan.bottle != null && scan.tagId != null) {
  // Show "Reessayer la confirmation" button -> calls confirmConsume
} else {
  // Show "Scanner" button -> calls startScan
}
```

### What Already Works (Verify, Don't Reimplement)

These ACs are already satisfied by Story 2.4:
- AC1: ScanProvider has 6 states including error with French message
- AC3: NOT_FOUND -> S.unknownTag
- AC5: NfcSessionCancelledException -> silent idle return

### What NOT to Do

- Do NOT add `connectivity_plus` package — deferred, app lifecycle + backoff is sufficient for MVP
- Do NOT implement circuit breaker — overkill for solo user
- Do NOT add offline mode or caching — server must be reachable per PRD constraints
- Do NOT add cancellation tokens to in-flight gRPC — Dart gRPC doesn't support true cancellation; timeout is the mechanism
- Do NOT change the ScanState enum — the 6 states from 2.4 are sufficient; the epics AC1 mentions "idle, scanning, result, error" but the actual implementation uses finer-grained states which is correct

### Previous Story Intelligence

Story 2.4 deferred items now in scope:
- "cancel() doesn't cancel in-flight gRPC call" — addressed via deadlines (5s timeout acts as cancellation)
- "No gRPC deadline on consume/lookup calls" — Task 1

Story 2.3 deferred items NOT in scope:
- "NFR7 needs connectivity_plus listener" — post-MVP
- "No mutex on connect/reconnect interleaving" — generation counter mitigates

Story 2.4 established:
- ScanProvider with 6-state machine, gRPC error mapping, auto-reset timer
- ConsumeScreen with switch-based rendering, cancel button during scanning
- SnackBar for null client
- Disposal guards and double-tap prevention

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 2.5 ACs (lines 420-454)
- [Source: mobile/lib/providers/scan_provider.dart] — Current error handling, _mapGrpcError
- [Source: mobile/lib/screens/consume_screen.dart] — Error state rendering
- [Source: mobile/lib/l10n/strings.dart] — Available French error strings
- [Source: _bmad-output/implementation-artifacts/2-4-consume-flow-scan-confirm-consume.md] — Deferred items

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Added 5s `CallOptions(timeout)` to both gRPC calls — prevents indefinite hangs
- Enhanced error messages: UNAVAILABLE now shows WiFi hint, NFC timeout shows retry hint
- Added `S.serverUnreachableWithHint`, `S.noTagDetectedWithHint`, `S.retryConsume` to strings.dart
- Duplicate tag suppression via `_lastScannedTagId` — cleared on cancel/reset
- Connection drop resilience: `confirmConsume` keeps `_bottle` on failure, `canRetryConsume` getter enables retry-consume button in error state
- Error screen now shows bottle details card when available + context-appropriate retry (consume retry vs full re-scan)
- Default gRPC error mapping now uses hint-enhanced messages
- All existing error paths (AC1/3/5) verified working from Story 2.4

### Change Log

- 2026-03-31: Error handling hardening — gRPC deadlines, enhanced messages, duplicate suppression, connection drop resilience

### File List

- mobile/lib/providers/scan_provider.dart (modified — deadlines, duplicate suppression, retry consume)
- mobile/lib/screens/consume_screen.dart (modified — retry consume button, bottle card in error state)
- mobile/lib/l10n/strings.dart (modified — 3 new compound error strings)
