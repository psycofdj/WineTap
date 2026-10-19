# WineTap

Wine cellar inventory management system using NFC tags to track bottles from purchase to consumption.

Attach an NFC tag to each bottle when you add it to your cellar. When you open a bottle, scan the tag to mark it as consumed -- the tag is freed and can be reused. Everything runs locally on your WiFi network: the phone holds the cellar and serves a web site, usable in the app and from any desktop browser. No cloud, no account.

## Table of contents

- [Features](#features)
- [How it works](#how-it-works)
- [Installation](#installation)
  - [Mobile app](#mobile-app)
  - [Desktop access](#desktop-access)
- [Architecture and Design](#architecture-and-design)
  - [System overview](#system-overview)
  - [Desktop access and security](#desktop-access-and-security)
  - [NFC reading](#nfc-reading)
  - [Data model](#data-model)
  - [Project structure](#project-structure)
  - [Key design decisions](#key-design-decisions)
- [Developer Guide](#developer-guide)
  - [Prerequisites](#prerequisites)
  - [Web site](#web-site)
  - [Mobile app](#mobile-app-1)
  - [Running tests](#running-tests)
  - [Continuous integration and releases](#continuous-integration-and-releases)

## Features

- **NFC tag lifecycle** -- attach a tag on intake, scan to consume, tag is freed for reuse
- **Full catalogue management** -- appellations (AOC/AOP, with region, description and map image), domains and cuvées
- **Inventory** -- sort, filter and group the cellar; drink-before highlighting; add from an existing bottle; "save and continue" to enter a whole case, one tag after the other
- **Dashboard** -- bottles in stock, breakdown by colour and by region
- **Tasting history** -- consumed bottles, newest first, with editable comments
- **Backup / restore** -- download or restore the whole database as a SQLite file, compatible with v2 backups
- **"Ask the AI"** -- opens ChatGPT or Claude with a prepared question about an appellation, a domain or a cuvée
- **Desktop access** -- the same site in a desktop browser, at the address shown by the phone; each browser must be authorized on the phone once

## How it works

| Component | Tech | Role |
|-----------|------|------|
| **Web site** (`web/`) | Svelte 5 / Vite | All screens: inventory, catalogue, dashboard, tastings, settings. Shown in the app's WebView (phone layout) and in desktop browsers (wide layout) |
| **Mobile app** (`mobile/`) | Flutter / Dart | HTTP server on port 8080 (site + `/api`), SQLite database, NFC reading, and the few native screens: address, connection approval, authorized connections, NFC reading |

The site is built once and embedded in the app's assets. The phone serves it, together with the JSON API described in [web/API.md](web/API.md).

## Installation

### Mobile app

- **Android**: Google Play (internal track), or the `.aab` attached to each [GitHub release](https://github.com/psycofdj/WineTap/releases)
- **iOS**: available on the App Store (search "WineTap")

### Desktop access

1. Open WineTap on the phone, then Réglages → « Accès depuis un ordinateur »: the phone shows an address such as `http://192.168.1.42:8080`
2. Type that address in a desktop browser on the same WiFi network
3. Approve the connection on the phone (« Autoriser cette connexion ? »). The browser is remembered until you revoke it (Réglages → « Connexions autorisées »)

The phone must stay on with WineTap open while you use it from the computer.

---

# Architecture and Design

## System overview

```
+---------------------------+                 +--------------------------------------+
|  Desktop browser          |                 |  Phone (Android / iOS)               |
|                           |   HTTP + SSE    |                                      |
|  WineTap site             |---- WiFi ------>|  shelf server (:8080)                |
|  (wide layout)            |                 |    /           embedded site         |
+---------------------------+                 |    /api/*      JSON API              |
                                              |    /api/events server-sent events    |
                                              |  drift SQLite database               |
                                              |  NFC (nfc_manager)                   |
                                              |                                      |
                                              |  WebView -> http://localhost:8080    |
                                              |  (phone layout + JS bridge to NFC)   |
                                              +--------------------------------------+
```

- **Phone is the server** -- the SQLite database lives on the phone; browsers are clients
- **One site, two layouts** -- desktop layout from 720 px wide and 500 px high; phone layout otherwise, including a phone in landscape
- **Live updates** -- `/api/events` pushes data changes, remote scan progress and session decisions to every open page

## Desktop access and security

There is no HTTPS (the phone has no certificate a browser would trust on a LAN). Access control relies on:

- **Approval on the phone** -- a new browser gets a pending session cookie (`wt_session`, HttpOnly, SameSite=Strict); the phone asks « Autoriser cette connexion ? », showing the browser, system and IP address. Authorized sessions have no expiry and can be revoked one by one or all at once. Only hashes of session ids are stored
- **App token** -- the WebView gets a random token generated at each launch, injected with the JavaScript bridge; it never leaves the phone
- **Host and Origin checks** -- requests must target `localhost` or an IP address (against DNS rebinding), and writes must come from the same origin

## NFC reading

Every tag reading goes through the native NFC screen on the phone:

- **In the app**, the site calls the JavaScript bridge (`winetapBridge.readTag`); the native screen opens and the tag id comes back to the page
- **From a desktop browser**, the site asks the phone to read a tag (`POST /api/scan`); the phone opens the same native screen, labelled « Demandé par un ordinateur », and the result is pushed back through `/api/events`

Consuming and identifying a bottle by its tag are only available in the app; intake works from both.

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
| `cuvees` | Named wines (links domain + designation + colour) | FK to domains, FK to designations |
| `bottles` | Physical bottles with optional NFC tag | `tag_id` UNIQUE among non-null; FK to cuvees |

Bottle lifecycle:
- **In stock**: `consumed_at` is NULL, `tag_id` is set
- **Consumed**: `consumed_at` is set, `tag_id` cleared to NULL (tag freed for reuse)
- **Hard deleted**: only for lost or damaged tag recovery

The schema is unchanged since v2: databases and backups are compatible both ways. Settings and authorized sessions are stored in the app's preferences, not in the database.

## Project structure

```
winetap/
|-- web/                           # Embedded site (Svelte 5, Vite)
|   |-- src/                       # Screens, components, API client
|   |-- mock/                      # In-memory API for development
|   +-- API.md                     # API and JS bridge contract
|-- mobile/
|   |-- lib/
|   |   |-- server/                # HTTP server, API, database, sessions, events
|   |   |-- native/                # WebView shell, JS bridge, native screens
|   |   +-- services/              # NFC, tag normalization
|   +-- assets/
|       |-- fonts/                 # Fonts of the native screens (OFL)
|       +-- site/                  # Built site (generated, not versioned)
|-- scripts/
|   |-- build_web.sh               # Builds web/ into mobile/assets/site/
|   +-- build_packages.sh          # Local signed Android build
|-- specs/                         # v3 specification
|-- design_handoff_winetap_v3/     # Mockups and design tokens
+-- dat/                           # Technical architecture document
```

## Key design decisions

- **Phone as server**: the phone already has NFC hardware and is always with the user; making it the server avoids needing a separate always-on device
- **Web site instead of a desktop app**: one code base for the phone and the computer, nothing to install on the computer
- **No mDNS**: the phone shows its address; the browser keeps it once typed
- **Tags are temporary associations**: a tag does not permanently identify a wine -- it is an association that exists only while the bottle is in stock
- **Single database on phone**: no sync, no replication -- the phone is the single source of truth, with backup/restore for safety
- **French UI**: the app targets French wine cellars; all labels and strings are in French

See [specs/v3-web.md](specs/v3-web.md) for the full specification and decisions.

---

# Developer Guide

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Node.js | 22 (see `web/.nvmrc`) |
| Flutter SDK | stable, Dart 3.11+ |
| Android SDK | API 26+ |
| NFC hardware | Physical phone for NFC testing |

## Web site

```bash
cd web
npm install
npm run dev      # http://localhost:5173, with a simulated API and phone
npm run check    # svelte-check
npm run build    # dist/
```

The development server simulates the phone: a « Téléphone simulé » panel approves connections and answers tag readings, and `?app` imitates the app's WebView. See [web/README.md](web/README.md).

## Mobile app

The site must be built into the app's assets before any Flutter build:

```bash
./scripts/build_web.sh
cd mobile
flutter pub get
flutter run
```

On dev builds (version `0.0.0`), an empty database is seeded with a test catalogue.

To try the real server with the built site in a desktop browser, without a phone:

```bash
./scripts/build_web.sh
cd mobile
WINETAP_E2E=1 WINETAP_E2E_SECONDES=300 flutter test test/e2e/serve_test.dart
# then open http://127.0.0.1:8099/ (connections are approved automatically)
```

## Running tests

```bash
cd web && npm run check

cd mobile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Mobile tests use in-memory SQLite and a fake NFC service. The API tests run the shelf handler directly; the native screens are covered by widget tests.

## Continuous integration and releases

- `web-ci.yml` -- `svelte-check` and build, on pull requests touching `web/`
- `mobile-ci.yml` -- builds the site, then format, analyze and tests, on pull requests touching `mobile/` or `web/`
- `release.yml` -- on a `v*` tag: builds the site, then the signed Android bundle (uploaded to Google Play, internal track) and the iOS IPA (uploaded to App Store Connect), and attaches both to the GitHub release
