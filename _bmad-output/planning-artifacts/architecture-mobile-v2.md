---
stepsCompleted:
  - step-01-init
  - step-02-context
  - step-03-starter
  - step-04-decisions
  - step-05-patterns
  - step-06-structure
  - step-07-validation
  - step-08-complete
status: 'complete'
completedAt: '2026-04-01'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-mobile.md
  - _bmad-output/planning-artifacts/product-brief-winetap-mobile.md
  - _bmad-output/planning-artifacts/architecture-mobile.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-04-01.md
  - docs/data-models.md
  - docs/api-contracts.md
  - docs/development-guide.md
workflowType: 'architecture'
project_name: 'winetap-mobile'
user_name: 'Psy'
date: '2026-04-01'
---

# Architecture Decision Document — WineTap Mobile v2

_Phone-as-server evolution. Replaces architecture-mobile.md (v1 — RPi server + gRPC)._

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
38 FRs across 8 capability areas — the phone becomes a full-stack server while preserving its NFC scanning role:

- NFC Tag Scanning (FR1-5): Unchanged from v1 — platform-abstracted NFC reading, UID normalization, single + continuous scan modes, idempotent duplicate handling
- Consume Flow (FR6-10): Now fully local — phone queries its own SQLite database, no network required
- Intake Coordination (FR11-19): Manager POSTs scan request to phone HTTP server, long-polls for result. Phone handles NFC and responds. Replaces bidi gRPC stream.
- Phone Server & Database (FR20-25): NEW — Dart HTTP server (shelf), SQLite database (drift), REST API with full CRUD for all entities, mDNS registration
- Manager Connection (FR26-29): Manager discovers phone via mDNS, connects via HTTP. Replaces gRPC connection to RPi.
- Error Handling (FR30-32): Same UX patterns, different transport (HTTP errors instead of gRPC status codes)
- Manager Dual Scanning (FR33-35): NFC backend now POSTs to phone HTTP instead of bidi gRPC stream
- Data Resilience (FR36-38): NEW — backup, restore, import from RPi database

**Non-Functional Requirements:**
- Performance: consume < 3s (local), intake < 5s (long polling), server startup < 1s
- Reliability: manager auto-recovers, scan requests survive NFC failures, no data loss
- Integration: REST JSON API, mDNS `_winetap._tcp`, idempotent coordination
- Data resilience: backup < 10s, atomic restore, RPi migration preserves all data

**Scale & Complexity:**
- Complexity level: **Medium**
- Primary domain: Mobile server + desktop client (role inversion from typical architecture)
- Estimated new/modified architectural components: ~10

### Technical Constraints & Dependencies

**Inherited constraints (preserved from v1):**
- Flutter for mobile (cross-platform iOS + Android)
- Go/Qt for desktop manager (existing codebase)
- NFC via `nfc_manager` v4 Flutter plugin
- French-only UI throughout
- No authentication — WiFi-only trust model
- iOS NFC requires paid Apple Developer account

**New constraints from v2:**
- Dart `shelf` package for HTTP server (no gRPC server in Dart)
- `drift` for SQLite on phone (type-safe queries, migrations, reactive streams)
- HTTP REST (JSON) replaces gRPC (protobuf) as wire format
- Phone mDNS registration via `bonsoir`
- Manager must discover phone (was: discover RPi)
- Consume works offline (local server); intake requires WiFi
- Long polling replaces bidi streaming for scan coordination
- `wakelock` plugin for activity-based idle timeout

**Technology boundary:**
- Phone: Flutter/Dart (HTTP server + SQLite + NFC scanner)
- Manager: Go/Qt (HTTP client, existing UI)
- Shared contract: JSON REST API (replaces protobuf)
- Database: SQLite via drift (same schema as RPi, different host)

### Cross-Cutting Concerns Identified

1. **SQLite schema compatibility** — Phone database must match the existing RPi schema exactly (5 tables, same columns, same constraints). Migration from RPi database must be lossless. drift handles schema migrations.

2. **REST API design** — ~25 routes mirroring the current gRPC service (minus events). JSON request/response format. Must support all existing manager operations (CRUD for all entities, partial updates, autocompletion, scan coordination).

3. **Scan coordination protocol** — Replaces bidi gRPC stream. Three endpoints: POST /scan/request, GET /scan/result (long polling — holds connection until tag available or 30s timeout), POST /scan/cancel. Phone manages NFC session and scan state machine locally.

4. **mDNS role reversal** — Phone registers `_winetap._tcp` via bonsoir. Manager browses for it. Same service type, different registrar.

5. **Activity-based wakelock** — Any HTTP request from the manager resets a 5-minute idle timer. While timer is active, phone stays awake. Timer expires → wakelock released. Implemented as shelf middleware intercepting every request.

6. **Server lifecycle on phone** — HTTP server starts on app launch. Foreground-only for MVP (iOS kills background servers). Consume works anytime (local). Intake requires app open.

7. **Data resilience** — Phone is the single source of truth. All writes go through REST API. No sync, no conflict resolution. Backup/restore for lost/broken phone. Migration tool imports RPi database.

8. **Tag ID normalization** — Same logic on both sides (Dart `normalizeTagId` + Go `NormalizeTagID`). Already implemented and tested.

### Party Mode Architectural Decisions (2026-04-01)

Consensus from multi-agent discussion:

1. **No graceful degradation** — phone must be open for intake. This is a UX constraint, not a technical limitation. Accepted.
2. **All writes through REST** — phone is single source of truth. No database sync, no conflict resolution. Manager reads and writes via HTTP.
3. **drift for SQLite** — type-safe queries, built-in migrations, reactive streams. Replaces raw sqflite.
4. **Long polling for scan coordination** — phone holds GET /scan/result until tag available or 30s timeout. Near-instant delivery vs 500ms periodic polling. Trivial with shelf async handlers.
5. **Activity-based wakelock** — 5-minute idle timer, reset on each HTTP request from manager. Shelf middleware. Prevents phone sleep during intake and catalog editing.
6. **~25 REST routes for MVP** — all CRUD + completions + scan coordination. Events (push/subscribe/acknowledge) deferred post-MVP.
7. **iOS background: not attempted** — foreground-only. Accepted constraint.

## Starter Template Evaluation

### Primary Technology Domain

Brownfield project — Flutter app and Go manager already exist. No project scaffolding needed. Evaluation covers new dependencies only.

### New Dependencies

| Package | Purpose | Version | Notes |
|---------|---------|---------|-------|
| `shelf` | Dart HTTP server | ^1.4.0 | Official Dart team, production-ready |
| `shelf_router` | URL routing for shelf | ^1.1.0 | Official companion — essential for 25 routes |
| `drift` | Type-safe SQLite ORM | ^2.32.0 | Auto-bundles SQLite, migrations, reactive streams |
| `drift_flutter` | Flutter integration | ^0.2.0 | Companion package |
| `drift_dev` | Code generation | ^2.32.0 | dev_dependency — generates .g.dart files |
| `build_runner` | Dart code gen runner | ^2.4.0 | dev_dependency — runs drift codegen |
| `wakelock_plus` | Screen wakelock | ^1.4.0 | Activity-based idle timeout |

### Packages to Remove (from v1)

| Package | Reason |
|---------|--------|
| `grpc` | Replaced by shelf (phone) and net/http (manager) |
| `protobuf` | JSON replaces protobuf wire format |
| `fixnum` | Was needed by protobuf generated code |

### Selected Stack Rationale

- **shelf**: Official Dart HTTP server. Lightweight, composable middleware, async handlers (supports long polling natively). Maintained by the Dart team.
- **shelf_router**: `router.get('/bottles', handler)` style routing. Essential for 25 routes.
- **drift**: Most mature Dart SQLite ORM. Type-safe query builder, built-in schema migrations (versioned), reactive streams via `.watch()`, code generation via `build_runner`.

### Architecture Patterns Established

**drift:**
- Table definitions as Dart classes with `snake_case` column naming (matching existing RPi schema)
- Type-safe query builder — no raw SQL strings
- Versioned schema migrations
- Reactive streams via `.watch()` queries
- Code generation: `dart run build_runner build` after table changes

### Party Mode Decisions — Starter & API (2026-04-01)

1. **`snake_case` JSON fields everywhere** — matches database, matches old proto convention, REST standard. Go uses `json:"snake_case"` struct tags. Dart maps use string keys directly.
2. **REST API contract document written first** — `docs/rest-api-contracts.md` is the source of truth for both Dart server and Go client. 28 routes documented with exact field names, types, and error codes.
3. **shelf idle timeout ≥ 60s** — prevents framework from killing long-poll connections before the 30s scan timeout.
4. **Scan coordination state is ephemeral** — memory only, not persisted. Same as v1. Force-kill = state lost, manager treats as "phone unreachable".
5. **Configurable long-poll timeout** — injectable for testing (default 30s, 100ms in tests). Same pattern as v1 ScanSession.
6. **Revised implementation sequence** — manager HTTP client built before scan coordination (validate simple CRUD over HTTP before tackling complex polling).

**shelf:**
- Middleware pipeline: wakelock timer → logging → router
- Router-based URL dispatch (`shelf_router`)
- Async request handlers (long polling for scan coordination)
- JSON serialization via `dart:convert`

### Serialization & API Contract

- **Manual JSON mapping** on both sides — Dart `Map<String, dynamic>`, Go `encoding/json` struct tags
- **New Go structs** on manager — clean break from proto-generated types
- **API contract document** — update existing `docs/api-contracts.md` for REST. This replaces the proto file as the source of truth.
- **drift column naming**: `snake_case` configured from day one for RPi import compatibility

### Testing Strategy

- **Unit tests via mocks** — mock the shelf handlers and drift database in tests
- **Real testing on phone** — no standalone server harness. Run the app on the device for integration testing.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
1. Phone HTTP server — shelf on port 8080, idle timeout ≥ 60s
2. Phone database — drift (SQLite, snake_case columns)
3. REST API — flat URLs, snake_case JSON, manual mapping both sides
4. Scan coordination — long poll (30s default, configurable) + cancel
5. Manager structs — new Go types with json:"snake_case" tags, clean break from proto
6. API contract — `docs/rest-api-contracts.md` is source of truth (28 routes)

**Important Decisions (Shape Architecture):**
7. Activity-based wakelock — 5min idle timeout, shelf middleware, reset on each request
8. mDNS registration — phone registers `_winetap._tcp` on port 8080 via bonsoir
9. Backup/restore — GET /backup returns raw .db file, POST /restore replaces database
10. Error format — `{"error": "code", "message": "description"}` + HTTP status codes

**Deferred Decisions (Post-MVP):**
- Events system (push/subscribe/acknowledge)
- iOS background server — foreground-only accepted
- Authentication / HTTPS
- App Store distribution
- RPi database migration (manual seed SQL if needed)
- Designation picture BLOB in REST API

### Data Architecture

- **Database**: drift ^2.32.0, SQLite with `snake_case` column names
- **Schema**: mirrors existing RPi schema (designations, domains, cuvees, bottles; events table kept but API deferred)
- **Migrations**: drift built-in versioned migrations. No RPi import tool — manual seed SQL if needed.
- **Backup**: GET /backup → raw .db file. POST /restore → replace database atomically.

### Authentication & Security

- **No authentication** — WiFi-only trust model (unchanged from v1)
- **No HTTPS** — local network only, insecure HTTP
- **Same security posture as v1** — deferred post-MVP

### API & Communication Patterns

- **Transport**: HTTP REST (JSON) over WiFi on port 8080. Phone serves, manager consumes.
- **URL structure**: flat paths — `/designations`, `/bottles`, `/bottles/by-tag/:tag_id`
- **JSON field naming**: `snake_case` throughout — matches DB, matches old proto convention
- **Error format**: `{"error": "not_found", "message": "..."}` with HTTP status codes
- **Serialization**: manual JSON mapping. Dart `dart:convert`, Go `encoding/json` with struct tags.
- **Scan coordination**:
  - POST /scan/request `{"mode": "single|continuous"}` → 201
  - GET /scan/result (long poll, blocks 30s default, configurable) → 200 with tag_id, 204 timeout, 410 cancelled
  - POST /scan/cancel → 200
- **Scan state**: ephemeral, memory-only. Force-kill = state lost. Same as v1.
- **Backup/restore**: GET /backup → binary .db file. POST /restore → binary upload, atomic replace.
- **API contract**: `docs/rest-api-contracts.md` — 28 routes, source of truth for both sides.

### Frontend Architecture (Flutter — preserved from v1)

- **State management**: Provider (ChangeNotifier pattern) — unchanged
- **Screens**: ConsumeScreen, IntakeScreen, SettingsScreen — adapted for local HTTP
- **NFC**: nfc_manager v4 — unchanged
- **Navigation**: BottomNavigationBar with IndexedStack — unchanged
- **Strings**: French constants in S class — unchanged

### Manager Architecture (Go/Qt — adapted)

- **HTTP client**: Go `net/http` replacing gRPC client
- **Structs**: new Go types with `json:"snake_case"` tags (clean break from proto-generated types)
- **Scanner interface**: preserved. NFCScanner rewritten for HTTP polling (POST request, long-poll result)
- **mDNS discovery**: Go mDNS browser discovers phone's `_winetap._tcp` service
- **UI**: unchanged — all Qt screens preserved

### Infrastructure & Deployment

- **Phone**: Flutter app with embedded shelf server + drift database. Foreground-only.
- **Manager**: Go/Qt desktop app connecting to phone via HTTP.
- **No RPi**: decommissioned.
- **Distribution**: TestFlight (iOS, requires paid dev account) + sideloaded APK (Android)

### Decision Impact — Implementation Sequence

1. drift database + schema (foundation)
2. shelf HTTP server + router + wakelock middleware (transport)
3. CRUD REST endpoints — designations, domains, cuvees (catalog)
4. Bottle REST endpoints — add, list, consume, get-by-tag, update, bulk-update, delete, set-tag
5. **Manager HTTP client + mDNS discovery** (validate CRUD over HTTP end-to-end)
6. Consume flow migration (local HTTP calls)
7. Scan coordination REST endpoints (long poll)
8. Manager NFCScanner HTTP rewrite
9. Intake flow migration (polling)
10. Completions endpoint + INAO refresh
11. Backup/restore endpoints

## Implementation Patterns & Consistency Rules

### Phone Server Architecture

**Layer structure — flat (handlers call drift directly, no service layer):**

```
mobile/lib/
├── main.dart                    # Server init BEFORE runApp()
├── server/
│   ├── server.dart              # shelf setup, middleware pipeline, start/stop
│   ├── database.dart            # drift database class + ALL table definitions
│   ├── scan_coordinator.dart    # scan state machine (Completer + mode)
│   ├── handlers/
│   │   ├── designations.dart    # CRUD + INAO refresh
│   │   ├── domains.dart         # CRUD
│   │   ├── cuvees.dart          # CRUD
│   │   ├── bottles.dart         # CRUD + consume + by-tag + set-tag
│   │   ├── completions.dart     # autocomplete
│   │   ├── scan.dart            # request + result (long poll) + cancel
│   │   └── backup.dart          # backup + restore
│   └── middleware/
│       └── wakelock.dart        # activity-based 5min idle timer
├── services/                    # preserved from v1
│   ├── nfc_service.dart
│   ├── nfc_exceptions.dart
│   └── tag_id.dart
├── providers/                   # simplified from v1
│   ├── scan_provider.dart       # consume flow — calls localhost HTTP
│   └── intake_provider.dart     # intake flow — watches scan coordinator
├── screens/                     # preserved from v1
├── widgets/                     # preserved from v1
└── l10n/                        # preserved from v1
```

**Key changes from v1:**
- `ConnectionProvider` dropped on phone — local server is always available, no discovery/reconnection needed
- `DiscoveryService` becomes mDNS registrar (was: mDNS browser)
- New `server/` directory for all server-side code

### App Startup Sequence

Server MUST be running before UI renders:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase(NativeDatabase.createInBackground(...));
  final scanCoordinator = ScanCoordinator();
  final server = await startServer(db, scanCoordinator);
  runApp(WineTapApp(db: db, server: server, scanCoordinator: scanCoordinator));
}
```

Database and server are created in `main()` and passed down — no lazy initialization, no globals.

### Shelf Handler Pattern

```dart
Future<Response> addDesignation(Request request, AppDatabase db) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

  final name = body['name'] as String?;
  if (name == null || name.isEmpty) {
    return Response(400, body: jsonEncode({
      'error': 'invalid_argument',
      'message': 'name is required',
    }));
  }

  try {
    final id = await db.insertDesignation(...);
    final result = await db.getDesignation(id);
    return Response(201, body: jsonEncode(result.toJson()));
  } on SqliteException catch (e) {
    if (e.message.contains('UNIQUE constraint')) {
      return Response(409, body: jsonEncode({
        'error': 'already_exists',
        'message': 'designation "$name" already exists',
      }));
    }
    return Response(500, body: jsonEncode({'error': 'internal', 'message': e.toString()}));
  }
}
```

**Rules:**
- Parse JSON with `jsonDecode` + `as Map<String, dynamic>`
- Validate required fields → 400 with error JSON
- Call drift directly — no service layer
- Catch `SqliteException` for constraints → 409
- Use `dart:developer` `log()` — never `print()`
- Database passed as parameter — no global state

### Drift Entity JSON Serialization

drift does NOT auto-generate `toJson()`. Write explicit helpers per entity:

```dart
// In database.dart or alongside handlers
extension DesignationJson on Designation {
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'region': region,
    'description': description,
  };
}

extension BottleJson on BottleWithCuvee {
  Map<String, dynamic> toJson() => {
    'id': id,
    'tag_id': tagId,  // nullable — omit if null
    'cuvee_id': cuveeId,
    'vintage': vintage,
    'description': description,
    'purchase_price': purchasePrice,
    'drink_before': drinkBefore,
    'added_at': addedAt,
    'consumed_at': consumedAt,
    'cuvee': cuvee.toJson(),
  };
}
```

All JSON keys are `snake_case` — matching `docs/rest-api-contracts.md`.

### Scan Coordinator Pattern

Encapsulated class — not module-level variables:

```dart
class ScanCoordinator {
  Completer<String>? _completer;
  String? _mode;
  final Duration timeout;

  ScanCoordinator({this.timeout = const Duration(seconds: 30)});

  bool get hasPendingRequest => _completer != null;
  String? get mode => _mode;

  void request(String mode) { ... }
  Future<String?> waitForResult() { ... } // long poll with timeout
  void submitResult(String tagId) { ... } // called by NFC handler
  void cancel() { ... }
}
```

Passed to scan handlers as parameter (same as database). Timeout injectable for testing.

### Wakelock Middleware Pattern

```dart
Middleware wakelockMiddleware() {
  Timer? idleTimer;
  void resetTimer() {
    idleTimer?.cancel();
    WakelockPlus.enable();
    idleTimer = Timer(const Duration(minutes: 5), () {
      WakelockPlus.disable();
    });
  }
  return (Handler innerHandler) {
    return (Request request) async {
      resetTimer();
      return innerHandler(request);
    };
  };
}
```

### Go Manager HTTP Client Pattern

```go
// internal/manager/http_client.go
type WineTapClient struct {
    baseURL string
    http    *http.Client
}

func (c *WineTapClient) ListDesignations() ([]Designation, error) {
    resp, err := c.http.Get(c.baseURL + "/designations")
    // ... json.Decode into []Designation
}
```

```go
// internal/manager/api_types.go
type Bottle struct {
    ID            int64    `json:"id"`
    TagID         *string  `json:"tag_id,omitempty"`
    CuveeID       int64    `json:"cuvee_id"`
    Vintage       int32    `json:"vintage"`
    Description   string   `json:"description"`
    PurchasePrice *float64 `json:"purchase_price,omitempty"`
    DrinkBefore   *int32   `json:"drink_before,omitempty"`
    AddedAt       string   `json:"added_at"`
    ConsumedAt    *string  `json:"consumed_at,omitempty"`
    Cuvee         Cuvee    `json:"cuvee"`
}
```

### Testing Patterns

- **Drift tests**: in-memory database `AppDatabase(NativeDatabase.memory())`
- **Handler tests**: call handler function directly with mock `Request` — no shelf server needed
- **ScanCoordinator tests**: inject short timeout (100ms), test state transitions
- **Manager tests**: mock HTTP responses, test struct deserialization

### Anti-Patterns (FORBIDDEN)

- ❌ Raw SQL strings in Dart — use drift query builder
- ❌ `print()` in Dart — use `dart:developer` `log()`
- ❌ Proto-generated types in manager HTTP code — use new Go structs
- ❌ Global mutable state — pass `AppDatabase`, `ScanCoordinator` as parameters
- ❌ Hardcoded scan timeout — injectable (30s default, short for tests)
- ❌ `camelCase` JSON fields — always `snake_case`
- ❌ Service layer between handlers and drift — handlers call drift directly
- ❌ Storing scan state in database — ephemeral, memory only
- ❌ `ConnectionProvider` on phone — server is local, always available
- ❌ Lazy server initialization — server starts in `main()` before `runApp()`
- ❌ Consume flow through HTTP — ScanProvider calls drift directly (local operations bypass server)

## Project Structure & Boundaries

### Complete Directory Structure

**Phone (Flutter — server + scanner):**

```
mobile/lib/
├── main.dart                          # DB + server + scanCoordinator init BEFORE runApp()
│
├── server/
│   ├── server.dart                    # shelf setup, router, middleware, start/stop
│   ├── database.dart                  # drift AppDatabase + all tables + toJson() extensions
│   ├── database.g.dart               # drift generated (build_runner)
│   ├── scan_coordinator.dart          # Completer + mode + timeout — shared with IntakeProvider
│   ├── handlers/
│   │   ├── designations.dart          # CRUD + INAO refresh
│   │   ├── domains.dart               # CRUD
│   │   ├── cuvees.dart                # CRUD
│   │   ├── bottles.dart               # CRUD + consume + by-tag + set-tag + bulk
│   │   ├── completions.dart           # autocomplete
│   │   ├── scan.dart                  # request + result (long poll) + cancel
│   │   └── backup.dart                # backup + restore
│   └── middleware/
│       └── wakelock.dart              # 5min activity-based idle timer
│
├── services/                          # preserved from v1
│   ├── nfc_service.dart
│   ├── nfc_exceptions.dart
│   └── tag_id.dart
│
├── providers/
│   ├── scan_provider.dart             # consume flow — calls DRIFT DIRECTLY (not HTTP)
│   └── intake_provider.dart           # watches ScanCoordinator for manager requests
│
├── screens/
│   ├── consume_screen.dart
│   ├── intake_screen.dart
│   └── settings_screen.dart
│
├── widgets/
│   ├── bottle_details_card.dart
│   └── connection_indicator.dart      # shows server status (running/stopped)
│
└── l10n/
    └── strings.dart

mobile/test/
├── server/
│   ├── database_test.dart
│   ├── handlers/
│   │   ├── designations_test.dart
│   │   ├── bottles_test.dart
│   │   └── scan_test.dart
│   └── scan_coordinator_test.dart
├── services/
│   └── tag_id_test.dart
└── widget_test.dart
```

**Manager (Go/Qt — HTTP client):**

```
winetap/internal/manager/
├── manager.go                         # MODIFIED — HTTP client init, discover phone
├── config.go                          # MODIFIED — phone_address field
├── http_client.go                     # NEW — WineTapClient (net/http → phone REST)
├── api_types.go                       # NEW — Go structs with json:"snake_case" tags
├── scanner.go                         # preserved — Scanner interface
├── rfid_scanner.go                    # preserved — RFIDScanner
├── nfc_scanner.go                     # REWRITTEN — HTTP POST + long poll
└── screen/
    ├── ctx.go                         # MODIFIED — HTTP client replaces gRPC
    ├── inventory.go                   # MODIFIED — HTTP client methods
    ├── inventory_form.go              # MODIFIED — HTTP client methods
    └── settings.go                    # MODIFIED — phone discovery

winetap/docs/
├── rest-api-contracts.md              # NEW — 28 routes, source of truth
├── api-contracts.md                   # legacy gRPC reference
└── data-models.md                     # unchanged
```

### Architectural Boundaries

**Phone ↔ Manager boundary:**
- HTTP REST on port 8080 (JSON, snake_case fields)
- Manager discovers phone via mDNS (`_winetap._tcp`)
- All writes from manager go through HTTP — phone is single source of truth
- Scan coordination: POST request → long poll result

**Local ↔ Remote access (within phone):**
- **ScanProvider (consume)**: calls drift directly — no HTTP roundtrip
- **IntakeProvider (intake)**: watches ScanCoordinator (populated by shelf handler when manager POSTs)
- **shelf handlers**: called by manager via HTTP, call drift for data
- **Single drift instance**: created in `main()`, passed to both providers and handlers. WAL handles concurrent access.

**Handler ↔ Database boundary:**
- Handlers call drift directly — no service layer
- Database + ScanCoordinator passed as parameters
- JSON serialization via toJson() extensions

### Data Flow

**Consume flow (fully local — no HTTP):**
```
User taps Scanner → NfcService.readTagId()
  → ScanProvider calls db.getBottleByTagId(tagId) DIRECTLY
  → Bottle data → ScanProvider shows details
  → User taps Confirmer → db.consumeBottle(tagId) DIRECTLY
  → "Marquée comme bue ✓"
```

**Intake flow (manager → phone via HTTP):**
```
Manager clicks Scanner
  → POST phone:8080/scan/request {"mode":"single"}
  → shelf handler calls scanCoordinator.request("single")
  → IntakeProvider sees pending request → shows "Prêt à scanner"
  → User taps → NfcService.readTagId() → scanCoordinator.submitResult(tagId)
  → Manager long-poll GET phone:8080/scan/result → 200 {"tag_id":"04A32BFF"}
  → Manager form populates tag field
```

**Manager catalog CRUD (via HTTP):**
```
Manager lists bottles → GET phone:8080/bottles
  → shelf handler → db.listBottles() → JSON array → manager displays
Manager adds bottle → POST phone:8080/bottles {...}
  → shelf handler → db.insertBottle() → JSON → manager confirms
```

### Requirements to Structure Mapping

| FR Category | Phone Files | Manager Files |
|-------------|-------------|---------------|
| FR1-5: NFC | `services/nfc_service.dart`, `services/tag_id.dart` | — |
| FR6-10: Consume | `providers/scan_provider.dart` → drift direct, `screens/consume_screen.dart` | — |
| FR11-19: Intake | `providers/intake_provider.dart`, `scan_coordinator.dart`, `handlers/scan.dart` | `nfc_scanner.go`, `http_client.go` |
| FR20-25: Server | `server/server.dart`, `database.dart`, `handlers/*` | — |
| FR26-29: Manager conn | `middleware/wakelock.dart`, mDNS via bonsoir | `http_client.go`, `manager.go` |
| FR30-32: Errors | `providers/*`, `handlers/*` | `http_client.go` |
| FR33-35: Dual scan | — | `scanner.go`, `rfid_scanner.go`, `nfc_scanner.go` |
| FR36-37: Backup | `handlers/backup.dart` | — |

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:** shelf + drift + nfc_manager all Dart/Flutter, no cross-language issues. Go net/http + encoding/json on manager — standard library. snake_case JSON end-to-end.

**Pattern Consistency:** Handlers call drift directly everywhere. Database + ScanCoordinator passed as parameters. toJson() extensions for consistent serialization. Error format uniform across all handlers.

**Structure Alignment:** `server/` cleanly separates from UI. One handler file per entity. Providers call drift directly (consume) or watch ScanCoordinator (intake).

### Requirements Coverage ✅

All 38 FRs and 18 NFRs have architectural support. Complete mapping in Requirements to Structure table above.

### Implementation Readiness ✅

- All critical decisions documented with versions
- REST API contract (`docs/rest-api-contracts.md`) defines all 28 routes with exact JSON shapes
- Implementation patterns comprehensive with code examples
- Project structure maps every FR to specific files
- Anti-patterns explicitly listed

### Gap Analysis

**No critical gaps.**

Minor (non-blocking):
1. Add `package:http` to pubspec for INAO refresh outbound fetch
2. Designation picture BLOB excluded from REST API — deferred
3. Events system deferred post-MVP

### Party Mode Validation Enhancements (2026-04-01)

1. **ConnectionProvider removed on phone** — server is always local. Replace connection indicator with server address display (IP+port in AppBar/settings for manager configuration).
2. **Partial update convention documented** in REST contract: absent fields = don't update, explicit null = clear value. Handler uses `body.containsKey()`.
3. **Settings screen redesigned**: shows server IP+port, server status, backup/restore buttons. No "enter server address" — phone IS the server.
4. **Tag ID normalization documented** in REST contract: server normalizes on all tag_id inputs.
5. **ServerProvider replaces ConnectionProvider** — simple provider tracking server running state + IP address for display.

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — well-scoped evolution of validated v1 codebase. ~60% of existing code preserved. REST patterns well-understood. drift is production-tested.

**Key Strengths:**
- Consume flow is zero-latency (drift direct — no HTTP, no network)
- REST API fully documented with types before implementation starts
- Clean separation: server/ vs providers/ vs screens/
- Phone-as-server eliminates RPi deployment complexity
- Scan coordination simplified (long poll vs bidi stream)

**Areas for Future Enhancement:**
- Events system (post-MVP)
- iOS background server support
- Authentication/HTTPS
- Designation picture BLOB API
- App Store distribution

**First Implementation Priority:**
1. drift database + schema (foundation — everything depends on this)
2. shelf HTTP server + router + wakelock middleware
