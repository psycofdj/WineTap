---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
status: complete
completedAt: '2026-03-30'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-mobile.md
  - _bmad-output/planning-artifacts/architecture-mobile.md
  - _bmad-output/planning-artifacts/product-brief-winetap-mobile.md
  - docs/project-overview.md
  - docs/architecture.md
  - docs/data-models.md
  - docs/api-contracts.md
workflowType: 'epics'
project_name: 'winetap-mobile'
user_name: 'Psy'
date: '2026-03-30'
---

# winetap-mobile - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for winetap-mobile, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR1: User can read an NFC tag UID by holding the phone to a tagged bottle
- FR2: System normalizes NFC tag UIDs to canonical format (uppercase hex, no separators) regardless of platform
- FR3: User can initiate a single NFC scan session via explicit action ("Scanner" / "Prêt à scanner")
- FR4: User can enter continuous scan mode where phone stays NFC-ready for rapid consecutive scans
- FR5: System silently ignores duplicate reads of the same tag within a single scan session (idempotent)
- FR6: User can scan a bottle's NFC tag to look up the associated in-stock bottle
- FR7: System displays bottle details (cuvée, domain, vintage, appellation) for visual confirmation before committing
- FR8: User can confirm consumption ("Confirmer") or cancel ("Annuler") after seeing bottle details
- FR9: System marks the bottle as consumed and clears the tag association upon confirmation
- FR10: System displays a specific error when the scanned tag is not associated with any in-stock bottle
- FR11: Manager can initiate a scan request signaling it is waiting for an NFC tag UID
- FR12: Mobile app receives and displays pending scan requests from the manager in real-time
- FR13: User can respond to a scan request by initiating an NFC scan on the phone
- FR14: System relays the scanned tag UID from the mobile app to the requesting manager via the server
- FR15: Manager can initiate consecutive scan requests for bulk intake ("Ajouter la même") without re-filling the form
- FR16: Mobile app enters continuous scan mode during bulk intake — no per-scan user action between consecutive reads
- FR17: Manager can cancel a pending scan request, returning both devices to idle
- FR18: System enforces a configurable timeout (default 30s) on pending scan requests, notifying manager and returning both devices to idle
- FR19: Scan requests survive phone-side errors (NFC read failure, user cancel) and can be retried without restarting the desktop form
- FR20: Mobile app discovers the WineTap server automatically via mDNS on the local network
- FR21: User can manually configure the server address (IP:port) as a fallback
- FR22: System caches the last-known server address to expedite reconnection
- FR23: System automatically reconnects after connection loss without user action
- FR24: System displays a clear connection state indicator (connected, connecting, unreachable)
- FR25: System displays specific, actionable error messages for: unknown tag, tag already in use, server unreachable, scan timeout, NFC read failure
- FR26: System preserves desktop form data across all scan failures
- FR27: System provides clear recovery guidance (e.g., "réessayez", "vérifiez votre connexion WiFi")
- FR28: Manager supports two scanning backends: RFID (USB) and NFC (via mobile coordination)
- FR29: User can switch between RFID and NFC scanning mode via a setting
- FR30: Both scanning backends produce identical results across all operations
- FR31: Server exposes scan coordination RPCs (CoordinateScan bidi stream)
- FR32: Server registers as a discoverable mDNS service (`_winetap._tcp`)
- FR33: Proto field `rfid_epc` renamed to `tag_id` across all messages and components

### NonFunctional Requirements

- NFR1: Consume flow: scan initiation → confirmation screen in < 3s (excluding app launch and iOS NFC sheet)
- NFR2: Intake coordination: "Prêt à scanner" → UID in manager in < 5s
- NFR3: Scan request notification: manager initiation → phone prompt in < 1s
- NFR4: App cold start to ready state in < 3s on iPhone XS+ / Android 10+
- NFR5: Continuous scan: < 500ms between reads (Android); < 1.5s (iOS, including session restart)
- NFR6: mDNS discovery completes within 3s; falls back to cached address on timeout
- NFR7: gRPC auto-recovers after sleep/wake or WiFi reconnection within 5s of network availability
- NFR8: Intake scan requests survive phone-side NFC failures — retry without form restart
- NFR9: No data loss on manager side during any scan failure, timeout, or cancellation
- NFR10: App handles server restarts gracefully — auto-reconnects when available
- NFR11: gRPC client compatible with existing server proto plus new coordination RPCs — no breaking changes beyond `tag_id` rename
- NFR12: NFC UID reading works on both iOS (Core NFC) and Android (foreground dispatch) via single Flutter plugin
- NFR13: mDNS service type `_winetap._tcp` discoverable by iOS (Bonjour) and Android (NsdManager)
- NFR14: Scan coordination protocol is idempotent — duplicate reads produce no side effects

### Additional Requirements

- Starter template: `flutter create --org com.winetap --platforms ios,android wine_tap_mobile` (Epic 1, Story 1)
- Proto rename `rfid_epc` → `tag_id` must be atomic across all components (proto, DB migration, server, manager, cellar) before other work
- Proto: add `CoordinateScan` bidi streaming RPC with `ScanClientMessage`/`ScanServerMessage` types and `ScanMode` enum
- Proto: rename `GetBottleByEPC` → `GetBottleByTagId` (RPC + request/response types)
- Server: coordination stream handler with explicit state machine (IDLE → REQUESTED → SCANNING → RESOLVED/CANCELLED/TIMED_OUT)
- Server: mDNS registration as `_winetap._tcp`
- Server: `NormalizeTagID()` function for canonical tag ID format
- Server: 60s safety-net timeout for zombie session GC
- Manager: `Scanner` interface with `StartScan(ctx, mode)`, `StopScan()`, `OnTagScanned()` + `ScanMode` type
- Manager: `RFIDScanner` extracted from existing `rfid.go`
- Manager: `NFCScanner` implementation via bidi stream
- Manager: settings toggle for scan mode
- Flutter: Provider state management (`ConnectionProvider`, `ScanProvider`)
- Flutter: `NfcService` abstraction hiding iOS/Android differences
- Flutter: `DiscoveryService` for mDNS + manual fallback + cache
- Flutter: `GrpcClient` with keepalive (10s), exponential backoff reconnection
- Flutter: French strings centralized in `l10n/strings.dart`
- Dart proto generation: `make proto-dart` target, generated code committed to git
- Cellar binary updated for `tag_id` rename (transition support, retired post-MVP)

### UX Design Requirements

No UX Design Specification available. PRD user journeys (Marc's consume and intake stories) serve as UX reference.

### FR Coverage Map

| Requirement | Epic | Description |
|---|---|---|
| FR1 | Epic 2 | NFC tag UID reading |
| FR2 | Epic 2 | UID normalization (canonical format) |
| FR3 | Epic 2 | Single NFC scan session |
| FR4 | Epic 4 | Continuous scan mode |
| FR5 | Epic 2 | Duplicate read suppression |
| FR6 | Epic 2 | Scan tag → lookup bottle |
| FR7 | Epic 2 | Display bottle details for confirmation |
| FR8 | Epic 2 | Confirm/cancel consumption |
| FR9 | Epic 2 | Mark consumed + clear tag |
| FR10 | Epic 2 | Unknown tag error |
| FR11 | Epic 4 | Manager initiates scan request |
| FR12 | Epic 4 | Mobile receives scan requests |
| FR13 | Epic 4 | User responds with NFC scan |
| FR14 | Epic 4 | UID relay mobile → server → manager |
| FR15 | Epic 4 | Consecutive scan requests (bulk) |
| FR16 | Epic 4 | Continuous scan during bulk |
| FR17 | Epic 4 | Manager cancels scan request |
| FR18 | Epic 4 | Configurable timeout (30s) |
| FR19 | Epic 4 | Scan retry after phone-side error |
| FR20 | Epic 2 | mDNS auto-discovery |
| FR21 | Epic 2 | Manual server address fallback |
| FR22 | Epic 2 | Cached server address |
| FR23 | Epic 2 | Auto-reconnect after connection loss |
| FR24 | Epic 2 | Connection state indicator |
| FR25 | Epic 2+4 | Specific error messages (split) |
| FR26 | Epic 4 | Form data preserved across failures |
| FR27 | Epic 2+4 | Recovery guidance (split) |
| FR28 | Epic 3 | Dual scanning backends |
| FR29 | Epic 3 | Scan mode settings toggle |
| FR30 | Epic 3 | Identical results from both backends |
| FR31 | Epic 3 | CoordinateScan bidi stream RPC |
| FR32 | Epic 3 | mDNS service registration |
| FR33 | Epic 1 | Proto rename rfid_epc → tag_id |

## Epic List

### Epic 1: Tag ID Modernization
Rename `rfid_epc` to `tag_id` across the entire system — proto definitions, RPC rename (`GetBottleByEPC` → `GetBottleByTagId`), DB migration, server, manager, cellar — and provide a CLI seeding tool for associating NFC tag UIDs with existing bottles.

**FRs covered:** FR33
**NFRs covered:** NFR11
**Additional:** DB migration, RPC rename, cellar binary transition update, NFC tag seeding CLI tool
**User outcome:** System uses universal tag naming. Existing bottles can be re-tagged with NFC UIDs via CLI tool, enabling consume flow testing on real bottles.
**Standalone:** Yes — atomic rename + utility tool, all existing tests pass.

### Epic 2: Consume a Bottle by Phone
Flutter project setup (including Dart proto toolchain), NFC scanning, mDNS discovery, gRPC connection management, and the complete consume flow. Marc walks to the cellar, opens the app, scans a bottle's NFC tag, confirms consumption.

**FRs covered:** FR1, FR2, FR3, FR5, FR6, FR7, FR8, FR9, FR10, FR20, FR21, FR22, FR23, FR24, FR25 (consume errors), FR27
**NFRs covered:** NFR1, NFR4, NFR6, NFR7, NFR10, NFR12, NFR13
**Additional:** Flutter project init, `make proto-dart` target, Dart proto generation, NFC service, connection management
**User outcome:** Phone replaces the cellar RPi scanner for consuming bottles. Zero-config server discovery, resilient connection, NFC scan, confirmation, done.
**Standalone:** Yes — consume works independently of intake coordination.
**Depends on:** Epic 1
**Story ordering note:** NFC PoC as early story to validate riskiest technology first.

### Epic 3: Scan Coordination — Server & Manager
Server exposes `CoordinateScan` bidi stream with state machine, mDNS service registration, and tag ID normalization. Manager gets `Scanner` interface abstraction with RFID and NFC implementations and settings toggle.

**FRs covered:** FR28, FR29, FR30, FR31, FR32
**NFRs covered:** NFR9, NFR11, NFR14
**Additional:** Coordination state machine, `NormalizeTagID()` function + tests, server mDNS registration, Scanner interface, RFIDScanner extraction, NFCScanner implementation, settings toggle
**User outcome:** Manager supports dual scanning (RFID or NFC). Server ready to relay scans. Testable with Go CLI test client simulating mobile side.
**Standalone:** Yes — RFID still works, NFC coordination verifiable via CLI tool.
**Depends on:** Epic 1. Parallel with Epic 2.

### Epic 4: Coordinated Intake by Phone
Mobile intake screen receives scan requests from the manager. Single and continuous scan modes. Full error handling and recovery. The complete desktop + phone coordination dance.

**FRs covered:** FR4, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18, FR19, FR25 (intake errors), FR26, FR27
**NFRs covered:** NFR2, NFR3, NFR5, NFR8
**User outcome:** Complete intake coordination — Marc fills form on desktop, phone scans tags, UIDs relay back. Bulk intake with continuous mode. The novel "phone as wireless desktop scanner" experience.
**Standalone:** Yes — builds on consume app + coordination protocol.
**Depends on:** Epic 2 + Epic 3

## Epic 1: Tag ID Modernization

Rename `rfid_epc` to `tag_id` across the entire system and provide an NFC tag seeding tool.

### Story 1.1: Proto Rename and System-Wide Tag ID Migration

As a developer,
I want all references to `rfid_epc` renamed to `tag_id` across proto, database, and all Go components,
So that the system uses universal tag naming that supports both UHF RFID and NFC tags.

**Acceptance Criteria:**

**Given** the proto file `winetap.proto`
**When** the rename is applied
**Then** all `rfid_epc` fields are renamed to `tag_id` across all messages
**And** `GetBottleByEPC` RPC is renamed to `GetBottleByTagId` with updated request/response type names
**And** `buf lint` passes
**And** `make proto` regenerates Go code without errors

**Given** a new SQL migration `00N_rename_rfid_epc.sql`
**When** the server starts
**Then** the `bottles.rfid_epc` column is renamed to `tag_id`
**And** the UNIQUE constraint is preserved on non-null values

**Given** the server service layer (`bottles.go`, `convert.go`)
**When** updated for `tag_id`
**Then** `AddBottle`, `ConsumeBottle`, `GetBottleByTagId`, `ListBottles` all use `tag_id`
**And** all existing server tests pass

**Given** the server db layer (`db/bottles.go`)
**When** updated for `tag_id`
**Then** all SQL queries reference the `tag_id` column

**Given** the manager code (`rfid.go`, `inventory_form.go`, and all screens referencing EPC)
**When** updated for `tag_id`
**Then** the manager builds and runs without errors
**And** RFID scanning still works (functional regression)

**Given** the cellar binary (`internal/cellar/cellar.go`, `cmd/cellar/main.go`)
**When** updated for `tag_id`
**Then** the cellar builds, runs, and consumes bottles via RFID as before

**Given** all components are updated
**When** `make build` is run
**Then** all three binaries (server, cellar, manager) compile without errors

### Story 1.2: NFC Tag Seeding CLI Tool

As a developer,
I want a CLI tool that associates an NFC tag UID with an existing bottle,
So that I can re-tag bottles with NFC tags for testing and migration without needing the full intake flow.

**Acceptance Criteria:**

**Given** a new binary `cmd/nfc_seed/main.go`
**When** run as `./bin/winetap-nfc-seed --server localhost:50051 --bottle-id 42 --tag-id 04A32BFF`
**Then** it normalizes the tag_id (uppercase hex, no separators)
**And** connects to the server via gRPC and updates the bottle's `tag_id` directly (not via `UpdateBottle` RPC — uses a dedicated `SetBottleTagId` helper or direct DB approach to avoid FieldMask limitations)
**And** prints confirmation: bottle ID, normalized tag_id, cuvée name

**Given** the tag_id is already in use by another in-stock bottle
**When** the tool attempts to set it
**Then** it displays an error with the conflicting bottle's details
**And** does not modify either bottle

**Given** the bottle ID does not exist
**When** the tool is run
**Then** it displays a clear "bottle not found" error

**Given** the tag_id input contains colons, spaces, dashes, or lowercase
**When** the tool normalizes it
**Then** all separators are stripped and the result is uppercase hex (e.g., "04:a3:2b:ff" → "04A32BFF")

**Given** the `Makefile`
**Then** a `build-nfc-seed` target exists that produces `bin/winetap-nfc-seed`

## Epic 2: Consume a Bottle by Phone

Flutter project setup through complete consume flow. Marc walks to cellar, scans, confirms, done.

### Story 2.1: Flutter Project Setup and Dart Proto Toolchain

As a developer,
I want a Flutter project initialized in the monorepo with Dart proto generation,
So that I have a working mobile app skeleton that can communicate with the WineTap server.

**Acceptance Criteria:**

**Given** the command `flutter create --org com.winetap --platforms ios,android wine_tap_mobile` is run in `mobile/`
**Then** the Flutter project builds and runs on both iOS simulator and Android emulator
**And** `analysis_options.yaml` is configured with strict Dart analysis

**Given** a new `make proto-dart` Makefile target
**When** run
**Then** Dart proto code is generated into `mobile/lib/gen/winetap/v1/`
**And** the generated code compiles without errors
**And** the generated code is committed to git

**Given** `pubspec.yaml`
**Then** it includes dependencies: `grpc`, `protobuf`, `provider`, `shared_preferences`
**And** `flutter pub get` succeeds

**Given** the project structure
**Then** `lib/` contains: `main.dart`, `models/`, `services/`, `providers/`, `screens/`, `widgets/`, `l10n/`
**And** `l10n/strings.dart` exists with a `S` class containing initial French string constants
**And** `main.dart` sets up `MultiProvider` with placeholder providers and a `MaterialApp`

**Given** the app is launched
**Then** it displays a placeholder home screen (to be replaced in later stories)
**And** cold start to ready state is under 3s (NFR4)

### Story 2.2: NFC Tag Reading Proof of Concept

As a developer,
I want to read NFC tag UIDs on both iOS and Android,
So that the riskiest technology (NFC hardware integration) is validated before building the full consume flow.

**Acceptance Criteria:**

**Given** `services/nfc_service.dart` implements the `NfcService` abstraction
**Then** `isAvailable()` returns whether the device has NFC hardware
**And** `readTagId()` initiates an NFC session, reads one tag, and returns the UID as a normalized hex string
**And** `stopReading()` cancels any active NFC session

**Given** `services/tag_id.dart` implements `normalizeTagId(String raw)`
**When** called with any format (colons, spaces, dashes, lowercase)
**Then** it returns uppercase hex with no separators

**Given** an iOS device with NFC
**When** `readTagId()` is called
**Then** the system NFC sheet appears
**And** holding the phone to an NTAG215 tag returns the UID
**And** the UID matches the physical tag's identifier

**Given** an Android device with NFC
**When** `readTagId()` is called
**Then** foreground dispatch captures the tag
**And** the UID is returned matching the physical tag's identifier

**Given** no NFC tag is presented within the session timeout
**Then** `readTagId()` throws `NfcReadTimeoutException`

**Given** the user cancels the iOS NFC sheet
**Then** `readTagId()` throws `NfcSessionCancelledException`

**Given** `test/services/tag_id_test.dart`
**Then** it covers: colons, spaces, dashes, lowercase, mixed, already-normalized, empty string

### Story 2.3: gRPC Client, mDNS Discovery, and Connection Management

As a user,
I want the app to find and connect to my WineTap server automatically,
So that I don't need to configure anything on first launch.

**Acceptance Criteria:**

**Given** `services/discovery_service.dart`
**When** the app launches
**Then** it browses for `_winetap._tcp` via mDNS with a 3s timeout (NFR6)
**And** on success, caches the server address in `SharedPreferences`
**And** on failure, checks for a cached address and uses it
**And** if no cache exists, navigates to the settings screen for manual IP entry

**Given** `services/grpc_client.dart`
**When** `connect(address)` is called
**Then** it creates a `ClientChannel` with keepalive pings (10s interval, 5s timeout)
**And** exposes `isConnected` getter

**Given** the gRPC connection is lost (WiFi drop, server restart)
**When** network becomes available again
**Then** the client reconnects with exponential backoff (1s, 2s, 4s, 8s, max 30s)
**And** reconnection succeeds within 5s of network availability (NFR7)

**Given** `providers/connection_provider.dart`
**Then** it exposes `ConnectionState` enum: `connected`, `connecting`, `unreachable`
**And** calls `notifyListeners()` on every state change

**Given** `widgets/connection_indicator.dart`
**Then** it displays the current connection state visually
**And** updates reactively when `ConnectionProvider` state changes

**Given** `screens/settings_screen.dart`
**Then** the user can enter a manual server address (IP:port) (FR21)
**And** the address is saved to `SharedPreferences`
**And** connection info (address, state) is displayed

**Given** the app is backgrounded and resumed, or the phone sleeps and wakes
**Then** the connection auto-recovers without user action (FR23, NFR10)

### Story 2.4: Consume Flow — Scan, Confirm, Consume

As a user,
I want to scan a bottle's NFC tag and mark it as consumed with a confirmation step,
So that I can manage my cellar from the phone without touching the desktop.

**Acceptance Criteria:**

**Given** `screens/consume_screen.dart` is the app's main screen
**When** the user taps "Scanner" button
**Then** `NfcService.readTagId()` is called (FR3)
**And** on iOS the system NFC sheet appears; on Android foreground dispatch activates

**Given** a tag is successfully read
**When** the UID is obtained
**Then** `ScanProvider` calls `GetBottleByTagId(tagId)` via gRPC (FR6)
**And** the UID is normalized for display via `normalizeTagId()` (FR2)

**Given** the server returns bottle details
**Then** `widgets/bottle_details_card.dart` displays: cuvée, domain, vintage, appellation (FR7)
**And** two buttons are shown: "Confirmer" and "Annuler" (FR8)

**Given** the user taps "Confirmer"
**Then** `ScanProvider` calls `ConsumeBottle(tagId)` via gRPC (FR9)
**And** on success, the screen shows "Marquée comme bue ✓" with the bottle details
**And** the screen returns to idle state after a brief display

**Given** the user taps "Annuler"
**Then** no server call is made
**And** the screen returns to the idle scan state

**Given** the scanned tag is not associated with any in-stock bottle
**When** the server returns `NOT_FOUND`
**Then** the screen displays "Tag inconnu" with recovery guidance "réessayez" (FR10, FR25, FR27)

**Given** the user scans the same tag immediately after successfully consuming the bottle
**When** the tag_id has been cleared by consumption
**Then** the server returns `NOT_FOUND` and the screen displays "Tag inconnu" — this is expected behavior, not a bug

**Given** the entire flow from scan initiation to confirmation screen
**Then** it completes in under 3s excluding app launch and iOS NFC sheet (NFR1)

### Story 2.5: Consume Error Handling and Connection Resilience

As a user,
I want clear error messages when something goes wrong during scanning,
So that I know what happened and how to recover.

**Acceptance Criteria:**

**Given** `providers/scan_provider.dart` manages scan state
**Then** it exposes states: `idle`, `scanning`, `result`, `error`
**And** error state includes a French message from `l10n/strings.dart`

**Given** the server is unreachable during a consume attempt
**When** the gRPC call fails with `UNAVAILABLE`
**Then** the screen displays "Serveur injoignable" with "vérifiez votre connexion WiFi" (FR25, FR27)

**Given** the scanned tag is already associated with a consumed bottle (edge case)
**When** the server returns `NOT_FOUND` (tag cleared on consumption)
**Then** "Tag inconnu" is displayed

**Given** the NFC read fails (bad angle, timeout)
**Then** the screen displays "Aucun tag détecté — réessayez" (FR25)
**And** the user can tap "Scanner" again without restarting the app

**Given** the NFC session is cancelled by the user (iOS sheet dismissed)
**Then** the screen silently returns to idle — no error shown

**Given** duplicate reads of the same tag within a single scan session (FR5)
**Then** only the first read is processed; subsequent reads are silently ignored

**Given** the connection drops during a consume flow
**When** the user was on the confirmation screen (bottle details shown)
**Then** the confirmation screen remains visible
**And** tapping "Confirmer" retries the `ConsumeBottle` call when connection recovers
**Or** shows "Serveur injoignable" if still disconnected

## Epic 3: Scan Coordination — Server & Manager

Server bidi stream coordination + manager dual scanning abstraction.

### Story 3.1: Coordination Proto and Server Stream Handler

As a developer,
I want the server to expose a `CoordinateScan` bidirectional streaming RPC with a state machine,
So that the manager and mobile app can coordinate NFC scanning in real-time through the server.

**Acceptance Criteria:**

**Given** `winetap.proto`
**When** the coordination messages are added
**Then** `ScanClientMessage` has a `oneof payload` with: `ScanRequest`, `ScanResult`, `ScanCancel`
**And** `ScanServerMessage` has a `oneof payload` with: `ScanRequestNotification`, `ScanAck`, `ScanError`
**And** `ScanMode` enum has: `SCAN_MODE_UNSPECIFIED`, `SCAN_MODE_SINGLE`, `SCAN_MODE_CONTINUOUS`
**And** `ScanRequest` includes a `scan_mode` field
**And** `ScanResult` includes a `tag_id` field
**And** `rpc CoordinateScan(stream ScanClientMessage) returns (stream ScanServerMessage)` is defined
**And** `buf lint` passes and `make proto` + `make proto-dart` regenerate without errors

**Given** `service/scan_session.go` implements the coordination state machine
**Then** states are: `IDLE`, `REQUESTED`, `SCANNING`, `RESOLVED`, `CANCELLED`, `TIMED_OUT`
**And** transitions follow the architecture spec (IDLE → REQUESTED → SCANNING → RESOLVED/CANCELLED/TIMED_OUT)
**And** the struct is mutex-protected for concurrent access
**And** the server has a 60s safety-net timeout that garbage-collects zombie sessions
**And** in continuous mode, RESOLVED transitions back to SCANNING (not IDLE)

**Given** `service/coordination.go` implements the `CoordinateScan` stream handler
**When** a manager client sends a `ScanRequest`
**Then** the server transitions to REQUESTED and relays a `ScanRequestNotification` to connected mobile clients
**When** a mobile client sends a `ScanResult`
**Then** the server transitions to RESOLVED and relays a `ScanAck` (with tag_id) to the manager client
**When** either side sends a `ScanCancel`
**Then** the server transitions to CANCELLED and notifies both sides

**Given** `service/scan_session_test.go`
**Then** it covers all state transitions, concurrent access safety, timeout GC, continuous mode looping, and invalid transition attempts

**Given** `service/coordination_test.go` (integration test — spins up real server, requires network port)
**Then** it opens two bidi streams (simulating manager and mobile) and drives through: single scan, continuous scan (2 reads), cancel, timeout, and duplicate read scenarios

### Story 3.2: Server mDNS Registration and Tag ID Normalization

As a user,
I want the server to be discoverable on the local network and normalize all tag IDs consistently,
So that the mobile app can find the server automatically and tag IDs are always in canonical format.

**Acceptance Criteria:**

**Given** `cmd/server/main.go`
**When** the server starts
**Then** it registers an mDNS service as `_winetap._tcp` on the gRPC port
**And** the service is discoverable by both iOS (Bonjour) and Android (NsdManager) (NFR13)
**And** the registration is cleaned up on graceful shutdown

**Given** `service/tagid.go` implements `NormalizeTagID(raw string) string`
**When** called with any format (colons, spaces, dashes, lowercase, mixed)
**Then** it returns uppercase hex with no separators (e.g., "04:a3:2b:ff" → "04A32BFF")

**Given** `service/tagid_test.go`
**Then** it covers: colons, spaces, dashes, lowercase, mixed, already-normalized, empty string
**And** test cases match the Dart `normalizeTagId` tests exactly (same inputs, same outputs)

**Given** the coordination stream handler processes a `ScanResult`
**Then** it calls `NormalizeTagID` on the received `tag_id` before any lookup or relay

**Given** the server config
**Then** mDNS registration is enabled by default with no additional configuration required

### Story 3.3: Manager Scanner Interface and RFID Extraction

As a developer,
I want a Scanner interface in the manager with the existing RFID logic extracted into it,
So that the scanning abstraction is in place before adding the NFC backend.

**Acceptance Criteria:**

**Given** `internal/manager/scanner.go`
**Then** it defines the `Scanner` interface: `StartScan(ctx, mode ScanMode) error`, `StopScan() error`, `OnTagScanned(callback func(tagID string))`
**And** `ScanMode` type with `ScanModeSingle` and `ScanModeContinuous` constants

**Given** `internal/manager/rfid_scanner.go`
**Then** it implements `Scanner` using the existing RFID logic extracted from `rfid.go`
**And** `StartScan` with `ScanModeSingle` triggers one `InventorySingle`
**And** `StartScan` with `ScanModeContinuous` runs the `Inventory` loop
**And** `StopScan` halts the scan loop
**And** `OnTagScanned` fires the callback with the scanned tag_id

**Given** `manager.go` initializes the scanner
**Then** it creates `RFIDScanner` by default (preserving existing behavior)
**And** `inventory_form.go` calls `Scanner.StartScan()` instead of directly using RFID methods

**Given** all existing RFID scanning functionality
**When** the refactor is complete
**Then** RFID scanning works identically to before — no behavioral regression (FR30)
**And** the manager builds and all existing workflows pass

### Story 3.4: NFC Scanner Implementation and Settings Toggle

As a user,
I want to switch between RFID and NFC scanning in the manager settings,
So that I can use my phone as a wireless NFC scanner for bottle intake.

**Acceptance Criteria:**

**Given** `internal/manager/nfc_scanner.go` implements `Scanner`
**When** `StartScan` is called
**Then** it opens a `CoordinateScan` bidi stream to the server (if not already open)
**And** sends a `ScanClientMessage{ScanRequest{mode}}` with the requested scan mode
**And** listens for `ScanServerMessage{ScanAck{tag_id}}` on the return stream
**And** fires `OnTagScanned(tagID)` when a result arrives

**Given** `StopScan` is called on `NFCScanner`
**Then** it sends `ScanClientMessage{ScanCancel}` to the server
**And** the stream remains open for future scan requests

**Given** the gRPC connection drops while the stream is active
**Then** `NFCScanner` reports an error via the existing manager error notification
**And** `StopScan` is called to clean up state
**And** form data on the manager side is preserved (NFR9)

**Given** `screen/settings.go`
**Then** a scan mode toggle is added: "RFID (USB)" / "NFC (Mobile)" (FR29)
**And** the selection is persisted in `config.yaml` via `config.go`

**Given** `manager.go`
**When** the scan mode setting is "NFC"
**Then** it initializes `NFCScanner` instead of `RFIDScanner`
**And** switching modes takes effect on next scan (no app restart required)

**Given** either scanning backend is selected
**When** a bottle is scanned during intake
**Then** the result (tag_id in the form field) is identical regardless of backend (FR28, FR30)

## Epic 4: Coordinated Intake by Phone

Mobile intake screen with single and continuous scan modes, full error handling.

### Story 4.1: Intake Screen — Single Scan Mode

As a user,
I want my phone to receive scan requests from the desktop manager and respond by scanning an NFC tag,
So that I can register bottles at my desk using the phone as a wireless scanner.

**Acceptance Criteria:**

**Given** `screens/intake_screen.dart` is added to the app navigation
**When** the user navigates to the intake screen
**Then** a `CoordinateScan` bidi stream is opened to the server via `GrpcClient`

**Given** the stream is open and idle
**Then** the screen displays "En attente…" indicating no pending scan request

**Given** the manager initiates a scan request (single mode)
**When** the server relays a `ScanRequestNotification` to the mobile stream (FR12)
**Then** the screen displays "En attente du scan…" with a pulsing indicator
**And** a "Prêt à scanner" button is shown (FR13)
**And** the notification arrives within 1s of manager initiation (NFR3)

**Given** the user taps "Prêt à scanner"
**When** `NfcService.readTagId()` is called
**Then** on successful NFC read, a `ScanClientMessage{ScanResult{tag_id}}` is sent to the server (FR14)
**And** the screen shows "Tag lu ✓" briefly
**And** the screen returns to "En attente…" (single mode — one scan per request)

**Given** the full flow from "Prêt à scanner" tap to UID appearing in the manager form
**Then** it completes in under 5s (NFR2)

**Given** the user leaves the intake screen
**Then** the bidi stream is closed gracefully

### Story 4.2: Continuous Scan Mode for Bulk Intake

As a user,
I want the phone to stay in scanning mode during bulk intake,
So that I can tag and scan multiple bottles rapidly without tapping "Prêt à scanner" between each one.

**Acceptance Criteria:**

**Given** the manager initiates a scan request with continuous mode (FR15, FR16)
**When** the `ScanRequestNotification` includes `SCAN_MODE_CONTINUOUS`
**Then** the screen displays "Mode continu — scanner les bouteilles"
**And** the user taps "Prêt à scanner" once for the first scan

**Given** continuous mode is active after the first scan
**When** the server acknowledges the first result (ScanAck)
**Then** `NfcService.continuousRead()` stream remains active (FR4)
**And** the phone is immediately ready for the next tag — no user action required between scans
**And** the screen shows "Prêt" indicating NFC is active
**And** on iOS, `continuousRead()` internally handles NFC session restarts between reads — the < 1.5s between reads target (NFR5) accounts for this overhead

**Given** a tag is read in continuous mode
**Then** a `ScanResult` is sent to the server automatically
**And** "Tag lu ✓" flashes briefly, then returns to "Prêt"
**And** time between consecutive reads is under 500ms on Android, under 1.5s on iOS (NFR5)

**Given** the same tag is read twice in succession (FR5, NFR14)
**Then** the duplicate is silently ignored — no `ScanResult` sent for the duplicate
**And** no error is shown to the user

**Given** continuous mode is active
**When** the manager sends a new scan request (from "Ajouter la même")
**Then** continuous mode persists — no interruption on the mobile side

### Story 4.3: Intake Error Handling, Cancellation, and Timeout

As a user,
I want clear feedback when things go wrong during intake scanning, and clean recovery,
So that I never lose my desktop form data or end up in a stuck state.

**Acceptance Criteria:**

**Given** the manager cancels a pending scan request (FR17)
**When** the server sends a `ScanError` with cancellation reason to the mobile stream
**Then** the intake screen returns to "En attente…" immediately
**And** any active NFC session is stopped
**And** transition to idle happens within 1s

**Given** the manager's 30s timeout expires (FR18)
**When** the server sends a `ScanError` with timeout reason
**Then** the intake screen displays "Délai dépassé" briefly
**And** returns to "En attente…"
**And** the manager is notified and form data is preserved (FR26, NFR9)

**Given** the NFC read fails (bad angle, no tag detected)
**When** `NfcService` throws `NfcReadTimeoutException`
**Then** the screen displays "Aucun tag détecté — réessayez" (FR25, FR27)
**And** the scan request remains active — the user can retry without restarting the desktop form (FR19, NFR8)
**And** in continuous mode, NFC remains active for the next attempt

**Given** the user cancels the iOS NFC sheet during intake
**Then** the screen shows "Scan annulé — réessayez"
**And** the scan request remains active for retry (FR19)

**Given** the scanned tag is already associated with an in-stock bottle
**When** the server returns a `ScanError` with "already in use" reason
**Then** the screen displays "Tag déjà utilisé — [bottle details]" (FR25)
**And** continuous mode stays active — scan the next bottle

**Given** the server becomes unreachable during intake
**Then** the screen displays "Serveur injoignable" (FR25)
**And** the bidi stream reconnects when the connection recovers (via `ConnectionProvider`)
**And** the manager's form data is preserved (FR26)

**Given** the connection recovers after a disruption
**When** the bidi stream is re-established
**Then** if the manager still has a pending scan request, the mobile resumes intake seamlessly
