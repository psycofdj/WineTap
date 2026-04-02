# Story 2.4: Consume Flow — Scan, Confirm, Consume

Status: done

## Story

As a user,
I want to scan a bottle's NFC tag and mark it as consumed with a confirmation step,
So that I can manage my cellar from the phone without touching the desktop.

## Acceptance Criteria

1. **Given** `screens/consume_screen.dart` is the app's main screen
   **When** the user taps "Scanner" button
   **Then** `NfcService.readTagId()` is called (FR3)
   **And** on iOS the system NFC sheet appears; on Android foreground dispatch activates

2. **Given** a tag is successfully read
   **When** the UID is obtained
   **Then** `ScanProvider` calls `GetBottleByTagId(tagId)` via gRPC (FR6)
   **And** the UID is normalized for display via `normalizeTagId()` (FR2)

3. **Given** the server returns bottle details
   **Then** `widgets/bottle_details_card.dart` displays: cuvee, domain, vintage, appellation (FR7)
   **And** two buttons are shown: "Confirmer" and "Annuler" (FR8)

4. **Given** the user taps "Confirmer"
   **Then** `ScanProvider` calls `ConsumeBottle(tagId)` via gRPC (FR9)
   **And** on success, the screen shows "Marquee comme bue" with the bottle details
   **And** the screen returns to idle state after a brief display

5. **Given** the user taps "Annuler"
   **Then** no server call is made
   **And** the screen returns to the idle scan state

6. **Given** the scanned tag is not associated with any in-stock bottle
   **When** the server returns `NOT_FOUND`
   **Then** the screen displays "Tag inconnu" with recovery guidance (FR10, FR25, FR27)

7. **Given** the entire flow from scan initiation to confirmation screen
   **Then** it completes in under 3s excluding app launch and iOS NFC sheet (NFR1)

## Tasks / Subtasks

- [x] Task 1: Implement ScanProvider state machine (AC: #1, #2, #3, #4, #5, #6)
  - [x] Replace placeholder with full implementation — 6-state machine
  - [x] `ScanState` enum: `idle`, `scanning`, `found`, `consuming`, `consumed`, `error`
  - [x] Holds `tagId`, `Bottle`, `errorMessage`
  - [x] `startScan(client)` — NFC read + GetBottleByTagId RPC
  - [x] `confirmConsume(client)` — ConsumeBottle RPC + auto-reset after 3s
  - [x] `cancel()` / `reset()` — state management
  - [x] gRPC errors mapped to French S class strings
- [x] Task 2: Create BottleDetailsCard widget (AC: #3)
  - [x] Created `mobile/lib/widgets/bottle_details_card.dart`
  - [x] Displays: domain name, cuvee name + vintage, designation (appellation)
  - [x] Accepts `Bottle` proto message
- [x] Task 3: Create ConsumeScreen (AC: #1, #3, #4, #5, #6)
  - [x] Created `mobile/lib/screens/consume_screen.dart`
  - [x] 6 states: idle (Scanner btn), scanning (spinner), found (card + buttons), consuming (spinner), consumed (check + card), error (message + retry)
  - [x] Reactive via `context.watch<ScanProvider>()`
  - [x] Actions via `context.read<ScanProvider/ConnectionProvider>()`
- [x] Task 4: Wire ConsumeScreen as home (AC: #1)
  - [x] Replaced NfcTestScreen with ConsumeScreen in main.dart
  - [x] Connection indicator + settings icon preserved in ConsumeScreen AppBar
  - [x] Widget test updated
- [x] Task 5: Verification
  - [x] `flutter analyze` — no issues
  - [x] `flutter test` — 10/10 pass
  - [x] `flutter build apk --debug` — builds successfully
  - [x] Upgraded nfc_manager to ^4.2.0 (v3.5 had Kotlin deprecation build failure), rewrote NfcService for v4 API

### Review Findings

- [x] [Review][Patch] Auto-reset uses Timer field + _disposed guard, cancelled in dispose()
- [x] [Review][Patch] startScan guards: returns early if not idle/error
- [x] [Review][Patch] Cancel button added to scanning state — user can escape 30s Android wait
- [x] [Review][Patch] SnackBar shown when gRPC client null (server unreachable)
- [x] [Review][Defer] cancel() doesn't cancel in-flight gRPC call — Story 2.5 scope
- [x] [Review][Defer] No gRPC deadline on consume/lookup calls — Story 2.5 scope
- [x] [Review][Defer] onSessionErrorIos always maps to cancelled — same as 2.2 defer
- [x] [Review][Defer] NfcService not injectable for testing — PoC testability

## Dev Notes

### ScanProvider State Machine

This is the core business logic for the consume flow. Per architecture: providers own state, call services, notify listeners. Screens are pure UI.

```
                startScan()
  IDLE ────────────────────► SCANNING
   ▲                            │
   │                   NFC read + GetBottleByTagId
   │                            │
   │  cancel()                  ▼
   ├◄──────────────────────── FOUND ──── (error) ──► ERROR
   │                            │                      │
   │                   confirmConsume()           reset()
   │                            │                      │
   │                            ▼                      ▼
   │                        CONSUMING                IDLE
   │                            │
   │                    ConsumeBottle OK
   │                            │
   │                            ▼
   └◄─── reset() ────────── CONSUMED
         (auto 3s)
```

### ScanProvider Implementation

```dart
enum ScanState { idle, scanning, found, consuming, consumed, error }

class ScanProvider extends ChangeNotifier {
  final NfcService _nfcService = NfcService();

  ScanState _state = ScanState.idle;
  String? _tagId;
  Bottle? _bottle;
  String? _errorMessage;

  ScanState get state => _state;
  String? get tagId => _tagId;
  Bottle? get bottle => _bottle;
  String? get errorMessage => _errorMessage;

  Future<void> startScan(WineTapClient client) async { ... }
  Future<void> confirmConsume(WineTapClient client) async { ... }
  void cancel() { ... }
  void reset() { ... }
}
```

Key: `startScan` and `confirmConsume` accept `WineTapClient` as parameter (injected from ConnectionProvider via screen) — providers don't call other providers.

### gRPC Call Patterns

```dart
// Look up bottle
final bottle = await client.getBottleByTagId(
  GetBottleByTagIdRequest(tagId: tagId),
);

// Consume bottle
final consumed = await client.consumeBottle(
  ConsumeBottleRequest(tagId: tagId),
);
```

Error mapping (from architecture spec):
- `StatusCode.notFound` -> `S.unknownTag` ("Tag inconnu")
- `StatusCode.unavailable` -> `S.serverUnreachable` ("Serveur injoignable")
- Other -> generic error with `S.retryPrompt`

### BottleDetailsCard Widget

Displays bottle info from the `Bottle` proto message:

```dart
class BottleDetailsCard extends StatelessWidget {
  final Bottle bottle;
  // Display: bottle.cuvee.domainName, bottle.cuvee.name,
  //          bottle.vintage, bottle.cuvee.designationName
}
```

Access pattern for proto `Bottle`:
- `bottle.cuvee.domainName` — domain (e.g., "Domaine Brumont")
- `bottle.cuvee.name` — cuvee name (e.g., "Chateau Montus")
- `bottle.vintage` — year (e.g., 2019)
- `bottle.cuvee.designationName` — appellation (e.g., "Madiran")

### ConsumeScreen Layout

Per architecture: screens are pure UI, read state from providers, call provider methods.

```
┌──────────────────────┐
│ WineTap  [●] [⚙]│  <- AppBar with connection indicator + settings
├──────────────────────┤
│                      │
│   [State-dependent   │
│    content area]     │
│                      │
│  IDLE: Scanner btn   │
│  SCANNING: spinner   │
│  FOUND: bottle card  │
│    + Confirmer/Annuler│
│  CONSUMED: success ✓ │
│  ERROR: message      │
│                      │
└──────────────────────┘
```

### Auto-Reset After Consume

After showing "Marquee comme bue", auto-reset to idle after 3 seconds:

```dart
if (_state == ScanState.consumed) {
  Future<void>.delayed(const Duration(seconds: 3), () {
    if (_state == ScanState.consumed) reset();
  });
}
```

### French Strings Already Available

All needed strings exist in `S` class:
- `S.scanButton` = "Scanner"
- `S.confirm` = "Confirmer"
- `S.cancel` = "Annuler"
- `S.markedAsConsumed` = "Marquee comme bue ✓"
- `S.unknownTag` = "Tag inconnu"
- `S.serverUnreachable` = "Serveur injoignable"
- `S.retryPrompt` = "Reessayez"
- `S.noTagDetected` = "Aucun tag detecte"

### What NOT to Do

- Do NOT put business logic in ConsumeScreen — all logic in ScanProvider
- Do NOT call providers from other providers — pass client as parameter
- Do NOT handle connection errors here — that's Story 2.5
- Do NOT implement duplicate scan suppression — that's Story 2.5
- Do NOT use `setState()` for scan state — use Provider pattern
- Do NOT hardcode French strings — use `S.xxx` constants

### Previous Story Intelligence

Story 2.3 established:
- `ConnectionProvider` with `grpcClient` getter -> `GrpcClient` -> `client` (WineTapClient?)
- `AppConnectionState` enum for connection status
- `ConnectionIndicator` widget in AppBar
- Settings navigation via IconButton
- `WineTapApp` as StatefulWidget initializing connection

Story 2.2 established:
- `NfcService.readTagId()` returns normalized hex string
- Typed exceptions: `NfcReadTimeoutException`, `NfcSessionCancelledException`
- 30s timeout on Android

Story 2.1 established:
- Provider pattern with MultiProvider
- French strings in `S` class
- Generated `WineTapClient` with `getBottleByTagId()` and `consumeBottle()` methods
- `Bottle` proto with `cuvee` field containing `domainName`, `name`, `designationName`

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 2.4 ACs (lines 378-418)
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — Consume flow data flow (line ~745), Provider patterns (line ~420), error mapping (line ~492)
- [Source: mobile/lib/gen/winetap/v1/winetap.pbgrpc.dart] — WineTapClient.getBottleByTagId(), consumeBottle() signatures
- [Source: mobile/lib/providers/connection_provider.dart] — grpcClient getter (line 28)
- [Source: mobile/lib/services/nfc_service.dart] — readTagId() signature
- [Source: mobile/lib/l10n/strings.dart] — All French consume flow strings

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- ScanProvider: 6-state machine (idle/scanning/found/consuming/consumed/error), accepts WineTapClient as parameter (no provider-to-provider coupling), auto-reset after 3s on consumed
- BottleDetailsCard: Card widget displaying domain, cuvee+vintage, designation from Bottle proto
- ConsumeScreen: switch-based rendering for all 6 states, connection indicator + settings in AppBar
- NfcService rewritten for nfc_manager v4 API — v3.5 had Kotlin compilation failure (deprecated toLowerCase). v4 uses `NfcTagAndroid.from(tag)?.id` (Android) and `Iso7816Ios.from(tag)?.identifier` / `MiFareIos.from(tag)?.identifier` (iOS)
- v4 API changes: `startSession` requires `pollingOptions` parameter, `onError` replaced by `onSessionErrorIos`, `stopSession` uses `errorMessageIos` instead of `errorMessage`
- gRPC error mapping: NOT_FOUND->unknownTag, UNAVAILABLE->serverUnreachable, ALREADY_EXISTS->tagInUse, DEADLINE_EXCEEDED->timeout
- NfcTestScreen retained in codebase but no longer wired as home

### Change Log

- 2026-03-31: Consume flow — ScanProvider state machine, ConsumeScreen, BottleDetailsCard, nfc_manager v4 upgrade

### File List

- mobile/lib/providers/scan_provider.dart (replaced — full state machine)
- mobile/lib/widgets/bottle_details_card.dart (new)
- mobile/lib/screens/consume_screen.dart (new)
- mobile/lib/services/nfc_service.dart (rewritten — nfc_manager v4 API)
- mobile/lib/main.dart (modified — ConsumeScreen as home)
- mobile/pubspec.yaml (modified — nfc_manager ^4.2.0)
- mobile/test/widget_test.dart (modified — consume screen test)
