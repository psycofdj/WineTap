---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
inputDocuments:
  - _bmad-output/planning-artifacts/prd-mobile.md
  - _bmad-output/planning-artifacts/architecture-mobile-v2.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - docs/rest-api-contracts.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-04-01.md
workflowType: 'epics'
project_name: 'winetap-mobile-v2'
user_name: 'Psy'
date: '2026-04-01'
---

# winetap-mobile-v2 — Epic Breakdown

## Overview

This document provides the epic and story breakdown for winetap-mobile v2 (phone-as-server), decomposing the requirements from the PRD v2 and Architecture v2 into implementable stories.

**Context:** This is the v2 evolution. v1 (Epics 1-4, RPi server + gRPC) is complete. v2 replaces the RPi server with an embedded HTTP server on the phone, moves the SQLite database to the phone, and migrates the manager from gRPC to HTTP REST.

## Requirements Inventory

### Functional Requirements

- FR1: User can read an NFC tag UID by holding the phone to a tagged bottle
- FR2: System normalizes NFC tag UIDs to canonical format (uppercase hex, no separators)
- FR3: User can initiate a single NFC scan session via explicit action
- FR4: User can enter continuous scan mode for rapid consecutive scans
- FR5: System silently ignores duplicate reads within a scan session (idempotent)
- FR6: User can scan a bottle's NFC tag to look up the associated in-stock bottle via local HTTP server
- FR7: System displays bottle details (cuvée, domain, vintage, appellation) for confirmation
- FR8: User can confirm consumption ("Confirmer") or cancel ("Annuler")
- FR9: System marks bottle as consumed and clears tag association
- FR10: System displays error when scanned tag is not associated with any in-stock bottle
- FR11: Manager can initiate a scan request by POSTing to the phone's HTTP server
- FR12: Mobile app receives and displays pending scan requests via its local server
- FR13: User can respond to a scan request by initiating an NFC scan
- FR14: Manager retrieves the scanned tag UID by polling the phone's HTTP server
- FR15: Manager can initiate consecutive scan requests for bulk intake
- FR16: Mobile app enters continuous scan mode during bulk intake
- FR17: Manager can cancel a pending scan request via HTTP POST
- FR18: System enforces configurable timeout (30s default) on pending scan requests
- FR19: Scan requests survive phone-side errors and can be retried
- FR20: Phone hosts an HTTP REST server that starts automatically on app launch
- FR21: Phone stores all wine data in a local SQLite database
- FR22: Phone registers as discoverable mDNS service (`_winetap._tcp`)
- FR23: Phone REST API provides full CRUD for designations, domains, cuvees, and bottles
- FR25: Phone REST API provides autocompletion endpoints
- FR26: Manager discovers the phone automatically via mDNS
- FR27: User can manually configure phone address in manager settings
- FR28: Manager caches last-known phone address
- FR29: Manager displays connection state indicator
- FR30: System displays specific error messages for all failure modes
- FR31: System preserves desktop form data across scan failures
- FR32: System provides recovery guidance
- FR33: Manager supports two scanning backends: RFID (USB) and NFC (via phone HTTP)
- FR34: User can switch between RFID and NFC scanning mode
- FR35: Both scanning backends produce identical results
- FR36: User can export the phone's SQLite database as a backup
- FR37: User can restore the database from a backup file

### NonFunctional Requirements

- NFR1: Consume flow < 3s (local server)
- NFR2: Intake coordination < 5s (WiFi, long polling)
- NFR3: Scan request delivery < 2s
- NFR4: App cold start (server + database) < 3s
- NFR5: Continuous scan < 500ms (Android) / < 1.5s (iOS)
- NFR6: mDNS discovery < 3s
- NFR7: HTTP server startup < 1s
- NFR8: Manager HTTP client auto-recovers within 5s
- NFR9: Scan requests survive NFC failures
- NFR10: No data loss on manager during failures
- NFR11: Phone database survives restarts
- NFR12: NFC works on iOS + Android via single plugin
- NFR13: mDNS `_winetap._tcp` discoverable by manager
- NFR14: Scan coordination idempotent
- NFR15: REST API returns JSON
- NFR16: Database backup < 10s for 500 bottles
- NFR17: Database restore is atomic
- NFR18: Migration from RPi preserves all data (deferred — manual seed SQL)

### Additional Requirements

- drift ^2.32.0 for SQLite (type-safe, migrations, snake_case columns)
- shelf ^1.4.0 + shelf_router ^1.1.0 for HTTP server
- wakelock_plus ^1.4.0 for activity-based idle timeout
- Server starts in `main()` before `runApp()` — database + server + scanCoordinator init first
- Handlers call drift directly — no service layer
- ScanCoordinator class passed as parameter (not global state)
- Consume flow calls drift directly — no HTTP roundtrip
- Manual JSON mapping — snake_case fields, toJson() extensions on drift entities
- New Go structs in manager with json:"snake_case" tags (clean break from proto)
- Remove grpc, protobuf, fixnum packages from Flutter
- ConnectionProvider dropped on phone — replaced by ServerProvider showing IP+port
- REST API contract: `docs/rest-api-contracts.md` (27 routes)
- Long poll for scan coordination (30s default, configurable for tests)
- Shelf idle timeout ≥ 60s
- Partial updates: absent = don't update, null = clear
- Tag ID normalization on all endpoints accepting tag_id

### UX Design Requirements

- No UX spec changes required for v2 — existing screens adapted for local server
- Settings screen redesigned: shows server IP+port, status, backup/restore (no "enter server address")
- Connection indicator on phone → server status indicator (IP+port display)

### FR Coverage Map

| FR | Epic | Description |
|-----|------|-------------|
| FR1 | 6 | NFC read |
| FR2 | 6 | Tag normalization |
| FR3 | 6 | Single scan initiation |
| FR4 | 7 | Continuous scan mode |
| FR5 | 6 | Duplicate suppression |
| FR6 | 6 | Scan → lookup bottle (drift direct) |
| FR7 | 6 | Display bottle details |
| FR8 | 6 | Confirm/cancel |
| FR9 | 6 | Mark consumed |
| FR10 | 6 | Unknown tag error |
| FR11 | 7 | Manager POST scan request |
| FR12 | 7 | Phone displays request |
| FR13 | 7 | User responds with NFC |
| FR14 | 7 | Manager polls result |
| FR15 | 7 | Consecutive requests |
| FR16 | 7 | Continuous bulk intake |
| FR17 | 7 | Manager cancels request |
| FR18 | 7 | Timeout (30s) |
| FR19 | 7 | Retry after NFC failure |
| FR20 | 5 | HTTP server auto-starts |
| FR21 | 5 | SQLite on phone |
| FR22 | 5 | mDNS registration |
| FR23 | 5 | Full CRUD API |
| FR25 | 5 | Completions |
| FR26 | 6-mgr | Manager mDNS discovery |
| FR27 | 6-mgr | Manual IP fallback |
| FR28 | 6-mgr | Cached address |
| FR29 | 6-mgr | Connection indicator |
| FR30 | 6+7 | Error messages |
| FR31 | 7 | Preserve form data |
| FR32 | 6+7 | Recovery guidance |
| FR33 | 7 | Dual scanning backends |
| FR34 | 7 | Scan mode toggle |
| FR35 | 7 | Identical results |
| FR36 | 8 | Backup export |
| FR37 | 8 | Restore import |

**Deferred:** FR24 (events), FR38 (RPi migration)

## Epic List

### Epic 5: Phone Server + Local Consume
Build the Dart HTTP server with SQLite on the phone, serve all REST endpoints, migrate consume to local drift access, and remove gRPC dependencies. The phone becomes a fully functional server and standalone consume device.

**FRs covered:** FR1-3, FR5-10, FR20-23, FR25, FR30, FR32
**NFRs covered:** NFR1, NFR4, NFR5, NFR7, NFR11, NFR12, NFR15
**User outcome:** Phone stores all wine data, serves REST API, consume flow works locally with zero network dependency.
**Standalone:** Yes — phone is fully functional as server + consumer.
**Language:** Dart/Flutter

### Epic 6: Manager HTTP Migration
Replace the Go manager's gRPC client with HTTP client targeting the phone. Discover phone via mDNS. Rewire all screens for HTTP.

**FRs covered:** FR26-29
**NFRs covered:** NFR6, NFR8, NFR13
**User outcome:** Manager connects to phone over HTTP, can browse and manage the full catalog.
**Standalone:** Yes — manager works with phone server from Epic 5.
**Depends on:** Epic 5

### Epic 7: Coordinated Intake via HTTP
Scan coordination REST endpoints on the phone. Manager requests scans via HTTP, long-polls for results. Single + continuous mode. Full error handling.

**FRs covered:** FR4, FR11-19, FR30-35
**NFRs covered:** NFR2, NFR3, NFR5, NFR8-10, NFR14
**User outcome:** Complete intake coordination — Marc fills form on desktop, phone scans tags, UIDs relay back via HTTP.
**Standalone:** Yes — builds on server + manager connection.
**Depends on:** Epic 5 + Epic 6

### Epic 8: Data Resilience
Backup and restore the phone's SQLite database.

**FRs covered:** FR36, FR37
**NFRs covered:** NFR16, NFR17
**User outcome:** Marc can protect his cellar data against lost/broken phone.
**Standalone:** Yes.
**Depends on:** Epic 5

## Epic 5: Phone Server + Local Consume

Build the Dart HTTP server with SQLite on the phone, serve all REST endpoints, migrate consume to local drift access, and remove gRPC dependencies.

### Story 5.1: Drift Database and Schema

As a developer,
I want the phone to have a SQLite database with the complete wine cellar schema,
So that all subsequent server endpoints and the consume flow have a data foundation.

**Acceptance Criteria:**

**Given** `server/database.dart` defines all drift tables (designations, domains, cuvees, bottles)
**When** `dart run build_runner build` is run
**Then** `database.g.dart` generates without errors
**And** all tables use `snake_case` column names matching the RPi schema
**And** `toJson()` extensions exist for all entities (snake_case JSON keys)
**And** foreign key constraints match existing schema (cuvees→domains, cuvees→designations, bottles→cuvees)
**And** `flutter analyze` passes

### Story 5.2: Shelf HTTP Server + Middleware

As a developer,
I want the phone to run an HTTP server that starts before the UI,
So that the manager and local consume flow have an API endpoint.

**Acceptance Criteria:**

**Given** `server/server.dart` sets up shelf + shelf_router on port 8080
**When** the app launches
**Then** the server starts in `main()` before `runApp()` (database → scanCoordinator → server → UI)
**And** wakelock middleware resets a 5-minute idle timer on each request
**And** the phone registers `_winetap._tcp` via mDNS (bonsoir)
**And** shelf idle timeout is ≥ 60s
**And** a health check `GET /` returns 200
**And** database and scanCoordinator are passed to handlers as parameters (no globals)

### Story 5.3: Catalog REST API (Designations, Domains, Cuvees)

As a user,
I want the phone to serve CRUD endpoints for designations, domains, and cuvees,
So that the manager can manage the wine catalog.

**Acceptance Criteria:**

**Given** `handlers/designations.dart`, `handlers/domains.dart`, `handlers/cuvees.dart`
**When** any CRUD operation is performed
**Then** GET/POST/PUT/DELETE for each entity works per `docs/rest-api-contracts.md`
**And** 409 returned on unique constraint violations (name already exists)
**And** 412 returned on foreign key delete violations (entity referenced by children)
**And** all JSON responses use snake_case fields
**And** handlers call drift directly (no service layer)

### Story 5.4: Bottle REST API + Completions

As a user,
I want the phone to serve all bottle endpoints and autocomplete,
So that the manager can add, browse, update, and consume bottles.

**Acceptance Criteria:**

**Given** `handlers/bottles.dart` and `handlers/completions.dart`
**When** any bottle or completion operation is performed
**Then** all 9 bottle routes work per `docs/rest-api-contracts.md`: GET /bottles, GET /bottles/:id, GET /bottles/by-tag/:tag_id, POST /bottles, POST /bottles/consume, PUT /bottles/:id, PUT /bottles/bulk, DELETE /bottles/:id, PUT /bottles/:id/tag
**And** GET /completions returns matching values for designation/domain/cuvee prefix
**And** partial updates: absent fields = don't update, explicit null = clear value
**And** tag_id normalized on all accepting endpoints (strips separators, uppercases)
**And** bottles response includes denormalized cuvee (with domain_name, designation_name, region)

### Story 5.5: Local Consume Flow (Drift Direct)

As a user,
I want to consume bottles by scanning NFC tags with zero network dependency,
So that I can manage my cellar from the phone alone.

**Acceptance Criteria:**

**Given** ScanProvider is rewired to call drift directly (not HTTP, not gRPC)
**When** the user scans a bottle
**Then** scan → `db.getBottleByTagId(tagId)` → bottle details → confirm → `db.consumeBottle(tagId)` — all drift direct
**And** no HTTP roundtrip for consume — fully local, zero latency
**And** ConsumeScreen works without any network connection
**And** UI widgets (BottleDetailsCard, ConsumeScreen, ScanProvider) accept drift data classes — proto Bottle type retired
**And** ConnectionProvider removed from phone — replaced by ServerProvider showing server IP+port
**And** error messages preserved (unknown tag → "Tag inconnu", NFC failure → "Aucun tag détecté")

### Story 5.6: Remove gRPC Dependencies

As a developer,
I want all gRPC/protobuf code removed from the Flutter project,
So that the codebase is clean and only uses HTTP REST + drift.

**Acceptance Criteria:**

**Given** pubspec.yaml
**When** cleanup is complete
**Then** `grpc`, `protobuf`, `fixnum` packages are removed
**And** `mobile/lib/gen/` directory is deleted
**And** all imports of generated proto code are replaced with drift types
**And** `make proto-dart` target removed from Makefile
**And** `buf.gen.dart.yaml` removed
**And** `flutter analyze` passes
**And** `flutter test` passes
**And** `flutter build apk --debug` succeeds

## Epic 6: Manager HTTP Migration

Replace the Go manager's gRPC client with HTTP client targeting the phone. Discover phone via mDNS. Rewire all screens.

### Story 6.1: Go HTTP Client and API Types

As a developer,
I want a Go HTTP client with typed structs matching the phone's REST API,
So that the manager can communicate with the phone over HTTP.

**Acceptance Criteria:**

**Given** `internal/manager/http_client.go` and `internal/manager/api_types.go`
**When** the client is used
**Then** all entity structs (Designation, Domain, Cuvee, Bottle) have `json:"snake_case"` tags
**And** nullable fields use pointer types (`*string`, `*float64`, `*int32`) with `omitempty`
**And** `WineTapClient` struct wraps `*http.Client` with `baseURL`
**And** methods exist for all 27 routes per `docs/rest-api-contracts.md`
**And** error responses parsed into structured `APIError{Code, Message}`
**And** manager builds without errors

### Story 6.2: Manager mDNS Discovery of Phone

As a user,
I want the manager to discover the phone automatically on the local network,
So that I don't need to configure the phone's IP address manually.

**Acceptance Criteria:**

**Given** the manager starts and the phone app is running
**When** the manager browses for `_winetap._tcp`
**Then** on discovery, caches the phone address in config
**And** on failure, falls back to cached address
**And** if no cache, shows settings for manual IP:port entry (FR27)
**And** connection state indicator shows connected/connecting/unreachable (FR29)
**And** auto-recovers within 5s of WiFi reconnection (NFR8)

### Story 6.3: Rewire Manager Screens for HTTP

As a user,
I want all manager screens to work with the phone's HTTP API,
So that I can browse inventory and manage the catalog as before.

**Note:** This is the largest story — mechanical refactoring of all screen files from gRPC to HTTP. Same pattern repeated across files.

**Acceptance Criteria:**

**Given** `screen/ctx.go` updated to use `WineTapClient` (HTTP) instead of gRPC
**When** any manager screen operation is performed
**Then** inventory screen lists bottles via HTTP GET /bottles
**And** inventory form creates/updates bottles via HTTP POST/PUT
**And** designation/domain/cuvee management screens work via HTTP
**And** autocomplete fields use GET /completions
**And** all existing manager functionality preserved — identical behavior
**And** gRPC client code (`v1.NewWineTapClient`, proto imports) removed from manager
**And** manager builds and all tests pass

### Story 6.4: Manager NFCScanner Stub for HTTP

As a developer,
I want the NFCScanner in the manager to be prepared for HTTP polling,
So that the intake flow (Epic 7) has a foundation.

**Acceptance Criteria:**

**Given** `internal/manager/nfc_scanner.go` rewritten for HTTP
**When** `StartScan` is called
**Then** it POSTs to /scan/request on the phone
**And** `StopScan` POSTs to /scan/cancel
**And** result retrieval via GET /scan/result (long poll) prepared but not wired to UI yet
**And** Scanner interface contract preserved (OnTagScanned callback)
**And** manager builds

## Epic 7: Coordinated Intake via HTTP

Scan coordination REST endpoints on the phone. Manager requests scans via HTTP, long-polls for results. Single + continuous mode. Full error handling.

### Story 7.1: Scan Coordination REST Endpoints

As a developer,
I want the phone to serve scan coordination endpoints,
So that the manager can request NFC scans and retrieve results over HTTP.

**Note:** Long-poll handler test requires concurrent async pattern — one task calls GET /scan/result (blocks), another submits result after delay. Use configurable timeout (100ms in tests).

**Acceptance Criteria:**

**Given** `handlers/scan.dart` and `server/scan_coordinator.dart`
**When** the manager requests a scan
**Then** POST /scan/request creates a pending scan with mode (single/continuous), returns 201
**And** GET /scan/result long-polls: blocks until tag available (200 + tag_id) or timeout (204)
**And** POST /scan/cancel cancels pending scan, returns 200
**And** 409 returned if scan already in progress
**And** 410 returned on GET /scan/result if cancelled during wait
**And** ScanCoordinator is a class passed as parameter (not global)
**And** timeout is configurable (30s default, injectable for tests)

### Story 7.2: IntakeProvider Rewrite for Local Server

As a user,
I want the phone's intake screen to show scan requests from the manager,
So that I know when to scan a bottle.

**Acceptance Criteria:**

**Given** IntakeProvider rewritten to watch ScanCoordinator (not bidi stream)
**When** the manager sends a scan request
**Then** IntakeProvider detects pending request and shows "Prêt à scanner"
**And** user taps button → NfcService.readTagId() → ScanCoordinator.submitResult(tagId)
**And** the long-polling manager receives the tag_id immediately
**And** single mode: returns to waiting after result delivered
**And** IntakeScreen preserved with all states (idle, scanRequested, scanning, tagSent, continuousReady, error)
**And** NFC session cancelled → scan request stays active for retry (FR19)

### Story 7.3: Manager NFCScanner HTTP Polling

As a user,
I want the manager to request scans and receive tag UIDs from the phone over HTTP,
So that I can register bottles at the desktop while scanning with the phone.

**Acceptance Criteria:**

**Given** `nfc_scanner.go` fully wired for HTTP
**When** a scan is initiated from the manager
**Then** `StartScan(single)` → POST /scan/request → long-poll GET /scan/result → OnTagScanned(tagId)
**And** `StartScan(continuous)` → POST /scan/request with mode=continuous → repeated long-polls
**And** `StopScan` → POST /scan/cancel
**And** long-poll timeout (204) → automatic retry
**And** phone unreachable → error notification, form data preserved (FR31, NFR10)
**And** Scanner interface contract preserved — RFID/NFC toggle still works (FR33-35)
**And** manager inventory form populates tag field on scan result

### Story 7.4: Continuous Scan Mode + Error Handling

As a user,
I want continuous scanning for bulk intake with clear error recovery,
So that I can register many bottles quickly without interruption.

**Acceptance Criteria:**

**Given** continuous mode active
**When** bottles are scanned in sequence
**Then** after first scan, NFC stays active for next tag automatically (FR4, FR16)
**And** duplicate tags silently ignored (FR5, NFR14)
**And** "Tag lu ✓" flashes briefly, then returns to "Prêt" (FR15)
**And** manager cancel → phone stops NFC, returns to waiting (FR17)
**And** 30s timeout → phone shows "Délai dépassé" briefly (FR18)
**And** NFC failure → scan request stays active, user retries (FR19, NFR9)
**And** phone unreachable → manager shows error, form data preserved (FR30, FR31)

## Epic 8: Data Resilience

Backup and restore the phone's SQLite database.

### Story 8.1: Backup and Restore Endpoints

As a user,
I want to download and upload the phone's database,
So that I can protect my cellar data against a lost or broken phone.

**Acceptance Criteria:**

**Given** `handlers/backup.dart`
**When** GET /backup is called
**Then** returns raw SQLite .db file with `Content-Type: application/octet-stream`
**And** includes `Content-Disposition: attachment; filename="winetap.db"`
**And** backup completes in < 10s for 500-bottle database (NFR16)
**When** POST /restore is called with a raw SQLite file
**Then** replaces the current database atomically (NFR17)
**And** partial upload does not corrupt the existing database
**And** server reinitializes drift with the new database after restore

### Story 8.2: Settings Screen with Backup/Restore

As a user,
I want backup and restore buttons on the phone's settings screen,
So that I can manage my data without technical knowledge.

**Acceptance Criteria:**

**Given** the settings screen redesigned for v2
**When** the user views settings
**Then** it shows: server IP + port, server status (running/stopped)
**And** "Exporter la base" button triggers backup and saves to phone storage
**And** "Restaurer la base" button lets user pick a .db file and uploads to restore
**And** confirmation dialog before restore ("Cela remplacera toutes les données actuelles")
**And** success/error feedback after each operation
**And** all strings from S class (French)
