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
completedAt: '2026-03-30'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-mobile.md
  - _bmad-output/planning-artifacts/product-brief-winetap-mobile.md
  - docs/index.md
  - docs/project-overview.md
  - docs/architecture.md
  - docs/source-tree-analysis.md
  - docs/data-models.md
  - docs/api-contracts.md
  - docs/development-guide.md
workflowType: 'architecture'
project_name: 'winetap-mobile'
user_name: 'Psy'
date: '2026-03-30'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
33 FRs across 7 capability areas — spanning a new Flutter mobile client and modifications to all existing components:

- NFC Tag Scanning (FR1-5): Platform-abstracted NFC reading, UID normalization, single + continuous scan modes, idempotent duplicate handling
- Consume Flow (FR6-10): Standalone scan → lookup → confirm/cancel → mark consumed. Phone-only, no desktop involvement
- Intake Coordination (FR11-19): Server-mediated real-time coordination between manager and phone. Scan request/response protocol, continuous mode for bulk intake, timeout, cancellation, retry-on-failure
- Server Discovery & Connection (FR20-24): mDNS auto-discovery, manual IP fallback, cached address, auto-reconnect, connection state indicator
- Error Handling (FR25-27): Specific actionable errors for 5 failure modes, form data preservation, recovery guidance
- Manager Dual Scanning (FR28-30): RFID + NFC backends behind common interface, settings toggle, identical results
- Server Protocol Changes (FR31-33): Coordination RPCs, mDNS registration, `rfid_epc` → `tag_id` rename

The intake coordination cluster (FR11-19) is the architectural heart — a novel server-mediated real-time protocol between two different client types.

**Non-Functional Requirements:**
- Performance: consume < 3s, intake coordination < 5s, notification < 1s, cold start < 3s, continuous scan < 500ms (Android) / < 1.5s (iOS)
- Reliability: auto-recover after sleep/wake within 5s, scan requests survive NFC failures, no data loss on manager side, graceful server restart handling
- Integration: no breaking changes beyond `tag_id` rename, cross-platform NFC via single Flutter plugin, mDNS on both iOS and Android, idempotent coordination protocol

**Scale & Complexity:**
- Complexity level: **Medium**
- Primary domain: Cross-platform mobile client + server RPC extension + desktop client modification
- Estimated new/modified architectural components: ~12 (Flutter app structure, NFC service, gRPC client, connection manager, mDNS discovery, 3 new server RPCs, mDNS registration, manager scan abstraction, manager settings, proto schema migration)

### Technical Constraints & Dependencies

**Inherited constraints (from existing codebase):**
- Go 1.26 monorepo — server, cellar, manager all in one module
- gRPC + Protobuf on port 50051, insecure (no TLS), local network only
- SQLite with WAL mode, single connection
- `rfid_epc` field name baked into proto, DB schema, service layer, and all clients
- French-only UI throughout
- No authentication — WiFi-only trust model

**New constraints from PRD:**
- Flutter for mobile (cross-platform iOS + Android)
- Dart gRPC client (`package:grpc`)
- NFC via `nfc_manager` Flutter plugin (community-maintained; `flutter_nfc_kit` as fallback)
- mDNS service type: `_winetap._tcp`
- iOS NFC requires system modal sheet (~1s overhead per session)
- iOS 14+ / Android 9+ minimum
- TestFlight + sideloaded APK distribution only
- Foreground-only app — no background permissions
- Solo developer learning Flutter/Dart (Go expert)

**Technology boundary:**
- Server and manager: Go (existing, extend)
- Mobile app: Flutter/Dart (new)
- Shared contract: Protobuf (extended with coordination RPCs)

### Cross-Cutting Concerns Identified

1. **Proto rename (`rfid_epc` → `tag_id`)** — Touches proto definitions, generated code, DB schema (migration), server service layer, manager client code, and the new mobile client. Must be coordinated as a single atomic change before other work begins.

2. **Scan coordination protocol** — New server-side RPCs consumed by both the Flutter app (scan submitter) and the manager (scan requester). Protocol must handle: request lifecycle, timeout, cancellation from either side, continuous mode, idempotency. This is the novel architectural element.

3. **Connection management** — Both the mobile app (new) and the manager (existing) need resilient gRPC connections. Mobile adds complexity: phone sleep/wake, WiFi reconnection, mDNS re-discovery. Manager's existing event subscription reconnection pattern is a reference implementation.

4. **NFC UID normalization** — UID format must be canonical (uppercase hex, no separators) regardless of platform. Normalization could live in the mobile client, the server, or both. Must be consistent with the `tag_id` field across the system.

5. **Dual scanning abstraction in manager** — Manager must support both RFID (USB, existing) and NFC (via coordination protocol, new) behind a common interface. Settings toggle switches between them. Both must produce identical results for all operations.

6. **Server topology decision** — Keep standalone RPi server vs. embed into manager. Affects deployment, availability (consume without desktop), and mobile connection target. PRD defers this; architecture must decide.

## Starter Template Evaluation

### Primary Technology Domain

Cross-platform mobile app (Flutter/Dart) extending an existing Go monorepo. Server and manager sides are brownfield — no starter needed. Evaluation covers the new Flutter mobile client only.

### Starter Options Considered

| Option | Verdict |
|---|---|
| `flutter create` (standard) | **Selected** — minimal, clean, learnable |
| `flutter create --empty` | Too bare — no platform config scaffolding |
| Very Good CLI (`very_good_cli`) | Over-engineered for 2 screens — Bloc-first, 100% coverage templates, feature-flag infra |
| Mason bricks | Template generator — adds indirection for a solo dev learning Flutter |

### Selected Starter: `flutter create`

**Rationale:** Minimal scaffolding that a Flutter newcomer can fully understand. The app's complexity lives in NFC hardware and gRPC coordination, not in the Flutter project structure. Adding layers (Bloc, code generation, feature flags) would obscure the learning path without solving real problems at this scope.

**Initialization Command:**

```bash
flutter create --org com.winetap --platforms ios,android wine_tap_mobile
```

**Established Technology Stack:**

| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter | 3.41.x (stable) |
| Language | Dart | 3.5+ |
| State management | Provider | Latest (official, minimal boilerplate) |
| gRPC | `package:grpc` | v4.0.0 |
| NFC | `nfc_manager` | Latest |
| mDNS | `nsd` or `bonsoir` | To be validated |
| Proto tooling | `protoc_plugin` (Dart) | Latest |

**State Management Decision: Provider**
- Official Flutter team recommendation for simple apps
- Minimal boilerplate — `ChangeNotifier` + `Consumer` pattern
- Gentle learning curve for someone coming from Go (closest to "pass dependencies down, notify on change")
- Sufficient for 2 screens with shared connection state
- No code generation, no annotations, no magic

**Project Structure (layer-first):**

```
wine_tap_mobile/
├── lib/
│   ├── main.dart                 # App entry, Provider setup, MaterialApp
│   ├── models/                   # Data classes (BreakdownResult, ScanState, etc.)
│   ├── services/                 # Business logic layer
│   │   ├── grpc_client.dart      # gRPC connection manager (keepalive, reconnect)
│   │   ├── nfc_service.dart      # NFC abstraction (platform differences hidden)
│   │   ├── discovery_service.dart # mDNS discovery + manual fallback
│   │   └── scan_coordinator.dart # Intake coordination state machine
│   ├── providers/                # Provider/ChangeNotifier classes
│   │   ├── connection_provider.dart  # Connection state (connected/connecting/unreachable)
│   │   └── scan_provider.dart        # Scan state (idle/waiting/scanning/result)
│   ├── screens/                  # Top-level screens
│   │   ├── consume_screen.dart   # Consume flow UI
│   │   ├── intake_screen.dart    # Intake listener UI
│   │   └── settings_screen.dart  # Manual IP, connection info
│   ├── widgets/                  # Reusable UI components
│   └── l10n/                     # French strings (even without i18n, centralize)
├── proto/                        # Shared .proto files (symlink or copy from monorepo)
├── test/
├── android/
├── ios/
├── pubspec.yaml
└── analysis_options.yaml
```

**Development Experience:**
- Hot reload for UI iteration
- `dart analyze` for static analysis (strict mode)
- `flutter test` for unit + widget tests
- No code generation step needed (Provider doesn't require it)

**Note:** The Flutter project lives outside the Go module (separate `pubspec.yaml`), but proto files are shared. Proto generation for Dart uses `protoc` with `protoc-gen-dart` — this needs a Makefile target alongside the existing `make proto` for Go.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
1. Server topology — keep standalone RPi server
2. Scan coordination protocol — bidirectional streaming RPC
3. Flutter project location — inside monorepo (`mobile/`)

**Important Decisions (Shape Architecture):**
4. Proto coordination message design — separate client/server message types
5. NFC UID normalization — server-side authority, mobile normalizes for display
6. Manager dual scanning — Scanner interface with two implementations

**Deferred Decisions (Post-MVP):**
- Server embedding into manager (evaluate after RFID removal)
- App Store / Play Store distribution
- Offline mode / scan queueing
- Authentication (if system moves beyond local network)

### Server Topology

- **Decision:** Keep standalone RPi server (Option A from product brief)
- **Rationale:** Consume flow must work when desktop is off. RPi already runs 24/7. Cellar binary gets retired; server stays. Mobile becomes a second client alongside the manager.
- **Affects:** Deployment (RPi stays), mobile connection target (RPi address), mDNS registration (server registers itself)

### Scan Coordination Protocol

- **Decision:** Single bidirectional streaming RPC (`CoordinateScan`)
- **Rationale:** Real-time coordination between manager and mobile. Server acts as relay hub routing messages between the two connected clients.
- **Proto design:** Separate `ScanClientMessage` and `ScanServerMessage` types with `oneof` payloads — type-safe per direction
- **Server state:** Ephemeral in-memory coordination state (active session, connected clients). Not persisted to DB. Mutex-protected struct with explicit state machine.
- **Affects:** Proto definitions (new service methods + message types), server service layer (new stream handler + relay logic), mobile gRPC client (stream management), manager NFC scanner implementation (stream consumer)
- **Fallback:** If bidi streaming proves infeasible during PoC, the proto message types (`ScanClientMessage`, `ScanServerMessage`) are compatible with a split into separate unary + server-streaming RPCs. The message sub-types remain unchanged.

**`ScanClientMessage` variants:**
- `ScanRequest` — manager initiates scan (includes mode: single or continuous)
- `ScanResult` — mobile submits scanned tag UID
- `ScanCancel` — either side cancels the active scan session

**`ScanServerMessage` variants:**
- `ScanRequestNotification` — server relays scan request to mobile (includes mode)
- `ScanAck` — server acknowledges a result (with bottle details for consume, or confirmation for intake)
- `ScanError` — server reports error (unknown tag, tag in use, timeout, etc.)

**Coordination State Machine:**

```
              ScanRequest
  IDLE ──────────────────────► REQUESTED
   ▲                              │
   │                    Mobile connects &
   │                    sends "ready"
   │                              │
   │                              ▼
   │  cancel/timeout          SCANNING
   ├◄──────────────────────────── │
   │                              │
   │                    ScanResult received
   │                              │
   │                              ▼
   └◄──────────────────────── RESOLVED
```

States: `IDLE` → `REQUESTED` → `SCANNING` → `RESOLVED` | `CANCELLED` | `TIMED_OUT`

- `IDLE`: No active scan session
- `REQUESTED`: Manager sent ScanRequest, waiting for mobile to be ready
- `SCANNING`: Mobile is actively scanning (NFC session open)
- `RESOLVED`: Tag UID received and processed. Returns to IDLE (single mode) or SCANNING (continuous mode)
- `CANCELLED`: Either side sent ScanCancel. Returns to IDLE.
- `TIMED_OUT`: Timer expired. Returns to IDLE.

**Timeout Ownership:**
- **Manager owns the 30s timeout** (configurable). Manager sends `ScanCancel` when timer expires.
- **Server has a 60s safety-net timeout** to garbage-collect zombie sessions if the manager's cancel message is lost (network failure, crash). Server sends `ScanError` with timeout reason.
- In continuous mode, timeout resets after each successful scan result.

### Flutter Project Location

- **Decision:** Inside the monorepo at `winetap/mobile/`
- **Rationale:** Solo developer, shared proto source of truth, single git history. Go module ignores the `mobile/` directory.
- **Affects:** Repository structure, Makefile (new `proto-dart` target), `.gitignore` (Flutter build artifacts)

### NFC UID Normalization

- **Decision:** Server normalizes on receipt for storage and comparison (authority). Mobile normalizes locally for display.
- **Rationale:** Server is the single source of truth. But mobile must also normalize for display — the consume confirmation screen shows the UID before sending it, and it must match what the server stores. Both sides use the same normalization logic (uppercase hex, no separators).
- **Format:** Uppercase hex, no separators (e.g., `04A32BFF`)
- **Affects:** Server service layer (normalization function), mobile NFC service (display normalization), proto `tag_id` field contract

### Manager Dual Scanning

- **Decision:** Go `Scanner` interface with two implementations (`RFIDScanner`, `NFCScanner`)
- **Rationale:** Clean abstraction — manager code doesn't know which scanner it's using. Settings toggle swaps implementation. Directly supports post-MVP RFID removal (delete one implementation).
- **Affects:** `internal/manager/rfid.go` (refactor into `Scanner` interface), new `internal/manager/nfc_scanner.go`, `screen/settings.go` (scan mode toggle), `manager.go` (scanner initialization)

**Scanner Interface:**
```go
type Scanner interface {
    StartScan(ctx context.Context, mode ScanMode) error
    StopScan() error
    OnTagScanned(callback func(tagID string))
}

type ScanMode int
const (
    ScanModeSingle     ScanMode = iota
    ScanModeContinuous
)
```

- `StartScan` accepts a `ScanMode` — single (one tag, then stop) or continuous (stay active for rapid consecutive scans)
- `RFIDScanner`: single mode triggers one `InventorySingle`, continuous mode runs `Inventory` loop
- `NFCScanner`: single mode sends `ScanRequest` with single mode, continuous sends with continuous mode. Stream stays open across scans.

### Decision Impact Analysis

**Implementation Sequence:**
1. Proto rename (`rfid_epc` → `tag_id`) — standalone, touches all components
2. Proto: add `CoordinateScan` bidi stream + message types
3. Server: mDNS registration + coordination stream handler + state machine
4. Manager: `Scanner` interface refactor (RFID first, then NFC implementation)
5. Flutter: project setup, gRPC client, NFC service
6. Flutter: consume flow (standalone, validates NFC + gRPC)
7. Flutter: intake flow (validates coordination protocol end-to-end)

**Cross-Component Dependencies:**
- Proto rename must land first — everything depends on `tag_id`
- Coordination proto must be defined before server handler or any client can be built
- Server mDNS + coordination handler must be running before mobile can connect
- Manager `Scanner` interface can be developed in parallel with mobile app
- Mobile consume flow can be tested independently of intake coordination

## Implementation Patterns & Consistency Rules

### Critical Conflict Points Identified

8 areas where AI agents could deviate when implementing the mobile project:

1. Server coordination handler structure
2. Tag ID normalization placement and implementation
3. Flutter Provider granularity and naming
4. gRPC connection lifecycle in Flutter
5. NFC service platform abstraction
6. Error handling and presentation (both Go and Dart)
7. French string management in Flutter
8. Proto coordination message conventions

### Go Naming Patterns (Existing — Follow Exactly)

**File naming:**
- Go files: `snake_case.go` (e.g., `nfc_scanner.go`, `scan_coordinator.go`)
- One primary type per file, named after the type
- Test files: `*_test.go` co-located with source

**Type naming:**
- Exported types: `PascalCase` (e.g., `Scanner`, `ScanMode`, `NFCScanner`)
- Interface names: describe behavior, not "I"-prefix (e.g., `Scanner` not `IScanner`)
- Constructor: `NewNFCScanner(...)` pattern

**Package naming:**
- Lowercase, single word when possible (e.g., `coordination` not `scan_coordination`)
- No stuttering: `coordination.Handler` not `coordination.CoordinationHandler`

### Flutter/Dart Naming Patterns (New — Establish)

**File naming:**
- Dart files: `snake_case.dart` (e.g., `grpc_client.dart`, `nfc_service.dart`, `consume_screen.dart`)
- One primary class per file
- Test files: `*_test.dart` in `test/` mirroring `lib/` structure

**Class naming:**
- `PascalCase` (e.g., `ConnectionProvider`, `NfcService`, `ConsumeScreen`)
- Providers suffixed with `Provider`: `ConnectionProvider`, `ScanProvider`
- Services suffixed with `Service`: `NfcService`, `DiscoveryService`
- Screens suffixed with `Screen`: `ConsumeScreen`, `IntakeScreen`

**Variable/method naming:**
- `camelCase` (Dart convention)
- Private members prefixed with `_`
- Boolean getters: `isConnected`, `isScanning`, `hasError`

### Proto Naming Patterns

**Message naming (existing convention + extension):**
- `PascalCase` messages: `ScanClientMessage`, `ScanServerMessage`, `ScanRequest`
- `snake_case` fields: `tag_id`, `scan_mode`, `bottle_details`
- Enum values: `UPPER_SNAKE_CASE` with type prefix: `SCAN_MODE_SINGLE`, `SCAN_MODE_CONTINUOUS`
- `oneof` field name: lowercase descriptive: `payload`

**Coordination-specific:**
```protobuf
enum ScanMode {
  SCAN_MODE_UNSPECIFIED = 0;
  SCAN_MODE_SINGLE = 1;
  SCAN_MODE_CONTINUOUS = 2;
}
```
- Always include `_UNSPECIFIED = 0` per proto3 convention
- RPC name: `CoordinateScan` (verb + noun)

### Structure Patterns

**Server coordination handler:**
- New file: `internal/server/service/coordination.go` — handles `CoordinateScan` stream
- State machine struct: `internal/server/service/scan_session.go` — mutex-protected, no DB
- Normalization function: `internal/server/service/tagid.go` — `NormalizeTagID(raw string) string`
- All coordination logic in `service/` layer — not in `db/` (no persistence)

**Manager Scanner refactor:**
- Interface + types: `internal/manager/scanner.go` — `Scanner` interface, `ScanMode`
- RFID implementation: `internal/manager/rfid_scanner.go` — extracted from existing `rfid.go`
- NFC implementation: `internal/manager/nfc_scanner.go` — bidi stream client
- Existing `rfid.go` becomes a thin wrapper or gets replaced entirely

**Flutter project:**
```
mobile/lib/
├── main.dart                      # App entry, MultiProvider setup
├── models/                        # Plain Dart data classes
│   └── scan_state.dart            # ScanState enum + associated data
├── services/                      # Stateless or singleton business logic
│   ├── grpc_client.dart           # ClientChannel lifecycle, keepalive, reconnect
│   ├── nfc_service.dart           # Platform NFC abstraction
│   ├── discovery_service.dart     # mDNS browse + manual fallback + cache
│   └── tag_id.dart                # NormalizeTagId() — display normalization
├── providers/                     # ChangeNotifier classes (stateful)
│   ├── connection_provider.dart   # ConnectionState: connected/connecting/unreachable
│   └── scan_provider.dart         # ScanState: idle/waiting/scanning/result/error
├── screens/                       # Full-screen widgets
│   ├── consume_screen.dart
│   ├── intake_screen.dart
│   └── settings_screen.dart
├── widgets/                       # Reusable sub-screen widgets
└── l10n/                          # French strings
    └── strings.dart               # Static const class — no i18n framework
```

### Provider Patterns (Flutter)

**Granularity rule:** One Provider per independent state domain. Two providers for MVP:
- `ConnectionProvider` — connection lifecycle (connected/connecting/unreachable), server address, reconnection
- `ScanProvider` — scan state machine (idle/waiting/scanning/result/error), current bottle details, error messages

**Provider structure:**
```dart
class ConnectionProvider extends ChangeNotifier {
  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  // Methods that mutate state call notifyListeners()
  Future<void> connect(String address) async { ... }
  void disconnect() { ... }
}
```

**Rules:**
- Providers own state and expose it via getters
- Providers call services (gRPC, NFC) — services don't call providers
- Screens consume providers via `context.watch<T>()` for reactive rebuilds
- Screens call provider methods for actions (e.g., `provider.startConsumeScan()`)
- No business logic in screens — screens are pure UI that read state and call methods

### gRPC Connection Lifecycle (Flutter)

**Connection manager pattern:**
- `GrpcClient` service wraps `ClientChannel`
- Exposes `connect(address)`, `disconnect()`, `isConnected` getter
- Keepalive pings: 10s interval, 5s timeout
- Reconnection: exponential backoff (1s, 2s, 4s, 8s, max 30s)
- On reconnect success: re-establish bidi stream if intake was active
- Cache last-known server address in `SharedPreferences`

**Stream lifecycle:**
- Bidi stream opened when intake screen is active
- Stream closed when leaving intake screen or on disconnect
- Stream errors trigger reconnection via `ConnectionProvider`
- Consume flow uses unary RPCs (`ConsumeBottle`, `GetBottleByTag`) — no stream needed

### NFC Service Abstraction (Flutter)

**Platform abstraction pattern:**
```dart
abstract class NfcService {
  Future<bool> isAvailable();
  Future<String> readTagId();        // Single read — returns normalized UID
  Stream<String> continuousRead();   // Continuous — emits UIDs
  Future<void> stopReading();
}
```

- Single implementation using `nfc_manager` plugin — platform differences hidden inside
- iOS: manages `NFCTagReaderSession` lifecycle (start/stop per read in single mode, restart in continuous)
- Android: uses foreground dispatch (naturally continuous)
- UID extraction: reads tag identifier bytes, converts to hex string, normalizes for display
- Errors thrown as typed exceptions: `NfcNotAvailableException`, `NfcReadTimeoutException`, `NfcSessionCancelledException`

### Error Handling Patterns

**Go server (existing convention — extend):**
- gRPC status codes for all error responses (NOT_FOUND, ALREADY_EXISTS, etc.)
- New coordination errors: `DEADLINE_EXCEEDED` for timeout, `CANCELLED` for user cancel, `UNAVAILABLE` for no mobile connected
- All logging via `log/slog` — accept `*slog.Logger` as dependency
- Debug level for stream message traces

**Flutter:**
- Services throw typed exceptions — never return null to indicate error
- Providers catch exceptions, set error state, call `notifyListeners()`
- Screens read error state from providers and display French error messages
- Error messages are user-facing French strings from `l10n/strings.dart`
- gRPC errors mapped to user-facing messages:

| gRPC Status | French Message |
|---|---|
| `NOT_FOUND` | "Tag inconnu" |
| `ALREADY_EXISTS` | "Tag déjà utilisé — [bottle details]" |
| `UNAVAILABLE` | "Serveur injoignable" |
| `DEADLINE_EXCEEDED` | "Délai dépassé" |
| `CANCELLED` | (silent — return to idle) |

### French String Management (Flutter)

**Pattern:** Static constants class — no i18n framework for MVP.

```dart
// l10n/strings.dart
class S {
  static const scanButton = 'Scanner';
  static const readyToScan = 'Prêt à scanner';
  static const waitingForScan = 'En attente du scan…';
  static const tagRead = 'Tag lu ✓';
  static const confirm = 'Confirmer';
  static const cancel = 'Annuler';
  static const markedAsConsumed = 'Marquée comme bue ✓';
  // ...
}
```

- All user-facing strings in one file — never hardcode French in widget code
- Referenced as `S.scanButton` throughout
- Easy to convert to proper i18n later (replace with `AppLocalizations`)

### Process Patterns

**Logging:**
- Go: `log/slog` everywhere. Debug for stream messages, Info for connection events, Error for failures.
- Flutter: `dart:developer` `log()` for debug, `print()` banned. In production, consider `package:logging`.

**Tag ID normalization function (both sides):**
```
Input: any string (e.g., "04:a3:2b:ff", "04A32BFF", "04 a3 2b ff")
Output: uppercase hex, no separators (e.g., "04A32BFF")
Logic: strip colons/spaces/dashes, uppercase
```
- Go: `service/tagid.go` — `NormalizeTagID(raw string) string`
- Dart: `services/tag_id.dart` — `String normalizeTagId(String raw)`
- Same logic, same output — must be tested with identical test cases on both sides

**Async patterns:**
- Go server: goroutine per bidi stream connection, mutex for shared state
- Go manager: `doAsync()` pattern for gRPC calls (existing)
- Flutter: `async/await` everywhere. No raw `Future.then()` chains. Provider methods are `async`.

### Enforcement Guidelines

**All AI agents implementing this feature MUST:**
- Follow existing Go conventions for server/manager code — read existing files first
- Use `log/slog` for all Go logging — never `fmt.Println` or `log.Println`
- Use Provider pattern for Flutter state — never `setState()` for shared state
- Keep all French strings in `l10n/strings.dart` — never hardcode in widgets
- Use typed exceptions in Dart services — never return null for errors
- Keep NFC platform differences inside `NfcService` — screens never reference iOS/Android
- Keep coordination state machine in server `service/` layer — never in `db/` layer
- Use `NormalizeTagID`/`normalizeTagId` for all tag ID handling — never raw string comparison

**Anti-Patterns:**
- ❌ Business logic in Flutter screens (screens only read state and call provider methods)
- ❌ Providers calling other providers (use services as shared dependencies instead)
- ❌ Raw gRPC calls from screens (always go through a provider or service)
- ❌ Platform-specific NFC code outside `NfcService`
- ❌ Storing coordination state in SQLite (ephemeral — memory only)
- ❌ Hardcoding server address (always via mDNS discovery or settings)
- ❌ Using `setState()` for connection or scan state (use Provider)
- ❌ Catching gRPC errors in screens (providers handle errors, screens display state)

## Project Structure & Boundaries

### New & Modified Files

**Go Monorepo (existing — modified and extended):**

```
winetap/
├── proto/winetap/v1/
│   └── winetap.proto              # MODIFIED — tag_id rename across all messages,
│                                    #   rename GetBottleByEPC → GetBottleByTagId,
│                                    #   add CoordinateScan bidi RPC,
│                                    #   add ScanClientMessage, ScanServerMessage,
│                                    #   add ScanMode enum
│
├── gen/winetap/v1/                # REGENERATED — Go proto output
│
├── internal/server/
│   └── service/
│       ├── service.go               # MODIFIED — register CoordinateScan handler
│       ├── coordination.go          # NEW — CoordinateScan bidi stream handler
│       ├── coordination_test.go     # NEW — integration test: spin up server,
│       │                            #   simulate manager + mobile bidi streams
│       ├── scan_session.go          # NEW — state machine struct + transitions
│       ├── scan_session_test.go     # NEW — state machine unit tests (all transitions,
│       │                            #   concurrent access, timeout GC)
│       ├── tagid.go                 # NEW — NormalizeTagID() function
│       ├── tagid_test.go            # NEW — normalization test cases
│       ├── bottles.go               # MODIFIED — tag_id rename in AddBottle,
│       │                            #   ConsumeBottle, GetBottleByTagId
│       └── convert.go              # MODIFIED — tag_id field mapping
│
├── internal/server/db/
│   └── bottles.go                   # MODIFIED — tag_id column name (after migration)
│
├── internal/migrations/
│   └── 00N_rename_rfid_epc.sql     # NEW — ALTER TABLE rename rfid_epc → tag_id
│
├── internal/cellar/
│   └── cellar.go                    # MODIFIED — tag_id rename (keeps working during
│                                    #   transition; retired post-MVP)
│
├── internal/manager/
│   ├── manager.go                   # MODIFIED — Scanner interface init, settings toggle
│   ├── scanner.go                   # NEW — Scanner interface + ScanMode type
│   ├── rfid_scanner.go              # NEW — RFIDScanner (extracted from rfid.go)
│   ├── nfc_scanner.go               # NEW — NFCScanner (bidi stream client)
│   ├── rfid.go                      # MODIFIED/REPLACED — logic moves to rfid_scanner.go
│   ├── config.go                    # MODIFIED — add scan_mode setting
│   └── screen/
│       ├── inventory_form.go        # MODIFIED — use Scanner interface instead of direct RFID
│       └── settings.go              # MODIFIED — scan mode toggle (RFID/NFC)
│
├── cmd/server/main.go               # MODIFIED — add mDNS registration
├── cmd/cellar/main.go               # MODIFIED — tag_id rename (transition support)
│
├── Makefile                         # MODIFIED — add proto-dart target
├── buf.gen.yaml                     # MODIFIED — add Dart plugin output
│
└── mobile/                          # NEW — Flutter project (see below)
```

**Flutter Mobile App (new):**

```
mobile/
├── pubspec.yaml                     # Dependencies: grpc, nfc_manager, provider,
│                                    #   nsd/bonsoir, shared_preferences, protobuf
├── analysis_options.yaml            # Strict Dart analysis
├── .gitignore                       # Flutter build artifacts (NOT gen/ — committed)
│
├── lib/
│   ├── main.dart                    # App entry, MultiProvider setup, MaterialApp
│   │
│   ├── gen/                         # Generated Dart proto code (committed to git —
│   │   └── winetap/v1/            #   builds without protoc installed)
│   │       ├── winetap.pb.dart
│   │       ├── winetap.pbgrpc.dart
│   │       └── winetap.pbenum.dart
│   │
│   ├── models/
│   │   └── scan_state.dart          # ScanState enum, BottleInfo data class
│   │
│   ├── services/
│   │   ├── grpc_client.dart         # ClientChannel lifecycle, keepalive, reconnect
│   │   ├── nfc_service.dart         # NFC abstraction (iOS/Android differences hidden)
│   │   ├── discovery_service.dart   # mDNS browse (_winetap._tcp) + manual fallback
│   │   └── tag_id.dart              # normalizeTagId() — display normalization
│   │
│   ├── providers/
│   │   ├── connection_provider.dart # ConnectionState, server address, auto-reconnect
│   │   └── scan_provider.dart       # ScanState machine, bottle details, errors
│   │
│   ├── screens/
│   │   ├── consume_screen.dart      # Scan → lookup → confirm/cancel → consumed
│   │   ├── intake_screen.dart       # Scan request listener, single + continuous
│   │   └── settings_screen.dart     # Manual IP, connection info, cache clear
│   │
│   ├── widgets/
│   │   ├── connection_indicator.dart # Connected/connecting/unreachable indicator
│   │   ├── bottle_details_card.dart  # Cuvée, domain, vintage, appellation display
│   │   └── scan_button.dart          # Reusable scan trigger button
│   │
│   └── l10n/
│       └── strings.dart             # All French UI strings as static constants
│
├── test/
│   ├── services/
│   │   ├── tag_id_test.dart         # Normalization tests (same cases as Go)
│   │   ├── grpc_client_test.dart    # Connection/reconnection logic (mocked channel)
│   │   └── discovery_service_test.dart # mDNS → cache → manual fallback
│   ├── providers/
│   │   ├── connection_provider_test.dart
│   │   └── scan_provider_test.dart
│   └── screens/
│       ├── consume_screen_test.dart  # Widget test with mocked providers
│       └── intake_screen_test.dart   # Widget test with mocked providers
│
├── android/
│   └── app/src/main/AndroidManifest.xml  # NFC permission
│
└── ios/
    └── Runner/Info.plist            # NFCReaderUsageDescription, NSLocalNetworkUsageDescription,
                                     # NSBonjourServices (_winetap._tcp)
```

### Architectural Boundaries

**Mobile ↔ Server boundary:**
- Mobile connects to server via gRPC on port 50051
- Consume flow: unary RPCs (`ConsumeBottle`, `GetBottleByTagId`)
- Intake flow: bidi `CoordinateScan` stream
- Discovery: mDNS `_winetap._tcp` service, fallback to manual IP
- No direct mobile ↔ manager communication — all coordination goes through server

**Manager ↔ Server boundary (existing + extended):**
- Existing unary RPCs unchanged (beyond `tag_id` rename)
- New: manager opens `CoordinateScan` bidi stream via `NFCScanner` implementation
- Manager is a "requester" on the coordination stream; mobile is a "scanner"

**Scanner interface boundary (within manager):**
- `Scanner` interface isolates scanning logic from screen code
- `inventory_form.go` calls `Scanner.StartScan()` — never knows if RFID or NFC
- `manager.go` initializes the correct `Scanner` implementation based on config
- `RFIDScanner` owns the serial port; `NFCScanner` owns the gRPC stream

**Service ↔ Provider boundary (within Flutter):**
- Services are stateless/singleton — they do work and return results or throw
- Providers are stateful — they call services, hold state, notify listeners
- Screens are pure UI — they read providers and call provider methods
- One-way dependency: Screen → Provider → Service → gRPC/NFC

**Proto boundary:**
- `proto/winetap/v1/winetap.proto` is the single source of truth
- Go generated code: `gen/winetap/v1/` (committed to git)
- Dart generated code: `mobile/lib/gen/winetap/v1/` (committed to git)
- Both generated from the same proto by `make proto` (Go) and `make proto-dart` (Dart)
- Committing generated code ensures both Go and Flutter build without `protoc`/`buf` installed

**Cellar binary transition:**
- `cmd/cellar/` and `internal/cellar/` updated for `tag_id` rename to keep working during MVP
- Cellar binary is retired post-MVP once NFC scanning is validated
- No new features added to cellar — rename only

### Requirements to Structure Mapping

| FR | Component | File(s) |
|---|---|---|
| FR1-5: NFC scanning | Mobile | `services/nfc_service.dart`, `services/tag_id.dart` |
| FR6-10: Consume flow | Mobile + Server | `screens/consume_screen.dart`, `providers/scan_provider.dart`, server `bottles.go` |
| FR11-19: Intake coordination | All three | `service/coordination.go`, `service/scan_session.go`, `nfc_scanner.go`, `screens/intake_screen.dart` |
| FR20-24: Discovery & connection | Mobile + Server | `services/discovery_service.dart`, `services/grpc_client.dart`, `providers/connection_provider.dart`, `cmd/server/main.go` (mDNS) |
| FR25-27: Error handling | Mobile | `providers/scan_provider.dart`, `l10n/strings.dart` |
| FR28-30: Manager dual scanning | Manager | `scanner.go`, `rfid_scanner.go`, `nfc_scanner.go`, `screen/settings.go` |
| FR31-33: Server protocol | Server + Proto | `winetap.proto`, `service/coordination.go`, `cmd/server/main.go` |

### Data Flow

**Consume flow:**
```
User taps "Scanner" on phone
  → NfcService.readTagId() → iOS/Android NFC read
  → normalizeTagId() for display
  → ScanProvider calls GetBottleByTagId(tagId) via GrpcClient
  → Server normalizes tag_id, looks up bottle
  → Bottle details returned → ScanProvider updates state
  → ConsumeScreen shows bottle details (cuvée, domain, vintage)
  → User taps "Confirmer"
  → ScanProvider calls ConsumeBottle(tagId) via GrpcClient
  → Server marks consumed, clears tag_id
  → ConsumeScreen shows "Marquée comme bue ✓"
```

**Intake coordination flow:**
```
Manager clicks "Scanner" (NFC mode)
  → NFCScanner.StartScan(ScanModeSingle)
  → Opens CoordinateScan bidi stream (if not open)
  → Sends ScanClientMessage{ScanRequest{mode: SINGLE}}
  → Server relay: ScanSession state IDLE → REQUESTED
  → Server sends ScanServerMessage{ScanRequestNotification} to mobile stream
  → Mobile ScanProvider shows "En attente du scan…"
  → User taps "Prêt à scanner"
  → NfcService.readTagId() → NFC read
  → Mobile sends ScanClientMessage{ScanResult{tag_id: "04A32BFF"}}
  → Server: state SCANNING → RESOLVED
  → Server normalizes tag_id, sends ScanServerMessage{ScanAck{tag_id}} to manager stream
  → Manager NFCScanner fires OnTagScanned("04A32BFF")
  → Manager form populates tag field
  → Single mode: server state → IDLE
  → Continuous mode: server state → SCANNING (ready for next scan)
```

**mDNS discovery flow:**
```
App launch
  → DiscoveryService.discover()
  → Browse for _winetap._tcp (3s timeout)
  → Found → cache address in SharedPreferences → connect
  → Not found → check cached address → connect if available
  → No cache → show settings screen for manual IP
```

### Build & Deployment

**Makefile targets (extended):**
```makefile
proto:          # Existing — generate Go code
proto-dart:     # NEW — generate Dart code into mobile/lib/gen/
build:          # Existing — build Go binaries
build-mobile:   # NEW — flutter build apk / flutter build ios (convenience)
```

**Proto generation for Dart:**
- Requires: `protoc-gen-dart` (from `protoc_plugin` Dart package)
- Output: `mobile/lib/gen/winetap/v1/`
- Both `make proto` and `make proto-dart` read from same `proto/` source
- Generated code committed to git — `make proto-dart` only needed when proto changes

**Deployment:**
- Server: RPi systemd (unchanged)
- Manager: desktop Linux binary (unchanged)
- Mobile: `flutter build apk` → sideload, `flutter build ios` → TestFlight

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:** All technology choices are compatible. Go 1.26 + gRPC v1.79 on server, Dart + `package:grpc` v4.0.0 on mobile — both speak proto3 natively. Bidi streaming supported on both sides. Flutter 3.41 + Provider + nfc_manager — no dependency conflicts. mDNS libraries exist for both Go (zeroconf) and Flutter (nsd/bonsoir).

**Pattern Consistency:** Go patterns follow existing codebase conventions exactly. Flutter patterns (Provider + Service + Screen layering) are internally consistent and align with Dart community conventions. Naming conventions (snake_case files, PascalCase types) are standard for both languages. Proto patterns follow proto3 style guide.

**Structure Alignment:** One-way dependencies enforced throughout (Screen → Provider → Service → gRPC/NFC). Scanner interface cleanly separates manager from scanning implementation. Server coordination logic isolated in service layer with no DB dependency. Flutter project inside monorepo shares proto source of truth.

### Requirements Coverage ✅

All 33 FRs mapped to specific files with architectural support. All 14 NFRs addressed: performance (unary RPCs for consume, bidi stream for real-time coordination), reliability (keepalive, backoff, scan request survival, timeout ownership), integration (single proto, cross-platform NFC, mDNS, idempotent protocol).

### Implementation Readiness ✅

- All 6 critical/important decisions documented with rationale and affected files
- Coordination state machine fully specified (5 states, transitions, timeout ownership)
- Scanner interface specified with Go code signature
- NFC service abstraction specified with Dart signature
- Proto message variants listed for both directions
- Naming, structure, and process patterns comprehensive
- Anti-patterns listed to prevent common mistakes
- Two rounds of party-mode review caught 11 additional specifics

### Gap Analysis Results

**No critical gaps.** All FRs and NFRs have architectural support.

**Minor clarifications added during validation:**
- Consume flow is a two-step pattern: `GetBottleByTagId` (lookup) → display details → `ConsumeBottle` (commit). Both RPCs exist in the renamed API.
- `GetBottleByEPC` renamed to `GetBottleByTagId` — explicitly listed in proto modifications.
- Cellar binary included in tag_id rename scope for transition support.

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — well-scoped MVP with established server-side patterns and a deliberately simple Flutter client. Two rounds of multi-agent review.

**Key Strengths:**
- Bidi stream protocol fully specified with state machine and timeout ownership
- Clear separation: Go side extends existing patterns, Flutter side starts clean with minimal framework
- Scanner interface enables clean RFID removal post-MVP
- Proto is single source of truth, generated code committed for both languages

**First Implementation Priority:**
1. Proto rename (`rfid_epc` → `tag_id`, `GetBottleByEPC` → `GetBottleByTagId`) — atomic, all components
2. Flutter + NFC proof-of-concept — validates riskiest technology first
3. Server: coordination RPC + mDNS
4. Manager: Scanner interface refactor
5. Mobile: consume flow
6. Mobile: intake flow
7. Integration testing
