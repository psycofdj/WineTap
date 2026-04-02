# Story 4.1: Intake Screen — Single Scan Mode

Status: done

## Story

As a user,
I want my phone to receive scan requests from the desktop manager and respond by scanning an NFC tag,
So that I can register bottles at my desk using the phone as a wireless scanner.

## Acceptance Criteria

1. **Given** `screens/intake_screen.dart` is added to the app navigation
   **When** the user navigates to the intake screen
   **Then** a `CoordinateScan` bidi stream is opened to the server via `GrpcClient`

2. **Given** the stream is open and idle
   **Then** the screen displays "En attente..." indicating no pending scan request

3. **Given** the manager initiates a scan request (single mode)
   **When** the server relays a `ScanRequestNotification` to the mobile stream (FR12)
   **Then** the screen displays "En attente du scan..." with a pulsing indicator
   **And** a "Pret a scanner" button is shown (FR13)
   **And** the notification arrives within 1s of manager initiation (NFR3)

4. **Given** the user taps "Pret a scanner"
   **When** `NfcService.readTagId()` is called
   **Then** on successful NFC read, a `ScanClientMessage{ScanResult{tag_id}}` is sent to the server (FR14)
   **And** the screen shows "Tag lu" briefly
   **And** the screen returns to "En attente..." (single mode)

5. **Given** the full flow from "Pret a scanner" tap to UID appearing in the manager form
   **Then** it completes in under 5s (NFR2)

6. **Given** the user leaves the intake screen
   **Then** the bidi stream is closed gracefully

## Tasks / Subtasks

- [x] Task 1: Create IntakeProvider (AC: #1, #2, #3, #4)
  - [x] `IntakeState` enum: idle, waitingForRequest, scanRequested, scanning, tagSent, error
  - [x] Bidi stream via `StreamController<ScanClientMessage>` + `client.coordinateScan(stream)`
  - [x] `openStream(client)` / `closeStream()` — lifecycle management
  - [x] `ScanRequestNotification` -> scanRequested, `ScanAck` -> tagSent (auto-reset 2s), `ScanError` -> error (cancel -> waitingForRequest)
  - [x] `startNfcScan()` — NFC read + send ScanResult, NfcSessionCancelled -> back to scanRequested
  - [x] `_disposed` guard, timer cleanup in dispose
- [x] Task 2: Add intake strings (AC: #2, #3)
  - [x] Added `S.intake`, `S.waitingForRequest`, `S.scanRequestReceived`, `S.tagSentSuccess`
- [x] Task 3: Create IntakeScreen (AC: #1, #2, #3, #4, #6)
  - [x] 6 states rendered: idle (disconnected), waitingForRequest (listening icon), scanRequested (pulsing + "Pret a scanner" button), scanning (spinner), tagSent (green check + tag ID), error
  - [x] Stream opened in initState via postFrameCallback
  - [x] ConnectionIndicator + settings in AppBar
- [x] Task 4: Add navigation (AC: #1)
  - [x] `HomeScreen` with `BottomNavigationBar` — "Scanner" (consume) + "Prise en charge" (intake)
  - [x] `IndexedStack` preserves state across tab switches
  - [x] `IntakeProvider` registered in MultiProvider
- [x] Task 5: Verification
  - [x] `flutter analyze` — no issues
  - [x] `flutter test` — 10/10 pass
  - [x] `flutter build apk --debug` — builds successfully

## Dev Notes

### Dart Bidi Stream Pattern

The Dart gRPC client for bidi streaming is different from Go. The `coordinateScan` method takes a `Stream<ScanClientMessage>` and returns a `Stream<ScanServerMessage>`:

```dart
// Create a controller to send messages to the server
final sendController = StreamController<ScanClientMessage>();

// Open bidi stream — pass the send stream, get the receive stream
final responseStream = client.coordinateScan(sendController.stream);

// Listen for server messages
responseStream.listen(
  (ScanServerMessage msg) {
    switch (msg.whichPayload()) {
      case ScanServerMessage_Payload.scanRequestNotification:
        // Manager requested a scan
        break;
      case ScanServerMessage_Payload.scanAck:
        // Tag was acknowledged
        break;
      case ScanServerMessage_Payload.scanError:
        // Error from server
        break;
      default:
        break;
    }
  },
  onError: (error) { /* stream error */ },
  onDone: () { /* stream closed */ },
);

// Send a scan result after NFC read
sendController.add(ScanClientMessage(
  scanResult: ScanResult(tagId: normalizedTagId),
));

// Clean up
sendController.close(); // closes the stream
```

### Mobile Role in Coordination

The mobile is NOT the "manager" — it's the "mobile" client. Per the server coordination handler (Story 3.1):
- Streams pre-register as "mobile" by default
- The mobile receives `ScanRequestNotification` when the manager requests a scan
- The mobile sends `ScanResult` after reading an NFC tag
- The mobile receives `ScanAck` confirming the tag was relayed to the manager

The mobile does NOT send `ScanRequest` — that's the manager's job (Story 3.4 NFCScanner).

### IntakeProvider State Machine

```
Stream opened
  ↓
WAITING_FOR_REQUEST ←──────────────────┐
  ↓ (ScanRequestNotification)          │
SCAN_REQUESTED                         │
  ↓ (user taps "Pret a scanner")       │
SCANNING                               │
  ↓ (NFC read success)                 │
TAG_SENT (send ScanResult)             │
  ↓ (ScanAck received, auto-reset)     │
  └────────────────────────────────────┘
```

Error from any state -> ERROR -> can retry or wait for next request.

### Navigation: Bottom Navigation Bar

Add a `BottomNavigationBar` with two tabs:
- "Scanner" (consume flow) — existing ConsumeScreen
- "Prise en charge" (intake listener) — new IntakeScreen

```dart
class HomeScreen extends StatefulWidget { ... }

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _screens = const [ConsumeScreen(), IntakeScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.nfc), label: S.scanButton),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: S.intake),
        ],
      ),
    );
  }
}
```

Move the AppBar (with ConnectionIndicator + settings) into each screen individually, or keep it in the HomeScreen shell.

### What NOT to Do

- Do NOT implement continuous scan mode — that's Story 4.2
- Do NOT implement error handling for timeout/cancellation — that's Story 4.3
- Do NOT send ScanRequest from mobile — only ScanResult (mobile is not the manager)
- Do NOT modify the server or manager code — this is Flutter only

### Previous Story Intelligence

Story 2.4 established:
- ScanProvider with 6-state machine — reference for IntakeProvider pattern
- ConsumeScreen with switch-based rendering — reference for IntakeScreen

Story 2.2 established:
- NfcService.readTagId() — reuse for intake NFC scan

Story 3.1 established:
- Server CoordinateScan handler — mobile pre-registers, receives ScanRequestNotification
- ScanAck relayed after mobile sends ScanResult

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 4.1 ACs (lines 596-627)
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — Intake coordination flow (line ~760)
- [Source: mobile/lib/gen/winetap/v1/winetap.pbgrpc.dart] — coordinateScan Dart signature
- [Source: mobile/lib/screens/consume_screen.dart] — Screen pattern reference
- [Source: mobile/lib/providers/scan_provider.dart] — Provider pattern reference

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- IntakeProvider: bidi stream via StreamController pattern (Dart gRPC takes Stream input, returns ResponseStream)
- Mobile role: receives ScanRequestNotification, sends ScanResult — does NOT send ScanRequest
- ScanAck triggers tagSent state with 2s auto-reset to waitingForRequest
- ScanError with "cancelled" reason returns to waitingForRequest (not error)
- NfcSessionCancelled returns to scanRequested (user can retry without losing server request)
- HomeScreen with BottomNavigationBar + IndexedStack for tab switching
- IndexedStack preserves both screens' state across tab switches

### Change Log

- 2026-03-31: Intake screen with bidi stream listener, IntakeProvider state machine, bottom navigation

### File List

- mobile/lib/providers/intake_provider.dart (new)
- mobile/lib/screens/intake_screen.dart (new)
- mobile/lib/main.dart (modified — HomeScreen with BottomNavigationBar, IntakeProvider registered)
- mobile/lib/l10n/strings.dart (modified — 4 intake strings)
- mobile/test/widget_test.dart (modified — IntakeProvider + bottom nav test)
