# WineTap — Source Tree Analysis

## Directory Structure

```
winetap/
├── cmd/                                  # Application entry points
│   └── manager/main.go                   # Desktop GUI: config, logger, Qt app launch
│
├── internal/                             # Go business logic (not importable externally)
│   ├── client/                           # HTTP client for the phone API
│   │   ├── api_types.go                  # Request/response structs, APIError type
│   │   ├── http_client.go               # WineTapHTTPClient: all REST calls
│   │   └── http_client_test.go          # Client unit tests (httptest server)
│   │
│   └── manager/                          # Desktop GUI application
│       ├── manager.go                    # Qt app, window, sidebar, navigation
│       ├── config.go                     # YAML config persistence
│       ├── discovery.go                  # mDNS phone discovery
│       ├── discovery_test.go
│       ├── logger.go                     # Slog logger setup
│       ├── nfc_scanner.go                # NFC scan coordination via HTTP long-poll
│       ├── nfc_scanner_test.go
│       ├── rfid_scanner.go               # RFID reader wrapper (Chafon CF-RU5102)
│       ├── scanner.go                    # Scanner interface
│       ├── assets/                       # Embedded resources
│       │   └── assets.go                 # Icon PNG + CSS stylesheet (go:embed)
│       ├── screen/                       # UI screens
│       │   ├── ctx.go                    # Shared context with callbacks (decouples screens from manager)
│       │   ├── table_screen.go           # Reusable table+panel layout widget
│       │   ├── crud_base.go              # Generic CRUD boilerplate (generics)
│       │   ├── base_form.go              # Shared form skeleton with AI button
│       │   ├── helpers.go                # Accent folding, async, dialogs, filter popups
│       │   ├── inventory.go              # Inventory screen (grouped/flat/history views)
│       │   ├── inventory_form.go         # Bottle add/edit form with scan wait widget
│       │   ├── designations.go           # Appellations CRUD screen
│       │   ├── designation_form.go
│       │   ├── domains.go                # Domaines CRUD screen
│       │   ├── domain_form.go
│       │   ├── cuvees.go                 # Cuvées CRUD screen
│       │   ├── cuvee_form.go
│       │   ├── dashboard.go              # Dashboard screen with stats
│       │   ├── dashboard_test.go
│       │   ├── settings.go               # Settings screen (server, RFID, logs)
│       │   ├── ai.go                     # ChromeDP ChatGPT integration
│       │   └── ai_test.go
│       └── widget/                       # Reusable Qt widgets
│           ├── aggregate.go              # Aggregation helpers
│           ├── aggregate_test.go
│           ├── dashboard_panel.go
│           ├── hero_count.go
│           └── pie_chart.go
│
├── mobile/                               # Flutter application (server + UI)
│   ├── lib/
│   │   ├── main.dart                     # App entry point
│   │   ├── server/                       # HTTP server — no Flutter imports
│   │   │   ├── server.dart               # shelf server setup, route mounting, health endpoint
│   │   │   ├── database.dart             # drift ORM: tables, queries, migrations
│   │   │   ├── scan_coordinator.dart     # Single-scan lifecycle with Completer (long-poll)
│   │   │   ├── consume_tracker.dart      # Tracks recent consumption events
│   │   │   ├── seed_data.dart            # Sentinel designation seeding
│   │   │   ├── handlers/                 # Route handlers (one file per resource)
│   │   │   │   ├── bottles.dart          # CRUD + consume + partial update
│   │   │   │   ├── cuvees.dart           # CRUD with denormalized joins
│   │   │   │   ├── designations.dart     # CRUD + unique name enforcement
│   │   │   │   ├── domains.dart          # CRUD + unique name enforcement
│   │   │   │   ├── scan.dart             # request / result (long-poll) / cancel
│   │   │   │   ├── completions.dart      # Autocomplete search
│   │   │   │   └── backup.dart           # Database download + restore
│   │   │   └── middleware/
│   │   │       └── wakelock.dart         # Keep screen awake while server is active
│   │   ├── providers/                    # ChangeNotifier state management
│   │   │   ├── scan_provider.dart        # Consume flow: idle → scanning → consumed | error
│   │   │   ├── intake_provider.dart      # Polls ScanCoordinator; auto-starts NFC on request
│   │   │   └── server_provider.dart      # Manages shelf server lifecycle
│   │   ├── screens/                      # Flutter UI screens
│   │   │   ├── consume_screen.dart       # Tap-to-consume flow
│   │   │   ├── identify_screen.dart      # Scan to identify a bottle
│   │   │   ├── intake_screen.dart        # Shown during manager-initiated scan
│   │   │   └── settings_screen.dart      # App settings
│   │   ├── services/                     # Platform services
│   │   │   ├── nfc_service.dart          # NFC interface
│   │   │   ├── nfc_service_android.dart  # Android NFC implementation
│   │   │   ├── nfc_service_ios.dart      # iOS NFC implementation
│   │   │   ├── nfc_exceptions.dart       # NFC error types
│   │   │   ├── discovery_service.dart    # mDNS advertisement
│   │   │   └── tag_id.dart              # Tag ID normalization
│   │   ├── widgets/                      # Reusable Flutter widgets
│   │   │   ├── bottle_details_card.dart
│   │   │   └── connection_indicator.dart
│   │   └── l10n/
│   │       └── strings.dart              # French localization strings
│   └── test/                             # Flutter/Dart tests
│       ├── providers/                    # Provider unit tests
│       ├── screens/                      # Screen widget tests
│       └── server/                       # Server-side tests
│           ├── database_test.dart        # Drift database tests (in-memory SQLite)
│           ├── scan_coordinator_test.dart
│           └── handlers/                 # Handler integration tests
│               ├── bottles_test.dart
│               ├── cuvees_test.dart
│               ├── designations_test.dart
│               ├── domains_test.dart
│               ├── scan_test.dart
│               ├── completions_test.dart
│               └── backup_test.dart
│
├── docs/                                 # Documentation
├── go.mod / go.sum                       # Go module
├── seed_inventory.sh                     # Dev seed script (~200 bottles)
├── spec.md                               # Full project specification
└── README.md
```

## Critical Directories

| Directory                    | Purpose                                           |
|------------------------------|---------------------------------------------------|
| `cmd/manager/`               | Entry point only — config, flags, Qt app launch    |
| `internal/client/`           | HTTP client for the phone REST API                 |
| `internal/manager/`          | Desktop app orchestration, discovery, scanning     |
| `internal/manager/screen/`   | All UI screens, forms, reusable widgets            |
| `internal/manager/widget/`   | Dashboard widgets (charts, aggregates)             |
| `mobile/lib/server/`         | shelf HTTP server, drift database, scan coordinator|
| `mobile/lib/server/handlers/`| Route handlers — one file per REST resource        |
| `mobile/lib/providers/`      | ChangeNotifier state (scan, intake, server)        |
| `mobile/lib/screens/`        | Flutter UI screens                                 |
| `mobile/lib/services/`       | NFC, mDNS, tag normalization                       |

## Entry Points

| Binary             | Entry                  | Initializes                                         |
|--------------------|------------------------|-----------------------------------------------------|
| `winetap-manager`  | `cmd/manager/main.go`  | Config → Logger → Qt App → HTTP Client → mDNS → UI |
| Mobile app         | `mobile/lib/main.dart` | Providers → shelf Server → mDNS → NFC → UI         |
