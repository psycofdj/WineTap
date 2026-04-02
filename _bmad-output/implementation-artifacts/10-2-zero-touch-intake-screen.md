# Story 10.2: Zero-Touch Intake Screen

Status: done

## Story

As a **wine collector using the desktop manager**,
I want the phone to automatically switch to the intake scan screen when the manager requests a scan,
so that I never need to touch the phone during intake.

## Acceptance Criteria

1. **Given** the phone is on any screen (home, post-consume feedback, settings) **When** the server receives a scan request from the manager **Then** the phone automatically switches to the intake scan screen **And** NFC scanning initiates without any user interaction **And** the intake scan screen displays "Ajout en cours — Scannez le tag pour le manager"

2. **Given** the phone is on the intake scan screen **When** an NFC tag is read **Then** the tag UID is relayed to the manager (via ScanCoordinator) **And** the phone returns to the home screen automatically

3. **Given** the phone is on the intake scan screen **When** the manager cancels the scan request **Then** the phone returns to the home screen automatically

4. **Given** the phone is in continuous intake mode (bulk intake) **When** the manager sends consecutive scan requests **Then** the phone stays on the intake scan screen with NFC active between reads **And** no user interaction is required on the phone at any point

5. **Given** the codebase after this story **When** reviewing IntakeProvider and IntakeScreen **Then** no "Prêt à scanner" button or manual scan initiation exists **And** NFC scanning starts automatically when the intake screen is shown **And** all existing intake_provider tests pass with updated flows

**Covers:** FR12, FR13, FR16, FR19c + legacy cleanup

## Tasks / Subtasks

- [x] Task 1: Simplify IntakeState enum and IntakeProvider (AC: #1, #2, #3, #4)
  - [x] Removed `scanRequested` state from enum — flow: idle → waitingForRequest → scanning → tagSent → waitingForRequest (single) | continuousReady (continuous)
  - [x] When coordinator has pending request, immediately transition to `scanning` and call NFC read automatically
  - [x] Removed manual `startNfcScan()` public method — NFC starts automatically on request detection
  - [x] After `tagSent` in single mode: 1s delay then returns to waitingForRequest (HomeScreen auto-switches to tab 0)
  - [x] After `tagSent` in continuous mode: 800ms delay then continuousReady, auto-continues
  - [x] Removed `retryFromError()` — errors auto-retry by returning to `scanning`
  - [x] Removed `_briefErrorActive` flag — no longer needed

- [x] Task 2: Auto-navigate to intake screen on scan request (AC: #1)
  - [x] Added `shouldShowIntakeScreen` getter — true when state != idle and != waitingForRequest
  - [x] HomeScreen watches IntakeProvider via `context.watch()` and auto-switches tab index
  - [x] Uses `addPostFrameCallback` to avoid setState during build
  - [x] Works regardless of current screen (consume, settings, etc.)

- [x] Task 3: Auto-navigate back to home after scan/cancel (AC: #2, #3)
  - [x] After single scan completes → tagSent → 1s → waitingForRequest → shouldShowIntakeScreen=false → HomeScreen switches to tab 0
  - [x] After manager cancels → waitingForRequest → HomeScreen switches to tab 0
  - [x] In continuous mode → stays on intake screen (shouldShowIntakeScreen=true)

- [x] Task 4: Update IntakeScreen UI (AC: #1, #5)
  - [x] Removed `_buildScanRequested()` widget entirely (no "Prêt à scanner" button)
  - [x] Updated `_buildScanning()` to show S.intakeInProgress label with CircularProgressIndicator
  - [x] Removed cancel button from scanning state (fully passive)
  - [x] Removed retry button from error state (auto-retries)
  - [x] Kept tagSent and continuousReady visual feedback

- [x] Task 5: Update strings (AC: #1)
  - [x] Removed `readyToScan` ("Prêt à scanner")
  - [x] Added `intakeInProgress` = "Ajout en cours — Scannez le tag pour le manager"
  - [x] Kept `continuousMode` and `continuousReady` strings

- [x] Task 6: Update tests (AC: #5)
  - [x] Rewrote intake_provider_test.dart — 13 tests (was 14, restructured for new flow)
    - Removed all tests for `scanRequested` state
    - Removed tests for manual `startNfcScan()` and `retryFromError()`
    - Added tests for auto-scan on request detection
    - Added tests for `shouldShowIntakeScreen` navigation flag
    - Added test for auto-return to waitingForRequest after single scan
    - Updated error recovery tests (auto-retry to scanning, not scanRequested)
  - [x] widget_test.dart had no references to "Prêt à scanner" — no change needed
  - [x] Full suite: 215 tests pass, 0 regressions

## Dev Notes

### Architecture Compliance

- **AR12**: Scan state is ephemeral — ScanCoordinator uses Completer + mode, memory only.
- **Polling**: IntakeProvider polls ScanCoordinator at 500ms interval. This is unchanged — the change is what happens AFTER detecting a request (auto-scan instead of showing button).
- **NFC service**: Use same `_nfcService.readTagId()` for single and `_nfcService.continuousRead()` for continuous. Unchanged.
- **Logging**: Use `dart:developer` `log()` — never `print()`.

### Current State Machine (BEFORE — to change)

```
idle → waitingForRequest → scanRequested → [USER TAPS "Prêt à scanner"] → scanning → tagSent → (2s delay) → waitingForRequest
                                                                                                    ↓ (continuous)
                                                                                              continuousReady → scanning
```

### New State Machine (AFTER)

```
idle → waitingForRequest → scanning (auto) → tagSent → HOME (single) | continuousReady (continuous)
                                    ↓
                                  error → (2s) → scanning (auto-retry)
```

### Navigation Architecture Decision

The key design decision is how IntakeProvider (a ChangeNotifier) triggers navigation to the intake tab. Recommended approach:

**Option: Flag-based with HomeScreen watch.**
IntakeProvider exposes a `bool shouldShowIntakeScreen` property. HomeScreen watches this and switches `_currentIndex` to 1 when true, back to 0 when false. This keeps navigation in the widget layer (Flutter convention) while the provider controls intent.

```dart
// In IntakeProvider
bool get shouldShowIntakeScreen => _state != IntakeState.idle;

// In HomeScreen build()
final intake = context.watch<IntakeProvider>();
if (intake.shouldShowIntakeScreen && _currentIndex != 1) {
  setState(() => _currentIndex = 1);
}
if (!intake.shouldShowIntakeScreen && _currentIndex == 1) {
  setState(() => _currentIndex = 0);
}
```

### Key Files to Modify

| File | Change |
|------|--------|
| `mobile/lib/providers/intake_provider.dart` | Remove `scanRequested` state, auto-start NFC on request detection, add navigation flag |
| `mobile/lib/screens/intake_screen.dart` | Remove `_buildScanRequested()`, update scan screen label to "Ajout en cours…" |
| `mobile/lib/main.dart` | HomeScreen watches IntakeProvider for auto-tab-switch |
| `mobile/lib/l10n/strings.dart` | Remove `readyToScan`, add `intakeInProgress` |
| `mobile/test/providers/intake_provider_test.dart` | Update 204 tests for new flow |
| `mobile/test/widget_test.dart` | Update if references "Prêt à scanner" |

### Dependency on Story 10.1

Story 10.2 can be implemented independently of 10.1. The intake flow is separate from consume. However, if both are in the same sprint, the HomeScreen changes (tab switching) should be coordinated.

### Project Structure Notes

- IntakeProvider is provided at app root level via `MultiProvider` in `main.dart`
- IntakeScreen is index 1 in `HomeScreen._screens` (IndexedStack)
- ScanCoordinator is shared between shelf handlers (write) and IntakeProvider (read)

### References

- [Source: _bmad-output/planning-artifacts/prd-mobile.md — FR12, FR13, FR16, FR19c]
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md — AR12: ephemeral scan state]
- [Source: mobile/lib/providers/intake_provider.dart — current IntakeState enum, startNfcScan(), polling]
- [Source: mobile/lib/screens/intake_screen.dart — _buildScanRequested() with "Prêt à scanner"]
- [Source: mobile/lib/l10n/strings.dart — readyToScan constant]
- [Source: mobile/test/providers/intake_provider_test.dart — 204 existing tests]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Removed `scanRequested` state from IntakeState enum (6 states → 5, was 7 originally)
- Removed `startNfcScan()` public method — NFC auto-starts when request detected by polling
- Removed `retryFromError()` — errors auto-retry to `scanning` state
- Added `shouldShowIntakeScreen` getter for HomeScreen auto-tab-switching
- HomeScreen now watches IntakeProvider and switches tabs via addPostFrameCallback
- IntakeScreen: removed `_buildScanRequested()` (Prêt à scanner), removed cancel/retry buttons from scanning/error
- New label: "Ajout en cours — Scannez le tag pour le manager" (FR19c)
- Removed `readyToScan` string, added `intakeInProgress`
- Error flow now returns to `scanning` (auto-retry) instead of `scanRequested`
- Single mode tagSent delay reduced from 2s to 1s, then auto-returns to waitingForRequest
- Rewrote 13 intake_provider tests for simplified flow
- Full suite: 215 tests pass, 0 regressions

### File List

- mobile/lib/providers/intake_provider.dart (modified)
- mobile/lib/screens/intake_screen.dart (modified)
- mobile/lib/l10n/strings.dart (modified)
- mobile/lib/main.dart (modified — HomeScreen auto-tab-switch)
- mobile/test/providers/intake_provider_test.dart (rewritten — 13 tests)
