# Story 10.3: Intake-Over-Consume Priority

Status: done

## Story

As a **wine collector**,
I want intake scan requests to take priority over an active consume scan,
so that the manager is never blocked waiting when I happen to be consuming a bottle.

## Acceptance Criteria

1. **Given** the user is in an active consume NFC scan (tapped "Consommer une bouteille", NFC session running) **When** the server receives a scan request from the manager **Then** the active consume scan is cancelled **And** the phone switches to the intake scan screen **And** the intake screen displays "Ajout en cours — Scannez le tag pour le manager"

2. **Given** the user was on the post-consume feedback screen (bottle details + "Terminé") **When** the server receives a scan request from the manager **Then** the phone switches to the intake scan screen (interrupting the feedback) **And** the already-consumed bottle is NOT rolled back — consume is final once the tag is read, regardless of whether "Terminé" was tapped

3. **Given** an intake scan interrupted an active consume **When** the intake scan completes and the phone returns to home **Then** the user can re-initiate consume by tapping "Consommer une bouteille" again **And** no bottle state was modified by the interrupted consume (unless a tag was already read and consumed per AC #2)

**Covers:** FR19b

## Tasks / Subtasks

- [x] Task 1: ScanProvider interrupt mechanism (AC: #1, #2)
  - [x] Added `cancelForIntake()` method — resets any state to idle, cancels NFC if scanning
  - [x] Does NOT undo completed consume — once consumeBottle() ran, it's final
  - [x] Cancels NFC via stopReading() when in scanning state

- [x] Task 2: IntakeProvider triggers consume interruption (AC: #1)
  - [x] IntakeProvider accepts optional `ScanProvider` via constructor injection
  - [x] In `_onPollTick()`, calls `_scanProvider?.cancelForIntake()` before starting intake scan
  - [x] main.dart passes ScanProvider to IntakeProvider via `ctx.read<ScanProvider>()`

- [x] Task 3: HomeScreen coordination (AC: #1, #3)
  - [x] Already handled by Story 10.2 — HomeScreen uses `effectiveIndex` based on `shouldShowIntakeScreen`
  - [x] When cancelForIntake() resets ScanProvider to idle, ConsumeScreen shows idle state (ready for fresh tap)
  - [x] IntakeProvider's shouldShowIntakeScreen=true forces tab switch regardless of current ConsumeScreen state

- [x] Task 4: Write tests (AC: #1, #2, #3)
  - [x] scan_provider_test.dart: 5 new tests for cancelForIntake
    - cancelForIntake from idle → no-op
    - cancelForIntake from scanning → idle (NFC stopped)
    - cancelForIntake from consumed → idle (consume NOT rolled back, verified in DB)
    - cancelForIntake from error → idle
  - [x] intake_provider_test.dart: 1 new test for priority mechanism
    - ScanProvider in scanning → intake request → scanProvider.cancelForIntake called → ScanProvider idle → IntakeProvider scanning
  - [x] Full suite: 220 tests pass, 0 regressions

## Dev Notes

### Architecture Compliance

- **AR7**: ScanProvider calls drift directly for consume. The interrupt does NOT route through HTTP.
- **AR12**: Scan state (ScanCoordinator) is ephemeral. The intake request arriving via ScanCoordinator triggers the priority logic.
- **Key invariant**: Once `db.consumeBottle(tagId)` executes, the consume is permanent. `cancelForIntake()` only cancels UI state, never database state.

### Priority Logic Flow

```
User taps "Consommer une bouteille" → ScanProvider: scanning
    ↓
Manager sends POST /scan/request → ScanCoordinator: pending
    ↓
IntakeProvider polling detects pending request
    ↓
IntakeProvider calls scanProvider.cancelForIntake()
    ↓
ScanProvider: cancels NFC session → idle
    ↓
IntakeProvider: starts intake flow → HomeScreen switches to tab 1
    ↓
Intake completes → HomeScreen switches to tab 0
    ↓
User can tap "Consommer une bouteille" again
```

### Edge Case: Tag Read During Interrupt Race

If the NFC tag is read at the exact moment `cancelForIntake()` is called:
- If `consumeBottle()` already executed: bottle is consumed, ScanProvider goes to `consumed`, then `cancelForIntake()` resets to idle. No rollback. Correct.
- If `cancelForIntake()` runs before `consumeBottle()`: NFC cancelled, no consume happens. User re-initiates later. Correct.
- The drift database handles this atomically — no partial state.

### Dependency on Stories 10.1 and 10.2

This story requires:
- **Story 10.1** implemented: ScanProvider has the simplified state machine (no `found`/`consuming` states) and `cancelForIntake()` only needs to handle `idle`, `scanning`, `consumed`, `error`
- **Story 10.2** implemented: IntakeProvider auto-starts NFC on request detection and manages tab navigation

### Key Files to Modify

| File | Change |
|------|--------|
| `mobile/lib/providers/scan_provider.dart` | Add `cancelForIntake()` method |
| `mobile/lib/providers/intake_provider.dart` | Inject ScanProvider, call `cancelForIntake()` before intake flow |
| `mobile/lib/main.dart` | Pass ScanProvider to IntakeProvider in MultiProvider setup |
| `mobile/test/providers/scan_provider_test.dart` | Add cancelForIntake tests |
| `mobile/test/providers/intake_provider_test.dart` | Add priority interrupt tests |

### Project Structure Notes

- Both providers are created in `main.dart` MultiProvider. ScanProvider is created before IntakeProvider, so it can be injected.
- ScanCoordinator is shared: shelf handlers write to it, IntakeProvider reads from it. No change needed to ScanCoordinator.
- No changes to shelf server or REST endpoints — this is purely phone-side UI/state logic.

### References

- [Source: _bmad-output/planning-artifacts/prd-mobile.md — FR19b: intake-over-consume priority]
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md — AR7: ScanProvider calls drift directly]
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md — AR12: ephemeral scan state]
- [Source: mobile/lib/providers/scan_provider.dart — current state machine and NFC service usage]
- [Source: mobile/lib/providers/intake_provider.dart — polling loop and ScanCoordinator integration]
- [Source: mobile/lib/main.dart — MultiProvider setup]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Added `cancelForIntake()` to ScanProvider — handles all states (idle/scanning/consumed/error), cancels NFC if active, never rolls back consume
- IntakeProvider constructor now accepts optional `ScanProvider` for priority mechanism
- In `_onPollTick()`, calls `_scanProvider?.cancelForIntake()` before entering scanning state
- main.dart passes ScanProvider to IntakeProvider via `ctx.read<ScanProvider>()`
- HomeScreen tab switching (Story 10.2) already handles the visual transition
- 5 new cancelForIntake tests + 1 priority integration test
- Full suite: 220 tests pass, 0 regressions

### File List

- mobile/lib/providers/scan_provider.dart (modified — added cancelForIntake)
- mobile/lib/providers/intake_provider.dart (modified — accepts ScanProvider, calls cancelForIntake)
- mobile/lib/main.dart (modified — passes ScanProvider to IntakeProvider)
- mobile/test/providers/scan_provider_test.dart (modified — 5 new cancelForIntake tests)
- mobile/test/providers/intake_provider_test.dart (modified — 1 new priority test)
