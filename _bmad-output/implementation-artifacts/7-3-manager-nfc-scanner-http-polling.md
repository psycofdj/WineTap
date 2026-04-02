# Story 7.3: Manager NFCScanner HTTP Polling

Status: done

## Story

As a user,
I want the manager to request scans and receive tag UIDs from the phone over HTTP,
So that I can register bottles at the desktop while scanning with the phone.

## Acceptance Criteria

1. **Given** `nfc_scanner.go` fully wired for HTTP
   **When** a scan is initiated from the manager
   **Then** `StartScan(single)` -> POST /scan/request -> long-poll GET /scan/result -> OnTagScanned(tagId)
   **And** `StartScan(continuous)` -> POST /scan/request with mode=continuous -> repeated long-polls
   **And** `StopScan` -> POST /scan/cancel
   **And** long-poll timeout (204) -> automatic retry
   **And** phone unreachable -> error notification, form data preserved (FR31, NFR10)
   **And** Scanner interface contract preserved -- RFID/NFC toggle still works (FR33-35)
   **And** manager inventory form populates tag field on scan result

## Tasks / Subtasks

- [x] Task 1: Add `OnScanError` callback to Scanner (AC: #1 — FR31)
  - [x] 1.1 Add `OnScanError func(callback func(err error))` field to `screen.Scanner` struct
  - [x] 1.2 Add `errCallback func(err error)` field to `NFCScanner` struct
  - [x] 1.3 Add `OnScanError(callback func(err error))` method to `NFCScanner`
  - [x] 1.4 In `pollLoop`: fire `errCallback` via `dispatch` on non-cancelled, non-context error exit
  - [x] 1.5 Wire in `manager.go` `makeCtx()`: `OnScanError: m.nfcScanner.OnScanError`
  - [x] 1.6 RFID no-op: not needed — `OnScanError` wired directly to `nfcScanner`

- [x] Task 2: Handle StartScan errors in inventory form (AC: #1 — FR30, FR31)
  - [x] 2.1 `openAddForm()`: check error, exit waiting, show QMessageBox, load empty form
  - [x] 2.2 `addBottleFrom(template)`: check error, preserve template data (FR31), show QMessageBox
  - [x] 2.3 `onSearchByTag()`: check error, exit waiting, hide right panel, show QMessageBox

- [x] Task 3: Handle async poll errors in inventory form (AC: #1 — FR31, NFR10)
  - [x] 3.1 `OnScanError` registered at all 3 call sites
  - [x] 3.2 Error callback: `SetWaiting(false)`, show error via QMessageBox
  - [x] 3.3 `addBottleFrom`: error preserves template data via `loadBottle(template)`
  - [x] 3.4 Error callback dispatched on Qt main thread via `dispatch`

- [x] Task 4: Add error notification UI pattern (AC: #1 — FR30)
  - [x] 4.1 Error shown via QMessageBox_Warning (existing inventory pattern)
  - [x] 4.2 Message: "Téléphone inaccessible — entrez le tag manuellement ou réessayez."
  - [x] 4.3 Inline French strings (consistent with existing inventory.go)

- [x] Task 5: Update NFCScanner tests (AC: #1)
  - [x] 5.1 Test: poll error (500) fires `OnScanError` callback
  - [x] 5.2 Test: `StartScan` error does NOT fire `OnScanError`
  - [x] 5.3 Test: 410 cancelled does NOT fire `OnScanError`
  - [x] 5.4 Test: context cancel (StopScan) does NOT fire `OnScanError`

- [x] Task 6: Verify integration (AC: #1)
  - [x] 6.1 `go build ./...` passes
  - [x] 6.2 All existing tests pass (11 total)
  - [x] 6.3 New NFCScanner error tests pass (4 new)
  - [x] 6.4 Scanner struct change is additive — RFID toggle unaffected

## Dev Notes

### What's Already Done (Story 6.4) vs What's New

**Story 6.4 completed the NFCScanner HTTP implementation:**
- `nfc_scanner.go`: POST /scan/request, long-poll GET /scan/result, POST /scan/cancel
- Single mode: poll loop exits after one tag; continuous mode: loops for next tag
- 204 timeout: automatic retry; 410 cancelled: clean exit
- Wired into `manager.go` via `makeCtx()` -> `screen.Scanner` -> inventory form
- 6 tests in `nfc_scanner_test.go`

**This story adds the error handling layer that 6.4 deferred:**
1. When the phone is unreachable during a scan, the user gets feedback (not stuck in "waiting" forever)
2. Form data is preserved across scan failures (FR31)
3. `OnScanError` callback propagates async poll errors to the UI

### The Problem — Silent Failure on Phone Unreachable

Currently, all 3 scan call sites in `inventory.go` ignore the `StartScan` return error:

```go
// openAddForm — line 475
s.ctx.Scanner.StartScan(ScanModeSingle)  // error ignored!

// addBottleFrom — line 519
s.ctx.Scanner.StartScan(ScanModeSingle)  // error ignored!

// onSearchByTag — line 983
s.ctx.Scanner.StartScan(ScanModeSingle)  // error ignored!
```

And when the poll loop exits on error (phone goes unreachable mid-scan), the goroutine just logs and returns — no UI callback:

```go
// nfc_scanner.go pollLoop
n.log.Error("NFC scan: poll error", "error", err)
return  // UI stays in "waiting for scan" forever
```

### Solution: OnScanError Callback

Add an async error callback to the Scanner, mirroring the `OnTagScanned` pattern:

**In `screen/ctx.go`:**
```go
type Scanner struct {
    OnTagScanned func(callback func(tagID string))
    OnScanError  func(callback func(err error))  // NEW
    StartScan    func(mode ScanMode) error
    StopScan     func() error
    Simulate     func(tagID string)
}
```

**In `nfc_scanner.go`:**
```go
type NFCScanner struct {
    // ... existing fields ...
    errCallback func(err error)  // NEW
}

func (n *NFCScanner) OnScanError(callback func(err error)) {
    n.mu.Lock()
    defer n.mu.Unlock()
    n.errCallback = callback
}
```

**In pollLoop — fire error callback on non-normal exit:**
```go
// In pollLoop, after existing error handling:
if ctx.Err() != nil {
    return  // StopScan called — no error callback
}
if errors.Is(err, client.ErrScanCancelled) {
    n.log.Info("NFC scan: cancelled by phone")
    return  // cancellation is normal — no error callback
}
n.log.Error("NFC scan: poll error", "error", err)
// Fire error callback to UI
n.mu.Lock()
ecb := n.errCallback
disp := n.dispatch
n.mu.Unlock()
if ecb != nil {
    capturedErr := err
    disp(func() { ecb(capturedErr) })
}
return
```

**In `manager.go` `makeCtx()`:**
```go
Scanner: screen.Scanner{
    OnTagScanned: m.scanner.OnTagScanned,
    OnScanError:  m.nfcScanner.OnScanError,  // NEW — direct to nfcScanner
    StartScan: func(mode screen.ScanMode) error {
        return m.scanner.StartScan(context.Background(), ScanMode(mode))
    },
    StopScan: func() error { return m.scanner.StopScan() },
    Simulate: func(tagID string) {
        if m.rfidScanner != nil {
            m.rfidScanner.Simulate(tagID)
        }
    },
},
```

**Note on RFID:** `OnScanError` on the `Scanner` struct is wired to `nfcScanner.OnScanError` directly. When RFID mode is active, `m.scanner` points to `rfidScanner` which has no async poll — errors are synchronous from `StartScan`. The `OnScanError` field in the `Scanner` struct is only registered by NFC. If a future RFID async error path is needed, `RFIDScanner` can add the same method.

### Inventory Form Error Handling Pattern

**For `openAddForm()` — add-bottle flow:**
```go
func (s *InventoryScreen) openAddForm() {
    s.ts.TableView.ClearSelection()
    s.bottleForm.clearFields()
    s.bottleForm.SetWaiting(true)
    s.ts.SetSaveEnabled(false)
    s.ts.ShowRight("En attente d'un scan RFID…")

    s.ctx.Scanner.OnTagScanned(func(tagID string) {
        s.ctx.Scanner.StopScan()
        s.bottleForm.SetEPC(tagID)
        s.bottleForm.loadData(nil)
        s.bottleForm.SetWaiting(false)
        s.ts.SetSaveEnabled(false)
        s.ts.ShowRight("Nouvelle bouteille")
    })
    s.ctx.Scanner.OnScanError(func(err error) {  // NEW
        s.bottleForm.SetWaiting(false)
        s.bottleForm.loadData(nil)                // show empty form
        s.ts.ShowRight("Nouvelle bouteille")
        s.ctx.Log.Error("scan error during add", "error", err)
        qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
    })
    if err := s.ctx.Scanner.StartScan(ScanModeSingle); err != nil {  // CHECK ERROR
        s.bottleForm.SetWaiting(false)
        s.bottleForm.loadData(nil)
        s.ts.ShowRight("Nouvelle bouteille")
        s.ctx.Log.Error("scan start failed", "error", err)
        qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
    }
}
```

**For `addBottleFrom(template)` — template copy flow (FR31 critical):**
```go
// Same pattern but preserve template data on error:
if err := s.ctx.Scanner.StartScan(ScanModeSingle); err != nil {
    s.bottleForm.SetWaiting(false)
    s.bottleForm.loadData(func() {
        s.bottleForm.loadBottle(template)    // PRESERVE template data (FR31)
        s.bottleForm.editBottleID = 0
    })
    s.ts.ShowRight("Nouvelle bouteille (copie)")
    qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
}
```

### Thread Safety — Same Pattern as OnTagScanned

The error callback is dispatched via `dispatch` (defaults to `mainthread.Start`), ensuring it runs on the Qt main thread. The `mu` lock is NOT held when the callback fires — the callback pointer is copied under lock, then called outside:

```go
n.mu.Lock()
ecb := n.errCallback
disp := n.dispatch
n.mu.Unlock()
if ecb != nil {
    disp(func() { ecb(capturedErr) })
}
```

This is identical to how `OnTagScanned` works in the existing code.

### Scanner Interface — NOT Changed

The `Scanner` interface in `scanner.go` is NOT modified. `OnScanError` is added to the `screen.Scanner` struct (function fields) and to `NFCScanner` (concrete type). This preserves the clean interface contract and avoids touching `RFIDScanner`.

### Testing — Error Callback Tests

Add to `nfc_scanner_test.go`:

```go
func TestNFCScanner_PollErrorFiresOnScanError(t *testing.T) {
    // Test server: request succeeds, result returns 500
    ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        switch r.URL.Path {
        case "/scan/request":
            w.WriteHeader(http.StatusCreated)
            fmt.Fprintln(w, `{"status":"requested","mode":"single"}`)
        case "/scan/result":
            w.WriteHeader(http.StatusInternalServerError)
            fmt.Fprintln(w, `{"error":"internal","message":"boom"}`)
        }
    }))
    defer ts.Close()

    scanner := newTestNFCScanner(ts)
    done := make(chan struct{})
    scanner.pollExitHook = func() { close(done) }

    gotErr := make(chan error, 1)
    scanner.OnScanError(func(err error) { gotErr <- err })
    scanner.OnTagScanned(func(tagID string) { t.Fatal("unexpected tag") })
    require.NoError(t, scanner.StartScan(context.Background(), ScanModeSingle))

    select {
    case err := <-gotErr:
        assert.Error(t, err)
    case <-time.After(2 * time.Second):
        t.Fatal("timeout waiting for error callback")
    }
    <-done // ensure goroutine exited
}
```

### Previous Story Intelligence

**From Story 6.4 (Manager NFCScanner Stub):**
- `dispatch func(func())` field enables testability — defaults to `mainthread.Start`, tests set to `syncDispatch`
- `pollExitHook func()` enables tests to wait for goroutine exit
- `errors.Is(err, client.ErrScanCancelled)` is the 410 check — sentinel from `internal/client`
- Code review applied P1 (lock not held during HTTP call) and P2 (`errors.Is` instead of `==`)
- 6 existing tests cover happy path, 204 retry, 410 cancel, single/continuous modes

**From Story 5.5 (Local Consume Flow):**
- Inventory form uses `SetWaiting(true/false)` to toggle between waiting-for-scan and form display
- `loadData(callback)` loads cuvee list then calls callback to fill fields
- `SetEPC(tagID)` sets the tag field

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `internal/manager/nfc_scanner.go` | MODIFY | Add `errCallback` field, `OnScanError` method, fire callback in pollLoop |
| `internal/manager/screen/ctx.go` | MODIFY | Add `OnScanError func(callback func(err error))` to Scanner struct |
| `internal/manager/screen/inventory.go` | MODIFY | Handle StartScan errors + register OnScanError at 3 call sites |
| `internal/manager/manager.go` | MODIFY | Wire OnScanError in makeCtx() |
| `internal/manager/nfc_scanner_test.go` | MODIFY | Add error callback tests (4 new tests) |

### Anti-Patterns to Avoid

- Do NOT modify the `Scanner` interface in `scanner.go` — add `OnScanError` only to `screen.Scanner` struct and `NFCScanner` concrete type
- Do NOT fire `OnScanError` on cancellation (410 or context cancel) — those are normal flow, not errors
- Do NOT fire `OnScanError` under `mu` lock — copy callback, release lock, then dispatch (deadlock prevention)
- Do NOT use `print()` — slog only
- Do NOT block the Qt main thread — error callback is async via `dispatch`
- Do NOT lose form data on scan error — the whole point of FR31 is preservation

### Project Structure Notes

No new files — only modifications to existing files. The `Scanner` struct in `ctx.go` gains one field. The `NFCScanner` gains one field and one method. The inventory form gains error handling at 3 call sites.

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 7.3] — acceptance criteria, FR31/NFR10 references
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Manager Architecture] — NFCScanner rewritten for HTTP polling
- [Source: internal/manager/nfc_scanner.go] — current NFCScanner implementation (Story 6.4 output)
- [Source: internal/manager/screen/ctx.go] — Scanner struct with function fields
- [Source: internal/manager/screen/inventory.go:461-519,948-984] — 3 call sites using StartScan without error handling
- [Source: internal/manager/manager.go:244-260] — makeCtx() wiring Scanner fields
- [Source: internal/manager/nfc_scanner_test.go] — existing 6 tests, syncDispatch and pollExitHook patterns
- [Source: _bmad-output/implementation-artifacts/6-4-manager-nfc-scanner-stub-for-http.md] — NFCScanner design, dispatch pattern, review findings
- [Source: docs/rest-api-contracts.md#Scan Coordination Endpoints] — HTTP contract for scan endpoints

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None

### Completion Notes List
- Added `errCallback` field and `OnScanError` method to NFCScanner, following OnTagScanned pattern
- `pollLoop` fires error callback via `dispatch` only on non-cancelled, non-context errors
- Wired `OnScanError` in `makeCtx()` directly to `nfcScanner` (not `m.scanner` — avoids RFID interface change)
- All 3 scan call sites in inventory.go now handle StartScan errors and register OnScanError
- `addBottleFrom` preserves template data on error (FR31)
- Error shown via QMessageBox_Warning with French text consistent with existing patterns
- 4 new tests: poll error fires callback, StartScan error doesn't, 410 doesn't, context cancel doesn't

### Change Log
- 2026-04-01: Implemented Story 7.3 — OnScanError callback and inventory form error handling

### File List
- internal/manager/nfc_scanner.go (MODIFIED)
- internal/manager/screen/ctx.go (MODIFIED)
- internal/manager/screen/inventory.go (MODIFIED)
- internal/manager/manager.go (MODIFIED)
- internal/manager/nfc_scanner_test.go (MODIFIED)
