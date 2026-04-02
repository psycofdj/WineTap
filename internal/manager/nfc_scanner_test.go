package manager

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"winetap/internal/client"
)

// syncDispatch calls f directly (synchronous), replacing mainthread.Start in tests.
// Without a Qt event loop, mainthread.Start would block indefinitely.
func syncDispatch(f func()) { f() }

func newTestNFCScanner(ts *httptest.Server) *NFCScanner {
	s := NewNFCScanner(client.NewWineTapHTTPClient(ts.URL), slog.Default())
	s.dispatch = syncDispatch
	return s
}

// ── Happy path ──────────────────────────────────────────────────────────────

func TestNFCScanner_StartScanHappyPath(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			w.WriteHeader(http.StatusCreated)
			fmt.Fprintln(w, `{"status":"requested"}`)
		case "/scan/result":
			w.Header().Set("Content-Type", "application/json")
			if err := json.NewEncoder(w).Encode(map[string]string{"status": "resolved", "tag_id": "04AABBCC"}); err != nil {
				t.Errorf("encode: %v", err)
			}
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer ts.Close()

	scanner := newTestNFCScanner(ts)
	got := make(chan string, 1)
	scanner.OnTagScanned(func(tagID string) { got <- tagID })

	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	select {
	case tagID := <-got:
		if tagID != "04AABBCC" {
			t.Errorf("got tag %q, want %q", tagID, "04AABBCC")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for tag callback")
	}
}

// ── 204 retry ───────────────────────────────────────────────────────────────

func TestNFCScanner_204Retry(t *testing.T) {
	// Channel controls responses in order: first 204, then 200.
	responses := make(chan func(http.ResponseWriter), 2)
	responses <- func(w http.ResponseWriter) { w.WriteHeader(http.StatusNoContent) }
	responses <- func(w http.ResponseWriter) {
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(map[string]string{"status": "resolved", "tag_id": "DEADBEEF"}); err != nil {
			t.Errorf("encode: %v", err)
		}
	}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			w.WriteHeader(http.StatusCreated)
		case "/scan/result":
			respond := <-responses
			respond(w)
		}
	}))
	defer ts.Close()

	scanner := newTestNFCScanner(ts)
	got := make(chan string, 1)
	scanner.OnTagScanned(func(tagID string) { got <- tagID })

	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	select {
	case tagID := <-got:
		if tagID != "DEADBEEF" {
			t.Errorf("got tag %q, want %q", tagID, "DEADBEEF")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for tag after 204 retry")
	}
}

// ── StopScan ────────────────────────────────────────────────────────────────

func TestNFCScanner_StopScan(t *testing.T) {
	cancelReceived := make(chan struct{}, 1)
	var once sync.Once
	resultStarted := make(chan struct{})

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			w.WriteHeader(http.StatusCreated)
		case "/scan/result":
			// Signal that the poll goroutine is now blocking.
			once.Do(func() { close(resultStarted) })
			// Block until the client's context is cancelled.
			<-r.Context().Done()
		case "/scan/cancel":
			select {
			case cancelReceived <- struct{}{}:
			default:
			}
			w.WriteHeader(http.StatusOK)
		}
	}))
	defer ts.Close()

	scanner := newTestNFCScanner(ts)
	goroutineDone := make(chan struct{})
	scanner.pollExitHook = func() { close(goroutineDone) }

	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	// Wait until the poll goroutine is blocking on GET /scan/result.
	select {
	case <-resultStarted:
	case <-time.After(2 * time.Second):
		t.Fatal("timeout: poll goroutine did not start")
	}

	if err := scanner.StopScan(); err != nil {
		t.Fatalf("StopScan: %v", err)
	}

	// Verify POST /scan/cancel was sent.
	select {
	case <-cancelReceived:
	case <-time.After(2 * time.Second):
		t.Fatal("timeout: POST /scan/cancel not received")
	}

	// Verify poll goroutine exited.
	select {
	case <-goroutineDone:
	case <-time.After(2 * time.Second):
		t.Fatal("timeout: poll goroutine did not exit after StopScan")
	}
}

// ── 410 cancellation ────────────────────────────────────────────────────────

func TestNFCScanner_410Cancelled(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			w.WriteHeader(http.StatusCreated)
		case "/scan/result":
			w.WriteHeader(http.StatusGone) // 410
		}
	}))
	defer ts.Close()

	scanner := newTestNFCScanner(ts)
	callbackFired := false
	scanner.OnTagScanned(func(_ string) { callbackFired = true })

	goroutineDone := make(chan struct{})
	scanner.pollExitHook = func() { close(goroutineDone) }

	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	// Wait for the goroutine to exit after processing 410.
	select {
	case <-goroutineDone:
	case <-time.After(2 * time.Second):
		t.Fatal("timeout: poll goroutine did not exit after 410")
	}

	if callbackFired {
		t.Error("callback fired on 410 cancellation — should not fire")
	}
}

// ── Single mode stops after one result ──────────────────────────────────────

func TestNFCScanner_SingleModeStopsAfterOne(t *testing.T) {
	var mu sync.Mutex
	callCount := 0
	secondGET := make(chan struct{}, 1)

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			w.WriteHeader(http.StatusCreated)
		case "/scan/result":
			mu.Lock()
			callCount++
			n := callCount
			mu.Unlock()
			if n == 1 {
				w.Header().Set("Content-Type", "application/json")
				if err := json.NewEncoder(w).Encode(map[string]string{"tag_id": "AABBCCDD"}); err != nil {
					t.Errorf("encode: %v", err)
				}
			} else {
				select {
				case secondGET <- struct{}{}:
				default:
				}
				w.WriteHeader(http.StatusNoContent)
			}
		}
	}))
	defer ts.Close()

	scanner := newTestNFCScanner(ts)
	got := make(chan string, 1)
	scanner.OnTagScanned(func(tagID string) { got <- tagID })

	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	// Wait for the callback.
	select {
	case <-got:
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for callback")
	}

	// Ensure the poller does not retry after single-mode result.
	select {
	case <-secondGET:
		t.Error("poll loop continued after single-mode scan — second GET /scan/result was issued")
	case <-time.After(200 * time.Millisecond):
		// expected: no second request
	}
}

// ── Idempotent restart ───────────────────────────────────────────────────────

func TestNFCScanner_IdempotentRestart(t *testing.T) {
	var mu sync.Mutex
	requestCount := 0
	firstPolling := make(chan struct{})
	var firstPollingOnce sync.Once

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			mu.Lock()
			requestCount++
			mu.Unlock()
			w.WriteHeader(http.StatusCreated)
		case "/scan/cancel":
			w.WriteHeader(http.StatusOK)
		case "/scan/result":
			// Signal once that the first poll goroutine is blocking.
			firstPollingOnce.Do(func() { close(firstPolling) })
			// Block until context is cancelled (first scan stopped by second StartScan).
			<-r.Context().Done()
		}
	}))
	defer ts.Close()

	scanner := newTestNFCScanner(ts)
	got := make(chan string, 10)
	scanner.OnTagScanned(func(tagID string) { got <- tagID })

	// First StartScan.
	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("first StartScan: %v", err)
	}

	// Wait until first poll goroutine is blocking on /scan/result.
	select {
	case <-firstPolling:
	case <-time.After(2 * time.Second):
		t.Fatal("timeout: first poll goroutine did not start")
	}

	// Second StartScan — must cancel the first without double-delivering callbacks.
	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("second StartScan: %v", err)
	}

	// No callbacks should have fired (neither scan resolved a tag).
	select {
	case tag := <-got:
		t.Errorf("unexpected callback fired with tag %q", tag)
	case <-time.After(200 * time.Millisecond):
		// expected: no callback
	}

	_ = scanner.StopScan()

	mu.Lock()
	n := requestCount
	mu.Unlock()
	if n != 2 {
		t.Errorf("POST /scan/request called %d times, want 2", n)
	}
}

// ── OnScanError tests ──────────────────────────────────────────────────────

func TestNFCScanner_PollErrorFiresOnScanError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			w.WriteHeader(http.StatusCreated)
			fmt.Fprintln(w, `{"status":"requested"}`)
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

	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	select {
	case err := <-gotErr:
		if err == nil {
			t.Error("expected non-nil error")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for error callback")
	}
	<-done
}

func TestNFCScanner_StartScanErrorDoesNotFireOnScanError(t *testing.T) {
	// Server is closed immediately — StartScan will fail.
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	ts.Close()

	scanner := newTestNFCScanner(ts)
	errFired := false
	scanner.OnScanError(func(err error) { errFired = true })

	err := scanner.StartScan(context.Background())
	if err == nil {
		t.Fatal("expected StartScan to fail")
	}

	// Give time for any spurious callback.
	time.Sleep(100 * time.Millisecond)
	if errFired {
		t.Error("OnScanError fired on synchronous StartScan error — should not")
	}
}

func TestNFCScanner_410DoesNotFireOnScanError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			w.WriteHeader(http.StatusCreated)
		case "/scan/result":
			w.WriteHeader(http.StatusGone) // 410
		}
	}))
	defer ts.Close()

	scanner := newTestNFCScanner(ts)
	done := make(chan struct{})
	scanner.pollExitHook = func() { close(done) }

	errFired := false
	scanner.OnScanError(func(err error) { errFired = true })

	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	<-done
	if errFired {
		t.Error("OnScanError fired on 410 cancellation — should not")
	}
}

func TestNFCScanner_ContextCancelDoesNotFireOnScanError(t *testing.T) {
	resultStarted := make(chan struct{})
	var once sync.Once

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/scan/request":
			w.WriteHeader(http.StatusCreated)
		case "/scan/cancel":
			w.WriteHeader(http.StatusOK)
		case "/scan/result":
			once.Do(func() { close(resultStarted) })
			<-r.Context().Done()
		}
	}))
	defer ts.Close()

	scanner := newTestNFCScanner(ts)
	done := make(chan struct{})
	scanner.pollExitHook = func() { close(done) }

	errFired := false
	scanner.OnScanError(func(err error) { errFired = true })

	if err := scanner.StartScan(context.Background()); err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	<-resultStarted
	_ = scanner.StopScan()
	<-done

	if errFired {
		t.Error("OnScanError fired on context cancel (StopScan) — should not")
	}
}
