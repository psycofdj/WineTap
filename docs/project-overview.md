# WineTap — Project Overview

## Purpose

WineTap is a wine cellar inventory system that uses RFID tags to track the lifecycle of each bottle — from purchase to consumption. Each bottle receives an RFID tag on intake; scanning the tag on exit marks the bottle as consumed and frees the tag for reuse.

## Architecture

Two components communicating over HTTP REST:

| Component   | Technology        | Role                                                          | Runs On        |
|-------------|-------------------|---------------------------------------------------------------|----------------|
| **mobile**  | Flutter / Dart    | HTTP server, SQLite database, NFC scanning, user-facing app   | Android phone  |
| **manager** | Go / Qt6          | Desktop GUI for adding bottles, browsing inventory, RFID scan | Desktop (Linux)|

The phone is the server. The manager is the client. The manager discovers the phone via mDNS (`_winetap._tcp`) and connects over WiFi.

## Tech Stack Summary

### Mobile (phone)

| Category        | Technology                          | Version / Details              |
|-----------------|-------------------------------------|--------------------------------|
| Language        | Dart                                | 3.x (Flutter SDK)              |
| UI Framework    | Flutter                             | 3.x                            |
| HTTP Server     | shelf + shelf_router                | dart pub                       |
| Database        | SQLite via drift (code-gen ORM)     | drift + drift_flutter          |
| NFC             | flutter_nfc_kit                     | Android NFC API                |
| State mgmt      | provider (ChangeNotifier)           |                                |
| Service disc.   | bonsoir (mDNS / DNS-SD)             | `_winetap._tcp` on port 8080 |

### Manager (desktop)

| Category        | Technology                          | Version / Details              |
|-----------------|-------------------------------------|--------------------------------|
| Language        | Go                                  | 1.26                           |
| GUI Framework   | Qt6 via miqt bindings (CGo)         | github.com/mappu/miqt v0.13    |
| HTTP Client     | net/http (stdlib)                   |                                |
| RFID Hardware   | Chafon CF-RU5102 UHF reader         | ISO 18000-6C / EPC Gen2        |
| Serial I/O      | go.bug.st/serial                    | v1.6.2                         |
| Config          | YAML                                | gopkg.in/yaml.v3               |
| Service disc.   | mDNS client                         | phone discovery on local net   |
| AI Integration  | ChromeDP (headless Chrome)          | ChatGPT web scraping for forms |
| Logging         | log/slog                            | info-level HTTP request traces |

## Repository Structure

- **`mobile/`** — Flutter application (server + UI)
  - `lib/server/` — shelf HTTP server, drift database, scan coordinator
  - `lib/providers/` — ChangeNotifier state (ScanProvider, IntakeProvider, ServerProvider)
  - `lib/screens/` — ConsumeScreen, IntakeScreen, InventoryScreen, …
- **`internal/`** — Go manager business logic
  - `internal/client/` — HTTP client for phone API
  - `internal/manager/` — Manager orchestration, NFC scanner, screen contexts
- **`cmd/manager/`** — Go binary entry point
- **`docs/`** — This documentation

## Key Design Decisions

- **Phone as server** — all data lives on the phone; manager is a thin client
- **No authentication** — local home WiFi only
- **French UI** — all labels and user-facing text in French
- **Single scan per request** — each scan request covers one tag; manager loops for bulk intake
- **Long polling** — GET /scan/result holds connection until tag scanned, timeout, or cancel
- **tag_id as temporary association** — bottles identified by autoincrement integer; tag_id is mutable, cleared on consumption
- **Soft delete by default** — bottles get `consumed_at` set; hard delete only for lost/damaged tag recovery
- **Client-side filtering** — phone returns full inventory; manager handles sort/filter/group