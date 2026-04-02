# WineTap — API Contracts (Legacy Reference)

> **This document describes the v1 gRPC API, which is no longer in use.**
>
> The current API is a REST/JSON API served by the Flutter phone app.
> See [rest-api-contracts.md](./rest-api-contracts.md) for the live specification.

---

The original v1 system used a gRPC service (`WineTap`) defined in `proto/winetap/v1/winetap.proto`, served by a Go binary (`winetap-server`) running on a Raspberry Pi on port 50051.

That architecture has been replaced by:
- **Phone** (Flutter/Dart) — shelf HTTP server on port 8080, SQLite database via drift
- **Manager** (Go/Qt6) — HTTP client connecting to the phone over WiFi

The gRPC proto files, generated code, and the `rpc-server` / `cellar` binaries are preserved in git history but are no longer part of the active codebase.
