# WineTap — Source Tree Analysis

## Directory Structure

```
winetap/
├── cmd/                              # Application entry points
│   ├── server/main.go                # rpc-server: config, logger, signal handling
│   ├── cellar/main.go                # cellar: config, serial port, LEDs, signal handling
│   ├── manager/main.go               # manager: config, logger, Qt app launch
│   └── cfru5102_read/main.go         # Debug tool: standalone RFID reader test loop
│
├── internal/                         # All business logic (not importable externally)
│   ├── server/                       # rpc-server implementation
│   │   ├── server.go                 # gRPC server setup, interceptors, graceful shutdown
│   │   ├── db/                       # Data access layer (SQLite)
│   │   │   ├── db.go                 # Connection, migrations, WAL/pragma config
│   │   │   ├── bottles.go            # Bottle CRUD + consume + dynamic field updates
│   │   │   ├── cuvees.go             # Cuvee CRUD with domain/designation joins
│   │   │   ├── designations.go       # Designation CRUD + INAO upsert + completions
│   │   │   ├── domains.go            # Domain CRUD
│   │   │   └── events.go             # Event insert + list unacknowledged + acknowledge
│   │   └── service/                  # gRPC service handlers
│   │       ├── service.go            # WineTapServer impl + event broadcaster
│   │       ├── bottles.go            # Bottle RPCs + FieldMask handling
│   │       ├── completions.go        # GetCompletions dispatcher
│   │       ├── convert.go            # DB ↔ Proto type conversions
│   │       ├── cuvees.go             # Cuvee RPCs + inline domain resolution
│   │       ├── designations_rpc.go   # Designation CRUD RPCs
│   │       ├── domains.go            # Domain CRUD RPCs
│   │       ├── events.go             # PushEvent + SubscribeEvents stream + Acknowledge
│   │       └── inao.go               # INAO CSV download + parse from data.gouv.fr
│   │
│   ├── cellar/                       # Cellar scanning logic
│   │   └── cellar.go                 # Main scan loop, debounce, cooldown, LED signals
│   │
│   ├── manager/                      # Desktop GUI application
│   │   ├── manager.go                # Qt app, window, sidebar, navigation, event subscription
│   │   ├── config.go                 # YAML config persistence
│   │   ├── rfid.go                   # RFID scanner wrapper (open/start/stop/simulate)
│   │   ├── assets/                   # Embedded resources
│   │   │   └── assets.go             # Icon PNG + CSS stylesheet (go:embed)
│   │   └── screen/                   # UI screens
│   │       ├── ctx.go                # Shared context with callbacks (decouples from manager)
│   │       ├── table_screen.go       # Reusable table+panel layout widget
│   │       ├── crud_base.go          # Generic CRUD boilerplate (generics)
│   │       ├── base_form.go          # Shared form skeleton with AI button
│   │       ├── helpers.go            # Accent folding, async, dialogs, filter popups
│   │       ├── inventory.go          # Inventory screen (grouped/flat/history views)
│   │       ├── inventory_form.go     # Bottle add/edit form with RFID wait widget
│   │       ├── designations.go       # Appellations CRUD screen
│   │       ├── domains.go            # Domaines CRUD screen
│   │       ├── cuvees.go             # Cuvées CRUD screen (inline domain/designation creation)
│   │       ├── settings.go           # Settings screen (server, RFID, logs, INAO refresh)
│   │       ├── ai.go                 # ChromeDP ChatGPT integration
│   │       └── ai_test.go            # AI integration test
│   │
│   ├── integration/                  # Hardware integrations
│   │   └── cfru5102/                 # Chafon CF-RU5102 UHF RFID reader driver
│   │       ├── reader.go             # Core serial I/O, command exchange, debug logging
│   │       ├── frame.go              # Binary frame encoding/decoding, CRC-16
│   │       ├── types.go              # Protocol enums, constants, frame builders
│   │       ├── status.go             # 38+ response status codes
│   │       ├── cmd_inventory.go      # Inventory + InventorySingle commands
│   │       ├── cmd_memory.go         # ReadData, WriteData, WriteEPC, BlockErase/Write
│   │       ├── cmd_tag_security.go   # Kill, Lock, ReadProtect, EAS, UserBlockLock
│   │       ├── cmd_6b.go             # ISO 18000-6B tag commands
│   │       ├── cmd_reader_config.go  # SetRegion, SetAddress, SetScanTime, SetPower
│   │       └── cmd_get_reader_information.go  # Reader info query
│   │
│   ├── led/                          # LED controller
│   │   └── led.go                    # Sysfs + console mode, async blink
│   │
│   └── migrations/                   # Database schema
│       └── migrations.go             # Embedded SQL files (go:embed)
│
├── proto/                            # Protocol Buffer definitions
│   └── winetap/v1/
│       └── winetap.proto           # WineTap service (17 RPCs), all messages
│
├── gen/                              # Generated code (do not edit)
│   └── winetap/v1/
│       ├── winetap.pb.go           # Proto message types
│       └── winetap_grpc.pb.go      # gRPC client/server stubs
│
├── deploy/                           # Deployment configuration
│   └── systemd/
│       ├── winetap-server.service # Server systemd unit
│       └── winetap-cellar.service # Cellar systemd unit (depends on server)
│
├── specs/                            # Design specifications
│   ├── diagrams/                     # PlantUML source files
│   │   ├── architecture.puml
│   │   ├── bottle_lifecycle.puml
│   │   ├── screen_inventory.puml
│   │   ├── screen_add_bottle.puml
│   │   ├── screen_add_bottle_confirm.puml
│   │   ├── screen_read_bottle.puml
│   │   ├── screen_settings.puml
│   │   ├── screen_notifications.puml
│   │   └── screen_bulk_edit.puml
│   └── generated/                    # Rendered PNGs from PlantUML
│       └── *.png
│
├── go.mod                            # Go module definition
├── go.sum                            # Dependency checksums
├── Makefile                          # Build targets: proto, build-server/cellar/manager, clean
├── buf.yaml                          # Buf lint config for proto
├── buf.gen.yaml                      # Buf code generation config
├── buf.lock                          # Buf dependency lock
├── spec.md                           # Full project specification document
├── example.server.yaml               # Example server config
├── example.cellar.yaml               # Example cellar config
├── winetap.db                     # Local dev SQLite database
└── winetap.db-shm/wal            # SQLite WAL files
```

## Critical Directories

| Directory                    | Purpose                                          |
|------------------------------|--------------------------------------------------|
| `cmd/`                       | Entry points only — config, flags, signal handling |
| `internal/server/`           | gRPC server: transport, service logic, data access |
| `internal/server/db/`        | SQLite operations, migrations, schema management |
| `internal/server/service/`   | Business logic, proto conversion, event broadcast |
| `internal/cellar/`           | RFID scan loop with debounce and LED feedback    |
| `internal/manager/`          | Qt6 desktop app with RFID and gRPC integration   |
| `internal/manager/screen/`   | All UI screens, reusable widgets, AI integration |
| `internal/integration/cfru5102/` | Complete RFID reader driver (binary protocol) |
| `internal/led/`              | Raspberry Pi LED control (sysfs + console mode)  |
| `internal/migrations/`       | Embedded SQL migration files                     |
| `proto/`                     | Source of truth for API contract                 |
| `gen/`                       | Auto-generated — never edit manually              |
| `deploy/systemd/`           | Production deployment config                      |
| `specs/`                     | Visual design specs (PlantUML → PNG)              |

## Entry Points

| Binary              | Entry                      | Initializes                              |
|---------------------|----------------------------|------------------------------------------|
| `winetap-server` | `cmd/server/main.go`       | Config → Logger → DB → gRPC Server       |
| `winetap-cellar` | `cmd/cellar/main.go`       | Config → Logger → Serial → RFID → LEDs → gRPC Client → Scan Loop |
| `winetap-manager`| `cmd/manager/main.go`      | Config → Logger → Qt App → gRPC Client → Window → Event Sub |
| `cfru5102_read`     | `cmd/cfru5102_read/main.go`| Flags → Serial → RFID → Info Query → Inventory Loop |
