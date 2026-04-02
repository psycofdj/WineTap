# WineTap — Architecture

## System Architecture

```
┌─────────────────────────────────┐          ┌──────────────────────────────┐
│        Desktop (Linux)           │          │       Android Phone           │
│                                  │          │                              │
│  ┌────────────────────────────┐  │          │  ┌────────────────────────┐  │
│  │     manager (Qt6 GUI)      │  │          │  │  mobile (Flutter app)  │  │
│  │                            │  │  HTTP    │  │                        │  │
│  │  Inventory / Add / Read /  │──┼──REST ───┼──│  shelf HTTP (:8080)    │  │
│  │  Settings screens          │  │  WiFi    │  │  drift SQLite DB       │  │
│  │                            │  │          │  │  NFC (flutter_nfc_kit) │  │
│  │  RFID reader (USB)         │  │          │  │  mDNS (_winetap._tcp)│  │
│  └────────────────────────────┘  │          │  └────────────────────────┘  │
└─────────────────────────────────┘          └──────────────────────────────┘
```

Discovery: manager resolves the phone's IP via mDNS (`_winetap._tcp`). Phone advertises on startup.

## Component Details

### mobile (Flutter, `mobile/`)

**HTTP Server** (`mobile/lib/server/`)
- `shelf` + `shelf_router` listening on port 8080
- Routes mounted under `/`: designations, domains, cuvees, bottles, scan, backup, restore, completions
- `ScanCoordinator` manages single-scan lifecycle with `Completer<String?>` (long polling, injectable timeout)

**State Management** (`mobile/lib/providers/`)
- `ScanProvider` — consume flow state machine: `idle → scanning → consumed | error`
- `IntakeProvider` — polls ScanCoordinator; auto-starts NFC on request; exposes `shouldShowIntakeScreen`
- `ServerProvider` — manages shelf server lifecycle (start/stop)

**Database** (`mobile/lib/server/database.dart`)
- drift ORM over SQLite (`driftDatabase(name: 'winetap')`)
- Tables: `designations`, `domains`, `cuvees`, `bottles`
- Schema version tracked by drift; migrations in `MigrationStrategy`
- Foreign keys enabled via `PRAGMA foreign_keys = ON`

**Screens** (`mobile/lib/screens/`)
- `HomeScreen` — single-screen shell with `IndexedStack`; auto-switches to intake screen when `shouldShowIntakeScreen` is true
- `ConsumeScreen` — tap button → NFC scan → auto-consume → "Terminé"
- `IntakeScreen` — shown by manager request only; "Ajout en cours" label while scanning
- `InventoryScreen`, `SettingsScreen`, etc.

### manager (Go, `cmd/manager/` + `internal/`)

Desktop Qt6 application with sidebar navigation:

**Screens:**
1. **Inventory** — grouped/flat/history views, multi-selection bulk edit, sort/filter/group, drink-before warnings
2. **Add Bottles** — RFID scan trigger, form with autocompletion, loops for bulk intake (sends one scan request at a time, re-triggers after each save)
3. **Read Bottle** — scan to lookup, edit fields, delete for lost tag recovery
4. **Settings** — phone address (manual or auto-discovered), RFID port, log config

**Catalogue Management:**
- Appellations (designations), Domaines, Cuvées — CRUD with AI auto-fill (ChromeDP / ChatGPT)

**Infrastructure:**
- `screen.Ctx` callback pattern decouples screens from manager
- `crudBase[T]` generic for shared CRUD boilerplate
- `doAsync()` pattern: goroutine → Qt main thread callback
- HTTP client (`internal/client/`) logs all requests/responses at `slog.Info`

### cfru5102 Driver (`internal/integration/cfru5102/`)

Go driver for Chafon CF-RU5102 UHF RFID reader:

- **Protocol**: Binary frames over RS232 at 57600 baud (8N1)
- **Frame format**: `[Len][Addr][Cmd][Data...][CRC_LSB][CRC_MSB]`
- **CRC**: CRC-16/MCRF4XX (polynomial 0x8408, initial 0xFFFF)
- **Supported protocols**: ISO 18000-6C (EPC C1G2) and ISO 18000-6B

## Data Architecture

### Entity Relationships

```
designations (INAO appellations)
    │
    ├── 1:N ── cuvees (named wines)
                   │
                   ├── N:1 ── domains (producers)
                   │
                   └── 1:N ── bottles (physical instances)
```

### Database Tables (drift / SQLite, on phone)

| Table           | Key Fields                                                                    |
|-----------------|-------------------------------------------------------------------------------|
| `designations`  | id, name (UNIQUE), region, description                                        |
| `domains`       | id, name (UNIQUE), description                                                |
| `cuvees`        | id, name, domain_id (FK), designation_id (FK), color, description            |
| `bottles`       | id, tag_id (UNIQUE, nullable), cuvee_id (FK), vintage, description, purchase_price, drink_before, added_at, consumed_at |

### Key Constraints

- `tag_id` UNIQUE among non-null values (in-stock bottles only)
- Bottles → Cuvees: FK (prevents cuvee deletion with existing bottles)
- Cuvees → Domains / Designations: FK
- Sentinel designation `id=0` named `(unassigned)` seeded on first create

## REST API

27 endpoints served by the phone on port 8080. See [rest-api-contracts.md](./rest-api-contracts.md).

### Scan Coordination Flow

```
Manager                           Phone
  │                                 │
  │── POST /scan/request ──────────>│  coordinator.request()
  │<── 201 {"status":"requested"} ──│
  │                                 │  NFC session auto-starts
  │── GET /scan/result ────────────>│  long poll (holds up to 30s)
  │                                 │
  │       (tag scanned by user)     │
  │                                 │  coordinator.submitResult(tagId)
  │<── 200 {"tag_id":"04AABB"} ─────│
  │                                 │
  │   (timeout: manager retries)    │
  │<── 204 (empty) ─────────────────│
  │── GET /scan/result ────────────>│  retry
```

## Configuration

| Component | Config Source                        | Format |
|-----------|--------------------------------------|--------|
| manager   | `~/.config/winetap/manager.yaml`  | YAML   |
| mobile    | no config file — all UI-driven       | —      |

## Deployment

- **Manager**: desktop Linux binary, run directly
- **Mobile**: Flutter app installed on Android phone, started by user
- **No servers, no RPi, no systemd** — both components run on personal devices
