# Story 6.4: Manager NFCScanner Stub for HTTP

Status: done

## Story

As a developer,
I want the NFCScanner in the manager to be prepared for HTTP polling,
So that the intake flow (Epic 7) has a foundation.

## Acceptance Criteria

1. **Given** `internal/manager/nfc_scanner.go` rewritten for HTTP
   **When** `StartScan` is called
   **Then** it POSTs to `/scan/request` on the phone with the correct mode (`single`/`continuous`)
   **And** a goroutine starts that long-polls `GET /scan/result`
   **And** on 200 response with `tag_id`, the `OnTagScanned` callback is fired on the Qt main thread
   **And** on 204 (timeout), the poller loops and retries automatically (manager side retry)

2. **Given** `StopScan` is called
   **When** a scan is in progress
   **Then** it POSTs to `/scan/cancel` on the phone
   **And** the long-poll goroutine exits cleanly

3. **Given** `GET /scan/result` returns 410 (cancelled by phone) during the poll
   **When** the goroutine receives this
   **Then** the goroutine exits cleanly without firing the callback
   **And** no error is logged (cancellation is normal flow)

4. **Given** the phone is unreachable
   **When** `StartScan` or `StopScan` is called
   **Then** errors are logged with slog (not fatal)
   **And** the Scanner interface contract is preserved — UI doesn't crash

5. **Given** the complete implementation
   **When** `go build ./...` is run
   **Then** `nfc_scanner.go` has no remaining `v1 "winetap/gen/winetap/v1"` import
   **And** the `Scanner` interface compile-time check passes (`var _ Scanner = (*NFCScanner)(nil)`)
   **And** manager builds without errors

6. **Given** result retrieval
   **When** the manager is in `single` mode
   **Then** after one successful tag scan, the poller stops (does not loop)
   **When** in `continuous` mode
   **Then** after each tag scan (200 response), the poller immediately re-polls (no restart needed)

## Tasks / Subtasks

- [x] Task 1: Rewrite `NFCScanner` struct and constructor (AC: #5)
  - [x] 1.1 Replace `client v1.WineTapClient` field with `httpClient *client.WineTapHTTPClient`
  - [x] 1.2 Replace `stream v1.WineTap_CoordinateScanClient` field with `cancel context.CancelFunc` (goroutine cancel)
  - [x] 1.3 Add `mode ScanMode` field to track current scan mode
  - [x] 1.4 Update `NewNFCScanner(httpClient *client.WineTapHTTPClient, log *slog.Logger) *NFCScanner`
  - [x] 1.5 Remove `v1` import, add `winetap/internal/client` import
  - [x] 1.6 Keep compile-time check: `var _ Scanner = (*NFCScanner)(nil)`

- [x] Task 2: Implement `StartScan` (AC: #1, #6)
  - [x] 2.1 Under `mu` lock: if a goroutine is already running, call `StopScan()` first (idempotent restart)
  - [x] 2.2 Map `ScanMode` to string: `ScanModeSingle` → `"single"`, `ScanModeContinuous` → `"continuous"`
  - [x] 2.3 Call `n.httpClient.RequestScan(modeStr)` — POST `/scan/request`
  - [x] 2.4 If error: log with slog, return error (don't start goroutine)
  - [x] 2.5 Create `ctx, cancel := context.WithCancel(context.Background())`, store `cancel`
  - [x] 2.6 Start `go n.pollLoop(ctx, mode)` goroutine
  - [x] 2.7 Log: `"NFC scan: request sent"` with mode

- [x] Task 3: Implement `pollLoop` goroutine (AC: #1, #3, #4, #6)
  - [x] 3.1 Loop until `ctx.Done()`:
    - Call `n.httpClient.GetScanResult()` — blocks up to 35s (long poll)
    - On `tagID != ""` (200 response): fire `mainthread.Start(func() { cb(tagID) })`; if `single` mode → return (stop loop); if `continuous` mode → continue loop immediately
    - On `tagID == ""` and `err == nil` (204 timeout): log debug `"NFC scan: poll timeout, retrying"`, continue loop
    - On `err` containing "cancelled" or being a `*client.APIError{Code: "cancelled"}` (410): log info `"NFC scan: cancelled"`, return
    - On other `err`: log error `"NFC scan: poll error"`, return
  - [x] 3.2 On ctx cancellation (`ctx.Err() != nil`): exit loop silently (normal shutdown)

- [x] Task 4: Implement `StopScan` (AC: #2)
  - [x] 4.1 Under `mu` lock: if no goroutine running (`cancel == nil`), return nil
  - [x] 4.2 Call `n.cancel()` to stop the poll goroutine
  - [x] 4.3 Set `n.cancel = nil`
  - [x] 4.4 Call `n.httpClient.CancelScan()` — POST `/scan/cancel` (best-effort, log error but don't return it)
  - [x] 4.5 Log: `"NFC scan: scan stopped"`

- [x] Task 5: Keep `Close()` (AC: #5)
  - [x] 5.1 `Close()` just calls `StopScan()` — no stream to close anymore
  - [x] 5.2 Remove old `closeStreamLocked()` helper entirely

- [x] Task 6: Wire updated `NFCScanner` into `manager.go` (AC: #5)
  - [x] 6.1 In `manager.go` (after story 6.3 removes gRPC client): `NewNFCScanner(httpClient, log)` where `httpClient` is the `*client.WineTapHTTPClient` created in story 6.2
  - [x] 6.2 Remove the "NFC not yet available" fallback warning added by story 6.3
  - [x] 6.3 The `NFCScanner.Close()` method can stay in `manager.Close()` for cleanup
  - [x] 6.4 Keep NFC/RFID hot-swap in `SaveSettings` — same logic, just `NewNFCScanner(httpClient, log)` instead of the gRPC version

- [x] Task 7: Tests (AC: #1–#6)
  - [x] 7.1 Create `internal/manager/nfc_scanner_test.go`
  - [x] 7.2 Test `StartScan` happy path: mock HTTP server returns 201 on POST /scan/request, 200 with tag_id on GET /scan/result; verify `OnTagScanned` callback fires
  - [x] 7.3 Test 204 retry: first GET returns 204, second returns 200; verify callback fires after retry
  - [x] 7.4 Test `StopScan`: verify POST /scan/cancel is sent; verify poll goroutine exits
  - [x] 7.5 Test 410 cancelled: GET /scan/result returns 410; verify callback NOT fired, goroutine exits cleanly
  - [x] 7.6 Test single mode: callback fires once and poller stops (no second GET after 200)
  - [x] 7.7 Test continuous mode: after 200, poller immediately retries (second GET issued)

## Dev Notes

### Architecture Context

**v2 role reversal:** In v1, `NFCScanner` maintained a gRPC bidi stream (`CoordinateScan`) to the RPi server, which relayed between manager and phone. In v2, the phone IS the server. The manager talks directly to the phone via HTTP.

Old flow: `manager → gRPC stream → RPi server → bidi stream → phone`
New flow: `manager → POST /scan/request → phone`, `manager → GET /scan/result (long poll) → phone`

The HTTP client methods `RequestScan`, `GetScanResult`, `CancelScan` were implemented in Story 6.1 (`internal/client/http_client.go`). This story just wires them into the `Scanner` interface implementation.

### Dependency: Story 6.3 Must Be Done First

Story 6.3 moves `api_types.go` and `http_client.go` to `internal/client/` package. This story depends on that. If 6.3 is not complete:
- Import `WineTapHTTPClient` from `internal/manager` (old location)
- Change to `internal/client` once 6.3 is done

Story 6.3 also stubs out NFC mode with a warning log. This story removes that stub.

### NFCScanner Rewrite — Complete New Implementation

The new `nfc_scanner.go` is significantly simpler than the old bidi stream implementation:

```go
package manager

import (
    "context"
    "log/slog"
    "strings"
    "sync"

    "github.com/mappu/miqt/qt6/mainthread"

    "winetap/internal/client"
)

type NFCScanner struct {
    mu         sync.Mutex
    httpClient *client.WineTapHTTPClient
    cancel     context.CancelFunc
    callback   func(tagID string)
    log        *slog.Logger
}

var _ Scanner = (*NFCScanner)(nil)

func NewNFCScanner(httpClient *client.WineTapHTTPClient, log *slog.Logger) *NFCScanner {
    return &NFCScanner{httpClient: httpClient, log: log}
}

func (n *NFCScanner) OnTagScanned(callback func(tagID string)) {
    n.mu.Lock()
    defer n.mu.Unlock()
    n.callback = callback
}

func (n *NFCScanner) StartScan(_ context.Context, mode ScanMode) error {
    n.mu.Lock()
    defer n.mu.Unlock()

    // Stop any active scan first
    if n.cancel != nil {
        n.cancel()
        n.cancel = nil
    }

    modeStr := "single"
    if mode == ScanModeContinuous {
        modeStr = "continuous"
    }

    if err := n.httpClient.RequestScan(modeStr); err != nil {
        n.log.Error("NFC scan: request failed", "error", err)
        return err
    }
    n.log.Info("NFC scan: request sent", "mode", modeStr)

    ctx, cancel := context.WithCancel(context.Background())
    n.cancel = cancel
    go n.pollLoop(ctx, mode)
    return nil
}

func (n *NFCScanner) StopScan() error {
    n.mu.Lock()
    defer n.mu.Unlock()
    if n.cancel == nil {
        return nil
    }
    n.cancel()
    n.cancel = nil
    if err := n.httpClient.CancelScan(); err != nil {
        n.log.Debug("NFC scan: cancel failed", "error", err)
    }
    n.log.Info("NFC scan: scan stopped")
    return nil
}

func (n *NFCScanner) Close() {
    n.StopScan() //nolint:errcheck
}

func (n *NFCScanner) pollLoop(ctx context.Context, mode ScanMode) {
    for {
        if ctx.Err() != nil {
            return
        }

        tagID, err := n.httpClient.GetScanResult()
        if err != nil {
            // 410 cancelled — normal flow
            if isCancelledErr(err) {
                n.log.Info("NFC scan: cancelled by phone")
                return
            }
            n.log.Error("NFC scan: poll error", "error", err)
            return
        }

        if tagID == "" {
            // 204 timeout — retry
            n.log.Debug("NFC scan: poll timeout, retrying")
            continue
        }

        // 200 — tag received
        n.log.Info("NFC scan: tag received", "tag_id", tagID)
        n.mu.Lock()
        cb := n.callback
        n.mu.Unlock()
        if cb != nil {
            tid := tagID
            mainthread.Start(func() { cb(tid) })
        }

        if mode == ScanModeSingle {
            return // done — single scan complete
        }
        // Continuous: loop immediately for next tag
    }
}

func isCancelledErr(err error) bool {
    if apiErr, ok := err.(*client.APIError); ok {
        return apiErr.Code == "cancelled"
    }
    return strings.Contains(err.Error(), "cancelled")
}
```

### `GetScanResult` Return Convention (from Story 6.1)

Per story 6.1 completion notes, `GetScanResult()` returns:
- `(tagID string, err error)` where:
  - `tagID != ""`, `err == nil` → 200 — tag scanned successfully
  - `tagID == ""`, `err == nil` → 204 — timeout, retry
  - `err != nil` with `APIError{Code: "cancelled"}` → 410 — scan cancelled

The poll loop handles all three cases. The 35s client timeout on `GetScanResult` is set in the HTTP client (longer than the 30s server timeout to account for network latency).

### Scanner Interface Contract

The `Scanner` interface in `scanner.go` must be preserved exactly:

```go
type Scanner interface {
    OnTagScanned(callback func(tagID string))
    StartScan(ctx context.Context, mode ScanMode) error
    StopScan() error
}
```

The old `NFCScanner` also had `Close() error` (used in `manager.go` to clean up the bidi stream). The new version still has `Close()` (calls `StopScan`) for API compatibility with the manager's shutdown path.

### Thread Safety

Same pattern as `RFIDScanner` and old `NFCScanner`:
- `mu` protects `callback`, `cancel`
- `pollLoop` runs in a goroutine (not under lock except when reading `callback`)
- Qt callbacks dispatched via `mainthread.Start()` — never called under lock
- `ctx.Cancel()` signals the goroutine to exit; the goroutine checks `ctx.Err()` at loop top

### Testing Approach

Use `httptest.NewServer` (same as story 6.1 tests) to mock phone responses. The test server handles:
- `POST /scan/request` → 201
- `GET /scan/result` → configurable: 200+tag, 204, or 410

Since `GetScanResult` blocks on the HTTP call, tests can control sequencing via a channel in the test server handler.

Example test shape:
```go
func TestNFCScannerSingle(t *testing.T) {
    // Test server: immediate 200 with tag_id on first GET
    results := make(chan string, 1)
    results <- `{"status":"resolved","tag_id":"04AABBCC"}`
    ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        switch r.URL.Path {
        case "/scan/request":
            w.WriteHeader(http.StatusCreated)
            fmt.Fprintln(w, `{"status":"requested","mode":"single"}`)
        case "/scan/result":
            body := <-results
            w.Header().Set("Content-Type", "application/json")
            fmt.Fprintln(w, body)
        }
    }))
    defer ts.Close()

    httpClient := client.NewWineTapHTTPClient(ts.URL)
    scanner := NewNFCScanner(httpClient, slog.Default())

    got := make(chan string, 1)
    scanner.OnTagScanned(func(tagID string) { got <- tagID })
    require.NoError(t, scanner.StartScan(context.Background(), ScanModeSingle))

    select {
    case tagID := <-got:
        assert.Equal(t, "04AABBCC", tagID)
    case <-time.After(2 * time.Second):
        t.Fatal("timeout waiting for tag")
    }
}
```

**Note:** `mainthread.Start()` dispatches to Qt main thread. In tests (no Qt event loop), this call will block forever. Use a mock or skip mainthread dispatch in tests. Option: extract the callback dispatch to a `dispatch func(func())` field, defaulting to `mainthread.Start` in production and direct call in tests.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `internal/manager/nfc_scanner.go` | REWRITE | HTTP-based NFCScanner (replaces gRPC bidi stream) |
| `internal/manager/nfc_scanner_test.go` | CREATE | Unit tests with httptest mock server |
| `internal/manager/manager.go` | MODIFY | Wire `NewNFCScanner(httpClient, log)` — remove "NFC not available" stub |

### Anti-Patterns to Avoid

- Do NOT use `print()` — slog only (`log.Info`, `log.Debug`, `log.Error`)
- Do NOT call Qt callbacks under `mu` lock — deadlock risk; copy callback, release lock, then dispatch
- Do NOT use a hardcoded timeout for `GetScanResult` — it uses the 35s client timeout set in Story 6.1
- Do NOT import `v1 "winetap/gen/winetap/v1"` — this story removes all gRPC from NFCScanner
- Do NOT make `pollLoop` retry on phone-unreachable errors — return and let the manager's health check handle recovery (story 6.2)
- Do NOT block `StartScan` waiting for a result — the poll is async in a goroutine; `StartScan` returns immediately after POST

### Project Structure Notes

- Only `nfc_scanner.go` is rewritten; `scanner.go` and `rfid_scanner.go` are untouched
- No new dependencies — `internal/client` package was established in story 6.3
- The old `Close()` on `NFCScanner` was called by `manager.go` — keep it (calls `StopScan`)

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 6.4] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Manager Architecture] — NFCScanner rewritten for HTTP polling
- [Source: docs/rest-api-contracts.md#Scan Coordination Endpoints] — POST /scan/request, GET /scan/result (long poll), POST /scan/cancel; 200/204/410 semantics
- [Source: _bmad-output/implementation-artifacts/6-1-go-http-client-and-api-types.md] — `WineTapHTTPClient.RequestScan`, `GetScanResult`, `CancelScan` signatures and return conventions
- [Source: internal/manager/nfc_scanner.go] — old gRPC bidi stream implementation (being replaced)
- [Source: internal/manager/rfid_scanner.go] — thread safety pattern with `mu`, `mainthread.Start()`, `stopFn context.CancelFunc`
- [Source: internal/manager/scanner.go] — Scanner interface contract to preserve

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — clean build and all tests passed on first attempt.

### Completion Notes List

- Rewrote `nfc_scanner.go` entirely: gRPC bidi stream replaced by HTTP long-poll pattern using `client.WineTapHTTPClient.RequestScan/GetScanResult/CancelScan`.
- Added `dispatch func(func())` field (defaults to `mainthread.Start`) to enable testability without Qt event loop — tests set it to a synchronous direct caller.
- Used `client.ErrScanCancelled` sentinel (not `*APIError{Code:"cancelled"}`) as the 410 indicator, matching the http_client implementation.
- Context cancellation check is done both at loop top (`ctx.Err() != nil`) and after `GetScanResult` returns an error, ensuring silent exit on StopScan in all timing scenarios.
- Added `nfcScanner *NFCScanner` field to `Manager` struct; both `rfidScanner` and `nfcScanner` are closed in `Manager.Close()`.
- NFC scanner creation moved after `httpClient` creation in `New()` (previously scanner selection was before httpClient).
- All 6 NFC scanner tests pass; full regression suite passes.

### File List

- `internal/manager/nfc_scanner.go` — rewritten (HTTP-based NFCScanner)
- `internal/manager/nfc_scanner_test.go` — created (6 tests with httptest mock server)
- `internal/manager/manager.go` — wired `NewNFCScanner(httpClient, log)`; removed NFC stub warnings; added `nfcScanner` field; `Close()` closes both scanners

## Review Findings

**Reviewed:** 2026-04-01 | **Model:** claude-sonnet-4-6
**Summary:** 0 decision-needed, 5 patch, 3 defer, 4 dismissed

### Patch (all applied — 2026-04-01)

**[HIGH] P1 — `StartScan` holds `mu` during blocking HTTP call**
- Location: `nfc_scanner.go` `StartScan` — `n.httpClient.RequestScan(...)` called while `mu` is held
- Risk: Any concurrent call to `StopScan`, `OnTagScanned`, or `pollLoop` callback delivery will block for the full HTTP round-trip (up to 35s)
- Fix: Release lock before `RequestScan`, re-acquire before storing `cancel` and starting goroutine; or restructure to call `RequestScan` outside the lock entirely

**[MED] P2 — Use `errors.Is` for `ErrScanCancelled` check**
- Location: `nfc_scanner.go` `pollLoop` — `err == client.ErrScanCancelled`
- Risk: If `GetScanResult` ever wraps the error (`fmt.Errorf("...: %w", ErrScanCancelled)`), the equality check fails silently and the error is logged as a poll error instead of a clean exit
- Fix: `errors.Is(err, client.ErrScanCancelled)`

**[LOW] P3 — `TestNFCScanner_410Cancelled` uses `time.Sleep`**
- Location: `nfc_scanner_test.go:183` — `time.Sleep(200 * time.Millisecond)`
- Risk: Flaky under load; timing-dependent rather than behavioural assertion
- Fix: Add a `goroutineDone chan struct{}` that the dispatch function closes; wait on it with a timeout

**[LOW] P4 — No test for idempotent restart (double `StartScan`)**
- Missing: Test that calls `StartScan` twice, verifies the second call cancels the first (no duplicate callbacks, no panic)
- Fix: Add `TestNFCScanner_IdempotentRestart` test

**[LOW] P5 — `TestNFCScanner_StopScan` doesn't verify goroutine exit**
- Location: `nfc_scanner_test.go TestNFCScanner_StopScan` — only verifies `/scan/cancel` was sent, not that the poll goroutine actually exited
- Fix: After `StopScan` returns, confirm the poll goroutine is gone (e.g. via a `goroutineDone` channel closed by the dispatch function, or by verifying `scanner.cancel == nil`)

### Deferred (recorded in deferred-work.md)

- **[HIGH] `m.scanner` hot-swap race in `SaveSettings`** — `m.scanner` field is read by scan callbacks (Qt main thread) and written by `SaveSettings` (also Qt main thread per Qt threading model, but no explicit mutex); pre-existing from story 6.3, not introduced here
- **[MED] `StartScan` ignores caller context** — `_ context.Context` discards the caller's ctx; intentional for consistency with `RFIDScanner` pattern
- **[MED] 204 poll loop has no backoff** — `continue` immediately re-polls on 204; server guarantees 30s hold per contract so acceptable; would need revisiting if server contract changes

### Dismissed

- Stale goroutine delivers callback after restart — false positive; Go net/http returns error on context cancel, not a tag result
- Continuous mode missing `/scan/request` re-issue between scans — spec explicitly states "no restart needed" for continuous mode
- `StopScan` sends spurious `/scan/cancel` when RFID mode active — `cancel == nil` guard prevents this
- AC3 `Info` log on 410 violates "no error logged" — misread; AC says no `Error`-level log, `Info` is correct
