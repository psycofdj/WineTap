# Story 3.4: NFC Scanner Implementation and Settings Toggle

Status: done

## Story

As a user,
I want to switch between RFID and NFC scanning in the manager settings,
So that I can use my phone as a wireless NFC scanner for bottle intake.

## Acceptance Criteria

1. **Given** `internal/manager/nfc_scanner.go` implements `Scanner`
   **When** `StartScan` is called
   **Then** it opens a `CoordinateScan` bidi stream to the server (if not already open)
   **And** sends a `ScanClientMessage{ScanRequest{mode}}` with the requested scan mode
   **And** listens for `ScanServerMessage{ScanAck{tag_id}}` on the return stream
   **And** fires `OnTagScanned(tagID)` when a result arrives

2. **Given** `StopScan` is called on `NFCScanner`
   **Then** it sends `ScanClientMessage{ScanCancel}` to the server
   **And** the stream remains open for future scan requests

3. **Given** the gRPC connection drops while the stream is active
   **Then** `NFCScanner` reports an error via the existing manager error notification
   **And** `StopScan` is called to clean up state
   **And** form data on the manager side is preserved (NFR9)

4. **Given** `screen/settings.go`
   **Then** a scan mode toggle is added: "RFID (USB)" / "NFC (Mobile)" (FR29)
   **And** the selection is persisted in `config.yaml` via `config.go`

5. **Given** `manager.go`
   **When** the scan mode setting is "NFC"
   **Then** it initializes `NFCScanner` instead of `RFIDScanner`
   **And** switching modes takes effect on next scan (no app restart required)

6. **Given** either scanning backend is selected
   **When** a bottle is scanned during intake
   **Then** the result (tag_id in the form field) is identical regardless of backend (FR28, FR30)

## Tasks / Subtasks

- [x] Task 1: Add ScanMode to config and settings (AC: #4)
  - [x] `ScanMode string` field added to Config struct (yaml:"scan_mode", default "rfid")
  - [x] `ScanMode string` added to SettingsData struct
  - [x] Scan mode combo box in settings.go — "RFID (USB)" / "NFC (Mobile)"
  - [x] GetSettings/SaveSettings closures updated in makeCtx()
- [x] Task 2: Change Manager.scanner to Scanner interface (AC: #5)
  - [x] `scanner Scanner` (interface) + `rfidScanner *RFIDScanner` (kept for Close)
  - [x] Simulate wrapped in closure using rfidScanner directly
  - [x] Hot-swap in SaveSettings: stops current scanner, creates new one based on mode
- [x] Task 3: Implement NFCScanner (AC: #1, #2, #3)
  - [x] `nfc_scanner.go` — NFCScanner implementing Scanner, compile-time check
  - [x] Lazy stream open on first StartScan, persistent across requests
  - [x] Reader goroutine: ScanAck -> mainthread.Start(callback), ScanError -> log
  - [x] StopScan sends ScanCancel (stream stays open), Close shuts down stream
  - [x] Stream errors: log, set stream=nil, re-opened on next StartScan
- [x] Task 4: Scanner selection in manager initialization (AC: #5)
  - [x] cfg.ScanMode=="nfc" -> NFCScanner, default -> RFIDScanner
  - [x] Hot-swap on settings save — takes effect on next scan
- [x] Task 5: Verification (AC: #6)
  - [x] `make build` — all 4 binaries compile
  - [x] `go test ./...` — all tests pass

## Dev Notes

### NFCScanner Implementation

The NFCScanner uses the `CoordinateScan` bidi stream to relay scan requests through the server to a connected mobile phone. The manager is the "requester" — it sends `ScanRequest`, the mobile sends `ScanResult`, the server relays `ScanAck` back.

```go
type NFCScanner struct {
    mu       sync.Mutex
    client   v1.WineTapClient
    stream   v1.WineTap_CoordinateScanClient
    callback func(tagID string)
    log      *slog.Logger
}
```

**Stream lifecycle:**
- Stream opened lazily on first `StartScan` call
- Stays open across multiple scan requests (persistent connection)
- Reader goroutine listens for server messages
- `StopScan` sends `ScanCancel` but doesn't close stream
- `Close()` closes the stream (app shutdown)

**Message flow (manager side):**
```
StartScan(mode) → send ScanClientMessage{ScanRequest{mode}} → server relays to mobile
                                                               ↓
OnTagScanned(tagID) ← mainthread.Start(cb(tagID)) ← recv ScanServerMessage{ScanAck{tagID}}
```

### gRPC Client Usage

```go
// Open bidi stream
stream, err := client.CoordinateScan(context.Background())

// Send scan request
stream.Send(&v1.ScanClientMessage{
    Payload: &v1.ScanClientMessage_ScanRequest{
        ScanRequest: &v1.ScanRequest{
            ScanMode: v1.ScanMode_SCAN_MODE_SINGLE, // or CONTINUOUS
        },
    },
})

// Receive ack (in reader goroutine)
msg, err := stream.Recv()
if ack := msg.GetScanAck(); ack != nil {
    callback(ack.TagId)
}

// Send cancel
stream.Send(&v1.ScanClientMessage{
    Payload: &v1.ScanClientMessage_ScanCancel{
        ScanCancel: &v1.ScanCancel{},
    },
})
```

### Scanner Hot-Swap

When settings change scan mode, the manager switches scanner for the next scan:

```go
func (m *Manager) setScanMode(mode string) {
    m.scanner.StopScan() // stop current
    switch mode {
    case "nfc":
        m.scanner = NewNFCScanner(m.client, m.log)
    default:
        m.scanner, _ = NewRFIDScanner(m.appCfg.RFIDPort, m.log)
    }
}
```

The `makeCtx` closures reference `m.scanner` — since they close over `m`, they automatically pick up the new scanner.

### Manager Struct Change

```go
type Manager struct {
    // ...
    scanner    Scanner      // was *RFIDScanner
    rfidScanner *RFIDScanner // keep for cleanup (Close)
}
```

Keep a reference to the RFID scanner for `Close()` on shutdown (serial port cleanup) even when NFC is active.

### Settings Screen Toggle

Add a combo box to the existing settings form:

```go
scanModeCombo := qt.NewQComboBox(nil)
scanModeCombo.AddItems([]string{"RFID (USB)", "NFC (Mobile)"})
if currentScanMode == "nfc" {
    scanModeCombo.SetCurrentIndex(1)
}
```

Map combo index to config value: 0 → "rfid", 1 → "nfc".

### Config Change

```go
type Config struct {
    Server    string `yaml:"server"`
    RFIDPort  string `yaml:"rfid_port"`
    ScanMode  string `yaml:"scan_mode"` // "rfid" (default) or "nfc"
    LogLevel  string `yaml:"log_level"`
    LogFormat string `yaml:"log_format"`
}
```

### Error Handling (AC #3)

When the bidi stream encounters an error (connection drop):
- Log the error
- Set stream to nil (will be re-opened on next StartScan)
- The screen code doesn't crash — it just doesn't receive a callback
- Form data is preserved since no state is modified on error

### What NOT to Do

- Do NOT close the stream on StopScan — only send ScanCancel
- Do NOT block on stream.Send — it should be non-blocking
- Do NOT implement the mobile side — that's Epic 4
- Do NOT modify proto — coordination messages already defined in Story 3.1
- Do NOT modify the server coordination handler — it already handles manager clients

### Previous Story Intelligence

Story 3.3 established:
- `Scanner` interface in `scanner.go`: `OnTagScanned`, `StartScan(ctx, mode)`, `StopScan`
- `RFIDScanner` in `rfid_scanner.go` — reference implementation
- `screen.Scanner` struct with function fields in `ctx.go`
- Manager holds `scanner *RFIDScanner` → needs to become `Scanner` interface
- `makeCtx` bridges manager.Scanner to screen.Scanner via closures
- `Simulate` method on RFIDScanner (debug only)

Story 3.1 established:
- `CoordinateScan` bidi stream RPC
- Server auto-detects manager (first ScanRequest) vs mobile (first ScanResult)
- `ScanAck{TagId}` relayed to manager when mobile scans
- `ScanError{Reason}` sent on cancel/timeout

Story 3.2 established:
- Server registers `_winetap._tcp` via mDNS — connection target for manager

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile.md] — Story 3.4 ACs (lines 555-591)
- [Source: _bmad-output/planning-artifacts/architecture-mobile.md] — Scanner interface (line ~278), NFCScanner spec (line ~293)
- [Source: internal/manager/scanner.go] — Scanner interface
- [Source: internal/manager/rfid_scanner.go] — Reference implementation pattern
- [Source: internal/manager/config.go] — Config struct
- [Source: internal/manager/screen/settings.go] — Settings screen layout
- [Source: gen/winetap/v1/winetap_grpc.pb.go:341] — CoordinateScan client method

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- NFCScanner: lazy bidi stream open, reader goroutine, ScanAck dispatched via mainthread.Start
- Stream persists across scan requests — StopScan sends ScanCancel, doesn't close stream
- Stream errors set stream=nil; re-opened automatically on next StartScan
- Manager.scanner now Scanner interface — hot-swap on settings save without restart
- RFIDScanner kept as rfidScanner field for Close() and Simulate (debug)
- Settings screen: "Mode de scan" combo box — "RFID (USB)" / "NFC (Mobile)"
- Config persists scan_mode in YAML

### Change Log

- 2026-03-31: NFCScanner + settings toggle + scanner hot-swap, completing Epic 3

### File List

- internal/manager/nfc_scanner.go (new — NFCScanner implementing Scanner)
- internal/manager/manager.go (modified — scanner interface, selection logic, hot-swap)
- internal/manager/config.go (modified — ScanMode field)
- internal/manager/screen/ctx.go (modified — ScanMode in SettingsData)
- internal/manager/screen/settings.go (modified — scan mode combo box)
