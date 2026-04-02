# Story 6.3: Rewire Manager Screens for HTTP

Status: done

## Story

As a user,
I want all manager screens to work with the phone's HTTP API,
So that I can browse inventory and manage the catalog as before.

**Note:** This is the largest story in Epic 6 — mechanical refactoring of all screen files from gRPC to HTTP. Same pattern repeated across files.

## Acceptance Criteria

1. **Given** `screen/ctx.go` updated to use `WineTapHTTPClient` instead of `v1.WineTapClient`
   **When** any manager screen operation is performed
   **Then** inventory screen lists bottles via HTTP `GET /bottles`
   **And** inventory form creates/updates bottles via HTTP `POST/PUT`
   **And** designation/domain/cuvee management screens work via HTTP
   **And** autocomplete fields use `GET /completions`
   **And** all existing manager functionality preserved — identical behavior

2. **Given** gRPC removal complete
   **When** `go build ./...` is run
   **Then** `v1.NewWineTapClient`, proto imports removed from manager
   **And** `gen/winetap/v1` import removed from all screen files
   **And** `google.golang.org/protobuf/types/known/fieldmaskpb` import removed from helpers.go
   **And** manager builds and all tests pass

3. **Given** INAO refresh button in Settings
   **When** refactoring is complete
   **Then** "Actualiser depuis data.gouv.fr" button is hidden/disabled (RefreshDesignations not in REST API — deferred)

## Tasks / Subtasks

- [x] Task 1: Create shared `internal/client` package to break circular import (AC: #2)
  - [x] 1.1 Create `internal/client/` directory
  - [x] 1.2 Move `internal/manager/api_types.go` → `internal/client/api_types.go` (change package to `client`)
  - [x] 1.3 Move `internal/manager/http_client.go` → `internal/client/http_client.go` (change package to `client`)
  - [x] 1.4 Move `internal/manager/http_client_test.go` → `internal/client/http_client_test.go`
  - [x] 1.5 Update `go.mod` module path references if needed (no new deps — all stdlib)
  - [x] 1.6 Update `internal/manager/manager.go` imports to use `winetap/internal/client`
  - [x] 1.7 Verify `go build ./...` passes after move

- [x] Task 2: Replace `v1.Color` enum with `int32` constants (AC: #2)
  - [x] 2.1 Add color constants to `internal/client/api_types.go`:
    ```go
    const (
        ColorUnspecified  int32 = 0
        ColorRouge        int32 = 1
        ColorBlanc        int32 = 2
        ColorRose         int32 = 3
        ColorEffervescent int32 = 4
        ColorAutre        int32 = 5
    )
    ```
  - [x] 2.2 Update `screen/helpers.go`: change `colorNames map[v1.Color]string` → `map[int32]string`, `colorOrder []v1.Color` → `[]int32`, use new constants from `client` package
  - [x] 2.3 Update `widget/aggregate.go`: same color type changes

- [x] Task 3: Update `screen/ctx.go` (AC: #1, #2)
  - [x] 3.1 Remove `v1 "winetap/gen/winetap/v1"` import
  - [x] 3.2 Replace `Client v1.WineTapClient` with `Client *client.WineTapHTTPClient`
  - [x] 3.3 Remove `context` import (HTTP client methods handle context internally)
  - [x] 3.4 Update `SettingsData` — no change needed here; Settings rewiring is in Task 9

- [x] Task 4: Update `screen/helpers.go` (AC: #2)
  - [x] 4.1 Remove `v1 "winetap/gen/winetap/v1"` import
  - [x] 4.2 Remove `google.golang.org/protobuf/types/known/fieldmaskpb` import
  - [x] 4.3 Delete `fieldMask()` function — HTTP uses `map[string]any` partial updates
  - [x] 4.4 Update `colorNames` and `colorOrder` to use `int32` + client constants (Task 2)
  - [x] 4.5 Add `import "winetap/internal/client"`

- [x] Task 5: Rewire `screen/inventory.go` (AC: #1)
  - [x] 5.1 Change `allBottles []*v1.Bottle` → `allBottles []client.Bottle`
  - [x] 5.2 `refreshThen`: replace `ctx.Client.ListBottles(ctx, &v1.ListBottlesRequest{IncludeConsumed: ...})` → `ctx.Client.ListBottles(includeConsumed)` — returns `([]client.Bottle, error)` directly
  - [x] 5.3 `populateFlat`/`populateGrouped`: change `b.Cuvee.Color` from `v1.Color` to `int32`; `b.AddedAt` from `*timestamppb.Timestamp` to `string` (RFC 3339, always set — remove nil guard, parse directly); `b.TagID` (was `b.TagId`)
  - [x] 5.4 `addBottle`: replace proto request `&v1.AddBottleRequest{...}` with `client.CreateBottle{TagID: f.epc, CuveeID: cuveeID, ...}`; response returns `(client.Bottle, error)` not `(v1.Bottle, error)`
  - [x] 5.5 `updateBottle`: replace `&v1.UpdateBottleRequest{Id: id, Fields: fields, Mask: fieldMask(...)}` with `client.UpdateBottle(id, map[string]any{"cuvee_id": cuveeID, "vintage": ..., ...})` — partial update via map
  - [x] 5.6 `onDelete`: replace `&v1.DeleteBottleRequest{Id: b.Id}` → `client.DeleteBottle(b.ID)`
  - [x] 5.7 `onConsumeBottle`: replace `&v1.ConsumeBottleRequest{TagId: epc}` → `client.ConsumeBottle(epc)`
  - [x] 5.8 `createInlineCuveeThenSave`: replace all inline gRPC calls (AddDomain, AddDesignation, AddCuvee) with HTTP client equivalents; note `dom.Id` → `dom.ID`
  - [x] 5.9 `addBottleFrom`: template is now `client.Bottle` (not `*v1.Bottle`)
  - [x] 5.10 `firstBottleAtGroupedRow`: `b.Cuvee.Color` → `int32`, use `colorNames[b.Cuvee.Color]`
  - [x] 5.11 `onSearchByTag`: `b.TagId` → `b.TagID`
  - [x] 5.12 Remove `colorIdentifiers` map keyed on `v1.Color` — rekey on `int32` using client constants
  - [x] 5.13 Remove `v1` import, add `client` import
  - [x] 5.14 Fix `rebuildDesigList`: `b.GetCuvee().GetDesignationName()` → `b.Cuvee.DesignationName` (no proto getters needed)

- [x] Task 6: Rewire `screen/inventory_form.go` (AC: #1)
  - [x] 6.1 Change `allCuvees []*v1.Cuvee` → `allCuvees []client.Cuvee`
  - [x] 6.2 `loadData`: replace `ctx.Client.ListCuvees(ctx, &v1.ListCuveesRequest{})` etc. with `client.ListCuvees()`, `client.ListDomains()`, `client.ListDesignations()`
  - [x] 6.3 `setCuvees`: change type from `[]*v1.Cuvee` to `[]client.Cuvee`; `c.DomainName` and `c.Name` are same field names ✓
  - [x] 6.4 `loadBottle(b *v1.Bottle)` → `loadBottle(b client.Bottle)` (value not pointer — new struct is not a proto)
  - [x] 6.5 `loadBottle`: `b.TagId` → `b.TagID`; `b.AddedAt.AsTime().Local().Format(...)` → `parseRFC3339(b.AddedAt).Local().Format(...)`; `b.ConsumedAt.AsTime()` → `parseRFC3339(*b.ConsumedAt)` 
  - [x] 6.6 `selectedCuveeID`: `f.allCuvees[i].Id` → `f.allCuvees[i].ID`
  - [x] 6.7 Add local helper: `func parseRFC3339(s string) time.Time { t, _ := time.Parse(time.RFC3339, s); return t }`
  - [x] 6.8 `setDomains`/`setDesignations` on inlineCuveeForm: type changes from `[]*v1.Domain` to `[]client.Domain`
  - [x] 6.9 Remove `v1` import, add `client` import

- [x] Task 7: Rewire `screen/designations.go` (AC: #1)
  - [x] 7.1 Change `crudBase[*v1.Designation]` → `crudBase[client.Designation]`
  - [x] 7.2 `listFn`: `ctx.Client.ListDesignations(c, &v1.ListDesignationsRequest{})` → `ctx.Client.ListDesignations()` (returns `[]client.Designation` directly)
  - [x] 7.3 `delFn`: `ctx.Client.DeleteDesignation(c, &v1.DeleteDesignationRequest{Id: d.Id})` → `ctx.Client.DeleteDesignation(d.ID)`
  - [x] 7.4 `onAdd`: `ctx.Client.AddDesignation(ctx, &v1.AddDesignationRequest{...})` → `ctx.Client.AddDesignation(client.CreateDesignation{...})`
  - [x] 7.5 `onUpdate`: similarly use `client.UpdateDesignation(id, client.CreateDesignation{...})`
  - [x] 7.6 `openEditForm(d *v1.Designation)` → `openEditForm(d client.Designation)` (value not pointer)
  - [x] 7.7 `desigForm.populate(d *v1.Designation)` → `populate(d client.Designation)` — note: `d.Picture` removed (not in REST API); hide/remove picture upload section from designation form OR keep UI but skip sending picture
  - [x] 7.8 Remove `v1` import, add `client` import

- [x] Task 8: Rewire `screen/domains.go` (AC: #1)
  - [x] 8.1 Change `crudBase[*v1.Domain]` → `crudBase[client.Domain]`
  - [x] 8.2 `listFn`: `ctx.Client.ListDomains(c, &v1.ListDomainsRequest{})` → `ctx.Client.ListDomains()`
  - [x] 8.3 `delFn`: `ctx.Client.DeleteDomain(c, &v1.DeleteDomainRequest{Id: d.Id})` → `ctx.Client.DeleteDomain(d.ID)`
  - [x] 8.4 `onAdd`: `&v1.AddDomainRequest{Name: name, Description: description}` → `client.CreateDomain{Name: name, Description: description}`
  - [x] 8.5 `onUpdate`: similarly use HTTP client
  - [x] 8.6 `openEditForm(d *v1.Domain)` → `openEditForm(d client.Domain)`
  - [x] 8.7 Remove `v1` import, add `client` import

- [x] Task 9: Rewire `screen/cuvees.go` (AC: #1)
  - [x] 9.1 Change `crudBase[*v1.Cuvee]` → `crudBase[client.Cuvee]`
  - [x] 9.2 `allDomains []*v1.Domain` → `[]client.Domain` in cuveeForm
  - [x] 9.3 `allDesig []*v1.Designation` → `[]client.Designation` in cuveeForm
  - [x] 9.4 `listFn`: `ctx.Client.ListCuvees(c, &v1.ListCuveesRequest{})` → `ctx.Client.ListCuvees()`
  - [x] 9.5 `loadCombos`: replace `ListDomains`/`ListDesignations` gRPC calls with HTTP client
  - [x] 9.6 `delFn`: `ctx.Client.DeleteCuvee(c, &v1.DeleteCuveeRequest{Id: cv.Id})` → `ctx.Client.DeleteCuvee(cv.ID)`
  - [x] 9.7 `onSave` goroutine: replace all `AddDomain`, `AddDesignation`, `AddCuvee`, `UpdateCuvee` calls
  - [x] 9.8 `cuveeForm.Color()` return type: `v1.Color` → `int32`
  - [x] 9.9 `cuveeForm.load(c *v1.Cuvee)` → `load(c client.Cuvee)`; color index lookup: same logic, now comparing int32
  - [x] 9.10 `setDomains([]*v1.Domain)` → `setDomains([]client.Domain)`, `setDesignations([]*v1.Designation)` → `setDesignations([]client.Designation)`
  - [x] 9.11 `DomainIDFor` / `DesignationIDFor`: `d.Id` → `d.ID`
  - [x] 9.12 `populate`: `c.Id` → `c.ID`, `c.Color` is now `int32` (colorNames map still works)
  - [x] 9.13 Remove `v1` import, add `client` import

- [x] Task 10: Rewire `screen/dashboard.go` (AC: #1)
  - [x] 10.1 `s.ctx.Client.ListBottles(ctx, &v1.ListBottlesRequest{})` → `s.ctx.Client.ListBottles(false)` (in-stock only)
  - [x] 10.2 `inStock []*v1.Bottle` → `inStock []client.Bottle`; `b.ConsumedAt == nil` stays ✓
  - [x] 10.3 `widget.AggregateByColor(inStock)` / `AggregateByDesignation(inStock)` — update signatures to accept `[]client.Bottle`
  - [x] 10.4 Remove `v1` import, add `client` import

- [x] Task 11: Update `widget/aggregate.go` (AC: #2)
  - [x] 11.1 Replace `[]*v1.Bottle` → `[]client.Bottle` in `AggregateByColor`/`AggregateByDesignation`
  - [x] 11.2 Replace `v1.Color` with `int32` in color maps; use `client.ColorRouge` etc. constants
  - [x] 11.3 Remove `v1` import, add `client` import

- [x] Task 12: Update `screen/settings.go` (AC: #3)
  - [x] 12.1 Hide/disable the "Actualiser depuis data.gouv.fr" button (INAO refresh not in REST API)
  - [x] 12.2 Remove `s.ctx.Client.RefreshDesignations(...)` call — replace with a TODO comment
  - [x] 12.3 Remove context/v1 imports from settings.go if no longer needed

- [x] Task 13: Update `internal/manager/manager.go` (AC: #2)
  - [x] 13.1 Remove gRPC imports: `google.golang.org/grpc`, `google.golang.org/grpc/credentials/insecure`, `winetap/gen/winetap/v1`
  - [x] 13.2 Remove `conn *grpc.ClientConn`, `client v1.WineTapClient` fields
  - [x] 13.3 Replace `grpc.NewClient(...)` + `v1.NewWineTapClient(conn)` with `client.NewWineTapHTTPClient(phoneAddr)` (phoneAddr from Story 6.2)
  - [x] 13.4 Remove `subscribeEvents` goroutine and `unackEvents`/events related code — replaced by Story 6.2's HTTP health check
  - [x] 13.5 Remove `conn.Close()` from `Close()`
  - [x] 13.6 Pass `*client.WineTapHTTPClient` as `Ctx.Client` in `makeCtx()`
  - [x] 13.7 NFCScanner currently wraps `v1.WineTapClient` — stub it out (Story 6.4 rewrites it); for now, pass nil or a no-op

- [x] Task 14: Final verification (AC: #1, #2)
  - [x] 14.1 `go build ./...` passes with zero errors
  - [x] 14.2 `go vet ./...` passes
  - [x] 14.3 `go test ./...` passes
  - [x] 14.4 Smoke-test: manager starts, connects to phone (or shows "unreachable" if phone offline), all screens accessible

## Dev Notes

### Critical: Circular Import Problem — Solve First

The current `screen/ctx.go` holds `Client v1.WineTapClient` (a gRPC interface from `gen/winetap/v1`). Story 6.1 created `WineTapHTTPClient` in `internal/manager/` package.

**Problem:** `manager` imports `screen` (to build screens). If `screen` imports `manager` (to get `WineTapHTTPClient`) → **circular import**.

**Solution — Task 1 (MUST DO FIRST):** Move `api_types.go` and `http_client.go` from `internal/manager/` to a new `internal/client/` package. Both `manager` and `screen` can then import `internal/client` independently.

```
internal/
├── client/              # NEW — shared between manager and screen
│   ├── api_types.go     # Designation, Domain, Cuvee, Bottle, APIError, request types
│   ├── http_client.go   # WineTapHTTPClient
│   └── http_client_test.go
├── manager/
│   ├── manager.go       # imports internal/client
│   ├── config.go
│   └── screen/
│       ├── ctx.go       # Client *client.WineTapHTTPClient — imports internal/client
│       ├── inventory.go  # imports internal/client
│       └── ...
└── widget/
    └── aggregate.go     # imports internal/client
```

### Type Migration Reference

| Old (proto) | New (client) | Notes |
|------------|-------------|-------|
| `*v1.Bottle` | `client.Bottle` | Value, not pointer |
| `*v1.Cuvee` | `client.Cuvee` | Value, not pointer |
| `*v1.Domain` | `client.Domain` | Value, not pointer |
| `*v1.Designation` | `client.Designation` | Value, not pointer |
| `v1.Color` (enum) | `int32` | Constants: `client.ColorRouge=1`, etc. |
| `b.Id` | `b.ID` | Go convention: `ID` not `Id` |
| `b.TagId` | `b.TagID` | Go convention: `TagID` not `TagId` |
| `b.CuveeId` | `b.CuveeID` | |
| `b.AddedAt *timestamppb.Timestamp` | `b.AddedAt string` | RFC 3339, always set (required field) |
| `b.AddedAt.AsTime()` | `parseRFC3339(b.AddedAt)` | Add helper in inventory_form.go |
| `b.ConsumedAt *timestamppb.Timestamp` | `b.ConsumedAt *string` | Nil check same ✓ |
| `b.ConsumedAt.AsTime()` | `parseRFC3339(*b.ConsumedAt)` | |
| `b.DrinkBefore *int32` | `b.DrinkBefore *int32` | Same ✓ |
| `b.PurchasePrice *float64` | `b.PurchasePrice *float64` | Same ✓ |
| `d.Picture []byte` | ❌ removed from REST API | Hide picture upload UI |

### gRPC → HTTP Method Call Mapping

| gRPC call | HTTP client method |
|-----------|-------------------|
| `Client.ListDesignations(ctx, &v1.ListDesignationsRequest{})` → `resp.Designations` | `Client.ListDesignations()` → `[]Designation, error` |
| `Client.AddDesignation(ctx, &v1.AddDesignationRequest{Name: n, Region: r, Description: d})` | `Client.AddDesignation(CreateDesignation{Name: n, Region: r, Description: d})` |
| `Client.UpdateDesignation(ctx, &v1.UpdateDesignationRequest{Id: id, ...})` | `Client.UpdateDesignation(id, CreateDesignation{...})` |
| `Client.DeleteDesignation(ctx, &v1.DeleteDesignationRequest{Id: id})` | `Client.DeleteDesignation(id)` |
| `Client.ListDomains(ctx, &v1.ListDomainsRequest{})` → `resp.Domains` | `Client.ListDomains()` |
| `Client.AddDomain(ctx, &v1.AddDomainRequest{...})` → `dom.Id` | `Client.AddDomain(CreateDomain{...})` → `dom.ID` |
| `Client.ListCuvees(ctx, &v1.ListCuveesRequest{})` → `resp.Cuvees` | `Client.ListCuvees()` |
| `Client.AddCuvee(ctx, &v1.AddCuveeRequest{...})` | `Client.AddCuvee(CreateCuvee{...})` |
| `Client.UpdateCuvee(ctx, &v1.UpdateCuveeRequest{...})` | `Client.UpdateCuvee(id, CreateCuvee{...})` |
| `Client.DeleteCuvee(ctx, &v1.DeleteCuveeRequest{Id: id})` | `Client.DeleteCuvee(id)` |
| `Client.ListBottles(ctx, &v1.ListBottlesRequest{IncludeConsumed: b})` → `resp.Bottles` | `Client.ListBottles(includeConsumed bool)` |
| `Client.AddBottle(ctx, &v1.AddBottleRequest{...})` → `bottle.Id` | `Client.AddBottle(CreateBottle{...})` → `bottle.ID` |
| `Client.UpdateBottle(ctx, &v1.UpdateBottleRequest{Id: id, Fields: f, Mask: m})` | `Client.UpdateBottle(id, map[string]any{"cuvee_id": ..., "vintage": ...})` |
| `Client.DeleteBottle(ctx, &v1.DeleteBottleRequest{Id: id})` | `Client.DeleteBottle(id)` |
| `Client.ConsumeBottle(ctx, &v1.ConsumeBottleRequest{TagId: epc})` | `Client.ConsumeBottle(epc)` |
| `Client.RefreshDesignations(ctx, ...)` | ❌ Not in REST API — remove/disable |

### Partial Updates: `UpdateBottle` — CRITICAL

Old pattern (gRPC with FieldMask):
```go
fields := &v1.BottleFields{
    CuveeId:     cuveeID,
    Vintage:     int32(f.vintageSpin.Value()),
    Description: f.descEdit.ToPlainText(),
}
paths := []string{"cuvee_id", "vintage", "description"}
_, err := s.ctx.Client.UpdateBottle(ctx, &v1.UpdateBottleRequest{
    Id: id, Fields: fields, Mask: fieldMask(paths...),
})
```

New pattern (HTTP with `map[string]any`):
```go
updates := map[string]any{
    "cuvee_id":    cuveeID,
    "vintage":     int32(f.vintageSpin.Value()),
    "description": f.descEdit.ToPlainText(),
}
if p := parseOptFloat(f.priceEdit.Text()); p != nil {
    updates["purchase_price"] = *p
} else {
    updates["purchase_price"] = nil // explicit null = clear
}
if v := f.drinkSpin.Value(); v > 0 {
    updates["drink_before"] = int32(v)
} else {
    updates["drink_before"] = nil // explicit null = clear
}
_, err := s.ctx.Client.UpdateBottle(id, updates)
```

Per REST API contract: absent = don't update, explicit `null` = clear value. Use `map[string]any` to support this pattern.

### Timestamp Parsing

`AddedAt` is now always a non-nil `string` in RFC 3339 format. Replace nil guard with direct parse:
```go
// OLD:
if b.AddedAt != nil {
    t := b.AddedAt.AsTime().Local()
    addedAtText = t.Format("02/01/2006")
}

// NEW:
if b.AddedAt != "" {
    if t, err := time.Parse(time.RFC3339, b.AddedAt); err == nil {
        addedAtText = t.Local().Format("02/01/2006")
        addedAtSortKey = t.UTC().Format(time.RFC3339)
    }
}
```

### Color Handling

Replace all `v1.Color_COLOR_*` references with `int32` constants from `client` package:

```go
// client/api_types.go — ADD these constants
const (
    ColorUnspecified  int32 = 0
    ColorRouge        int32 = 1
    ColorBlanc        int32 = 2
    ColorRose         int32 = 3
    ColorEffervescent int32 = 4
    ColorAutre        int32 = 5
)
```

```go
// screen/helpers.go — CHANGE these maps
var colorNames = map[int32]string{
    client.ColorRouge:        "Rouge",
    client.ColorBlanc:        "Blanc",
    client.ColorRose:         "Rosée",
    client.ColorEffervescent: "Effervescent",
    client.ColorAutre:        "Autre",
}

var colorOrder = []int32{
    client.ColorBlanc,
    client.ColorRouge,
    client.ColorRose,
    client.ColorEffervescent,
    client.ColorAutre,
}
```

### Designation Picture Field

`Designation.Picture []byte` is NOT in the REST API contract (excluded for MVP — see `docs/rest-api-contracts.md`):
> "Note: `picture` (BLOB) excluded from JSON API for MVP."

**Decision:** Keep the picture upload UI in the settings form for now but silently skip sending/receiving it. The `client.Designation` struct has no `Picture` field. When `designationForm.populate(d)` is called, just don't set the picture. When saving, don't include it. The UI elements stay but are functionally inert.

This preserves UI continuity for a potential future REST endpoint.

### NFCScanner Stub (Task 13.7)

`NFCScanner` currently wraps `v1.WineTapClient` for gRPC coordination. Story 6.4 rewrites it for HTTP. For this story:

```go
// In manager.go: when creating NFC scanner, use a stub/nil
// The screen Scanner.StartScan callback will gracefully do nothing
if cfg.ScanMode == "nfc" {
    // Story 6.4 will create NewNFCScanner(httpClient, log)
    // For now, fall back to RFID scanner with a log warning
    log.Warn("NFC scan mode not yet available with HTTP client — using RFID")
    scanner = rfid
}
```

This avoids breaking the NFC scanner while the gRPC client is removed.

### Files to Create/Modify

| File | Action | Key Changes |
|------|--------|-------------|
| `internal/client/api_types.go` | CREATE (move from manager) | Package renamed to `client`; add Color constants |
| `internal/client/http_client.go` | CREATE (move from manager) | Package renamed to `client` |
| `internal/client/http_client_test.go` | CREATE (move from manager) | Package renamed to `client` |
| `internal/manager/manager.go` | MODIFY | Remove gRPC; use HTTP client; remove subscribeEvents |
| `internal/manager/screen/ctx.go` | MODIFY | `Client *client.WineTapHTTPClient` |
| `internal/manager/screen/helpers.go` | MODIFY | Remove v1/fieldmaskpb; int32 colors |
| `internal/manager/screen/inventory.go` | MODIFY | All v1 → client type replacements |
| `internal/manager/screen/inventory_form.go` | MODIFY | All v1 → client type replacements |
| `internal/manager/screen/designations.go` | MODIFY | All v1 → client type replacements |
| `internal/manager/screen/domains.go` | MODIFY | All v1 → client type replacements |
| `internal/manager/screen/cuvees.go` | MODIFY | All v1 → client type replacements |
| `internal/manager/screen/dashboard.go` | MODIFY | ListBottles → HTTP |
| `internal/manager/screen/settings.go` | MODIFY | Disable INAO refresh button |
| `internal/manager/widget/aggregate.go` | MODIFY | `[]*v1.Bottle` → `[]client.Bottle` |

### Anti-Patterns to Avoid

- Do NOT leave any `import v1 "winetap/gen/winetap/v1"` in screen or widget files after this story
- Do NOT create circular import: screen must NOT import manager package
- Do NOT use `print()` — slog only
- Do NOT block Qt main thread — all client calls stay in goroutines, Qt updates via `mainthread.Start()`
- Do NOT remove the picture upload UI elements — keep them but functionally skip picture data
- Do NOT change the UI behavior or French strings — identical UX, different transport
- Do NOT use `context.Background()` as a parameter to HTTP client methods — the HTTP client manages its own context internally (Story 6.1 design)

### Project Structure Notes

- `internal/client/` is a new shared package — the only structural change
- All screen files are modifications only — no new screen files
- All gRPC generated code (`gen/winetap/v1/`) stays on disk but is no longer imported by screens (it's still used by NFCScanner until Story 6.4 rewrites it — but after manager.go removes the gRPC client, the gen code becomes dead until fully removed in Story 6.4/5.6)

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 6.3] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Go Manager HTTP Client Pattern] — type patterns
- [Source: docs/rest-api-contracts.md] — all 27 routes, exact field names, partial update convention
- [Source: _bmad-output/implementation-artifacts/6-1-go-http-client-and-api-types.md] — WineTapHTTPClient methods, struct names (WineTapHTTPClient, ID not Id)
- [Source: internal/manager/screen/inventory.go] — current gRPC call patterns, v1.Bottle usage
- [Source: internal/manager/screen/inventory_form.go] — loadBottle, timestamp parsing
- [Source: internal/manager/screen/designations.go] — listFn/delFn/onAdd/onUpdate patterns (shared with domains/cuvees via crudBase)
- [Source: internal/manager/screen/helpers.go:47-62] — colorNames/colorOrder maps to migrate
- [Source: internal/manager/screen/dashboard.go] — ListBottles call + widget.Aggregate usage
- [Source: internal/manager/widget/aggregate.go] — v1.Bottle/v1.Color usage to update

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — clean build first attempt after fixing Index2 → IndexFromItem in onSearchByTag.

### Completion Notes List

- Fixed `s.ts.SrcModel.Index2` (no such method on QStandardItemModel) → `s.ts.SrcModel.IndexFromItem(s.ts.SrcModel.Item2(row, 0))` in inventory.go onSearchByTag.
- INAO refresh button disabled with tooltip; `onRefreshINAO` method removed entirely along with context/fmt/mainthread imports from settings.go.
- aggregate_test.go updated in parallel with aggregate.go (same v1→client.Bottle migration).
- All AC met: `go build ./...` and `go test ./...` both pass with zero errors.

### File List

- `internal/client/api_types.go` — created (moved from internal/manager/, package client, added Color constants)
- `internal/client/http_client.go` — created (moved from internal/manager/, package client)
- `internal/client/http_client_test.go` — created (merged http_client_test + SetBaseURL tests)
- `internal/manager/api_types.go` — deleted
- `internal/manager/http_client.go` — deleted
- `internal/manager/http_client_test.go` — deleted
- `internal/manager/nfc_scanner.go` — rewritten as no-op stub (v1 removed)
- `internal/manager/manager.go` — rewritten (gRPC removed, HTTP client wired)
- `internal/manager/screen/ctx.go` — updated (Client *client.WineTapHTTPClient)
- `internal/manager/screen/helpers.go` — updated (v1/fieldmaskpb removed, int32 colors)
- `internal/manager/screen/inventory.go` — rewired to HTTP client types
- `internal/manager/screen/inventory_form.go` — rewired to HTTP client types
- `internal/manager/screen/designations.go` — rewired to HTTP client types
- `internal/manager/screen/domains.go` — rewired to HTTP client types
- `internal/manager/screen/cuvees.go` — rewired to HTTP client types
- `internal/manager/screen/dashboard.go` — rewired to HTTP client
- `internal/manager/screen/settings.go` — INAO button disabled, v1 removed
- `internal/manager/widget/aggregate.go` — migrated to []client.Bottle
- `internal/manager/widget/aggregate_test.go` — migrated to []client.Bottle
