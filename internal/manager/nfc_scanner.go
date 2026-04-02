package manager

import (
	"context"
	"errors"
	"log/slog"
	"sync"

	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
)

// NFCScanner implements Scanner using the phone's HTTP scan-coordination API.
// It POSTs /scan/request to start a scan, then long-polls GET /scan/result in a
// background goroutine, dispatching the result to the registered callback.
// Every scan is a single read — the manager loops for bulk intake.
type NFCScanner struct {
	mu          sync.Mutex
	httpClient  *client.WineTapHTTPClient
	cancel      context.CancelFunc // cancels the poll goroutine
	callback    func(tagID string)
	errCallback func(err error)
	log         *slog.Logger
	dispatch    func(func()) // defaults to mainthread.Start; overridden in tests
	pollExitHook func()      // called when pollLoop returns; nil in production
}

// Compile-time check that NFCScanner implements Scanner.
var _ Scanner = (*NFCScanner)(nil)

// NewNFCScanner creates an HTTP-based NFC scanner.
func NewNFCScanner(httpClient *client.WineTapHTTPClient, log *slog.Logger) *NFCScanner {
	return &NFCScanner{
		httpClient: httpClient,
		log:        log,
		dispatch:   mainthread.Start,
	}
}

// OnTagScanned registers the callback. Must be called before StartScan.
func (n *NFCScanner) OnTagScanned(callback func(tagID string)) {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.callback = callback
}

// OnScanError registers a callback invoked on the Qt main thread when an
// async poll error occurs (e.g., phone unreachable mid-scan). Not fired on
// cancellation (410 or StopScan) — those are normal flow.
func (n *NFCScanner) OnScanError(callback func(err error)) {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.errCallback = callback
}

// StartScan POSTs /scan/request then starts a background goroutine that
// long-polls /scan/result and delivers the tag via the OnTagScanned callback.
// If a scan is already in progress it is stopped first (idempotent restart).
func (n *NFCScanner) StartScan(_ context.Context) error {
	// Stop any active scan first (under lock), then release before the HTTP call.
	n.mu.Lock()
	if n.cancel != nil {
		n.cancel()
		n.cancel = nil
	}
	n.mu.Unlock()

	// HTTP call outside lock — may block for the full request timeout.
	if err := n.httpClient.RequestScan(context.Background()); err != nil {
		n.log.Error("NFC scan: request failed", "error", err)
		return err
	}
	n.log.Info("NFC scan: request sent")

	ctx, cancel := context.WithCancel(context.Background())
	n.mu.Lock()
	n.cancel = cancel
	n.mu.Unlock()
	go n.pollLoop(ctx)
	return nil
}

// StopScan cancels the poll goroutine and POSTs /scan/cancel to the phone.
func (n *NFCScanner) StopScan() error {
	n.mu.Lock()
	defer n.mu.Unlock()

	if n.cancel == nil {
		return nil
	}
	n.cancel()
	n.cancel = nil
	// Best-effort: always send cancel even if ctx is already done.
	if err := n.httpClient.CancelScan(context.Background()); err != nil {
		n.log.Debug("NFC scan: cancel failed", "error", err)
	}
	n.log.Info("NFC scan: scan stopped")
	return nil
}

// Close stops any active scan. Called by manager.Manager.Close() on shutdown.
func (n *NFCScanner) Close() {
	_ = n.StopScan()
}

// pollLoop runs in a goroutine and repeatedly calls GET /scan/result until:
//   - ctx is cancelled (StopScan was called)
//   - 410 is received (phone cancelled the scan)
//   - a non-retriable error occurs
//   - a successful tag is delivered (single scan complete)
func (n *NFCScanner) pollLoop(ctx context.Context) {
	if hook := n.pollExitHook; hook != nil {
		defer hook()
	}

	for {
		if ctx.Err() != nil {
			return
		}

		tagID, err := n.httpClient.GetScanResult(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			if errors.Is(err, client.ErrScanCancelled) {
				n.log.Info("NFC scan: cancelled by phone")
				return
			}
			n.log.Error("NFC scan: poll error", "error", err)
			n.mu.Lock()
			ecb := n.errCallback
			disp := n.dispatch
			n.mu.Unlock()
			if ecb != nil {
				capturedErr := err
				disp(func() { ecb(capturedErr) })
			}
			return
		}

		if tagID == "" {
			n.log.Debug("NFC scan: poll timeout, retrying")
			continue
		}

		// Tag received — deliver and exit (single scan).
		n.log.Info("NFC scan: tag received", "tag_id", tagID)
		n.mu.Lock()
		cb := n.callback
		disp := n.dispatch
		n.mu.Unlock()
		if cb != nil {
			tid := tagID
			disp(func() { cb(tid) })
		}
		return
	}
}
