# Story 2.5: Inventory Screen Filter Integration

Status: review

## Story

As a user,
I want the inventory screen to display filtered results when navigated from the dashboard,
so that drill-down shows exactly the bottles I'm interested in.

## Acceptance Criteria

1. `inventory.go` has a `SetFilter(filterType, filterValue string)` method
2. `SetFilter` triggers a fresh `ListBottles` gRPC call via goroutine + mainthread.Start
3. Filter applied client-side to fresh results — only matching bottles displayed
4. Zero matching bottles shows normal empty inventory table
5. Navigating away from filtered inventory and returning clears the filter (not persisted)
6. `manager.go` implements the `NavigateToInventoryWithFilter` callback: navigates to inventory + calls SetFilter
7. Full end-to-end: dashboard click → filtered inventory works

## Tasks / Subtasks

- [x] Task 1: Add SetFilter method to InventoryScreen (AC: #1, #2, #3, #4, #5)
  - [x] Add `colorIdentifiers` map (Color enum → identifier string) in inventory.go
  - [x] Implement `func (s *InventoryScreen) SetFilter(filterType, filterValue string)`
  - [x] SetFilter calls `refreshThen` with a callback that filters allBottles and re-populates
  - [x] Implement `matchesFilter` helper for color and designation matching
  - [x] For `FilterByColor`: maps Color enum via colorIdentifiers, handles UNSPECIFIED → "autre"
  - [x] For `FilterByDesignation`: matches `GetDesignationName()` directly
  - [x] After filtering: call `s.populate(filtered)` to display only matching bottles
  - [x] Filter is one-shot via refreshThen callback — no persistent state

- [x] Task 2: Ensure OnActivate clears any filter state (AC: #5)
  - [x] Verified: OnActivate → refresh() → refreshThen(nil) → populate(allBottles) — shows all bottles, no filter state
  - [x] No changes needed — OnActivate naturally resets to full display

- [x] Task 3: Implement NavigateToInventoryWithFilter callback in manager.go (AC: #6)
  - [x] In `makeCtx()`: added `NavigateToInventoryWithFilter` callback
  - [x] Callback: `navigate(idxInv)` then `inv.SetFilter(filterType, filterValue)`

- [x] Task 4: Verify compilation and full regression
  - [x] Build: `go build ./internal/manager/...` — passes
  - [x] Run: `go test ./...` — all tests pass
  - [ ] Build: `go build ./internal/manager/...`
  - [ ] Run: `go test ./...`

## Dev Notes

### Filter Implementation Strategy

**Option A (Simple — recommended):** SetFilter stores filter params, calls refreshThen with a post-refresh callback that filters allBottles and re-populates.

```go
func (s *InventoryScreen) SetFilter(filterType, filterValue string) {
    s.refreshThen(func() {
        var filtered []*v1.Bottle
        for _, b := range s.allBottles {
            if matchesFilter(b, filterType, filterValue) {
                filtered = append(filtered, b)
            }
        }
        s.populate(filtered)
    })
}
```

This uses the existing `refreshThen` mechanism — fetches fresh data, then applies filter in the callback.

**matchesFilter helper:**
```go
func matchesFilter(b *v1.Bottle, filterType, filterValue string) bool {
    switch filterType {
    case FilterByColor:
        return colorIdentifier(b.GetCuvee().GetColor()) == filterValue
    case FilterByDesignation:
        return b.GetCuvee().GetDesignationName() == filterValue
    }
    return true
}
```

**colorIdentifier helper** — maps Color enum to identifier string. The widget package has `wineColorIdentifier` but it's package-private (lowercase var). Options:
1. Export it from widget package — breaks the architecture (screen shouldn't depend on widget for this)
2. Duplicate the mapping in inventory.go — small, acceptable
3. Add an exported helper to widget package — cleanest

**Recommendation:** Add small `ColorIdentifier(c v1.Color) string` exported function in widget/aggregate.go. Or just duplicate the 5-entry map locally — it's trivial.

### Manager.go Callback Implementation

In `makeCtx()`, add to the Ctx struct literal:

```go
NavigateToInventoryWithFilter: func(filterType, filterValue string) {
    m.navigate(m.idxInv)
    m.inv.SetFilter(filterType, filterValue)
},
```

**Note on double-refresh:** `m.navigate(m.idxInv)` calls `OnActivate()` which calls `refresh()` (unfiltered). Then `SetFilter` calls `refreshThen()` again with the filter. This means two ListBottles calls happen. This is acceptable because:
- Both are fast (<100ms for 500 bottles)
- The user sees the filtered result (second populate overwrites the first)
- Alternative (skip OnActivate) would require special-casing navigate() which is more complex

### Existing InventoryScreen Code Reference

**Struct fields (line 25-51):**
- `allBottles []*v1.Bottle` — stored after fetch, used for client-side filtering
- `grouped bool`, `showConsumed bool` — existing filter state

**OnActivate (line 239-243):**
- Calls StopRFIDScan, HideRight, refresh()
- refresh() → refreshThen(nil) → ListBottles → populate(allBottles)

**refreshThen (line 249-268):**
- Goroutine → ListBottles → mainthread.Start → s.allBottles = bottles → s.populate(bottles) → then()
- The `then` callback runs AFTER populate — perfect for applying filter

**populate (line 270-289):**
- Clears model rows, rebuilds filter lists, calls populateFlat or populateGrouped
- Accepts the bottle slice to display — if we pass a filtered slice, it shows only those

### Architecture Constraints

- Modify: `internal/manager/screen/inventory.go` — add SetFilter method + matchesFilter helper
- Modify: `internal/manager/manager.go` — add callback in makeCtx
- Optionally modify: `internal/manager/widget/aggregate.go` — export ColorIdentifier if needed
- Do NOT modify dashboard.go or ctx.go (already done in Story 2.4)

### Color Identifier Mapping

The inventory filter needs to convert Color enum to identifier string for matching. The mapping:
```
COLOR_ROUGE → "rouge"
COLOR_BLANC → "blanc"
COLOR_ROSE → "rose"
COLOR_EFFERVESCENT → "effervescent"
COLOR_AUTRE → "autre"
COLOR_UNSPECIFIED → "autre"
```

### References

- [Source: internal/manager/screen/inventory.go:239-268 — OnActivate/refresh/refreshThen]
- [Source: internal/manager/screen/inventory.go:270-289 — populate]
- [Source: internal/manager/manager.go:243-268 — makeCtx]
- [Source: internal/manager/screen/ctx.go — FilterByColor/FilterByDesignation constants, NavigateToInventoryWithFilter callback]
- [Source: _bmad-output/planning-artifacts/architecture.md#SetFilter Behavior on Inventory Screen]
- [Source: _bmad-output/planning-artifacts/architecture.md#Filter Integration Test Scenarios]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.5]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Added `colorIdentifiers` map in inventory.go for Color enum → identifier string mapping
- Implemented `SetFilter(filterType, filterValue string)` using existing `refreshThen` mechanism
- `matchesFilter` helper handles FilterByColor (with UNSPECIFIED → autre fallback) and FilterByDesignation
- Filter is one-shot via refreshThen callback — no struct fields needed, no persistent state
- OnActivate already naturally clears filter (refresh → populate all bottles) — no changes needed
- Added `NavigateToInventoryWithFilter` callback in manager.go makeCtx: navigate(idxInv) + inv.SetFilter
- Double-refresh tradeoff accepted: OnActivate refreshes (unfiltered), SetFilter refreshes again (filtered) — user sees filtered result
- Compiles cleanly, all tests pass, no regressions

### Change Log

- 2026-03-30: Story 2.5 implemented — inventory filter integration with dashboard drill-down

### File List

- `internal/manager/screen/inventory.go` (MODIFIED — added colorIdentifiers, SetFilter, matchesFilter)
- `internal/manager/manager.go` (MODIFIED — added NavigateToInventoryWithFilter callback in makeCtx)
