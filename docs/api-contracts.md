# WineTap — API Contracts (Legacy Pointer)

Earlier versions used other APIs, none of which exist anymore:

- **v1**: a gRPC service served by a Go binary on a Raspberry Pi
- **v2**: a REST API served by the phone for the Go/Qt6 desktop manager (with mDNS discovery and long-polling scan)

The current API is the `/api/*` JSON API served by the phone for the embedded site. See [rest-api-contracts.md](./rest-api-contracts.md) for a summary of routes, and [web/API.md](../web/API.md) for the full contract.
