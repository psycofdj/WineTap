# Story 4.3: Intake Error Handling, Cancellation, and Timeout

Status: done

## Story

As a user,
I want clear feedback when things go wrong during intake scanning, and clean recovery,
So that I never lose my desktop form data or end up in a stuck state.

## Acceptance Criteria

1. **Given** the manager cancels a pending scan request (FR17)
   **When** the server sends a `ScanError` with cancellation reason
   **Then** the intake screen returns to "En attente..." immediately
   **And** any active NFC session is stopped
   **And** transition to idle happens within 1s

2. **Given** the manager's 30s timeout expires (FR18)
   **When** the server sends a `ScanError` with timeout reason
   **Then** the intake screen displays "Delai depasse" briefly
   **And** returns to "En attente..."

3. **Given** the NFC read fails (bad angle, no tag detected)
   **When** `NfcService` throws `NfcReadTimeoutException`
   **Then** the screen displays "Aucun tag detecte — reessayez" (FR25, FR27)
   **And** the scan request remains active for retry (FR19, NFR8)
   **And** in continuous mode, NFC remains active for the next attempt

4. **Given** the user cancels the iOS NFC sheet during intake
   **Then** the screen shows "Scan annule — reessayez"
   **And** the scan request remains active for retry (FR19)

5. **Given** the scanned tag is already associated with an in-stock bottle
   **When** the server returns a `ScanError` with "already in use" reason
   **Then** the screen displays "Tag deja utilise" (FR25)
   **And** continuous mode stays active

6. **Given** the server becomes unreachable during intake
   **Then** the screen displays "Serveur injoignable" (FR25)
   **And** the bidi stream reconnects when the connection recovers

7. **Given** the connection recovers after a disruption
   **When** the bidi stream is re-established
   **Then** if the manager still has a pending scan request, the mobile resumes intake seamlessly

## Tasks / Subtasks

- [ ] Task 1: Improve ScanError handling in IntakeProvider (AC: #1, #2, #5)
  - [ ] Distinguish cancellation (`cancelled`) -> stop NFC, return to waitingForRequest
  - [ ] Distinguish timeout (`timeout`) -> show "Delai depasse" briefly, return to waitingForRequest
  - [ ] Distinguish tag-in-use errors -> show "Tag deja utilise", stay in continuous mode if active
  - [ ] Other server errors -> show error message
- [ ] Task 2: NFC failure keeps scan request active (AC: #3, #4)
  - [ ] Single mode: NfcReadTimeoutException -> show error but remain in scanRequested (not waitingForRequest)
  - [ ] Single mode: NfcSessionCancelledException -> show "Scan annule — reessayez", remain in scanRequested
  - [ ] Continuous mode: NFC errors already handled by continuousRead() retry loop — verify
  - [ ] Add `S.scanCancelledRetry` string
- [ ] Task 3: Connection drop and recovery (AC: #6, #7)
  - [ ] On stream error: show "Serveur injoignable", stop NFC, set state to error
  - [ ] Watch ConnectionProvider state — when connected again, auto-reopen stream
  - [ ] Add `WidgetsBindingObserver` or ConnectionProvider listener to IntakeProvider
- [ ] Task 4: Update IntakeScreen error UI (AC: #1, #2, #3, #4, #5)
  - [ ] Error state shows specific message with retry button
  - [ ] Retry from error returns to scanRequested (not waitingForRequest) if scan request was active
  - [ ] Timeout shows briefly then auto-resets
- [ ] Task 5: Verification
  - [ ] Run `flutter analyze` — no issues
  - [ ] Run `flutter test` — all tests pass
  - [ ] Run `flutter build apk --debug` — builds successfully

## Dev Notes

### What Already Works (Verify, Don't Reimplement)

Current IntakeProvider already handles:
- `ScanError` with "cancelled" -> `waitingForRequest` + stop continuous (line 199)
- Other `ScanError` -> `_setError(reason)` (line 205)
- Stream error -> `_setError(S.serverUnreachable)` + cleanup (line 57)
- NfcSessionCancelledException in single mode -> `scanRequested` (line 98)
- NfcReadTimeoutException in single mode -> `_setError()` (line 101)
- Continuous mode NFC errors -> retry loop in `continuousRead()`

### What Needs to Change

1. **Timeout ScanError handling**: currently lumped with other errors. Need to show "Delai depasse" briefly then auto-reset to `waitingForRequest`.

2. **Tag-in-use ScanError**: server sends this when tag is already associated. Need to show error but keep continuous mode alive — don't call `_stopContinuous()`.

3. **NFC failure should keep scan request active (FR19)**: Currently single-mode NFC timeout goes to `error` state. Should go to `scanRequested` instead (user can retry without manager re-sending request).

4. **iOS NFC cancel should show message**: Currently goes silently to `scanRequested`. Should show "Scan annule — reessayez" briefly.

5. **Connection recovery**: Currently stream error kills everything. Need to watch for reconnection and auto-reopen stream.

### ScanError Classification

Server sends `ScanError.reason` as a string. Classify:

```dart
void _handleScanError(String reason) {
  if (reason == 'cancelled') {
    _stopContinuous();
    _setState(IntakeState.waitingForRequest);
  } else if (reason == 'timeout') {
    _stopContinuous();
    _showBriefError(S.timeout); // show 2s, then waitingForRequest
  } else if (reason.contains('already in use')) {
    // Tag in use — show error but keep continuous mode alive
    _showBriefError(S.tagInUse);
  } else {
    _stopContinuous();
    _setError(reason);
  }
}
```

### NFC Failure -> Scan Request Stays Active

Change single-mode NFC error handling:

```dart
// Before (goes to error, losing scan request):
on NfcReadTimeoutException {
  _setError(S.noTagDetectedWithHint);
}

// After (stays in scanRequested, user can retry):
on NfcReadTimeoutException {
  _showBriefError(S.noTagDetectedWithHint); // show briefly, then scanRequested
}
```

### Connection Recovery

Add a method to detect when ConnectionProvider transitions back to `connected`:

```dart
void onConnectionRestored(WineTapClient client) {
  if (_state == IntakeState.error || _state == IntakeState.idle) {
    openStream(client); // re-establish bidi stream
  }
}
```

Call this from IntakeScreen when it detects ConnectionProvider state change. The screen already watches ConnectionProvider for the indicator — can add logic there.

### New Strings

```dart
static const scanCancelledRetry = 'Scan annulé — réessayez';
```

### What NOT to Do

- Do NOT modify the server coordination handler
- Do NOT modify the manager NFCScanner
- Do NOT add complex retry/backoff — simple reconnect on connection recovery is sufficient
- Do NOT change the consume flow error handling (Story 2.5 already covers that)

### Previous Story Intelligence

Story 4.2 established:
- IntakeProvider with `continuousReady` state, `_stopContinuous()`, `_startContinuousRead()`
- ScanError handling: "cancelled" -> waitingForRequest, other -> _setError

Story 4.1 established:
- IntakeProvider bidi stream via StreamController
- IntakeScreen with state-based UI

Story 2.5 established:
- Consume flow error handling pattern: gRPC deadlines, enhanced messages, connection drop resilience
- `_showBriefError` pattern (show error briefly, auto-reset) — not in IntakeProvider yet

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 4.3 ACs (lines 662-705)
- [Source: mobile/lib/providers/intake_provider.dart] — Current error handling (lines 95-107, 195-207)
- [Source: mobile/lib/l10n/strings.dart] — Existing error strings

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
