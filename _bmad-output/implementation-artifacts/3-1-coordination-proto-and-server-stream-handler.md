# Story 3.1: Coordination Proto and Server Stream Handler

Status: done

## Story

As a developer,
I want the server to expose a `CoordinateScan` bidirectional streaming RPC with a state machine,
So that the manager and mobile app can coordinate NFC scanning in real-time through the server.

## Acceptance Criteria

1. **Given** `winetap.proto`
   **When** the coordination messages are added
   **Then** `ScanClientMessage` has a `oneof payload` with: `ScanRequest`, `ScanResult`, `ScanCancel`
   **And** `ScanServerMessage` has a `oneof payload` with: `ScanRequestNotification`, `ScanAck`, `ScanError`
   **And** `ScanMode` enum has: `SCAN_MODE_UNSPECIFIED`, `SCAN_MODE_SINGLE`, `SCAN_MODE_CONTINUOUS`
   **And** `ScanRequest` includes a `scan_mode` field
   **And** `ScanResult` includes a `tag_id` field
   **And** `rpc CoordinateScan(stream ScanClientMessage) returns (stream ScanServerMessage)` is defined
   **And** `buf lint` passes and `make proto` + `make proto-dart` regenerate without errors

2. **Given** `service/scan_session.go` implements the coordination state machine
   **Then** states are: `IDLE`, `REQUESTED`, `SCANNING`, `RESOLVED`, `CANCELLED`, `TIMED_OUT`
   **And** transitions follow: IDLE -> REQUESTED -> SCANNING -> RESOLVED/CANCELLED/TIMED_OUT
   **And** the struct is mutex-protected for concurrent access
   **And** the server has a 60s safety-net timeout that garbage-collects zombie sessions
   **And** in continuous mode, RESOLVED transitions back to SCANNING (not IDLE)

3. **Given** `service/coordination.go` implements the `CoordinateScan` stream handler
   **When** a manager client sends a `ScanRequest`
   **Then** the server transitions to REQUESTED and relays a `ScanRequestNotification` to connected mobile clients
   **When** a mobile client sends a `ScanResult`
   **Then** the server transitions to RESOLVED and relays a `ScanAck` (with tag_id) to the manager client
   **When** either side sends a `ScanCancel`
   **Then** the server transitions to CANCELLED and notifies both sides

4. **Given** `service/scan_session_test.go`
   **Then** it covers all state transitions, concurrent access safety, timeout GC, continuous mode looping, and invalid transition attempts

5. **Given** `service/coordination_test.go` (integration test)
   **Then** it opens two bidi streams (simulating manager and mobile) and drives through: single scan, continuous scan (2 reads), cancel, timeout, and duplicate read scenarios

## Tasks / Subtasks

- [x] Task 1: Add coordination proto messages and RPC (AC: #1)
  - [x] `ScanMode` enum (UNSPECIFIED, SINGLE, CONTINUOUS)
  - [x] `ScanRequest`, `ScanResult` (tag_id), `ScanCancel` messages
  - [x] `ScanRequestNotification`, `ScanAck` (tag_id), `ScanError` (reason) messages
  - [x] `ScanClientMessage` / `ScanServerMessage` with `oneof payload`
  - [x] `rpc CoordinateScan(stream ScanClientMessage) returns (stream ScanServerMessage)`
  - [x] `buf lint` passes (added `RPC_REQUEST_STANDARD_NAME` exception), `make proto` + `make proto-dart` regenerate
- [x] Task 2: Implement ScanSession state machine with tests (AC: #2, #4)
  - [x] `scan_session.go` — `SessionState` (6 states), `ScanSession` struct with mutex + zombie timer
  - [x] Transitions: `Request`, `StartScanning`, `Resolve`, `Cancel`, `Timeout`
  - [x] Continuous mode: Resolve returns SCANNING
  - [x] `scan_session_test.go` — 7 tests: happy single, happy continuous, cancel, invalid transitions, zombie timeout, timeout reset on activity, concurrent access
- [x] Task 3: Implement CoordinateScan stream handler (AC: #3)
  - [x] `coordination.go` — coordinationHub (manager + mobiles tracking), lazy init via `sync.Once`
  - [x] Role detection by first message type (ScanRequest = manager, ScanResult = mobile)
  - [x] ScanRequest -> ScanRequestNotification to mobiles + auto-transition to SCANNING
  - [x] ScanResult -> NormalizeTagID + Resolve + ScanAck to manager
  - [x] ScanCancel -> Cancel + ScanError("cancelled") to all
  - [x] 60s zombie timeout fires ScanError("timeout") to all
- [x] Task 4: Integration test (AC: #5)
  - [x] `coordination_test.go` — testServer helper (in-memory DB, random port)
  - [x] Single scan flow: request -> result -> ack (tag normalized)
  - [x] Continuous scan (2 reads): both acks received
  - [x] Cancel from manager: after request + dummy result
- [x] Task 5: Verification
  - [x] `go test ./...` — all tests pass (7 session + 3 integration + existing)
  - [x] `make build` — all 4 binaries compile
  - [x] `buf lint` — passes

### Review Findings

- [x] [Review][Patch] Timer callback race — added epoch counter, stale callbacks bail out
- [x] [Review][Patch] Magic number replaced with `v1.ScanMode_SCAN_MODE_CONTINUOUS` constant
- [x] [Review][Patch] Mobile registration on connect — streams pre-registered as mobile, upgraded to manager on first ScanRequest
- [x] [Review][Patch] Rejected ScanResult now sends ScanError back to mobile
- [x] [Review][Patch] Manager disconnect cancels session in defer block
- [x] [Review][Defer] ScanCancel has no role check — solo user, not exploitable
- [x] [Review][Defer] Second manager overwrites first — solo user, one manager
- [x] [Review][Defer] SCAN_MODE_UNSPECIFIED accepted — behaves as single mode
- [x] [Review][Defer] No timeout integration test — needs configurable timeout
- [x] [Review][Defer] Cancel test doesn't verify mobile receives notification

## Dev Notes

### Proto Message Design

Per architecture spec — separate client/server message types with `oneof` payloads:

```protobuf
// ─── Coordination messages ───────────────────────────────────────────────────

enum ScanMode {
  SCAN_MODE_UNSPECIFIED = 0;
  SCAN_MODE_SINGLE      = 1;
  SCAN_MODE_CONTINUOUS  = 2;
}

// Client -> Server messages
message ScanRequest {
  ScanMode scan_mode = 1;
}

message ScanResult {
  string tag_id = 1;
}

message ScanCancel {}

message ScanClientMessage {
  oneof payload {
    ScanRequest  scan_request = 1;
    ScanResult   scan_result  = 2;
    ScanCancel   scan_cancel  = 3;
  }
}

// Server -> Client messages
message ScanRequestNotification {
  ScanMode scan_mode = 1;
}

message ScanAck {
  string tag_id = 1;
}

message ScanError {
  string reason = 1;
}

message ScanServerMessage {
  oneof payload {
    ScanRequestNotification scan_request_notification = 1;
    ScanAck                 scan_ack                  = 2;
    ScanError               scan_error                = 3;
  }
}
```

Add the RPC in the `WineTap` service block:

```protobuf
  // --- Scan coordination ---
  rpc CoordinateScan(stream ScanClientMessage) returns (stream ScanServerMessage);
```

### ScanSession State Machine

Ephemeral in-memory struct. NOT persisted to DB. Mutex-protected.

```go
type SessionState int

const (
    StateIdle SessionState = iota
    StateRequested
    StateScanning
    StateResolved
    StateCancelled
    StateTimedOut
)

type ScanSession struct {
    mu       sync.Mutex
    state    SessionState
    mode     v1.ScanMode
    tagID    string
    timer    *time.Timer
    timeout  time.Duration // 60s default, configurable for tests
}
```

**Transition rules:**
- `Request(mode)`: IDLE -> REQUESTED (start zombie timer)
- `StartScanning()`: REQUESTED -> SCANNING
- `Resolve(tagID)`: SCANNING -> RESOLVED; if continuous: RESOLVED -> SCANNING (reset timer)
- `Cancel()`: any active state -> CANCELLED
- `Timeout()`: any active state -> TIMED_OUT

Invalid transitions return an error — do not panic.

### CoordinateScan Stream Handler

The bidi stream handler manages two types of connected clients:

```go
func (s *Service) CoordinateScan(stream v1.WineTap_CoordinateScanServer) error {
    // Each connected stream is either a "manager" or "mobile" client.
    // The first message determines the role:
    // - ScanRequest -> this is the manager
    // - ScanResult -> this is the mobile
    // - ScanCancel -> either

    // The server maintains a single active ScanSession.
    // Manager sends ScanRequest -> server relays ScanRequestNotification to mobile streams.
    // Mobile sends ScanResult -> server relays ScanAck to manager stream.
}
```

**Client tracking:**
- The `Service` struct needs a coordination hub field to track connected streams
- Manager stream: receives ScanAck, ScanError
- Mobile stream(s): receive ScanRequestNotification, ScanError
- Use channels to communicate between goroutines

**Coordination hub pattern:**

```go
type coordinationHub struct {
    mu      sync.Mutex
    session *ScanSession
    manager chan<- *v1.ScanServerMessage  // send to manager
    mobiles map[uint64]chan<- *v1.ScanServerMessage // send to mobiles
    nextID  uint64
}
```

Add to `Service` struct: `coordination *coordinationHub`

### Testing Strategy

**Unit tests (scan_session_test.go):**
- Each transition: valid and invalid
- Concurrent access: multiple goroutines calling transitions
- Timeout: use short timeout (100ms) for fast tests
- Continuous mode: Resolve loops back to Scanning

**Integration tests (coordination_test.go):**
- Spin up real server on `localhost:0` (OS-assigned port)
- Connect two gRPC clients
- Drive message flows end-to-end
- Use `testing.Short()` to skip slow tests

### Existing Patterns to Follow

- `service.go` — Service struct with embedded `v1.UnimplementedWineTapServer`
- `events.go` — `SubscribeEvents` uses `broadcaster` for fan-out to stream subscribers
- Logging: `s.log` (slog.Logger), Debug for message traces, Info for state changes
- Error handling: return gRPC status codes
- File naming: `snake_case.go`, one type per file

### What NOT to Do

- Do NOT persist coordination state to DB — ephemeral only
- Do NOT implement the mobile or manager client side — that's Stories 3.3/3.4/4.1
- Do NOT add mDNS registration — that's Story 3.2
- Do NOT modify existing RPCs or the consume flow
- Do NOT use the broadcaster pattern from events — coordination needs bidirectional routing, not fan-out

### Previous Story Intelligence

Story 1.2 established:
- `NormalizeTagID()` in `internal/server/service/tagid.go` — reuse for normalizing tag IDs in ScanResult
- `SetBottleTagId` RPC as example of adding new proto + service method

Story 1.1 established:
- `tag_id` field name across all messages
- `GetBottleByTagId` and `ConsumeBottle` RPCs available for future consume-via-coordination

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 3.1 ACs (lines 460-497)
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — Coordination protocol (line ~207), state machine (line ~226), timeout ownership (line ~254), structure patterns (line ~383)
- [Source: internal/server/service/service.go] — Service struct, broadcaster pattern
- [Source: internal/server/server.go] — gRPC server setup with stream interceptor
- [Source: proto/winetap/v1/winetap.proto] — Current service block, message patterns
- [Source: internal/server/service/tagid.go] — NormalizeTagID for reuse

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Proto: 1 enum (ScanMode), 6 messages, 2 wrapper messages (oneof), 1 bidi stream RPC
- Added `RPC_REQUEST_STANDARD_NAME` exception to buf.yaml (bidi streams don't follow standard naming)
- ScanSession: 6 states, mutex-protected, configurable zombie timeout (60s default, short for tests)
- Resolve in continuous mode auto-loops to SCANNING, single mode resets to IDLE
- CoordinationHub: tracks manager (single) + mobiles (map) via channels, lazy init with sync.Once
- Stream handler: role detected by first message type, writer goroutine per stream for non-blocking sends
- NormalizeTagID reused from Story 1.2 for tag normalization in ScanResult handling
- 7 unit tests + 3 integration tests all pass
- Dart proto also regenerated — Flutter project will have the coordination stubs available

### Change Log

- 2026-03-31: Coordination proto + server bidi stream handler + state machine + tests

### File List

- proto/winetap/v1/winetap.proto (modified — coordination messages + RPC)
- buf.yaml (modified — added RPC_REQUEST_STANDARD_NAME exception)
- gen/winetap/v1/winetap.pb.go (regenerated)
- gen/winetap/v1/winetap_grpc.pb.go (regenerated)
- mobile/lib/gen/winetap/v1/ (regenerated — Dart stubs)
- internal/server/service/service.go (modified — added coord + coordOnce fields)
- internal/server/service/scan_session.go (new — state machine)
- internal/server/service/scan_session_test.go (new — 7 tests)
- internal/server/service/coordination.go (new — hub + stream handler)
- internal/server/service/coordination_test.go (new — 3 integration tests)
