# Story 2.4: Drill-Down Navigation to Filtered Inventory

Status: review

## Story

As a user,
I want to click a color or designation in the dashboard to see those specific bottles in the inventory,
so that I can act on insights without manual searching.

## Acceptance Criteria

1. `screen/ctx.go` defines `FilterByColor` and `FilterByDesignation` constants
2. `screen.Ctx` has a `NavigateToInventoryWithFilter(filterType string, filterValue string)` callback field
3. Clicking a non-zero color slice/legend row calls `ctx.NavigateToInventoryWithFilter(FilterByColor, identifier)`
4. Clicking a non-zero designation slice/legend row calls `ctx.NavigateToInventoryWithFilter(FilterByDesignation, identifier)`
5. "Autres" (Identifier="") and zero-count: no navigation (already handled by widget — non-clickable)
6. Click callbacks are nil-safe (check before calling — implementation comes in Story 2.5)

## Tasks / Subtasks

- [x] Task 1: Add filter constants and callback to Ctx (AC: #1, #2)
  - [x] In `screen/ctx.go`: add filter type constants `FilterByColor = "color"` and `FilterByDesignation = "designation"`
  - [x] In `screen/ctx.go`: add `NavigateToInventoryWithFilter func(filterType, filterValue string)` field to Ctx struct

- [x] Task 2: Wire color click callbacks in dashboard (AC: #3, #6)
  - [x] In `dashboard.go` BuildDashboardScreen, after color hover wiring:
  - [x] Set `s.colorPie.OnSliceClicked = func(id string) { s.navigateFiltered(FilterByColor, id) }`
  - [x] Set `s.colorLegend.OnRowClicked = func(id string) { s.navigateFiltered(FilterByColor, id) }`

- [x] Task 3: Wire designation click callbacks in dashboard (AC: #4, #6)
  - [x] In `dashboard.go` BuildDashboardScreen, after designation hover wiring:
  - [x] Set `s.desigPie.OnSliceClicked = func(id string) { s.navigateFiltered(FilterByDesignation, id) }`
  - [x] Set `s.desigLegend.OnRowClicked = func(id string) { s.navigateFiltered(FilterByDesignation, id) }`

- [x] Task 4: Add navigateFiltered helper method (AC: #6)
  - [x] Add `func (s *DashboardScreen) navigateFiltered(filterType, filterValue string)` to dashboard.go
  - [x] Nil-check `s.ctx.NavigateToInventoryWithFilter` before calling (callback is nil until Story 2.5 implements it)
  - [x] Call `s.ctx.NavigateToInventoryWithFilter(filterType, filterValue)` if non-nil

- [x] Task 5: Verify compilation and regression
  - [x] Build: `go build ./internal/manager/...`
  - [x] Run: `go test ./...`

## Dev Notes

### Modification Points

**ctx.go — add constants and callback field:**
```go
// Filter type constants for dashboard drill-down navigation.
const (
    FilterByColor       = "color"
    FilterByDesignation = "designation"
)

// In Ctx struct, add:
NavigateToInventoryWithFilter func(filterType, filterValue string)
```

**dashboard.go — add click wiring after hover wiring (existing from Story 2.2):**

After color hover wiring block:
```go
s.colorPie.OnSliceClicked = func(id string) { s.navigateFiltered(FilterByColor, id) }
s.colorLegend.OnRowClicked = func(id string) { s.navigateFiltered(FilterByColor, id) }
```

After designation hover wiring block:
```go
s.desigPie.OnSliceClicked = func(id string) { s.navigateFiltered(FilterByDesignation, id) }
s.desigLegend.OnRowClicked = func(id string) { s.navigateFiltered(FilterByDesignation, id) }
```

**dashboard.go — add helper method:**
```go
func (s *DashboardScreen) navigateFiltered(filterType, filterValue string) {
    if s.ctx.NavigateToInventoryWithFilter != nil {
        s.ctx.NavigateToInventoryWithFilter(filterType, filterValue)
    }
}
```

### Why Nil-Check on Callback

The `NavigateToInventoryWithFilter` callback is added to Ctx in this story but NOT implemented in `manager.go` until Story 2.5. Between these two stories, the callback field is nil in the Ctx struct literal in `makeCtx()`. The nil-check prevents a panic if someone runs the app before Story 2.5 is complete.

### Architecture Reference

Per architecture final clarifications:
- Filter constants defined in `screen/ctx.go` (alongside the callback)
- Dashboard passes `FilterByColor`/`FilterByDesignation` as filterType — never the filter value as filterType
- "Autres" entries have Identifier="" — widgets already block click callbacks for these (Stories 1.3/1.4)

### What This Story Does NOT Do

- Does NOT implement the callback in manager.go (Story 2.5)
- Does NOT add SetFilter to inventory (Story 2.5)
- Click callbacks will no-op (nil callback) until Story 2.5 wires the implementation

### References

- [Source: internal/manager/screen/ctx.go — current Ctx struct]
- [Source: internal/manager/screen/dashboard.go — current dashboard with hover wiring from Story 2.2]
- [Source: _bmad-output/planning-artifacts/architecture.md#Final Clarifications — filter type constants]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.4]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Added FilterByColor and FilterByDesignation constants to ctx.go
- Added NavigateToInventoryWithFilter callback field to Ctx struct
- Wired 4 click callbacks in dashboard.go: color pie/legend → FilterByColor, designation pie/legend → FilterByDesignation
- Added navigateFiltered helper with nil-check for safe operation before Story 2.5
- Compiles cleanly, all tests pass

### Change Log

- 2026-03-30: Story 2.4 implemented — filter constants, Ctx callback, dashboard click wiring

### File List

- `internal/manager/screen/ctx.go` (MODIFIED — added constants + callback field)
- `internal/manager/screen/dashboard.go` (MODIFIED — added click wiring + navigateFiltered method)
