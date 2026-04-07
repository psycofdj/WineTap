package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// WineTapHTTPClient talks to the phone's REST API over HTTP.
type WineTapHTTPClient struct {
	mu      sync.RWMutex // protects baseURL
	baseURL string
	http    *http.Client
	// longPollHTTP is used for long-poll and large-transfer operations (scan
	// result, backup, restore).  Its timeout is larger than the 30s server-side
	// scan timeout and the NFR16 backup budget.
	longPollHTTP *http.Client
}

// NewWineTapHTTPClient creates an HTTP client targeting the phone at baseURL.
func NewWineTapHTTPClient(baseURL string) *WineTapHTTPClient {
	return &WineTapHTTPClient{
		baseURL:      strings.TrimRight(baseURL, "/"),
		http:         &http.Client{Timeout: 10 * time.Second},
		longPollHTTP: &http.Client{Timeout: 35 * time.Second},
	}
}

// ── Helpers ─────────────────────────────────────────────────────────────────

// doJSON sends a request with optional JSON body and returns the raw response.
func (c *WineTapHTTPClient) doJSON(ctx context.Context, method, path string, body any) (*http.Response, error) {
	return c.doJSONWith(ctx, c.http, method, path, body)
}

func (c *WineTapHTTPClient) doJSONWith(ctx context.Context, client *http.Client, method, path string, body any) (*http.Response, error) {
	var bodyReader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("marshal request: %w", err)
		}
		bodyReader = bytes.NewReader(b)
	}

	c.mu.RLock()
	url := c.baseURL + path
	c.mu.RUnlock()

	req, err := http.NewRequestWithContext(ctx, method, url, bodyReader)
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	slog.Info("HTTP request", "method", method, "path", path)
	resp, err := client.Do(req)
	if err != nil {
		slog.Info("HTTP request failed", "method", method, "path", path, "error", err)
		return nil, err
	}
	slog.Info("HTTP response", "method", method, "path", path, "status", resp.StatusCode)
	return resp, nil
}

// checkError reads and closes a non-2xx response body and parses it into an
// APIError.  On 2xx it is a no-op and does NOT touch the body.
func checkError(resp *http.Response) error {
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}
	body, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	var apiErr APIError
	if err := json.Unmarshal(body, &apiErr); err != nil {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return &apiErr
}

// decodeResponse reads the response body into T after checking for errors.
func decodeResponse[T any](resp *http.Response) (T, error) {
	var zero T
	if err := checkError(resp); err != nil {
		return zero, err
	}
	defer func() { _ = resp.Body.Close() }()
	var result T
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return zero, fmt.Errorf("decode response: %w", err)
	}
	return result, nil
}

// ── Designations ────────────────────────────────────────────────────────────

func (c *WineTapHTTPClient) ListDesignations(ctx context.Context) ([]Designation, error) {
	resp, err := c.doJSON(ctx, http.MethodGet, "/designations", nil)
	if err != nil {
		return nil, err
	}
	return decodeResponse[[]Designation](resp)
}

func (c *WineTapHTTPClient) AddDesignation(ctx context.Context, d CreateDesignation) (Designation, error) {
	resp, err := c.doJSON(ctx, http.MethodPost, "/designations", d)
	if err != nil {
		return Designation{}, err
	}
	return decodeResponse[Designation](resp)
}

func (c *WineTapHTTPClient) UpdateDesignation(ctx context.Context, id int64, d CreateDesignation) (Designation, error) {
	resp, err := c.doJSON(ctx, http.MethodPut, fmt.Sprintf("/designations/%d", id), d)
	if err != nil {
		return Designation{}, err
	}
	return decodeResponse[Designation](resp)
}

func (c *WineTapHTTPClient) DeleteDesignation(ctx context.Context, id int64) error {
	resp, err := c.doJSON(ctx, http.MethodDelete, fmt.Sprintf("/designations/%d", id), nil)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	return checkError(resp)
}

// ── Domains ─────────────────────────────────────────────────────────────────

func (c *WineTapHTTPClient) ListDomains(ctx context.Context) ([]Domain, error) {
	resp, err := c.doJSON(ctx, http.MethodGet, "/domains", nil)
	if err != nil {
		return nil, err
	}
	return decodeResponse[[]Domain](resp)
}

func (c *WineTapHTTPClient) AddDomain(ctx context.Context, d CreateDomain) (Domain, error) {
	resp, err := c.doJSON(ctx, http.MethodPost, "/domains", d)
	if err != nil {
		return Domain{}, err
	}
	return decodeResponse[Domain](resp)
}

func (c *WineTapHTTPClient) UpdateDomain(ctx context.Context, id int64, d CreateDomain) (Domain, error) {
	resp, err := c.doJSON(ctx, http.MethodPut, fmt.Sprintf("/domains/%d", id), d)
	if err != nil {
		return Domain{}, err
	}
	return decodeResponse[Domain](resp)
}

func (c *WineTapHTTPClient) DeleteDomain(ctx context.Context, id int64) error {
	resp, err := c.doJSON(ctx, http.MethodDelete, fmt.Sprintf("/domains/%d", id), nil)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	return checkError(resp)
}

// ── Cuvees ──────────────────────────────────────────────────────────────────

func (c *WineTapHTTPClient) ListCuvees(ctx context.Context) ([]Cuvee, error) {
	resp, err := c.doJSON(ctx, http.MethodGet, "/cuvees", nil)
	if err != nil {
		return nil, err
	}
	return decodeResponse[[]Cuvee](resp)
}

func (c *WineTapHTTPClient) AddCuvee(ctx context.Context, cv CreateCuvee) (Cuvee, error) {
	resp, err := c.doJSON(ctx, http.MethodPost, "/cuvees", cv)
	if err != nil {
		return Cuvee{}, err
	}
	return decodeResponse[Cuvee](resp)
}

func (c *WineTapHTTPClient) UpdateCuvee(ctx context.Context, id int64, cv CreateCuvee) (Cuvee, error) {
	resp, err := c.doJSON(ctx, http.MethodPut, fmt.Sprintf("/cuvees/%d", id), cv)
	if err != nil {
		return Cuvee{}, err
	}
	return decodeResponse[Cuvee](resp)
}

func (c *WineTapHTTPClient) DeleteCuvee(ctx context.Context, id int64) error {
	resp, err := c.doJSON(ctx, http.MethodDelete, fmt.Sprintf("/cuvees/%d", id), nil)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	return checkError(resp)
}

// ── Bottles ─────────────────────────────────────────────────────────────────

func (c *WineTapHTTPClient) ListBottles(ctx context.Context, includeConsumed bool) ([]Bottle, error) {
	path := "/bottles"
	if includeConsumed {
		path += "?include_consumed=true"
	}
	resp, err := c.doJSON(ctx, http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	return decodeResponse[[]Bottle](resp)
}

func (c *WineTapHTTPClient) GetBottle(ctx context.Context, id int64) (Bottle, error) {
	resp, err := c.doJSON(ctx, http.MethodGet, fmt.Sprintf("/bottles/%d", id), nil)
	if err != nil {
		return Bottle{}, err
	}
	return decodeResponse[Bottle](resp)
}

func (c *WineTapHTTPClient) GetBottleByTagID(ctx context.Context, tagID string) (Bottle, error) {
	resp, err := c.doJSON(ctx, http.MethodGet, "/bottles/by-tag/"+url.PathEscape(tagID), nil)
	if err != nil {
		return Bottle{}, err
	}
	return decodeResponse[Bottle](resp)
}

func (c *WineTapHTTPClient) AddBottle(ctx context.Context, b CreateBottle) (Bottle, error) {
	resp, err := c.doJSON(ctx, http.MethodPost, "/bottles", b)
	if err != nil {
		return Bottle{}, err
	}
	return decodeResponse[Bottle](resp)
}

func (c *WineTapHTTPClient) ConsumeBottle(ctx context.Context, tagID string) (Bottle, error) {
	resp, err := c.doJSON(ctx, http.MethodPost, "/bottles/consume", ConsumeRequest{TagID: tagID})
	if err != nil {
		return Bottle{}, err
	}
	return decodeResponse[Bottle](resp)
}

func (c *WineTapHTTPClient) UpdateBottle(ctx context.Context, id int64, fields map[string]any) (Bottle, error) {
	resp, err := c.doJSON(ctx, http.MethodPut, fmt.Sprintf("/bottles/%d", id), fields)
	if err != nil {
		return Bottle{}, err
	}
	return decodeResponse[Bottle](resp)
}


func (c *WineTapHTTPClient) DeleteBottle(ctx context.Context, id int64) error {
	resp, err := c.doJSON(ctx, http.MethodDelete, fmt.Sprintf("/bottles/%d", id), nil)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	return checkError(resp)
}


// ── Completions ─────────────────────────────────────────────────────────────

func (c *WineTapHTTPClient) GetCompletions(ctx context.Context, field, prefix string) ([]string, error) {
	path := fmt.Sprintf("/completions?field=%s&prefix=%s",
		url.QueryEscape(field), url.QueryEscape(prefix))
	resp, err := c.doJSON(ctx, http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	cr, err := decodeResponse[CompletionResponse](resp)
	if err != nil {
		return nil, err
	}
	return cr.Values, nil
}

// ── Scan Coordination ───────────────────────────────────────────────────────

// RequestScan asks the phone to start a single NFC scan session.
// The manager loops for bulk intake by calling RequestScan repeatedly.
func (c *WineTapHTTPClient) RequestScan(ctx context.Context) error {
	resp, err := c.doJSON(ctx, http.MethodPost, "/scan/request", nil)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	return checkError(resp)
}

// GetScanResult long-polls the phone for a scan result.
// Returns the tag ID on success, empty string on timeout (204), or
// ErrScanCancelled on cancellation (410).  The caller should retry on empty
// string and stop on ErrScanCancelled.
func (c *WineTapHTTPClient) GetScanResult(ctx context.Context) (string, error) {
	resp, err := c.doJSONWith(ctx, c.longPollHTTP, http.MethodGet, "/scan/result", nil)
	if err != nil {
		return "", err
	}
	defer func() { _ = resp.Body.Close() }()

	switch resp.StatusCode {
	case http.StatusOK:
		var sr ScanResult
		if err := json.NewDecoder(resp.Body).Decode(&sr); err != nil {
			return "", fmt.Errorf("decode scan result: %w", err)
		}
		return sr.TagID, nil
	case http.StatusNoContent:
		return "", nil // timeout — caller retries
	case http.StatusGone: // 410: scan was cancelled
		return "", ErrScanCancelled
	default:
		body, _ := io.ReadAll(resp.Body)
		var apiErr APIError
		if err := json.Unmarshal(body, &apiErr); err != nil {
			return "", fmt.Errorf("HTTP %d", resp.StatusCode)
		}
		return "", &apiErr
	}
}

// CancelScan cancels a pending scan request on the phone.
func (c *WineTapHTTPClient) CancelScan(ctx context.Context) error {
	resp, err := c.doJSON(ctx, http.MethodPost, "/scan/cancel", nil)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	return checkError(resp)
}

// ── Backup / Restore ────────────────────────────────────────────────────────

// GetBackup downloads the phone's SQLite database file.
// The caller must close the returned ReadCloser.
// Uses the long-poll client to accommodate the NFR16 backup time budget.
func (c *WineTapHTTPClient) GetBackup(ctx context.Context) (io.ReadCloser, error) {
	c.mu.RLock()
	url := c.baseURL + "/backup"
	c.mu.RUnlock()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	slog.Info("HTTP request", "method", http.MethodGet, "path", "/backup")
	resp, err := c.longPollHTTP.Do(req)
	if err != nil {
		slog.Info("HTTP request failed", "method", http.MethodGet, "path", "/backup", "error", err)
		return nil, err
	}
	slog.Info("HTTP response", "method", http.MethodGet, "path", "/backup", "status", resp.StatusCode)
	if err := checkError(resp); err != nil {
		return nil, err
	}
	return resp.Body, nil
}

// Restore uploads a SQLite database file to replace the phone's current
// database.  Uses the long-poll client to accommodate large uploads.
func (c *WineTapHTTPClient) Restore(ctx context.Context, r io.Reader) error {
	c.mu.RLock()
	url := c.baseURL + "/restore"
	c.mu.RUnlock()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, r)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	slog.Info("HTTP request", "method", http.MethodPost, "path", "/restore")
	resp, err := c.longPollHTTP.Do(req)
	if err != nil {
		slog.Info("HTTP request failed", "method", http.MethodPost, "path", "/restore", "error", err)
		return err
	}
	slog.Info("HTTP response", "method", http.MethodPost, "path", "/restore", "status", resp.StatusCode)
	defer func() { _ = resp.Body.Close() }()
	return checkError(resp)
}

// ── Discovery helpers ────────────────────────────────────────────────────────

// HealthCheck performs GET / and returns the health response from the phone.
func (c *WineTapHTTPClient) HealthCheck(ctx context.Context) (HealthResponse, error) {
	resp, err := c.doJSON(ctx, http.MethodGet, "/", nil)
	if err != nil {
		return HealthResponse{}, err
	}
	return decodeResponse[HealthResponse](resp)
}

// SetBaseURL updates the target address (used when mDNS re-discovery finds
// the phone at a new address).
func (c *WineTapHTTPClient) SetBaseURL(baseURL string) {
	c.mu.Lock()
	c.baseURL = strings.TrimRight(baseURL, "/")
	c.mu.Unlock()
}
