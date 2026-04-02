# Story 3.3: Manager Scanner Interface and RFID Extraction

Status: done

## Story

As a developer,
I want a Scanner interface in the manager with the existing RFID logic extracted into it,
So that the scanning abstraction is in place before adding the NFC backend.

## Acceptance Criteria

1. **Given** `internal/manager/scanner.go`
   **Then** it defines the `Scanner` interface: `StartScan(ctx, mode ScanMode) error`, `StopScan() error`, `OnTagScanned(callback func(tagID string))`
   **And** `ScanMode` type with `ScanModeSingle` and `ScanModeContinuous` constants

2. **Given** `internal/manager/rfid_scanner.go`
   **Then** it implements `Scanner` using the existing RFID logic extracted from `rfid.go`
   **And** `StartScan` with `ScanModeSingle` triggers one `InventorySingle`
   **And** `StartScan` with `ScanModeContinuous` runs the `Inventory` loop
   **And** `StopScan` halts the scan loop
   **And** `OnTagScanned` fires the callback with the scanned tag_id

3. **Given** `manager.go` initializes the scanner
   **Then** it creates `RFIDScanner` by default (preserving existing behavior)
   **And** `inventory_form.go` calls `Scanner.StartScan()` instead of directly using RFID methods

4. **Given** all existing RFID scanning functionality
   **When** the refactor is complete
   **Then** RFID scanning works identically to before — no behavioral regression (FR30)
   **And** the manager builds and all existing workflows pass

## Tasks / Subtasks

- [x] Task 1: Create Scanner interface and ScanMode type (AC: #1)
  - [x] Created `internal/manager/scanner.go` — `Scanner` interface, `ScanMode` type
- [x] Task 2: Extract RFID logic into RFIDScanner (AC: #2)
  - [x] Created `internal/manager/rfid_scanner.go` implementing `Scanner`
  - [x] `NewRFIDScanner(portName, log)` constructor, `var _ Scanner = (*RFIDScanner)(nil)` compile check
  - [x] `StartScan(ctx, ScanModeSingle)` — poll, stop after first tag
  - [x] `StartScan(ctx, ScanModeContinuous)` — poll continuously until StopScan
  - [x] `StopScan()`, `OnTagScanned(callback)`, `Simulate(tagID)`, `Close()`
  - [x] `mainthread.Start()` preserved for Qt thread safety
- [x] Task 3: Update screen.Ctx to use Scanner (AC: #3)
  - [x] `screen/ctx.go` — added `Scanner` struct with function fields + `ScanMode` type (avoids circular import)
  - [x] Removed `StartRFIDScan`, `StopRFIDScan`, `DebugSimulateScan` from Ctx
  - [x] `manager.go` makeCtx() — bridges manager.Scanner to screen.Scanner via closures
- [x] Task 4: Update screen code (AC: #3, #4)
  - [x] `inventory.go` — 3 scan patterns updated: OnTagScanned + StartScan(ScanModeSingle)
  - [x] `inventory.go` — 5 StopRFIDScan calls replaced with Scanner.StopScan()
  - [x] `inventory_form.go` — debug simulate via Scanner.Simulate
  - [x] `manager.go` navigate() — Scanner.StopScan()
- [x] Task 5: Clean up rfid.go (AC: #2)
  - [x] `rfid.go` deleted — all logic in `rfid_scanner.go`
- [x] Task 6: Verification (AC: #4)
  - [x] `make build` — all 4 binaries compile
  - [x] `go test ./internal/manager/...` — all tests pass
  - [x] Zero references to `StartRFIDScan`/`StopRFIDScan`/`m.rfid` remain

## Dev Notes

### Refactor Strategy: Extract, Don't Rewrite

The existing `rfidScanner` works. This is a pure refactoring — extract it behind an interface so Story 3.4 can add `NFCScanner` alongside it.

**Current flow:**
```
manager.go → rfidScanner.start(callback) → polling loop → mainthread.Start(callback(epc))
screens   → ctx.StartRFIDScan(callback) / ctx.StopRFIDScan()
```

**New flow:**
```
manager.go → RFIDScanner (implements Scanner) → same polling loop → mainthread.Start(callback(tagID))
screens   → ctx.Scanner.OnTagScanned(callback); ctx.Scanner.StartScan(ctx, mode)
           → ctx.Scanner.StopScan()
```

### Scanner Interface

```go
// scanner.go
type ScanMode int

const (
    ScanModeSingle     ScanMode = iota
    ScanModeContinuous
)

type Scanner interface {
    StartScan(ctx context.Context, mode ScanMode) error
    StopScan() error
    OnTagScanned(callback func(tagID string))
}
```

### RFIDScanner Implementation

The current `rfidScanner` becomes `RFIDScanner` implementing `Scanner`:

```go
// rfid_scanner.go
type RFIDScanner struct {
    mu       sync.Mutex
    port     serial.Port
    reader   *cfru5102.Reader
    stopFn   context.CancelFunc
    callback func(tagID string)
    log      *slog.Logger
}

func (r *RFIDScanner) OnTagScanned(callback func(tagID string)) {
    r.mu.Lock()
    defer r.mu.Unlock()
    r.callback = callback
}

func (r *RFIDScanner) StartScan(ctx context.Context, mode ScanMode) error {
    r.stop() // stop any existing scan
    scanCtx, cancel := context.WithCancel(ctx)
    r.mu.Lock()
    r.stopFn = cancel
    r.mu.Unlock()
    go r.loop(scanCtx, mode)
    return nil
}

func (r *RFIDScanner) StopScan() error {
    r.stop()
    return nil
}
```

**Key difference from current code**: `start(callback)` is split into `OnTagScanned(callback)` + `StartScan(ctx, mode)`. The callback is registered separately, then scan is started. This matches the architecture spec.

**ScanModeSingle vs ScanModeContinuous:**
- Single: poll, find first tag, fire callback, auto-stop (current behavior)
- Continuous: poll every 300ms, fire callback for each tag, keep going until `StopScan()`
- Current code is already single-mode. For continuous, remove the `break` after first tag.

### Screen Context Update

Current `screen/ctx.go`:
```go
type Ctx struct {
    StartRFIDScan     func(callback func(epc string))
    StopRFIDScan      func()
    DebugSimulateScan func(epc string)
    // ...
}
```

New:
```go
type Ctx struct {
    Scanner           Scanner  // Scanner interface
    DebugSimulateScan func(epc string)
    // ...
}
```

### Screen Usage Pattern Change

Current:
```go
s.ctx.StartRFIDScan(func(epc string) {
    s.ctx.StopRFIDScan()
    // process epc
})
```

New:
```go
s.ctx.Scanner.OnTagScanned(func(tagID string) {
    s.ctx.Scanner.StopScan()
    // process tagID
})
s.ctx.Scanner.StartScan(context.Background(), ScanModeSingle)
```

### Manager Initialization Change

Current `makeCtx()`:
```go
StartRFIDScan: m.rfid.start,
StopRFIDScan:  m.rfid.stop,
```

New:
```go
Scanner: m.scanner, // Scanner interface (RFIDScanner by default)
```

And in `New()`:
```go
m.scanner = NewRFIDScanner(cfg.RFIDPort, log) // returns Scanner
```

### Critical: mainthread.Start()

The existing code uses `mainthread.Start()` to dispatch callbacks to the Qt main thread. This MUST be preserved in the `RFIDScanner.loop()` method. The Qt UI cannot be updated from a goroutine.

### What NOT to Do

- Do NOT change RFID polling behavior — 300ms interval, same cfru5102 commands
- Do NOT add NFC scanner — that's Story 3.4
- Do NOT add settings toggle — that's Story 3.4
- Do NOT modify the proto or server — this is manager-only
- Do NOT remove debug simulate support — keep it working

### Previous Story Intelligence

Story 1.1 established:
- `RfidEpc` renamed to `TagId` across all proto field references in manager

Story 3.1 established:
- `CoordinateScan` bidi stream proto available for `NFCScanner` in Story 3.4

Manager codebase:
- `rfid.go` — `rfidScanner` struct with `start`, `stop`, `simulate`, `loop`, `open`, `close`
- `screen/ctx.go` — `Ctx` with `StartRFIDScan`, `StopRFIDScan`, `DebugSimulateScan` callbacks
- 3 scan usage patterns in `inventory.go`: openAddForm, addBottleFrom, onSearchByTag
- All callbacks dispatched on Qt main thread via `mainthread.Start()`
- Config: `RFIDPort` field in config.go

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 3.3 ACs (lines 527-553)
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — Scanner interface spec (line ~278), ScanMode (line ~286)
- [Source: internal/manager/rfid.go] — Current rfidScanner implementation
- [Source: internal/manager/manager.go] — Manager struct, rfid initialization, makeCtx()
- [Source: internal/manager/screen/ctx.go] — Ctx struct with StartRFIDScan/StopRFIDScan
- [Source: internal/manager/screen/inventory.go] — 3 scan patterns (openAddForm, addBottleFrom, onSearchByTag)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Scanner interface defined in manager package: OnTagScanned, StartScan(ctx, mode), StopScan
- screen.Scanner struct mirrors it via function fields to avoid circular import (same pattern as existing Ctx callbacks)
- RFIDScanner: exported type implementing Scanner, compile-time check, NewRFIDScanner constructor
- ScanModeSingle stops after first tag (existing behavior), ScanModeContinuous keeps polling (new for intake)
- Callback read under mutex in loop() for thread safety
- makeCtx bridges manager.ScanMode to screen.ScanMode via closure
- rfid.go deleted — fully replaced by rfid_scanner.go
- All 3 scan patterns in inventory.go converted: OnTagScanned + StartScan(ScanModeSingle)

### Change Log

- 2026-03-31: Scanner interface refactor — RFID extracted behind Scanner abstraction

### File List

- internal/manager/scanner.go (new — Scanner interface + ScanMode)
- internal/manager/rfid_scanner.go (new — RFIDScanner implementing Scanner)
- internal/manager/rfid.go (deleted — replaced by rfid_scanner.go)
- internal/manager/manager.go (modified — scanner field, NewRFIDScanner, makeCtx bridging)
- internal/manager/screen/ctx.go (modified — Scanner struct + ScanMode, removed old RFID callbacks)
- internal/manager/screen/inventory.go (modified — 3 scan patterns + 5 stop calls updated)
- internal/manager/screen/inventory_form.go (modified — debug simulate via Scanner)
