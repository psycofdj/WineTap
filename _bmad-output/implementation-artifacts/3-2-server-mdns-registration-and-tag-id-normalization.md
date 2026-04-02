# Story 3.2: Server mDNS Registration and Tag ID Normalization

Status: done

## Story

As a user,
I want the server to be discoverable on the local network and normalize all tag IDs consistently,
So that the mobile app can find the server automatically and tag IDs are always in canonical format.

## Acceptance Criteria

1. **Given** `cmd/server/main.go`
   **When** the server starts
   **Then** it registers an mDNS service as `_winetap._tcp` on the gRPC port
   **And** the service is discoverable by both iOS (Bonjour) and Android (NsdManager) (NFR13)
   **And** the registration is cleaned up on graceful shutdown

2. **Given** `service/tagid.go` implements `NormalizeTagID(raw string) string`
   **When** called with any format (colons, spaces, dashes, lowercase, mixed)
   **Then** it returns uppercase hex with no separators

3. **Given** `service/tagid_test.go`
   **Then** it covers: colons, spaces, dashes, lowercase, mixed, already-normalized, empty string
   **And** test cases match the Dart `normalizeTagId` tests exactly

4. **Given** the coordination stream handler processes a `ScanResult`
   **Then** it calls `NormalizeTagID` on the received `tag_id` before any lookup or relay

5. **Given** the server config
   **Then** mDNS registration is enabled by default with no additional configuration required

## Tasks / Subtasks

- [x] Task 1: Add mDNS dependency (AC: #1)
  - [x] Added `github.com/grandcat/zeroconf` v1.0.0 to go.mod (+ miekg/dns, cenkalti/backoff transitive)
  - [x] `go mod tidy` clean
- [x] Task 2: Implement mDNS registration in server (AC: #1, #5)
  - [x] `parsePort()` helper extracts port from listen address
  - [x] `zeroconf.Register("WineTap", "_winetap._tcp", "local.", port, nil, nil)` in main.go
  - [x] Registered after `server.New()`, before `s.Run(ctx)`
  - [x] `defer mdnsSrv.Shutdown()` for cleanup on graceful shutdown
  - [x] Non-fatal — logs error on failure, server continues
  - [x] Info log: "mDNS registered" with service and port
- [x] Task 3: Verify NormalizeTagID and tests (AC: #2, #3)
  - [x] Confirmed `NormalizeTagID` correct in `tagid.go` (Story 1.2)
  - [x] Confirmed 9 test cases in `tagid_test.go` match Dart side
- [x] Task 4: Verify coordination uses NormalizeTagID (AC: #4)
  - [x] Confirmed `handleScanResult` calls `NormalizeTagID(result.TagId)` at coordination.go:208
- [x] Task 5: Verification
  - [x] `go test ./...` — all tests pass
  - [x] `make build` — all 4 binaries compile

## Dev Notes

### Scope: mDNS Registration + Verification

AC2/3/4 are already implemented:
- `NormalizeTagID` exists in `internal/server/service/tagid.go` (Story 1.2)
- `tagid_test.go` has 9 test cases matching Dart side (Story 1.2)
- `handleScanResult` calls `NormalizeTagID` (Story 3.1, coordination.go line 208)

The only new work is **mDNS registration** (AC1 + AC5).

### mDNS Library: grandcat/zeroconf

`github.com/grandcat/zeroconf` is the standard Go mDNS/DNS-SD library. Used by many Go projects for service discovery.

```go
import "github.com/grandcat/zeroconf"

// Register the service
server, err := zeroconf.Register(
    "WineTap",        // instance name
    "_winetap._tcp",   // service type
    "local.",            // domain
    port,                // port number
    []string{"path=/"},  // TXT records (optional)
    nil,                 // interfaces (nil = all)
)
if err != nil {
    log.Error("mDNS registration failed", "error", err)
    // Non-fatal — server still works, mobile uses manual IP
}
defer server.Shutdown()
```

### Integration into cmd/server/main.go

```go
// After server.New() succeeds:
s, err := server.New(cfg.Listen, cfg.Database, logger)
// ...

// Parse port from listen address
port := parsePort(cfg.Listen) // ":50051" -> 50051

// Register mDNS
mdnsServer, err := zeroconf.Register("WineTap", "_winetap._tcp", "local.", port, nil, nil)
if err != nil {
    logger.Error("mDNS registration failed", "error", err)
    // Continue without mDNS — manual IP fallback still works
} else {
    defer mdnsServer.Shutdown()
    logger.Info("mDNS registered", "service", "_winetap._tcp", "port", port)
}

// Run gRPC server
if err := s.Run(ctx); err != nil { ... }
```

### Port Parsing

The `listenAddr` is typically `:50051` or `0.0.0.0:50051`. Extract the port:

```go
func parsePort(addr string) int {
    _, portStr, err := net.SplitHostPort(addr)
    if err != nil {
        // Might be just ":50051"
        portStr = strings.TrimPrefix(addr, ":")
    }
    port, _ := strconv.Atoi(portStr)
    return port
}
```

### Non-Fatal mDNS

mDNS registration failure should NOT prevent the server from starting. The mobile app already has manual IP fallback (Story 2.3 SettingsScreen). Log the error and continue.

### What NOT to Do

- Do NOT modify `NormalizeTagID` or its tests — they're already correct
- Do NOT modify the coordination handler — it already calls `NormalizeTagID`
- Do NOT add mDNS configuration options — enabled by default per AC5
- Do NOT add a new Go package for mDNS — keep it simple in `cmd/server/main.go`

### Previous Story Intelligence

Story 3.1 established:
- `CoordinateScan` bidi stream with coordination hub
- `handleScanResult` already calls `NormalizeTagID(result.TagId)` on line 208

Story 1.2 established:
- `NormalizeTagID()` in `internal/server/service/tagid.go`
- 9 test cases in `tagid_test.go` matching Dart side

Story 2.3 established:
- Mobile `DiscoveryService` browses for `_winetap._tcp` with 3s timeout
- Falls back to cached address, then manual IP in settings

Server structure:
- `cmd/server/main.go` — config, signal handlers, `server.New()` then `s.Run(ctx)`
- `internal/server/server.go` — `Server` struct with `listenAddr`, `Run()` starts TCP listener
- Default listen: `:50051`

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 3.2 ACs (lines 499-525)
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — mDNS service type `_winetap._tcp` (line ~237)
- [Source: cmd/server/main.go] — Server entry point, config with Listen field
- [Source: internal/server/server.go] — Server struct, Run method
- [Source: internal/server/service/tagid.go] — NormalizeTagID (already implemented)
- [Source: internal/server/service/coordination.go:208] — NormalizeTagID already called in handleScanResult

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Added `grandcat/zeroconf` v1.0.0 for mDNS/DNS-SD service registration
- mDNS registers `_winetap._tcp` on the gRPC port after `server.New()` succeeds
- `parsePort()` helper handles both `:50051` and `host:port` formats
- Non-fatal: failure logs error but server continues (mobile has manual IP fallback)
- `defer mdnsSrv.Shutdown()` cleans up on graceful shutdown (SIGINT/SIGTERM)
- NormalizeTagID and its 9 tests confirmed correct from Story 1.2
- Coordination handler confirmed calling NormalizeTagID from Story 3.1

### Change Log

- 2026-03-31: mDNS registration via zeroconf, verified existing NormalizeTagID integration

### File List

- cmd/server/main.go (modified — mDNS registration + parsePort helper)
- go.mod (modified — added grandcat/zeroconf + transitive deps)
- go.sum (modified)
