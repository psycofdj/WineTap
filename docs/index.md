# WineTap — Documentation Index

## Project Overview

- **Type:** Two-component system (phone app + desktop manager)
- **Languages:** Dart (Flutter mobile) + Go (Qt6 desktop)
- **Architecture:** Phone-as-server; manager is HTTP client over WiFi
- **Components:** mobile (Android, shelf HTTP server + drift SQLite + NFC), manager (Linux Qt6 GUI + RFID reader)

## Quick Reference

- **Tech Stack:** Flutter/Dart (shelf, drift, flutter_nfc_kit) + Go (Qt6, net/http, cfru5102 driver)
- **Entry Points:** `mobile/lib/main.dart`, `cmd/manager/main.go`
- **Architecture Pattern:** Phone runs shelf HTTP on port 8080; manager discovers phone via mDNS (`_winetap._tcp`)
- **HTTP Port:** 8080 (phone, insecure, WiFi only)
- **Database:** SQLite on phone via drift ORM
- **Config:** YAML at `~/.config/winetap/manager.yaml` (manager only)

## Documentation

- [Project Overview](./project-overview.md) — Purpose, architecture summary, tech stack, key decisions
- [Architecture](./architecture.md) — System diagram, component details, data model, scan flow, deployment
- [Data Models](./data-models.md) — Drift/SQLite schema, entity relationships, migration strategy
- [REST API Contracts](./rest-api-contracts.md) — All 26 HTTP endpoints with request/response shapes
- [Development Guide](./development-guide.md) — Prerequisites, build commands, local setup, testing

## Getting Started

1. Install Flutter SDK 3.x and Go 1.26+
2. Mobile: `cd mobile && flutter pub get && flutter run`
3. Manager: `go mod download && make build-manager && ./bin/winetap-manager`
4. Connect phone and desktop to same WiFi — manager auto-discovers phone via mDNS
