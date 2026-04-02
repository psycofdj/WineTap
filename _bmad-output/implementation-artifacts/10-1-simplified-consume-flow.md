# Story 10.1: Simplified Consume Flow

Status: done

## Story

As a **wine collector**,
I want to tap "Consommer une bouteille", scan a bottle, and see it marked as consumed immediately,
so that consuming a bottle takes two taps total with no unnecessary confirmation step.

## Acceptance Criteria

1. **Given** the user is on the home screen **When** they tap "Consommer une bouteille" **Then** the NFC scan session starts immediately **And** the button label reads "Consommer une bouteille" (not "Scanner")

2. **Given** an NFC scan session is active **When** the user taps "Annuler" before scanning a tag **Then** the scan session ends and the user returns to the home screen **And** no bottle state is modified

3. **Given** an NFC scan session is active **When** the phone reads a tag associated with an in-stock bottle **Then** the bottle is marked as consumed immediately (no confirmation step) **And** the screen displays bottle details: cuvée, domain, vintage, appellation **And** the screen displays "Marquée comme consommée ✓" **And** a single "Terminé" button is shown (no "Confirmer"/"Annuler")

4. **Given** the post-consume feedback screen is displayed **When** the user taps "Terminé" **Then** the user returns to the home screen

5. **Given** an NFC scan session is active **When** the phone reads a tag not associated with any in-stock bottle **Then** the screen displays "Tag inconnu" error **And** a single "Terminé" button returns to home (retry = re-initiate from home)

6. **Given** the codebase after this story **When** reviewing ScanProvider and ConsumeScreen **Then** no confirmation state (found), Confirmer/Annuler dialog, or retryConsume path exists **And** all existing tests pass with updated flows

**Covers:** FR3, FR7, FR8, FR10 + legacy cleanup

## Tasks / Subtasks

- [x] Task 1: Simplify ScanState enum and ScanProvider (AC: #1, #2, #3, #5)
  - [x] Remove `found` and `consuming` states from `ScanState` enum — new flow: idle → scanning → consumed | error
  - [x] In `startScan()`: after successful `db.getBottleByTagId(uid)`, immediately call `db.consumeBottle(tagId)` — combine lookup + consume into a single transition (scanning → consumed)
  - [x] Remove `confirmConsume()` method entirely
  - [x] Remove `canRetryConsume` property and retry-confirmation logic
  - [x] Update `cancel()` to only work during `scanning` state (not `found`)
  - [x] Remove the 3-second auto-reset timer from `consumed` state — user taps "Terminé" manually
  - [x] Update error state: remove "Réessayer la confirmation" path, error only shows "Terminé" to go home

- [x] Task 2: Update ConsumeScreen UI (AC: #3, #4, #5)
  - [x] Remove the `_buildFound()` widget (confirmation screen with Confirmer/Annuler)
  - [x] Update `_buildConsumed()`: replace auto-reset with a "Terminé" button that calls `provider.reset()`
  - [x] Update `_buildError()`: replace "Réessayez"/"Réessayer la confirmation" with a single "Terminé" button that calls `provider.reset()`
  - [x] Remove any widget references to `ScanState.found` or `ScanState.consuming`

- [x] Task 3: Rename home screen button (AC: #1)
  - [x] In `mobile/lib/l10n/strings.dart`: change `scanButton` to `consumeButton` = "Consommer une bouteille"
  - [x] In `mobile/lib/main.dart` HomeScreen: update BottomNavigationBar label for consume tab to use the new string
  - [x] Update `widget_test.dart` to find "Consommer une bouteille" instead of "Scanner"

- [x] Task 4: Update strings (AC: #3, #4, #5)
  - [x] Remove `confirm` ("Confirmer") string — no longer used
  - [x] Remove `retryConsume` ("Réessayer la confirmation") string — no longer used
  - [x] Add `done` = "Terminé" string (used on consumed and error screens)
  - [x] Keep `cancel` ("Annuler") — still used during NFC scanning
  - [x] Updated `markedAsConsumed` to "Marquée comme consommée ✓" per PRD Journey 1
  - [x] Keep `readyToScan` — still used by IntakeScreen (Story 10.2 scope)

- [x] Task 5: Write and update tests (AC: #6)
  - [x] Created `mobile/test/providers/scan_provider_test.dart` — 14 tests
    - Test idle → scanning transition on `startScan()`
    - Test scanning → consumed transition (auto-consume on tag read, no `found` state)
    - Test scanning → error on unknown tag
    - Test cancel during scanning → idle
    - Test duplicate tag suppression (FR5)
    - Test reset from consumed → idle
    - Test reset from error → idle
  - [x] Updated `mobile/test/widget_test.dart`: "Consommer une bouteille" instead of "Scanner"
  - [x] Made NfcService injectable via optional constructor parameter for testing
  - [x] Full test suite: 213 tests pass, 0 failures

## Dev Notes

### Architecture Compliance

- **AR7**: ScanProvider calls drift directly — no HTTP roundtrip. Consume is local. This is unchanged.
- **Anti-pattern**: Do NOT route consume through the shelf HTTP server. `db.getBottleByTagId()` and `db.consumeBottle()` are called directly on the drift instance.
- **Logging**: Use `dart:developer` `log()` — never `print()`.

### Current State Machine (BEFORE — to remove)

```
idle → scanning → found → consuming → consumed → (auto-reset 3s) → idle
                    ↓                      ↓
                  cancel                 error → retry
```

### New State Machine (AFTER)

```
idle → scanning → consumed → (user taps "Terminé") → idle
          ↓           
        error → (user taps "Terminé") → idle
          ↓
        cancel → idle
```

### Key Files to Modify

| File | Change |
|------|--------|
| `mobile/lib/providers/scan_provider.dart` | Remove `found`/`consuming` states, merge lookup+consume, remove `confirmConsume()`, remove auto-reset timer |
| `mobile/lib/screens/consume_screen.dart` | Remove `_buildFound()`, update consumed/error screens with "Terminé" button |
| `mobile/lib/l10n/strings.dart` | Rename `scanButton`, remove `confirm`/`retryConsume`, add `done` |
| `mobile/lib/main.dart` | Update BottomNavigationBar label |
| `mobile/test/providers/scan_provider_test.dart` | CREATE — full unit test suite for new simplified flow |
| `mobile/test/widget_test.dart` | Update button text assertion |

### Project Structure Notes

- All files are under `mobile/lib/` — standard Flutter project structure
- Provider pattern: extends `ChangeNotifier`, UI watches via `context.watch<ScanProvider>()`
- Drift database instance passed as constructor parameter to ScanProvider
- NFC service passed as constructor parameter to ScanProvider

### References

- [Source: _bmad-output/planning-artifacts/prd-mobile.md — FR3, FR7, FR8, FR10]
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md — AR7: ScanProvider calls drift directly]
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md — Anti-Patterns: ❌ Consume flow through HTTP]
- [Source: mobile/lib/providers/scan_provider.dart — current ScanState enum and confirmConsume() method]
- [Source: mobile/lib/screens/consume_screen.dart — current _buildFound() widget]
- [Source: mobile/lib/l10n/strings.dart — current string constants]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Simplified ScanState enum from 6 states to 4 (removed `found`, `consuming`)
- Merged lookup + consume into a single transition in `startScan()` — no confirmation step
- Removed `confirmConsume()`, `canRetryConsume`, `_setErrorKeepBottle()`, auto-reset timer
- ConsumeScreen now shows "Terminé" button on both consumed and error states (no retry-confirmation path)
- Button renamed from "Scanner" to "Consommer une bouteille"
- `markedAsConsumed` updated from "Marquée comme bue ✓" to "Marquée comme consommée ✓"
- Made NfcService injectable via optional constructor parameter (same pattern as IntakeProvider)
- Created 14 new scan_provider tests covering full simplified flow
- `readyToScan` string kept — still used by IntakeScreen (Story 10.2 will remove it)
- Full suite: 213 tests pass, 0 regressions

### File List

- mobile/lib/providers/scan_provider.dart (modified)
- mobile/lib/screens/consume_screen.dart (modified)
- mobile/lib/l10n/strings.dart (modified)
- mobile/lib/main.dart (modified)
- mobile/test/providers/scan_provider_test.dart (created)
- mobile/test/widget_test.dart (modified)
