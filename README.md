# WineTap

Wine cellar inventory management system using NFC/RFID tags to track bottles from purchase to consumption.

Attach an NFC tag to each bottle when you add it to your cellar. When you open a bottle, scan the tag to mark it as consumed -- the tag is freed and can be reused. Everything runs locally on your WiFi network between your phone and a desktop app, with no cloud or account required.

## Table of contents

- [Features](#features)
- [How it works](#how-it-works)
- [Installation](#installation)
  - [Mobile app](#mobile-app)
  - [Manager (desktop)](#manager-desktop)
  - [First run](#first-run)
- [Architecture and Design](#architecture-and-design)
  - [System overview](#system-overview)
  - [Data model](#data-model)
  - [NFC scan coordination](#nfc-scan-coordination)
  - [REST API](#rest-api)
  - [Project structure](#project-structure)
  - [Key design decisions](#key-design-decisions)
- [Developer Guide](#developer-guide)
  - [Prerequisites](#prerequisites)
  - [Running locally](#running-locally)
  - [RFID reader setup](#rfid-reader-setup)
  - [Seeding the database](#seeding-the-database)
  - [End-to-end local testing](#end-to-end-local-testing)
  - [Running tests](#running-tests)
  - [Code conventions](#code-conventions)

## Features

- **NFC tag lifecycle** -- attach a tag on intake, scan to consume, tag is freed for reuse
- **Full catalogue management** -- appellations (AOC/AOP), domains (producers), cuvees (named wines), and individual bottles
- **Inventory browsing** -- sort, filter, and group your cellar by any field; multi-selection for bulk edits
- **Drink-before warnings** -- yellow when approaching, red when overdue
- **Autocompletion** -- domain, designation, and cuvee names autocomplete from your existing data
- **Backup / restore** -- download or upload the entire database as a SQLite file
- **mDNS auto-discovery** -- the desktop app finds the phone automatically on the local network
- **AI-assisted catalogue entry** -- optional ChatGPT auto-fill for wine details (via ChromeDP)
- **RFID reader support** -- Chafon CF-RU5102 UHF reader for desktop-side tag operations

## How it works

The system has two components:

| Component | Tech | Runs on | Role |
|-----------|------|---------|------|
| **Mobile app** | Flutter / Dart | Android / iOS phone | HTTP server + NFC reader + SQLite database |
| **Manager** | Go / Qt6 | Linux / macOS / Windows desktop | GUI client + optional RFID reader |

The phone hosts the database and exposes a REST API on port 8080. The desktop manager connects as an HTTP client over WiFi. NFC scanning is coordinated via long-polling: the manager requests a scan, the phone activates NFC, the user taps a tag, and the result is sent back to the manager.

## Installation

### Mobile app

#### From a release (recommended)

- **Android**: download the latest APK from the [GitHub Releases](https://github.com/psmusic/wine-caver/releases) page
- **iOS**: available on the App Store (search "WineTap")

#### From source

```bash
cd mobile
flutter pub get
flutter build apk
# Install the APK from build/app/outputs/flutter-apk/app-release.apk
```

Requires Flutter SDK 3.x and Android SDK API 26+.

### Manager (desktop)

#### From a release (recommended)

Download the latest binary for your platform from the [GitHub Releases](https://github.com/psmusic/wine-caver/releases) page (Linux, macOS, Windows).

```bash
chmod +x winetap-manager   # Linux / macOS only
./winetap-manager
```

#### From source

```bash
go mod download
make build-manager
./bin/winetap-manager
```

Requires Go 1.26+ and Qt6 development headers (for the miqt CGo bindings).

### First run

1. Install and open the mobile app on your Android phone -- it starts the HTTP server and advertises itself via mDNS
2. Start the manager on your desktop -- it auto-discovers the phone on the same WiFi network
3. If auto-discovery fails, enter the phone's IP manually in the manager's Settings screen

---

# Architecture and Design

## System overview

```
+----------------------------------+          +-------------------------------+
|  Desktop (Linux / macOS / Win)   |          |    Phone (Android / iOS)      |
|                                  |          |                               |
|  +----------------------------+  |          |  +-------------------------+  |
|  |     manager (Qt6 GUI)      |  |          |  |  mobile (Flutter app)   |  |
|  |                            |  |  HTTP    |  |                         |  |
|  |  Inventory / Add / Read /  |--+--REST ---+--|  shelf HTTP (:8080)     |  |
|  |  Settings screens          |  |  WiFi    |  |  drift SQLite DB        |  |
|  |                            |  |          |  |  NFC (flutter_nfc_kit)  |  |
|  |  RFID reader (USB serial)  |  |          |  |  mDNS (_winetap._tcp)  |  |
|  +----------------------------+  |          |  +-------------------------+  |
+----------------------------------+          +-------------------------------+
```

- **No cloud, no accounts** -- everything stays on the local network
- **Phone is the server** -- the SQLite database lives on the phone; the desktop is a client
- **WiFi-only trust model** -- no authentication; security relies on network-level access control

## Data model

```
bottles (physical instances)
    |
    +-- N:1 -- cuvees (named wines)
                  |
                  +-- N:1 -- domains (producers)
                  |
                  +-- N:1 -- designations (AOC appellations)
```

| Table | Purpose | Key constraints |
|-------|---------|-----------------|
| `designations` | INAO appellations | `name` UNIQUE |
| `domains` | Wine producers / estates | `name` UNIQUE |
| `cuvees` | Named wines (links domain + designation + color) | FK to domains, FK to designations |
| `bottles` | Physical bottles with optional NFC tag | `tag_id` UNIQUE among non-null; FK to cuvees |

Bottle lifecycle:
- **In stock**: `consumed_at` is NULL, `tag_id` is set
- **Consumed**: `consumed_at` is set, `tag_id` cleared to NULL (tag freed for reuse)
- **Hard deleted**: only for lost or damaged tag recovery

A sentinel designation (`id=0`, name `(unassigned)`) is seeded on first database creation for cuvees with no appellation.

## NFC scan coordination

The manager and phone coordinate NFC scans via long-polling:

```
Manager                           Phone
  |                                 |
  |-- POST /scan/request --------->|  start NFC session
  |<-- 201 {"status":"requested"} -|
  |                                 |
  |-- GET /scan/result ----------->|  hold up to 30s
  |                                 |  (user scans tag)
  |<-- 200 {"tag_id":"04AABB"} ----|
  |                                 |
  |   (on timeout: 204, retry)     |
```

## REST API

27 endpoints served by the phone on port 8080. All JSON with `snake_case` fields, no authentication.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/designations` | List all designations |
| POST | `/designations` | Create designation |
| PUT | `/designations/:id` | Update designation |
| DELETE | `/designations/:id` | Delete designation |
| GET | `/domains` | List all domains |
| POST | `/domains` | Create domain |
| PUT | `/domains/:id` | Update domain |
| DELETE | `/domains/:id` | Delete domain |
| GET | `/cuvees` | List all cuvees |
| POST | `/cuvees` | Create cuvee |
| PUT | `/cuvees/:id` | Update cuvee |
| DELETE | `/cuvees/:id` | Delete cuvee |
| GET | `/bottles` | List bottles (`?include_consumed=true` for history) |
| GET | `/bottles/:id` | Get bottle by ID |
| GET | `/bottles/by-tag/:tag_id` | Get bottle by NFC tag |
| POST | `/bottles` | Add bottle |
| POST | `/bottles/consume` | Consume bottle by tag |
| PUT | `/bottles/:id` | Partial update bottle |
| PUT | `/bottles/bulk` | Bulk update bottles |
| DELETE | `/bottles/:id` | Hard delete bottle |
| PUT | `/bottles/:id/tag` | Set/update bottle tag |
| GET | `/completions` | Autocomplete (`?field=...&prefix=...`) |
| POST | `/scan/request` | Initiate NFC scan |
| GET | `/scan/result` | Long-poll for scan result |
| POST | `/scan/cancel` | Cancel pending scan |
| GET | `/backup` | Download SQLite database |
| POST | `/restore` | Upload replacement database |

Error responses follow a consistent format:

```json
{"error": "<code>", "message": "<description>"}
```

| HTTP Status | Code | Meaning |
|-------------|------|---------|
| 400 | `invalid_argument` | Missing or malformed field |
| 404 | `not_found` | Resource does not exist |
| 409 | `already_exists` | Unique constraint violation |
| 412 | `failed_precondition` | FK prevents deletion |
| 500 | `internal` | Unexpected server error |

## Project structure

```
winetap/
|-- cmd/
|   |-- manager/main.go           # Desktop GUI entry point
|   +-- cfru5102_read/main.go      # Standalone RFID reader debug tool
|-- internal/
|   |-- client/                    # HTTP client for the phone API
|   |-- manager/
|   |   |-- screen/                # Qt6 UI screens (inventory, add, read, settings, ...)
|   |   |-- widget/                # Reusable Qt widgets
|   |   |-- assets/                # Embedded icon + stylesheet
|   |   |-- manager.go             # Manager orchestration
|   |   |-- nfc_scanner.go         # NFC scan coordination via HTTP
|   |   |-- discovery.go           # mDNS phone discovery
|   |   +-- config.go              # YAML config loading/saving
|   +-- integration/cfru5102/      # Chafon CF-RU5102 RFID reader driver
|-- mobile/
|   +-- lib/
|       |-- server/                # HTTP server (shelf), database (drift), handlers
|       |-- providers/             # ChangeNotifier state management
|       |-- screens/               # Flutter UI screens
|       |-- services/              # NFC, mDNS, tag normalization
|       |-- widgets/               # Reusable Flutter widgets
|       |-- models/                # Data classes
|       +-- l10n/                  # Localization (French)
|-- docs/                          # Detailed documentation
+-- spec.md                        # Full project specification
```

## Key design decisions

- **Phone as server**: the phone already has NFC hardware and is always with the user; making it the server avoids needing a separate always-on device
- **No Raspberry Pi**: the initial plan included an RPi bridge, but the phone-as-server approach eliminated that need
- **REST over gRPC**: switched from gRPC to plain HTTP REST for simplicity and easier debugging
- **Tags are temporary associations**: a tag does not permanently identify a wine -- it is an association that exists only while the bottle is in stock
- **Single database on phone**: no sync, no replication -- the phone is the single source of truth, with backup/restore for safety
- **French UI**: the app targets French wine cellars; all labels and strings are in French

---

# Developer Guide

## Prerequisites

### Mobile (Flutter)

| Requirement | Version |
|-------------|---------|
| Flutter SDK | 3.x (includes Dart 3.x) |
| Android SDK | API 26+ |
| NFC hardware | Physical Android device for NFC testing |

### Manager (Go)

| Requirement | Version |
|-------------|---------|
| Go | 1.26+ |
| Qt6 headers | Required for miqt CGo bindings |
| Chrome/Chromium | Optional, for AI auto-fill feature |
| RFID reader | Optional, Chafon CF-RU5102 for hardware testing |

## Running locally

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

The app starts a shelf HTTP server on port 8080 and advertises itself via mDNS (`_winetap._tcp`). It is reachable on the local WiFi as soon as the app is open.

### Manager

```bash
go mod download
make build-manager
./bin/winetap-manager
```

On first launch, the manager auto-discovers the phone via mDNS. Configuration is saved to `~/.config/winetap/manager.yaml` when you use the Settings screen:

```yaml
phone_address: "192.168.1.x:8080"
rfid_port: "/dev/ttyUSB0"
log_level: "info"
log_format: "text"
```

### RFID reader setup

The Chafon CF-RU5102 connects via USB serial (57600 baud, 8N1). It typically appears as `/dev/ttyUSB0`. Grant serial port access:

```bash
sudo usermod -aG dialout $USER
# Log out and back in for the group change to take effect
```

### Seeding the database

A seed script populates the database with ~200 bottles across French wine regions (Bordeaux, Bourgogne, Rhone, Champagne, Loire, etc.) for development and testing:

```bash
# Against the phone app (default: http://localhost:8080)
./seed_inventory.sh

# Against a custom address
./seed_inventory.sh http://192.168.1.42:8080
```

The script is idempotent -- it skips designations, domains, and cuvees that already exist.

### End-to-end local testing

1. Start the mobile app on an Android device connected to the same WiFi
2. Run `./bin/winetap-manager`
3. The manager discovers the phone automatically (or enter the IP in Settings)
4. Use "Add Bottles": manager sends a scan request, phone shows intake screen, scan a tag, manager receives the tag ID and saves the bottle

## Running tests

### Mobile

```bash
cd mobile

# All tests
flutter test

# Specific file
flutter test test/providers/scan_provider_test.dart -v
```

Tests use in-memory SQLite and a mock NfcService. The ScanCoordinator uses short timeouts (100ms) in test setup.

### Manager

```bash
# All tests
go test ./...

# Specific package
go test ./internal/manager/... -v
```

## Code conventions

### Mobile (Dart)

- `lib/server/` has no Flutter imports -- pure Dart HTTP + database code
- `lib/providers/` manages state via ChangeNotifier; no direct handler calls
- `lib/screens/` is UI only -- reads from providers via `context.watch`, writes via `context.read`
- Logging uses `dart:developer`'s `log()` with a `name:` tag

### Manager (Go)

- All logging via `log/slog` -- accept `*slog.Logger` as a dependency, never use `slog.Default()` outside main
- Error logs include an `"error"` key with the error value
- `screen.Ctx` callback pattern decouples screens from the manager
- `doAsync()` runs work in a goroutine and dispatches the result back to the Qt main thread
- `crudBase[T]` provides generic shared CRUD boilerplate for catalogue screens
