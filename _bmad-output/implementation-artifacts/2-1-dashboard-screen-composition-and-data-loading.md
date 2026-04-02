# Story 2.1: Dashboard Screen Composition and Data Loading

Status: review

## Story

As a user,
I want to open the dashboard and see my cellar summary with stock count and breakdowns,
so that I instantly understand what's in my cellar without browsing individual bottles.

## Acceptance Criteria

1. `BuildDashboardScreen(ctx)` follows existing screen pattern (returns struct with `Widget *qt.QWidget` and `OnActivate()`)
2. Screen layout: HeroCountWidget in DashboardPanel (full width top), two breakdown panels side by side below (each with PieChartWidget + LegendWidget in QVBoxLayout container, passed to DashboardPanel)
3. `OnActivate()` fetches bottles via `ListBottles` gRPC call (include_consumed=false) in a goroutine, calls back on main thread
4. On data received: calls `AggregateByColor` and `AggregateByDesignation`, sets data on all widgets, sets hero count
5. UI thread never blocked during gRPC call (NFR3)
6. Dashboard does NOT subscribe to server event stream — stale-until-revisit by design (FR8)
7. Renders within 1 second for 500 bottles (NFR1)

## Tasks / Subtasks

- [x] Task 1: Create DashboardScreen struct and constructor (AC: #1, #2)
  - [x] Create `internal/manager/screen/dashboard.go`
  - [x] Define `DashboardScreen` struct with: `Widget *qt.QWidget`, `ctx *Ctx`, widget references for hero/pie/legend
  - [x] Implement `BuildDashboardScreen(ctx *Ctx) *DashboardScreen`
  - [x] Create root QWidget with QVBoxLayout
  - [x] Add screen title QLabel with role="screen-title" text="Tableau de bord"
  - [x] Create HeroCountWidget("bouteilles en stock") → wrap in DashboardPanel("Stock") → add to layout full width
  - [x] Create color PieChartWidget + LegendWidget → combine in QWidget with QVBoxLayout → wrap in DashboardPanel("Par couleur")
  - [x] Create designation PieChartWidget + LegendWidget → combine in QWidget with QVBoxLayout → wrap in DashboardPanel("Par appellation")
  - [x] Put both breakdown panels side by side in a QHBoxLayout
  - [x] Add breakdown row to main layout with stretch

- [x] Task 2: Implement OnActivate and data loading (AC: #3, #4, #5, #6)
  - [x] Implement `func (s *DashboardScreen) OnActivate()`
  - [x] Launch goroutine: call `s.ctx.Client.ListBottles(context.Background(), &v1.ListBottlesRequest{})` (default params, include_consumed=false)
  - [x] On error: log via `s.ctx.Log.Error("dashboard list bottles", "error", err)` and return
  - [x] On success: `mainthread.Start(func() { ... })` to update widgets on Qt thread
  - [x] In main thread callback: filter to in-stock bottles (ConsumedAt == nil), call AggregateByColor and AggregateByDesignation
  - [x] Set data on all widgets: `heroCount.SetCount(len(inStock))`, `colorPie.SetData(colorResult)`, `colorLegend.SetData(colorResult)`, `designationPie.SetData(designResult)`, `designationLegend.SetData(designResult)`
  - [x] No event subscription — no auto-refresh

- [x] Task 3: Verify compilation and regression (AC: #7)
  - [x] Build: `go build ./internal/manager/screen/`
  - [x] Run: `go test ./...` — all existing tests must pass
  - [x] NOTE: Dashboard screen is not registered in sidebar yet (Story 2.3) — this story just creates the screen

## Dev Notes

### Existing Screen Pattern (from inventory.go, settings.go)

**Constructor pattern:**
```go
type DashboardScreen struct {
    Widget *qt.QWidget  // exported — manager.go accesses this
    ctx    *Ctx
    // ... widget references
}

func BuildDashboardScreen(ctx *Ctx) *DashboardScreen {
    s := &DashboardScreen{ctx: ctx}
    s.Widget = qt.NewQWidget2()
    // ... build layout, create widgets ...
    return s
}
```

**OnActivate pattern (from inventory.go:239-267):**
```go
func (s *DashboardScreen) OnActivate() {
    go func() {
        resp, err := s.ctx.Client.ListBottles(context.Background(), &v1.ListBottlesRequest{})
        if err != nil {
            s.ctx.Log.Error("dashboard list bottles", "error", err)
            return
        }
        mainthread.Start(func() {
            // update widgets here — on Qt main thread
        })
    }()
}
```

**CRITICAL:** Do NOT use `doAsync` — the inventory screen uses direct goroutine + `mainthread.Start`. Follow the same pattern for consistency.

### Widget API Summary (from Epic 1)

```go
// All constructors take parent *qt.QWidget (can be nil)
hero := widget.NewHeroCountWidget("bouteilles en stock", nil)
hero.SetCount(127)

colorPie := widget.NewPieChartWidget(nil)
colorPie.SetData(colorResult)   // widget.BreakdownResult

colorLegend := widget.NewLegendWidget(nil)
colorLegend.SetData(colorResult)

panel := widget.NewDashboardPanel("Par couleur", childWidget, nil)
panel.Widget() // returns *qt.QWidget for layout
```

### Layout Composition (from architecture)

```
Root QVBoxLayout:
├── QLabel "Tableau de bord" (role="screen-title")
├── DashboardPanel("Stock", heroCount.Widget())  [full width]
└── QHBoxLayout [stretch=1]:
    ├── DashboardPanel("Par couleur", colorContainer)
    └── DashboardPanel("Par appellation", designContainer)

Where colorContainer = QWidget with QVBoxLayout:
├── colorPie.Widget()
└── colorLegend.Widget()
```

### Data Flow

```
OnActivate()
  → goroutine: ListBottles(default params)
  → mainthread.Start:
    → inStock = filter bottles where ConsumedAt == nil
    → colorResult = widget.AggregateByColor(inStock)
    → designResult = widget.AggregateByDesignation(inStock)
    → hero.SetCount(len(inStock))
    → colorPie.SetData(colorResult)
    → colorLegend.SetData(colorResult)
    → designPie.SetData(designResult)
    → designLegend.SetData(designResult)
```

**Note on filtering:** `ListBottles` with default params (include_consumed=false) already returns only in-stock bottles. But ConsumedAt nil-check is a safety net.

### Imports Needed

```go
import (
    "context"

    qt "github.com/mappu/miqt/qt6"
    "github.com/mappu/miqt/qt6/mainthread"

    v1 "winetap/gen/winetap/v1"
    "winetap/internal/manager/widget"
)
```

### Architecture Constraints

- File: `internal/manager/screen/dashboard.go` — NEW file
- Follows `screen.Ctx` callback pattern — screen communicates through ctx only
- Imports `widget` package (one-way: screen → widget)
- Does NOT import `manager` package (circular import prevention)
- No event subscription — no live refresh (per architecture final clarifications)
- ListBottles with default params — never request consumed bottles (per architecture)

### What This Story Does NOT Do

- Does NOT register in sidebar (Story 2.3)
- Does NOT wire bidirectional hover between pie and legend (Story 2.2)
- Does NOT implement drill-down navigation (Story 2.4)
- Callbacks on pie/legend widgets are left nil for now — wired in subsequent stories

### References

- [Source: internal/manager/screen/inventory.go:239-267 — OnActivate/refresh/ListBottles pattern]
- [Source: internal/manager/screen/settings.go — BuildSettingsScreen constructor pattern]
- [Source: internal/manager/screen/ctx.go — Ctx struct with Client field]
- [Source: _bmad-output/planning-artifacts/architecture.md#Data Flow]
- [Source: _bmad-output/planning-artifacts/architecture.md#Final Clarifications — no live refresh, ListBottles default params]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.1]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Created `dashboard.go` in screen package following existing BuildXxxScreen(ctx) pattern
- DashboardScreen struct with Widget (exported), ctx, and references to all 5 sub-widgets (heroCount, colorPie, colorLegend, desigPie, desigLegend)
- Layout: screen title (role=screen-title) → hero panel full width → breakdown row (QHBoxLayout) with color and designation panels side by side (stretch=1 each)
- Each breakdown panel: intermediate QWidget with QVBoxLayout holding pie (stretch=1) + legend, wrapped in DashboardPanel
- Root layout: 16px margins, 16px spacing
- OnActivate: goroutine + mainthread.Start pattern (matching inventory.go), ListBottles with default params
- In-stock filter (ConsumedAt==nil) as safety net
- Aggregation computed in goroutine before mainthread.Start — widget SetData calls on main thread only
- Widget callbacks left nil — wired in Stories 2.2 (hover) and 2.4 (drill-down)
- Compiles cleanly, all existing tests pass, no regressions

### Change Log

- 2026-03-30: Story 2.1 implemented — DashboardScreen composition with all widgets and async data loading

### File List

- `internal/manager/screen/dashboard.go` (NEW)
