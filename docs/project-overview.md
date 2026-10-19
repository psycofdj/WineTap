# WineTap — Project Overview

## Purpose

WineTap is a wine cellar inventory system that uses NFC tags to track the lifecycle of each bottle, from purchase to consumption. A tag is attached to each bottle on intake; scanning the tag when the bottle is opened marks it as consumed and frees the tag for reuse.

Everything runs locally: the phone holds the cellar and serves a web site, used in the app and from any desktop browser on the same WiFi. No cloud, no account.

## Architecture

| Component | Technology | Role | Runs on |
|-----------|------------|------|---------|
| **mobile** (`mobile/`) | Flutter / Dart | HTTP server on port 8080 (site + `/api/*`), SQLite database, NFC reading, WebView showing the site, native screens: address (N-E1), connection approval (N-E2), authorized connections (N-E3), NFC reading (N-E4) | Android and iOS phone |
| **web** (`web/`) | Svelte 5 / Vite | All management screens: inventory, catalogue, dashboard, tastings, settings, backup/restore. Desktop layout from 720 × 500 px, phone layout otherwise | Served by the phone; shown in the app's WebView and in desktop browsers |

The site is built by `scripts/build_web.sh` into `mobile/assets/site/` (not versioned) and embedded in the app. The phone is the only server; browsers are clients.

v3 replaced the v2 desktop manager (Go / Qt6), its mDNS discovery, its RFID reader support and the long-polling scan protocol. The v2 specification is kept in [spec.md](../spec.md); the v3 one is [specs/v3-web.md](../specs/v3-web.md).

## Tech Stack Summary

### Mobile (phone)

| Category | Technology |
|----------|------------|
| Language / UI | Dart 3.11+, Flutter |
| HTTP server | shelf + shelf_router |
| Database | SQLite via drift (drift_flutter, sqlite3) |
| NFC | nfc_manager (Android and iOS) |
| Site display | webview_flutter, with a JavaScript bridge (`window.winetapBridge`) |
| State outside the DB | shared_preferences (authorized sessions, settings) |
| Other | wakelock_plus (screen kept on while the server is used), url_launcher, crypto (SHA-256 of session ids), package_info_plus |

### Web site

| Category | Technology |
|----------|------------|
| Framework | Svelte 5 (`$state`, `$props`, `$derived`) |
| Build | Vite |
| Checks | svelte-check |
| Fonts | Newsreader, IBM Plex Sans, IBM Plex Mono (bundled, no network access at runtime) |
| Development | `web/mock/`: in-memory implementation of the API and a simulated phone |

## Repository Structure

- **`web/`** — Svelte site; `API.md` is the API and bridge contract
- **`mobile/lib/server/`** — HTTP server, `/api/*` handlers, database, sessions, events, remote scan, static site
- **`mobile/lib/native/`** — WebView shell, JavaScript bridge, native screens N-E1 to N-E4
- **`mobile/lib/services/`** — NFC service (Android, iOS), tag id normalization
- **`scripts/`** — site build, local signed Android build
- **`specs/`**, **`design_handoff_winetap_v3/`**, **`dat/`** — specification, mockups, architecture document
- **`docs/`** — this documentation

## Key Design Decisions

- **Phone as server** — the phone has the NFC hardware and is always with the user; no separate always-on device
- **One site, two layouts** — the same site in the app and on a computer; nothing to install on the computer
- **No mDNS** — the phone shows its address; the user types it once in the browser
- **Approval on the phone** — each new browser must be authorized on the phone; authorized sessions never expire and can be revoked
- **No HTTPS** — plain HTTP on the local network; protection relies on approval, Host and Origin checks
- **Every NFC read on the phone** — through the native N-E4 screen, whether asked by the site in the app or by a computer
- **Database schema unchanged** — drift schema version 2, v2 and v3 backups restore both ways; v3 state (sessions, settings) is kept in the app's preferences
- **Tags are temporary associations** — `tag_id` is cleared on consumption; bottles are identified by an integer id
- **Server-sent events** — `/api/events` pushes data changes, remote scan results and session decisions to open pages
- **French UI** — all labels and API route names are in French
