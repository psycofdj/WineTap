---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
status: 'complete'
completedAt: '2026-04-02'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-mobile.md
  - _bmad-output/planning-artifacts/architecture-mobile-v2.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-04-01.md
project_name: 'winetap-mobile'
user_name: 'Psy'
date: '2026-04-02'
---

# WineTap Mobile v2.1 — Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for WineTap Mobile v2.1, decomposing the PRD (v2.1 — simplified flows) and Architecture (v2 — phone-as-server) into implementable stories. Based on Epics 5-9 from the sprint change proposal, refined with v2.1 flow simplifications.

## Requirements Inventory

### Functional Requirements

- FR1: User can read an NFC tag UID by holding the phone to a tagged bottle
- FR2: System normalizes NFC tag UIDs to a canonical format (uppercase hex, no separators) regardless of platform
- FR3: User can initiate a consume NFC scan via "Consommer une bouteille" on the home screen; user can cancel before a tag is read
- FR4: User can enter continuous scan mode where the phone stays NFC-ready for rapid consecutive scans
- FR5: System silently ignores duplicate reads of the same tag within a single scan session (idempotent)
- FR6: User can scan a bottle's NFC tag to look up the associated in-stock bottle via the local HTTP server
- FR7: System marks the bottle as consumed immediately upon successful tag read — no post-scan confirmation gate
- FR8: System displays bottle details (cuvée, domain, vintage, appellation) as post-consume feedback with a single "Terminé" button to return to home
- FR9: User can reverse an accidental consume by re-registering the bottle via the manager intake flow
- FR10: System displays a specific error when the scanned tag is not associated with any in-stock bottle
- FR11: Manager can initiate a scan request by sending a request to the phone's server
- FR12: Mobile app automatically switches to the scan screen and initiates NFC when the server receives a scan request — no user interaction on the phone
- FR13: Phone returns to the home screen after relaying the scanned tag UID or when the manager cancels the request
- FR14: Manager retrieves the scanned tag UID by querying the phone's server for the scan result
- FR15: Manager can initiate consecutive scan requests for bulk intake ("Ajouter la même") without re-filling the form
- FR16: Mobile app enters continuous scan mode during bulk intake — no user action on the phone at any point (screen auto-switches, NFC stays active between reads)
- FR17: Manager can cancel a pending scan request via HTTP POST, returning both devices to idle
- FR18: System enforces a configurable timeout (default 30s) on pending scan requests, notifying the manager and returning both devices to idle
- FR19: Scan requests survive phone-side errors (NFC read failure, user cancel) and can be retried without restarting the desktop form
- FR19b: Pending scan requests from the manager take priority over an active consume scan — the phone interrupts consume, switches to intake mode, and the user can re-initiate consume after intake completes
- FR19c: The intake scan screen displays a label identifying the flow as intake (e.g., "Ajout en cours — Scannez le tag pour le manager"), distinguishing it from consume scanning
- FR20: Phone hosts an HTTP REST server that starts automatically when the app launches
- FR21: Phone stores all wine data (designations, domains, cuvees, bottles, events) in a local SQLite database
- FR22: Phone registers as a discoverable mDNS service (`_winetap._tcp`) on the HTTP port
- FR23: Phone REST API provides full CRUD for designations, domains, cuvees, and bottles
- FR24: Phone REST API provides event push and subscription endpoints
- FR25: Phone REST API provides autocompletion endpoints
- FR26: Manager discovers the phone automatically via mDNS on the local network
- FR27: User can manually configure the phone address (IP:port) in manager settings as a fallback
- FR28: Manager caches the last-known phone address to expedite reconnection
- FR29: Manager displays a clear connection state indicator (connected, connecting, unreachable)
- FR30: System displays specific, actionable error messages for: unknown tag, tag already in use, phone unreachable, scan timeout, NFC read failure
- FR31: System preserves desktop form data across all scan failures
- FR32: System provides clear recovery guidance (e.g., "réessayez", "vérifiez votre connexion WiFi")
- FR33: Manager supports two scanning backends: RFID (USB) and NFC (via phone HTTP)
- FR34: User can switch between RFID and NFC scanning mode via a setting
- FR35: Both scanning backends produce identical results across all operations
- FR36: User can export the phone's SQLite database as a backup file
- FR37: User can restore the database from a backup file
- FR38: User can import an existing RPi server database into the phone (migration tool)

### Non-Functional Requirements

- NFR1: Consume flow: "Consommer une bouteille" → bottle details displayed (consumed) in < 3s
- NFR2: Intake coordination: tag read → UID in manager in < 5s
- NFR3: Scan request delivery: manager POST → phone displays prompt in < 2s
- NFR4: App cold start to ready state (server + database) in < 3s
- NFR5: Continuous scan: < 500ms between reads (Android); < 1.5s (iOS)
- NFR6: mDNS discovery completes within 3s; falls back to cached address on timeout
- NFR7: HTTP server startup in < 1s after app launch
- NFR8: Manager HTTP client auto-recovers after WiFi reconnection within 5s
- NFR9: Intake scan requests survive phone-side NFC failures
- NFR10: No data loss on manager side during any scan failure, timeout, or cancellation
- NFR11: Phone database survives app restart, phone restart, and OS updates
- NFR12: NFC UID reading works on both iOS and Android via single Flutter plugin
- NFR13: mDNS service type `_winetap._tcp` discoverable by manager
- NFR14: Scan coordination protocol is idempotent
- NFR15: REST API returns JSON; manager parses standard JSON responses
- NFR16: Database backup export completes in < 10s for 500-bottle database
- NFR17: Database restore is atomic — partial restore does not corrupt data
- NFR18: Migration from RPi database preserves all data

### Additional Requirements (Architecture)

- AR1: drift ^2.32.0 for SQLite — type-safe queries, built-in migrations, snake_case column naming
- AR2: shelf ^1.4.0 + shelf_router ^1.1.0 for HTTP server — middleware pipeline: wakelock → logging → router
- AR3: Long polling for scan coordination — shelf async handler holds connection until tag available or 30s timeout (configurable, injectable for tests)
- AR4: Activity-based wakelock via wakelock_plus — 5min idle timer reset on each HTTP request, shelf middleware
- AR5: Flat handler architecture — handlers call drift directly, no service layer
- AR6: Server starts in main() before runApp() — DB + server + ScanCoordinator created before UI renders
- AR7: ScanProvider calls drift directly for consume flow (no HTTP roundtrip — local operations bypass server)
- AR8: Manual JSON mapping — toJson() extensions on drift entities, snake_case keys matching docs/rest-api-contracts.md
- AR9: New Go structs on manager with json:"snake_case" tags (clean break from proto-generated types)
- AR10: REST API contract (docs/rest-api-contracts.md) — 28 routes, source of truth for both Dart server and Go client
- AR11: Remove gRPC/protobuf/fixnum packages from Flutter; remove proto-generated types from manager HTTP code
- AR12: Scan state is ephemeral — memory only via ScanCoordinator (Completer + mode), not persisted
- AR13: ServerProvider replaces ConnectionProvider on phone — tracks server running state + IP address for display

### UX Design Requirements

N/A — UX spec covers desktop manager dashboard (separate feature, excluded from this epic breakdown)

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR3 (changed) | Epic 10 | Rename button to "Consommer une bouteille", cancel before scan |
| FR7 (changed) | Epic 10 | Auto-consume on tag read, no confirmation gate |
| FR8 (changed) | Epic 10 | Post-consume feedback with "Terminé" button |
| FR12 (changed) | Epic 10 | Auto screen switch on intake request, zero phone interaction |
| FR13 (changed) | Epic 10 | Auto return to home after intake scan/cancel |
| FR16 (changed) | Epic 10 | Zero user action in continuous intake mode |
| FR19b (new) | Epic 10 | Intake-over-consume priority |
| FR19c (new) | Epic 10 | Intake scan screen labeling |

## Epic List

### Epic 10: Flow Simplification (v2.1)

**User outcome:** Consume and intake flows are streamlined — consume is one-tap-scan-done with no confirmation gate, intake is fully phone-passive with zero user interaction, and intake takes priority over consume when both are active.

**Changed FRs:** FR3, FR7, FR8, FR12, FR13, FR16
**New FRs:** FR19b, FR19c
**Files impacted:** consume_screen.dart, intake_screen.dart, scan_provider.dart, intake_provider.dart + tests
**Rule:** Every story includes updated existing tests + new tests for new behavior.

## Epic 10: Flow Simplification (v2.1)

Streamline consume and intake flows — consume is one-tap-scan-done with no confirmation gate, intake is fully phone-passive with zero user interaction, and intake takes priority over consume when both are active.

### Story 10.1: Simplified Consume Flow

As a **wine collector**,
I want to tap "Consommer une bouteille", scan a bottle, and see it marked as consumed immediately,
So that consuming a bottle takes two taps total with no unnecessary confirmation step.

**Acceptance Criteria:**

**Given** the user is on the home screen
**When** they tap "Consommer une bouteille"
**Then** the NFC scan session starts immediately (iOS NFC sheet / Android foreground dispatch)
**And** the button label reads "Consommer une bouteille" (not "Scanner")

**Given** an NFC scan session is active
**When** the user taps "Annuler" before scanning a tag
**Then** the scan session ends and the user returns to the home screen
**And** no bottle state is modified

**Given** an NFC scan session is active
**When** the phone reads a tag associated with an in-stock bottle
**Then** the bottle is marked as consumed immediately (ScanProvider calls drift directly)
**And** the screen displays bottle details: cuvée, domain, vintage, appellation
**And** the screen displays "Marquée comme consommée ✓"
**And** a single "Terminé" button is shown (no "Confirmer"/"Annuler")

**Given** the post-consume feedback screen is displayed
**When** the user taps "Terminé"
**Then** the user returns to the home screen

**Given** an NFC scan session is active
**When** the phone reads a tag not associated with any in-stock bottle
**Then** the screen displays a specific error message (e.g., "Tag inconnu")
**And** a single "Terminé" button returns the user to the home screen
**And** to retry, the user re-initiates the consume flow from home

**And** all legacy confirmation UI (Confirmer/Annuler dialog, confirmation state in ScanProvider) is removed
**And** no dead code referencing the old confirmation flow remains

**Covers:** FR3, FR7, FR8, FR10 + cleanup from former Story 10.4

---

### Story 10.2: Zero-Touch Intake Screen

As a **wine collector using the desktop manager**,
I want the phone to automatically switch to the intake scan screen when the manager requests a scan,
So that I never need to touch the phone during intake.

**Acceptance Criteria:**

**Given** the phone is on any screen (home, post-consume feedback, settings)
**When** the server receives a scan request from the manager
**Then** the phone automatically switches to the intake scan screen
**And** NFC scanning initiates without any user interaction on the phone
**And** the intake scan screen displays "Ajout en cours — Scannez le tag pour le manager"

**Given** the phone is on the intake scan screen
**When** an NFC tag is read
**Then** the tag UID is relayed to the manager (via scan result endpoint)
**And** the phone returns to the home screen automatically

**Given** the phone is on the intake scan screen
**When** the manager cancels the scan request
**Then** the phone returns to the home screen automatically

**Given** the phone is in continuous intake mode (bulk intake)
**When** the manager sends consecutive scan requests
**Then** the phone stays on the intake scan screen with NFC active between reads
**And** no user interaction is required on the phone at any point

**And** all legacy "Prêt à scanner" UI (button, manual scan initiation in IntakeProvider) is removed
**And** no dead code referencing the old intake initiation flow remains

**Covers:** FR12, FR13, FR16, FR19c + cleanup from former Story 10.4

---

### Story 10.3: Intake-Over-Consume Priority

As a **wine collector**,
I want intake scan requests to take priority over an active consume scan,
So that the manager is never blocked waiting when I happen to be consuming a bottle.

**Acceptance Criteria:**

**Given** the user is in an active consume NFC scan (tapped "Consommer une bouteille", NFC session running)
**When** the server receives a scan request from the manager
**Then** the active consume scan is cancelled
**And** the phone switches to the intake scan screen
**And** the intake scan screen displays the intake label ("Ajout en cours — Scannez le tag pour le manager")

**Given** the user was on the post-consume feedback screen (bottle details + "Terminé")
**When** the server receives a scan request from the manager
**Then** the phone switches to the intake scan screen (interrupting the feedback)
**And** the already-consumed bottle is NOT rolled back — consume is final once the tag is read, regardless of whether "Terminé" was tapped

**Given** an intake scan interrupted an active consume
**When** the intake scan completes and the phone returns to home
**Then** the user can re-initiate consume by tapping "Consommer une bouteille" again
**And** no bottle state was modified by the interrupted consume (unless a tag was already read)

**Covers:** FR19b

