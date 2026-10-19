# WineTap — Documentation Index

## Project Overview

- **Type:** Phone app that holds the cellar and serves a web site
- **Languages:** Dart (Flutter app and embedded server), JavaScript (Svelte 5 site)
- **Architecture:** Phone-as-server. The Flutter app runs an HTTP server on port 8080 that serves the embedded site and a JSON API. The app shows the site in a WebView; desktop browsers on the same WiFi open the same site
- **Components:** `mobile/` (Android and iOS: shelf HTTP server, drift SQLite, NFC, native screens), `web/` (Svelte 5 + Vite site, built into the app's assets)

## Quick Reference

- **Tech stack:** Flutter/Dart (shelf, shelf_router, drift, nfc_manager, webview_flutter, shared_preferences) + Svelte 5 / Vite
- **Entry points:** `mobile/lib/main.dart` (app), `web/src/main.js` (site)
- **HTTP port:** 8080 (plain HTTP, local network only)
- **Database:** SQLite on the phone via drift, schema version 2 (unchanged since v2)
- **API:** `/api/*` JSON API, contract in [web/API.md](../web/API.md)
- **Desktop access:** `http://<phone IP>:8080`, address shown by the phone; each browser is approved once on the phone

## Documentation

- [Project Overview](./project-overview.md) — Purpose, components, tech stack, key decisions
- [Architecture](./architecture.md) — System diagram, server, security, NFC reading flow, deployment
- [Data Models](./data-models.md) — drift/SQLite schema, lifecycle, state kept outside the database
- [API Contracts](./rest-api-contracts.md) — Summary of the `/api/*` routes; full contract in [web/API.md](../web/API.md)
- [Development Guide](./development-guide.md) — Prerequisites, site and app builds, tests, CI and releases
- [Source Tree Analysis](./source-tree-analysis.md) — Directory layout and key files
- [Legacy API note](./api-contracts.md) — Pointer for readers looking for the v1/v2 APIs

## Other References

- [README](../README.md) — Features, installation, architecture summary
- [specs/v3-web.md](../specs/v3-web.md) — v3 specification and decisions (French)
- [web/README.md](../web/README.md) — Site development, mock API, simulated phone (French)
- [spec.md](../spec.md) — v2 specification, kept for history
- [dat/](../dat/) — Technical architecture document (French)

## Getting Started

1. Install Node.js 22 and the Flutter SDK (Dart 3.11+)
2. Site only: `cd web && npm install && npm run dev`, then open `http://localhost:5173` (mock API and simulated phone; add `?app` to simulate the WebView)
3. App: `./scripts/build_web.sh`, then `cd mobile && flutter pub get && flutter run`
4. Desktop access: on the phone, Réglages → « Accès depuis un ordinateur », type the address shown in a browser on the same WiFi, approve the connection on the phone
