package client

import (
	"errors"
	"fmt"
)

// ErrScanCancelled is returned by GetScanResult when the phone reports that
// the pending scan was cancelled (HTTP 410).
var ErrScanCancelled = errors.New("scan cancelled")

// Color constants matching the server's JSON values for Cuvee.Color.
const (
	ColorUnspecified  int32 = 0
	ColorRouge        int32 = 1
	ColorBlanc        int32 = 2
	ColorRose         int32 = 3
	ColorEffervescent int32 = 4
	ColorAutre        int32 = 5
)

// ── Entity types — match docs/rest-api-contracts.md JSON shapes ─────────────

// Designation represents an appellation (e.g. "Madiran", "Saint-Émilion").
type Designation struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Region      string `json:"region"`
	Description string `json:"description"`
	Picture     []byte `json:"picture,omitempty"`
}

// Domain represents a wine producer/estate.
type Domain struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
}

// Cuvee represents a specific wine from a domain, optionally linked to a
// designation.  Response-only denormalized fields (DomainName, DesignationName,
// Region) are populated by the server.
type Cuvee struct {
	ID              int64  `json:"id"`
	Name            string `json:"name"`
	DomainID        int64  `json:"domain_id"`
	DesignationID   int64  `json:"designation_id"`
	Color           int32  `json:"color"`
	Description     string `json:"description"`
	DomainName      string `json:"domain_name"`
	DesignationName string `json:"designation_name"`
	Region          string `json:"region"`
}

// Bottle represents a physical bottle in the cellar.  Nullable fields use
// pointer types so they are omitted from JSON when nil.
type Bottle struct {
	ID            int64    `json:"id"`
	TagID         *string  `json:"tag_id,omitempty"`
	CuveeID       int64    `json:"cuvee_id"`
	Vintage       int32    `json:"vintage"`
	Description   string   `json:"description"`
	PurchasePrice *float64 `json:"purchase_price,omitempty"`
	DrinkBefore   *int32   `json:"drink_before,omitempty"`
	AddedAt       string   `json:"added_at"`
	ConsumedAt    *string  `json:"consumed_at,omitempty"`
	Cuvee         Cuvee    `json:"cuvee"`
}

// ── Error type ──────────────────────────────────────────────────────────────

// APIError is the structured error returned by the phone server for non-2xx
// responses.  The JSON field name "error" matches the server convention.
type APIError struct {
	Code    string `json:"error"`
	Message string `json:"message"`
}

func (e *APIError) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// ── Request types — used when creating or updating entities ─────────────────

// CreateDesignation is the request body for POST /designations and PUT /designations/:id.
type CreateDesignation struct {
	Name        string `json:"name"`
	Region      string `json:"region"`
	Description string `json:"description"`
	Picture     []byte `json:"picture,omitempty"`
}

// CreateDomain is the request body for POST /domains and PUT /domains/:id.
type CreateDomain struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

// CreateCuvee is the request body for POST /cuvees and PUT /cuvees/:id.
type CreateCuvee struct {
	Name          string `json:"name"`
	DomainID      int64  `json:"domain_id"`
	DesignationID int64  `json:"designation_id"`
	Color         int32  `json:"color"`
	Description   string `json:"description"`
}

// CreateBottle is the request body for POST /bottles.
type CreateBottle struct {
	TagID         *string  `json:"tag_id,omitempty"`
	CuveeID       int64    `json:"cuvee_id"`
	Vintage       int32    `json:"vintage"`
	Description   string   `json:"description"`
	PurchasePrice *float64 `json:"purchase_price,omitempty"`
	DrinkBefore   *int32   `json:"drink_before,omitempty"`
}



// ConsumeRequest is the request body for POST /bottles/consume.
type ConsumeRequest struct {
	TagID string `json:"tag_id"`
}

// ScanRequest is the request body for POST /scan/request.
// No mode field — every scan is a single read. Manager loops for bulk intake.
type ScanRequest struct{}

// ScanResult is the response body for GET /scan/result (200).
type ScanResult struct {
	Status string `json:"status"`
	TagID  string `json:"tag_id"`
}


// HealthResponse is the response body for GET /.
type HealthResponse struct {
	Status         string `json:"status"`
	LastConsumedAt int64  `json:"last_consumed_at"`
}

// CompletionResponse is the response body for GET /completions.
type CompletionResponse struct {
	Values []string `json:"values"`
}
