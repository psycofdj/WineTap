# Story 4.2: Continuous Scan Mode for Bulk Intake

Status: done

## Story

As a user,
I want the phone to stay in scanning mode during bulk intake,
So that I can tag and scan multiple bottles rapidly without tapping "Pret a scanner" between each one.

## Acceptance Criteria

1. **Given** the manager initiates a scan request with continuous mode (FR15, FR16)
   **When** the `ScanRequestNotification` includes `SCAN_MODE_CONTINUOUS`
   **Then** the screen displays "Mode continu — scanner les bouteilles"
   **And** the user taps "Pret a scanner" once for the first scan

2. **Given** continuous mode is active after the first scan
   **When** the server acknowledges the first result (ScanAck)
   **Then** NFC remains active — the phone is immediately ready for the next tag
   **And** the screen shows "Pret" indicating NFC is active
   **And** on iOS, NFC session restarts between reads (< 1.5s overhead, NFR5)

3. **Given** a tag is read in continuous mode
   **Then** a `ScanResult` is sent to the server automatically
   **And** "Tag lu" flashes briefly, then returns to "Pret"
   **And** time between reads is under 500ms on Android, under 1.5s on iOS (NFR5)

4. **Given** the same tag is read twice in succession (FR5, NFR14)
   **Then** the duplicate is silently ignored — no `ScanResult` sent
   **And** no error is shown to the user

5. **Given** continuous mode is active
   **When** the manager sends a new scan request (from "Ajouter la meme")
   **Then** continuous mode persists — no interruption on the mobile side

## Tasks / Subtasks

- [ ] Task 1: Implement `continuousRead()` on NfcService (AC: #2, #3)
  - [ ] Add `Stream<String> continuousRead()` to `NfcService`
  - [ ] Android: after each tag read, immediately restart NFC polling
  - [ ] iOS: stop session after read, brief delay, start new session (handles iOS single-session limit)
  - [ ] Yield normalized tag ID strings
  - [ ] Stop stream via `stopReading()`
- [ ] Task 2: Add duplicate tag suppression (AC: #4)
  - [ ] Track `_lastContinuousTagId` in IntakeProvider
  - [ ] Skip sending ScanResult if same tag as last
  - [ ] Reset on new scan request or mode change
- [ ] Task 3: Update IntakeProvider for continuous mode (AC: #1, #2, #3, #5)
  - [ ] Detect `SCAN_MODE_CONTINUOUS` in `ScanRequestNotification`
  - [ ] After first user tap + NFC read, switch to continuous loop
  - [ ] On ScanAck in continuous mode: auto-restart NFC read (no user action)
  - [ ] On new ScanRequestNotification while continuous active: no-op (AC #5)
  - [ ] Add new state: `continuousReady` — NFC active, waiting for next tag
- [ ] Task 4: Update IntakeScreen for continuous mode UI (AC: #1, #2, #3)
  - [ ] Show "Mode continu — scanner les bouteilles" when continuous requested
  - [ ] After first scan: show "Pret" with active NFC indicator
  - [ ] Flash "Tag lu" briefly on each scan, return to "Pret"
  - [ ] Add new strings to S class
- [ ] Task 5: Verification
  - [ ] Run `flutter analyze` — no issues
  - [ ] Run `flutter test` — all tests pass
  - [ ] Run `flutter build apk --debug` — builds successfully

## Dev Notes

### continuousRead() Implementation

The architecture spec defines this as a Stream:

```dart
Stream<String> continuousRead() async* {
  while (true) {
    try {
      final tagId = await readTagId();
      yield tagId;
    } on NfcSessionCancelledException {
      return; // user cancelled — stop stream
    } on NfcReadTimeoutException {
      continue; // timeout — retry automatically
    }
  }
}
```

On **iOS**, each `readTagId()` creates a new NFC session (system sheet appears briefly each time). The < 1.5s target (NFR5) accounts for this overhead. On **Android**, the session stays active naturally.

### Duplicate Tag Suppression

In continuous mode, the same physical tag may be read multiple times as the user holds the phone near it. Track the last tag ID and skip duplicates:

```dart
String? _lastContinuousTagId;

void _onContinuousTag(String tagId) {
  if (tagId == _lastContinuousTagId) return; // duplicate — skip
  _lastContinuousTagId = tagId;
  _sendScanResult(tagId);
}
```

Reset `_lastContinuousTagId` when:
- A new `ScanRequestNotification` arrives
- The user cancels
- Switching away from continuous mode

### IntakeProvider Continuous Flow

```
ScanRequestNotification(CONTINUOUS)
  ↓
SCAN_REQUESTED ("Mode continu — scanner les bouteilles")
  ↓ (user taps "Pret a scanner")
SCANNING (first NFC read)
  ↓ (tag read)
TAG_SENT (send ScanResult, flash "Tag lu")
  ↓ (ScanAck received)
CONTINUOUS_READY ("Pret" — NFC active, waiting for next tag)
  ↓ (next tag read automatically)
TAG_SENT (send ScanResult, flash "Tag lu")
  ↓ (ScanAck received)
CONTINUOUS_READY (loop continues)
```

The key difference from single mode: after `ScanAck`, instead of returning to `waitingForRequest`, transition to `continuousReady` and auto-start the next NFC read.

### New Strings

```dart
static const continuousMode = 'Mode continu — scanner les bouteilles';
static const continuousReady = 'Prêt';
```

### What NOT to Do

- Do NOT implement error handling for continuous mode — that's Story 4.3
- Do NOT modify the server coordination handler — it already handles continuous mode (Story 3.1: Resolve loops back to SCANNING)
- Do NOT add timeout handling — that's Story 4.3

### Previous Story Intelligence

Story 4.1 established:
- IntakeProvider with bidi stream via StreamController pattern
- IntakeScreen with state-based UI rendering
- ScanRequestNotification handling with `_requestedMode` field
- NfcService.readTagId() for single reads

Story 2.2 established:
- NfcService with _sessionActive tracking, iOS session management
- readTagId() with timeout timer

Story 3.1 established:
- Server continuous mode: Resolve transitions back to SCANNING (not IDLE)
- ScanAck relayed on each successful scan in continuous mode

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 4.2 ACs (lines 629-661)
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — NfcService continuousRead() spec (line ~467), NFR5 timing (line ~51)
- [Source: mobile/lib/providers/intake_provider.dart] — Current IntakeProvider with _requestedMode
- [Source: mobile/lib/services/nfc_service.dart] — readTagId(), _sessionActive, stopReading()

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
