# Story 6.1: Go HTTP Client and API Types

Status: done

## Story

As a developer,
I want a Go HTTP client with typed structs matching the phone's REST API,
So that the manager can communicate with the phone over HTTP.

## Acceptance Criteria

1. **Given** `internal/manager/api_types.go` defines all entity structs
   **When** the structs are used with `encoding/json`
   **Then** Designation, Domain, Cuvee, Bottle all have `json:"snake_case"` tags
   **And** nullable fields use pointer types (`*string`, `*float64`, `*int32`) with `omitempty`
   **And** Bottle includes nested `Cuvee` field (denormalized, matching REST response shape)

2. **Given** `internal/manager/http_client.go` defines `WineTapHTTPClient`
   **When** methods are called
   **Then** methods exist for all 27 routes per `docs/rest-api-contracts.md`
   **And** the struct wraps `*http.Client` with `baseURL`

3. **Given** error responses from the phone server
   **When** the client receives a non-2xx response
   **Then** errors are parsed into structured `APIError{Code, Message}` implementing `error`

4. **Given** the complete implementation
   **When** `go build ./...` is run
   **Then** the manager builds without errors

## Tasks / Subtasks

- [x] Task 1: Create API type structs (AC: #1)
  - [x] Create `internal/manager/api_types.go`
  - [x] Define `Designation` struct: ID (int64), Name (string), Region (string), Description (string) — all `json:"snake_case"`
  - [x] Define `Domain` struct: ID (int64), Name (string), Description (string)
  - [x] Define `Cuvee` struct: ID (int64), Name (string), DomainID (int64), DesignationID (int64), Color (int32), Description (string), DomainName (string), DesignationName (string), Region (string) — response-only denormalized fields included
  - [x] Define `Bottle` struct: ID (int64), TagID (*string, omitempty), CuveeID (int64), Vintage (int32), Description (string), PurchasePrice (*float64, omitempty), DrinkBefore (*int32, omitempty), AddedAt (string), ConsumedAt (*string, omitempty), Cuvee (Cuvee)
  - [x] Define `APIError` struct: Code (string), Message (string) with `Error() string` method
  - [x] Define request structs for create/update operations: `CreateDesignation`, `CreateDomain`, `CreateCuvee`, `CreateBottle`, `UpdateBottle`, `BulkUpdateRequest`, `SetTagRequest`, `ConsumeRequest`, `ScanRequest`, `CompletionParams`

- [x] Task 2: Create HTTP client (AC: #2, #3)
  - [x] Create `internal/manager/http_client.go`
  - [x] Define `WineTapHTTPClient` struct with `baseURL string` and `http *http.Client`
  - [x] Implement `NewWineTapHTTPClient(baseURL string) *WineTapHTTPClient`
  - [x] Implement private helpers: `doJSON(method, path, body) (*http.Response, error)`, `decodeResponse[T](resp) (T, error)`, `checkError(resp) error`
  - [x] Designation methods: `ListDesignations()`, `AddDesignation(CreateDesignation)`, `UpdateDesignation(int64, CreateDesignation)`, `DeleteDesignation(int64)`
  - [x] Domain methods: `ListDomains()`, `AddDomain(CreateDomain)`, `UpdateDomain(int64, CreateDomain)`, `DeleteDomain(int64)`
  - [x] Cuvee methods: `ListCuvees()`, `AddCuvee(CreateCuvee)`, `UpdateCuvee(int64, CreateCuvee)`, `DeleteCuvee(int64)`
  - [x] Bottle methods: `ListBottles(includeConsumed bool)`, `GetBottle(int64)`, `GetBottleByTagID(string)`, `AddBottle(CreateBottle)`, `ConsumeBottle(string)`, `UpdateBottle(int64, map[string]any)`, `BulkUpdateBottles([]int64, map[string]any)`, `DeleteBottle(int64)`, `SetBottleTagID(int64, string)`
  - [x] Completions: `GetCompletions(field, prefix string)`
  - [x] Scan coordination: `RequestScan(mode string)`, `GetScanResult()`, `CancelScan()`
  - [x] Backup: `GetBackup() (io.ReadCloser, error)`, `Restore(io.Reader) error`

- [x] Task 3: Create tests (AC: #1, #2, #3)
  - [x] Create `internal/manager/http_client_test.go`
  - [x] Test JSON marshaling/unmarshaling of all entity structs (verify snake_case tags, nullable fields omitted when nil, present when set)
  - [x] Test `APIError.Error()` formatting
  - [x] Test client methods using `httptest.NewServer` — mock phone responses, verify correct HTTP method, path, request body, and response parsing
  - [x] Test error handling: 400, 404, 409, 412 responses parsed into `APIError`

- [x] Task 4: Verify build (AC: #4)
  - [x] Run `go build ./...`
  - [x] Run `go vet ./...`
  - [x] Run `go test ./internal/manager/...`

### Review Findings

- [x] [Review][Decision] Add `context.Context` to all HTTP methods now vs defer to Story 6.4 — fixed: all 27 public methods now accept `context.Context`; `doJSON`/`doJSONWith` use `http.NewRequestWithContext`
- [x] [Review][Patch] 410 scan cancel response shape mismatch: `GetScanResult` decodes 410 body as `APIError` but contract returns `{"status":"cancelled"}` — fixed: 410 returns `ErrScanCancelled` sentinel directly [api_types.go:10]
- [x] [Review][Patch] Double `resp.Body.Close()` on error path: `checkError` defers close on non-2xx, but Delete/RequestScan/CancelScan callers also defer close unconditionally — fixed: `checkError` reads+closes body inline on error, no defer [http_client.go:63]
- [x] [Review][Patch] Backup/Restore use 10s timeout which is exactly NFR16's budget — fixed: `GetBackup`/`Restore` routed through `longPollHTTP` (35s) [http_client.go:351]
- [x] [Review][Defer] `BulkUpdateBottles` with empty/nil IDs sends `{"ids":null,...}` — server behavior unspecified for zero IDs [http_client.go:244] — deferred, no client-side guard required by spec
- [x] [Review][Defer] Null vs `[]` on list endpoints — if server ever returns JSON `null` instead of `[]`, callers get nil slice; low risk given Dart/drift always returns arrays [http_client.go:87]

## Dev Notes

### Key Architecture Decisions

- **Clean break from proto types**: new Go structs with `json:"snake_case"` tags — do NOT reuse proto-generated types from `gen/winetap/v1/`
- **No new dependencies**: use `net/http` and `encoding/json` from stdlib
- **This story creates the client only** — screens are NOT rewired in this story (that's Story 6.3). The client must compile and be testable independently.
- **The `v1.WineTapClient` gRPC interface stays untouched** — it's still used by screens until Story 6.3 replaces it

### Struct Naming Convention

The HTTP client struct should be named `WineTapHTTPClient` (not `WineTapClient`) to avoid collision with the existing `v1.WineTapClient` gRPC interface that screens still reference until Story 6.3.

### REST API Contract Reference

All 27 routes are documented in `docs/rest-api-contracts.md`. The client must implement methods for every route. Key conventions:
- All JSON uses `snake_case` field names
- Nullable fields: omitted from JSON when nil (Go: `*type` + `omitempty`)
- Partial updates on PUT: absent = don't update, explicit null = clear. Use `map[string]any` for the `UpdateBottle` method to support this pattern.
- Tag ID normalization is server-side — client sends raw strings
- Timestamps are RFC 3339 strings (not `time.Time` — keep as `string` to match REST contract)

### Error Handling Pattern

```go
type APIError struct {
    Code    string `json:"error"`
    Message string `json:"message"`
}

func (e *APIError) Error() string {
    return fmt.Sprintf("%s: %s", e.Code, e.Message)
}
```

Parse non-2xx responses into `APIError`. For network/transport errors, return them directly (the caller in Story 6.3 will decide how to display them).

### HTTP Client Pattern

```go
type WineTapHTTPClient struct {
    baseURL string
    http    *http.Client
}

func NewWineTapHTTPClient(baseURL string) *WineTapHTTPClient {
    return &WineTapHTTPClient{
        baseURL: strings.TrimRight(baseURL, "/"),
        http:    &http.Client{Timeout: 10 * time.Second},
    }
}
```

For long-poll methods (`GetScanResult`), use a separate timeout (35s) or no timeout, since the server holds the connection for up to 30s.

### Scan Coordination Methods

```go
func (c *WineTapHTTPClient) RequestScan(mode string) error       // POST /scan/request
func (c *WineTapHTTPClient) GetScanResult() (string, error)      // GET /scan/result — returns tag_id or "" on timeout
func (c *WineTapHTTPClient) CancelScan() error                   // POST /scan/cancel
```

`GetScanResult` must handle three response cases:
- 200 → tag scanned, return tag_id
- 204 → timeout, return empty string + nil error (caller retries)
- 410 → cancelled, return specific error or empty + error

### Existing Codebase Context

**Current gRPC interface** (`gen/winetap/v1/winetap_grpc.pb.go`): `v1.WineTapClient` has these method groups:
- Designations: List, Add, Update, Delete
- Domains: List, Add, Update, Delete
- Cuvees: List, Add, Update, Delete
- Bottles: Add, Consume, List, Get, GetByTagId, Update, BulkUpdate, SetTagId, Delete
- Completions: GetCompletions
- INAO: RefreshDesignations (NOT in REST API — deferred)
- Scan: CoordinateScan (bidi stream → replaced by 3 HTTP endpoints)
- Events: PushEvent, SubscribeEvents, AcknowledgeEvent (deferred — NOT in REST API)

**Methods NOT to implement in HTTP client** (deferred/removed from v2 REST):
- `RefreshDesignations` — INAO refresh not in REST contract
- `PushEvent`, `SubscribeEvents`, `AcknowledgeEvent` — events deferred post-MVP

**Go module**: `go.mod` already has `net/http` (stdlib) and `encoding/json` (stdlib). No new deps needed.

### Type Reference

| JSON type | Go type | Notes |
|-----------|---------|-------|
| int (required) | `int64` | IDs, foreign keys |
| int (required, small) | `int32` | vintage, color, drink_before |
| float (nullable) | `*float64` | purchase_price |
| string (required) | `string` | name, description |
| string (nullable) | `*string` | tag_id, consumed_at |
| int (nullable) | `*int32` | drink_before |

### What NOT to Do

- Do NOT modify `screen/ctx.go` — screens are rewired in Story 6.3
- Do NOT modify `manager.go` — HTTP client wiring happens in Story 6.3
- Do NOT remove gRPC code or proto imports — that happens when screens are fully migrated
- Do NOT implement mDNS discovery — that's Story 6.2
- Do NOT modify `nfc_scanner.go` — that's Story 6.4
- Do NOT add any new Go module dependencies — stdlib `net/http` + `encoding/json` suffice
- Do NOT use `time.Time` for timestamps — keep as `string` to match REST contract

### Previous Story Intelligence (Story 5.1)

Key learnings from the drift database story:
- `drift_flutter` version had to be bumped from ^0.2.0 to ^0.3.0 for compatibility
- FK enforcement required explicit `PRAGMA foreign_keys = ON`
- `consumeBottle` had a race condition that was fixed in review — the HTTP client's `ConsumeBottle` just sends a POST, so no parallel concern here
- `BottleWithCuvee` toJson includes nested cuvee with denormalized fields — the Go `Bottle` struct must match this shape exactly
- Nullable fields omitted when null — Go `omitempty` handles this

### File Structure

```
internal/manager/
├── api_types.go          # NEW — Go structs with json:"snake_case" tags
├── http_client.go        # NEW — WineTapHTTPClient wrapping net/http
├── http_client_test.go   # NEW — unit tests with httptest
├── manager.go            # UNCHANGED in this story
├── scanner.go            # UNCHANGED
├── rfid_scanner.go       # UNCHANGED
├── nfc_scanner.go        # UNCHANGED (rewritten in Story 6.4)
├── config.go             # UNCHANGED
└── screen/               # UNCHANGED (rewired in Story 6.3)
```

### References

- [Source: docs/rest-api-contracts.md] — all 27 routes with exact JSON shapes, error codes, conventions
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Go Manager HTTP Client Pattern] — WineTapClient struct, api_types.go pattern
- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 6.1] — acceptance criteria
- [Source: gen/winetap/v1/winetap_grpc.pb.go] — existing gRPC client interface (22 methods + 1 stream)
- [Source: internal/manager/screen/ctx.go] — current Ctx passing v1.WineTapClient to screens
- [Source: internal/manager/nfc_scanner.go] — current bidi stream pattern being replaced

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- No issues encountered — stdlib net/http + encoding/json sufficient, no new deps
- Generic `decodeResponse[T]` helper used for type-safe response parsing
- Separate `longPollHTTP` client with 35s timeout for scan result polling (server holds 30s)
- `url.PathEscape` used for tag IDs in URL paths (GetBottleByTagID)

### Completion Notes List

- Created `api_types.go` with 4 entity structs (Designation, Domain, Cuvee, Bottle), APIError, 8 request/response types — all json:"snake_case" tags
- Created `http_client.go` with WineTapHTTPClient covering all 27 REST routes: 4 designation, 4 domain, 4 cuvee, 9 bottle, 1 completions, 3 scan, 2 backup/restore
- Nullable fields use pointer types + omitempty (TagID, PurchasePrice, DrinkBefore, ConsumedAt)
- Partial update via map[string]any for UpdateBottle
- Created 31 tests covering: JSON serialization (6), APIError (2), client methods (19), error handling (4)
- All 31 new + all existing tests pass, go build/vet clean, zero regressions

### File List

- internal/manager/api_types.go (new — entity structs, APIError, request/response types)
- internal/manager/http_client.go (new — WineTapHTTPClient with all 27 route methods)
- internal/manager/http_client_test.go (new — 31 tests)

### Change Log

- 2026-04-01: Implemented Story 6.1 — Go HTTP client and API types for phone REST API
