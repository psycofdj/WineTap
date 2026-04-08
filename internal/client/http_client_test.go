package client

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
)

// bgCtx is a convenience shorthand used throughout the tests.
var bgCtx = context.Background()

// ── JSON serialization tests ────────────────────────────────────────────────

func TestDesignationJSON(t *testing.T) {
	d := Designation{ID: 1, Name: "Madiran", Region: "Sud-Ouest", Description: ""}
	b, err := json.Marshal(d)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"id":1,"name":"Madiran","region":"Sud-Ouest","description":""}`
	if string(b) != want {
		t.Errorf("got %s, want %s", b, want)
	}

	var d2 Designation
	if err := json.Unmarshal(b, &d2); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(d2, d) {
		t.Errorf("roundtrip: got %+v, want %+v", d2, d)
	}
}

func TestDesignationJSONWithPicture(t *testing.T) {
	pic := []byte{0x89, 0x50, 0x4E, 0x47}
	d := Designation{ID: 2, Name: "Cahors", Region: "Sud-Ouest", Description: "", Picture: pic}
	b, err := json.Marshal(d)
	if err != nil {
		t.Fatal(err)
	}
	// []byte marshals as base64 in JSON.
	want := `{"id":2,"name":"Cahors","region":"Sud-Ouest","description":"","picture":"iVBORw=="}`
	if string(b) != want {
		t.Errorf("got %s, want %s", b, want)
	}

	var d2 Designation
	if err := json.Unmarshal(b, &d2); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(d2, d) {
		t.Errorf("roundtrip: got %+v, want %+v", d2, d)
	}
}

func TestDomainJSON(t *testing.T) {
	d := Domain{ID: 5, Name: "Brumont", Description: ""}
	b, err := json.Marshal(d)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"id":5,"name":"Brumont","description":""}`
	if string(b) != want {
		t.Errorf("got %s, want %s", b, want)
	}
}

func TestCuveeJSON(t *testing.T) {
	c := Cuvee{
		ID: 1, Name: "Montus", DomainID: 5, DesignationID: 1,
		Color: 1, Description: "",
		DomainName: "Brumont", DesignationName: "Madiran", Region: "Sud-Ouest",
	}
	b, err := json.Marshal(c)
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	json.Unmarshal(b, &m)
	for _, key := range []string{"id", "name", "domain_id", "designation_id", "color", "description", "domain_name", "designation_name", "region"} {
		if _, ok := m[key]; !ok {
			t.Errorf("missing key %q in JSON", key)
		}
	}
}

func TestBottleJSON_NullableFieldsOmitted(t *testing.T) {
	bottle := Bottle{
		ID: 42, CuveeID: 1, Vintage: 2019, Description: "", AddedAt: "2026-03-15T10:30:00Z",
		Cuvee: Cuvee{ID: 1, Name: "Montus", DomainID: 5, Color: 1},
	}
	b, err := json.Marshal(bottle)
	if err != nil {
		t.Fatal(err)
	}
	s := string(b)
	if strings.Contains(s, "tag_id") {
		t.Error("nil tag_id should be omitted")
	}
	if strings.Contains(s, "purchase_price") {
		t.Error("nil purchase_price should be omitted")
	}
	if strings.Contains(s, "drink_before") {
		t.Error("nil drink_before should be omitted")
	}
	if strings.Contains(s, "consumed_at") {
		t.Error("nil consumed_at should be omitted")
	}
}

func TestBottleJSON_NullableFieldsPresent(t *testing.T) {
	tag := "04A32BFF"
	price := 15.50
	drink := int32(2030)
	consumed := "2026-04-01T18:00:00Z"
	bottle := Bottle{
		ID: 42, TagID: &tag, CuveeID: 1, Vintage: 2019, Description: "",
		PurchasePrice: &price, DrinkBefore: &drink,
		AddedAt: "2026-03-15T10:30:00Z", ConsumedAt: &consumed,
		Cuvee: Cuvee{ID: 1, Name: "Montus"},
	}
	b, err := json.Marshal(bottle)
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	json.Unmarshal(b, &m)
	for _, key := range []string{"tag_id", "purchase_price", "drink_before", "consumed_at"} {
		if _, ok := m[key]; !ok {
			t.Errorf("expected key %q present when non-nil", key)
		}
	}
}

func TestBottleJSON_NestedCuvee(t *testing.T) {
	bottle := Bottle{
		ID: 42, CuveeID: 1, Vintage: 2019, AddedAt: "2026-03-15T10:30:00Z",
		Cuvee: Cuvee{ID: 1, Name: "Montus", DomainName: "Brumont"},
	}
	b, _ := json.Marshal(bottle)
	var m map[string]any
	json.Unmarshal(b, &m)
	cuveeMap, ok := m["cuvee"].(map[string]any)
	if !ok {
		t.Fatal("expected nested cuvee object")
	}
	if cuveeMap["name"] != "Montus" {
		t.Errorf("cuvee.name = %v, want Montus", cuveeMap["name"])
	}
	if cuveeMap["domain_name"] != "Brumont" {
		t.Errorf("cuvee.domain_name = %v, want Brumont", cuveeMap["domain_name"])
	}
}

func TestAPIErrorFormat(t *testing.T) {
	e := &APIError{Code: "not_found", Message: "bottle not found"}
	want := "not_found: bottle not found"
	if e.Error() != want {
		t.Errorf("got %q, want %q", e.Error(), want)
	}
}

func TestAPIErrorIsError(t *testing.T) {
	var err error = &APIError{Code: "internal", Message: "oops"}
	if err.Error() != "internal: oops" {
		t.Errorf("unexpected: %s", err)
	}
}

// ── HTTP client tests using httptest ────────────────────────────────────────

// newTestClient creates a WineTapHTTPClient backed by the given handler.
func newTestClient(t *testing.T, handler http.Handler) (*WineTapHTTPClient, *httptest.Server) {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return NewWineTapHTTPClient(srv.URL), srv
}

func TestListDesignations(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/designations" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`[{"id":1,"name":"Madiran","region":"Sud-Ouest","description":""}]`))
	}))

	desigs, err := client.ListDesignations(bgCtx)
	if err != nil {
		t.Fatal(err)
	}
	if len(desigs) != 1 || desigs[0].Name != "Madiran" {
		t.Errorf("got %+v", desigs)
	}
}

func TestAddDesignation(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("expected POST, got %s", r.Method)
		}
		var req CreateDesignation
		json.NewDecoder(r.Body).Decode(&req)
		if req.Name != "Cahors" {
			t.Errorf("expected name=Cahors, got %s", req.Name)
		}
		w.WriteHeader(201)
		json.NewEncoder(w).Encode(Designation{ID: 3, Name: req.Name, Region: req.Region})
	}))

	d, err := client.AddDesignation(bgCtx, CreateDesignation{Name: "Cahors", Region: "Sud-Ouest"})
	if err != nil {
		t.Fatal(err)
	}
	if d.ID != 3 || d.Name != "Cahors" {
		t.Errorf("got %+v", d)
	}
}

func TestUpdateDesignation(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut || r.URL.Path != "/designations/1" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		json.NewEncoder(w).Encode(Designation{ID: 1, Name: "Updated"})
	}))

	d, err := client.UpdateDesignation(bgCtx, 1, CreateDesignation{Name: "Updated"})
	if err != nil {
		t.Fatal(err)
	}
	if d.Name != "Updated" {
		t.Errorf("got %+v", d)
	}
}

func TestDeleteDesignation(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete || r.URL.Path != "/designations/1" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		w.WriteHeader(204)
	}))

	if err := client.DeleteDesignation(bgCtx, 1); err != nil {
		t.Fatal(err)
	}
}

func TestListBottles_IncludeConsumed(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("include_consumed") != "true" {
			t.Error("expected include_consumed=true")
		}
		w.Write([]byte(`[]`))
	}))

	_, err := client.ListBottles(bgCtx, true)
	if err != nil {
		t.Fatal(err)
	}
}

func TestListBottles_InStockOnly(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.RawQuery != "" {
			t.Errorf("expected no query params, got %s", r.URL.RawQuery)
		}
		w.Write([]byte(`[]`))
	}))

	_, err := client.ListBottles(bgCtx, false)
	if err != nil {
		t.Fatal(err)
	}
}

func TestGetBottleByTagID(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/bottles/by-tag/04A32BFF" {
			t.Errorf("unexpected path %s", r.URL.Path)
		}
		json.NewEncoder(w).Encode(Bottle{ID: 42, Vintage: 2019, Cuvee: Cuvee{ID: 1}})
	}))

	b, err := client.GetBottleByTagID(bgCtx, "04A32BFF")
	if err != nil {
		t.Fatal(err)
	}
	if b.ID != 42 {
		t.Errorf("got %+v", b)
	}
}

func TestConsumeBottle(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/bottles/consume" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		var req ConsumeRequest
		json.NewDecoder(r.Body).Decode(&req)
		if req.TagID != "04A32BFF" {
			t.Errorf("expected tag_id=04A32BFF, got %s", req.TagID)
		}
		consumed := "2026-04-01T18:00:00Z"
		json.NewEncoder(w).Encode(Bottle{ID: 42, ConsumedAt: &consumed, Cuvee: Cuvee{ID: 1}})
	}))

	b, err := client.ConsumeBottle(bgCtx, "04A32BFF")
	if err != nil {
		t.Fatal(err)
	}
	if b.ConsumedAt == nil {
		t.Error("expected consumed_at to be set")
	}
}

func TestUpdateBottle_PartialFields(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut || r.URL.Path != "/bottles/42" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		var m map[string]any
		json.NewDecoder(r.Body).Decode(&m)
		if m["vintage"] != float64(2020) {
			t.Errorf("expected vintage=2020, got %v", m["vintage"])
		}
		json.NewEncoder(w).Encode(Bottle{ID: 42, Vintage: 2020, Cuvee: Cuvee{ID: 1}})
	}))

	b, err := client.UpdateBottle(bgCtx, 42, map[string]any{"vintage": 2020})
	if err != nil {
		t.Fatal(err)
	}
	if b.Vintage != 2020 {
		t.Errorf("got vintage=%d", b.Vintage)
	}
}





func TestGetCompletions(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("field") != "designation" || r.URL.Query().Get("prefix") != "Mad" {
			t.Errorf("unexpected query: %s", r.URL.RawQuery)
		}
		json.NewEncoder(w).Encode(CompletionResponse{Values: []string{"Madiran"}})
	}))

	vals, err := client.GetCompletions(bgCtx, "designation", "Mad")
	if err != nil {
		t.Fatal(err)
	}
	if len(vals) != 1 || vals[0] != "Madiran" {
		t.Errorf("got %v", vals)
	}
}

// ── Scan coordination tests ─────────────────────────────────────────────────

func TestRequestScan(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/scan/request" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		w.WriteHeader(201)
		w.Write([]byte(`{"status":"requested"}`))
	}))

	if err := client.RequestScan(bgCtx); err != nil {
		t.Fatal(err)
	}
}

func TestGetScanResult_TagScanned(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"resolved","tag_id":"04A32BFF"}`))
	}))

	tag, err := client.GetScanResult(bgCtx)
	if err != nil {
		t.Fatal(err)
	}
	if tag != "04A32BFF" {
		t.Errorf("got %q", tag)
	}
}

func TestGetScanResult_Timeout(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(204)
	}))

	tag, err := client.GetScanResult(bgCtx)
	if err != nil {
		t.Fatal(err)
	}
	if tag != "" {
		t.Errorf("expected empty on timeout, got %q", tag)
	}
}

func TestGetScanResult_Cancelled(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Server returns 410 with {"status":"cancelled"} per REST contract.
		w.WriteHeader(410)
		w.Write([]byte(`{"status":"cancelled"}`))
	}))

	_, err := client.GetScanResult(bgCtx)
	if err != ErrScanCancelled {
		t.Errorf("expected ErrScanCancelled, got %v", err)
	}
}

func TestCancelScan(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/scan/cancel" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		w.Write([]byte(`{"status":"cancelled"}`))
	}))

	if err := client.CancelScan(bgCtx); err != nil {
		t.Fatal(err)
	}
}

// ── Context cancellation tests ──────────────────────────────────────────────

func TestContextCancellation(t *testing.T) {
	// Server that never responds — we cancel via context.
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		<-r.Context().Done()
	}))

	cancelCtx, cancel := context.WithCancel(context.Background())
	cancel() // cancel immediately

	_, err := client.ListDesignations(cancelCtx)
	if err == nil {
		t.Fatal("expected error from cancelled context")
	}
}

// ── Backup / Restore tests ──────────────────────────────────────────────────

func TestGetBackup(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/backup" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Write([]byte("fake-db-bytes"))
	}))

	rc, err := client.GetBackup(bgCtx)
	if err != nil {
		t.Fatal(err)
	}
	defer rc.Close()
	data, _ := io.ReadAll(rc)
	if string(data) != "fake-db-bytes" {
		t.Errorf("got %q", data)
	}
}

func TestRestore(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/restore" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		if r.Header.Get("Content-Type") != "application/octet-stream" {
			t.Errorf("unexpected content-type: %s", r.Header.Get("Content-Type"))
		}
		body, _ := io.ReadAll(r.Body)
		if string(body) != "fake-db-bytes" {
			t.Errorf("unexpected body: %q", body)
		}
		w.Write([]byte(`{"status":"restored"}`))
	}))

	err := client.Restore(bgCtx, strings.NewReader("fake-db-bytes"))
	if err != nil {
		t.Fatal(err)
	}
}

// ── Error handling tests ────────────────────────────────────────────────────

func TestErrorResponse_400(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(400)
		w.Write([]byte(`{"error":"invalid_argument","message":"name is required"}`))
	}))

	_, err := client.AddDesignation(bgCtx, CreateDesignation{})
	if err == nil {
		t.Fatal("expected error")
	}
	apiErr, ok := err.(*APIError)
	if !ok {
		t.Fatalf("expected *APIError, got %T: %v", err, err)
	}
	if apiErr.Code != "invalid_argument" {
		t.Errorf("got code=%s", apiErr.Code)
	}
}

func TestErrorResponse_404(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(404)
		w.Write([]byte(`{"error":"not_found","message":"bottle not found"}`))
	}))

	_, err := client.GetBottle(bgCtx, 999)
	if err == nil {
		t.Fatal("expected error")
	}
	apiErr, ok := err.(*APIError)
	if !ok {
		t.Fatalf("expected *APIError, got %T", err)
	}
	if apiErr.Code != "not_found" {
		t.Errorf("got code=%s", apiErr.Code)
	}
}

func TestErrorResponse_409(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(409)
		w.Write([]byte(`{"error":"already_exists","message":"name already exists"}`))
	}))

	_, err := client.AddDesignation(bgCtx, CreateDesignation{Name: "Madiran"})
	if err == nil {
		t.Fatal("expected error")
	}
	apiErr, ok := err.(*APIError)
	if !ok {
		t.Fatalf("expected *APIError, got %T", err)
	}
	if apiErr.Code != "already_exists" {
		t.Errorf("got code=%s", apiErr.Code)
	}
}

func TestErrorResponse_412(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(412)
		w.Write([]byte(`{"error":"failed_precondition","message":"referenced by cuvees"}`))
	}))

	err := client.DeleteDesignation(bgCtx, 1)
	if err == nil {
		t.Fatal("expected error")
	}
	apiErr, ok := err.(*APIError)
	if !ok {
		t.Fatalf("expected *APIError, got %T", err)
	}
	if apiErr.Code != "failed_precondition" {
		t.Errorf("got code=%s", apiErr.Code)
	}
}

// ── HealthCheck tests ────────────────────────────────────────────────────────

func TestHealthCheck_ReturnsResponse(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		w.Write([]byte(`{"status":"ok","last_consumed_at":1712000000}`))
	}))

	hr, err := client.HealthCheck(bgCtx)
	if err != nil {
		t.Fatal(err)
	}
	if hr.Status != "ok" {
		t.Errorf("got status=%q", hr.Status)
	}
	if hr.LastConsumedAt != 1712000000 {
		t.Errorf("got last_consumed_at=%d, want 1712000000", hr.LastConsumedAt)
	}
}

func TestHealthCheck_ZeroTimestamp(t *testing.T) {
	client, _ := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"ok","last_consumed_at":0}`))
	}))

	hr, err := client.HealthCheck(bgCtx)
	if err != nil {
		t.Fatal(err)
	}
	if hr.LastConsumedAt != 0 {
		t.Errorf("got last_consumed_at=%d, want 0", hr.LastConsumedAt)
	}
}

func TestHealthCheck_ServerDown(t *testing.T) {
	client := NewWineTapHTTPClient("http://127.0.0.1:1") // nothing listening
	_, err := client.HealthCheck(bgCtx)
	if err == nil {
		t.Fatal("expected error for unreachable server")
	}
}

func TestHealthResponseJSON(t *testing.T) {
	hr := HealthResponse{Status: "ok", LastConsumedAt: 1712000000}
	b, err := json.Marshal(hr)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"status":"ok","last_consumed_at":1712000000}`
	if string(b) != want {
		t.Errorf("got %s, want %s", b, want)
	}
}

// ── SetBaseURL tests ─────────────────────────────────────────────────────────

func TestWineTapHTTPClient_SetBaseURL(t *testing.T) {
	c := NewWineTapHTTPClient("http://old-address:8080")
	c.SetBaseURL("http://new-address:8080")
	if c.baseURL != "http://new-address:8080" {
		t.Errorf("expected updated baseURL, got %q", c.baseURL)
	}
}

func TestWineTapHTTPClient_SetBaseURL_TrimsSlash(t *testing.T) {
	c := NewWineTapHTTPClient("http://host:8080/")
	c.SetBaseURL("http://new-host:8080/")
	if c.baseURL != "http://new-host:8080" {
		t.Errorf("expected trimmed baseURL, got %q", c.baseURL)
	}
}
