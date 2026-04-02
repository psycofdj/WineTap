---
stepsCompleted:
  - step-01-init
  - step-02-context
  - step-03-starter
  - step-04-decisions
  - step-05-patterns
  - step-06-structure
  - step-07-validation
  - step-08-complete
status: 'complete'
completedAt: '2026-03-30'
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - docs/index.md
  - docs/project-overview.md
  - docs/architecture.md
  - docs/source-tree-analysis.md
  - docs/data-models.md
  - docs/api-contracts.md
  - docs/development-guide.md
workflowType: 'architecture'
project_name: 'winetap'
user_name: 'Psy'
date: '2026-03-30'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
10 FRs across 5 capability areas — all focused on a single new dashboard screen in the existing Qt6 manager app:
- Dashboard navigation (FR1-2): sidebar entry, screen switching
- Inventory overview (FR3-5): stock count, color breakdown, designation breakdown
- Interactive drill-down (FR6-7): click-to-filter navigation to Inventory screen
- Data freshness (FR8-9): refresh on screen open, derive from `ListBottles` API
- Empty state (FR10): graceful zero-bottle display

All FRs are read-only data presentation — no writes, no new API endpoints, no database changes.

**Non-Functional Requirements:**
- Render within 1 second for 500 bottles
- No UI thread blocking (async gRPC call)
- Cross-platform: Linux + Windows

**Scale & Complexity:**
- Complexity level: **Low**
- Primary domain: Desktop GUI feature addition
- Estimated new architectural components: 5 (4 custom widgets + 1 screen)
- No new server-side components, no new API endpoints, no schema changes

### Technical Constraints & Dependencies

**Existing constraints (inherited from the codebase):**
- Go 1.26 + miqt v0.13.0 (Qt6 bindings) — no QtCharts module available
- gRPC client already established in manager — reuse existing connection
- `screen.Ctx` callback pattern for screen decoupling — must follow this
- `doAsync()` pattern for async gRPC calls on Qt main thread — must use this
- Embedded CSS stylesheet in `assets.go` — extend for dashboard styles
- French UI labels throughout

**New constraint from UX spec:**
- Custom `QPainter`-based pie chart rendering (miqt lacks QtCharts)
- Bidirectional hover sync between PieChartWidget and LegendWidget via Qt signals
- Cross-screen navigation with filter parameter (dashboard → Inventory) — new pattern, requires Inventory screen modification

### Cross-Cutting Concerns Identified

1. **Inventory screen filter integration** — dashboard drill-down requires the Inventory screen to accept and apply an external filter parameter. This is the only cross-screen change and the main integration point.
2. **Stylesheet extension** — dashboard-specific CSS selectors must coexist with existing stylesheet without side effects on other screens.
3. **Data aggregation** — client-side computation from `ListBottles` response. Must handle edge cases: zero bottles, missing fields (null designation, null color), and large designation lists (top-N grouping with "Autres").

## Starter Template Evaluation

### Primary Technology Domain

Desktop GUI feature addition within an existing Go + Qt6 + gRPC monolith.

### Starter Options Considered

**Not applicable** — brownfield project with fully established tech stack. No starter template evaluation needed.

### Established Technology Stack (Inherited)

| Layer | Technology | Version |
|---|---|---|
| Language | Go | 1.26 |
| GUI Framework | Qt6 via miqt | v0.13.0 |
| RPC | gRPC + Protobuf | google.golang.org/grpc v1.79 |
| Database | SQLite (pure Go, WAL) | modernc.org/sqlite v1.48 |
| Serial I/O | go.bug.st/serial | v1.6.2 |
| Config | YAML | gopkg.in/yaml.v3 |
| Proto tooling | Buf | v2 |
| Build | Make | — |

**No new dependencies required for the dashboard feature.** All rendering uses existing miqt Qt6 bindings + QPainter.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
1. Widget package location — determines file structure before coding begins
2. Inventory filter integration — requires modifying `screen.Ctx` interface (cross-screen change)

**Important Decisions (Shape Architecture):**
3. Data aggregation location — affects testability and code organization

**Deferred Decisions (Post-MVP):**
- None — all decisions needed for MVP are made

### Frontend Architecture

**Widget Package:**
- **Decision:** New `internal/manager/widget/` package for reusable custom widgets
- **Rationale:** PieChartWidget, LegendWidget, HeroCountWidget, and DashboardPanel are reusable components, not screens. Separating them from `screen/` makes them available to future screens.
- **Affects:** File structure, import paths, all custom widget code
- **Contents:** `pie_chart.go`, `legend.go`, `hero_count.go`, `dashboard_panel.go`

**Dashboard Screen:**
- **Decision:** New `internal/manager/screen/dashboard.go` — follows existing screen pattern
- **Rationale:** Consistent with Inventory, Add Bottles, Read Bottle, Settings screens
- **Affects:** Screen registration, sidebar entry

### API & Communication Patterns

**Inventory Filter Integration:**
- **Decision:** Extend `screen.Ctx` with a navigation callback (e.g., `NavigateToInventoryWithFilter(filterType string, filterValue string)`)
- **Rationale:** Follows existing decoupling pattern — screens communicate through `screen.Ctx` callbacks, never referencing each other directly
- **Affects:** `screen/ctx.go` (interface change), `manager.go` (callback implementation), `screen/inventory.go` (filter application)
- **Cascading implication:** Inventory screen needs a `SetFilter()` or `ApplyFilter()` method that the manager calls when implementing the callback

### Data Architecture

**Data Aggregation:**
- **Decision:** Separate aggregation functions in the `widget` package (or a `dashboard` sub-package)
- **Rationale:** Pure functions that take `[]*v1.Bottle` and return aggregated data structures are easy to test independently. Dashboard screen calls these, passes results to widgets.
- **Affects:** `internal/manager/widget/` package, testability

### Decision Impact Analysis

**Implementation Sequence:**
1. Create `internal/manager/widget/` package with custom widgets (PieChartWidget, LegendWidget, HeroCountWidget, DashboardPanel)
2. Add aggregation functions to widget package
3. Extend `screen.Ctx` with `NavigateToInventoryWithFilter` callback
4. Create `screen/dashboard.go` — compose widgets, wire signals, connect to data
5. Register dashboard in manager sidebar and implement the filter callback
6. Add `SetFilter()` to Inventory screen, wire to manager callback

**Cross-Component Dependencies:**
- Widget package has no dependencies on screen package (one-way: screen imports widget)
- Dashboard screen depends on widget package + screen.Ctx
- Inventory screen modification is independent — only needs the new Ctx callback signature
- Stylesheet extension in `assets/stylesheet.css` is independent of all Go code changes

## Implementation Patterns & Consistency Rules

### Critical Conflict Points Identified

6 areas where AI agents could deviate when implementing the dashboard:

1. Widget naming and structure
2. Signal/callback patterns
3. Aggregation function signatures and return types
4. Widget data lifecycle
5. Null/edge case handling
6. Mouse tracking setup

### Naming Patterns

**File naming (existing convention — follow exactly):**
- Go files: `snake_case.go` (e.g., `pie_chart.go`, `hero_count.go`, `dashboard_panel.go`)
- One primary type per file, named after the type

**Type naming (existing convention):**
- Exported types: `PascalCase` (e.g., `PieChartWidget`, `LegendWidget`)
- Widget constructor: `NewPieChartWidget(parent *qt6.QWidget) *PieChartWidget`
- No interface needed for widgets — concrete types are fine for this scope

**Signal/callback naming:**
- Use descriptive names matching the UX interaction: `SliceClicked`, `SliceHovered`, `SliceUnhovered`
- Callback fields on widgets: `OnSliceClicked func(identifier string)`
- Follow existing `screen.Ctx` callback style — function fields, not Qt signal/slot

**CSS selector naming:**
- Use `role` property selectors matching existing convention: `QFrame[role="dashboard-panel"]`, `QLabel[role="hero-number"]`
- Prefix dashboard-specific roles with `dashboard-` to avoid collisions

### Structure Patterns

**Widget package organization:**
```
internal/manager/widget/
├── pie_chart.go          # PieChartWidget — QPainter rendering, hover/click
├── legend.go             # LegendWidget — synced label list
├── hero_count.go         # HeroCountWidget — large number + subtitle
├── dashboard_panel.go    # DashboardPanel — bordered container
├── aggregate.go          # Pure aggregation functions + types
└── aggregate_test.go     # Unit tests for aggregation edge cases
```

**Dashboard screen:**
```
internal/manager/screen/dashboard.go   # Dashboard screen — composes widgets
```

**Stylesheet extension:**
```
internal/manager/assets/stylesheet.css  # Append dashboard-specific selectors
```

### Widget Data Lifecycle Pattern

**Mandatory pattern — all widgets follow this:**
1. **Construct empty:** `widget := NewPieChartWidget(parent)` — no data at construction
2. **Set data after async load:** `widget.SetData(breakdownResult)` — called from `doAsync` callback
3. **Widget triggers repaint:** `SetData()` internally calls `update()` to trigger `paintEvent`
4. **Widgets render gracefully with no data** — empty/zero state by default until `SetData` is called

**Constructor signatures:**
- `NewPieChartWidget(parent *qt6.QWidget) *PieChartWidget`
- `NewLegendWidget(parent *qt6.QWidget) *LegendWidget`
- `NewHeroCountWidget(label string, parent *qt6.QWidget) *HeroCountWidget`
- `NewDashboardPanel(title string, child *qt6.QWidget, parent *qt6.QWidget) *DashboardPanel`

**PieChartWidget mandatory init:**
- Must call `setMouseTracking(true)` in constructor — required for `mouseMoveEvent` to fire on hover without button press

### Aggregation Types & Constants

**Defined in `aggregate.go`:**

```go
const maxDesignationSlices = 8

type BreakdownEntry struct {
    Label      string  // Display label (e.g., "Rouge", "Bordeaux")
    Identifier string  // Filter value for drill-down navigation
    Count      int     // Number of bottles
    Color      string  // Hex color string (e.g., "#c0392b")
}

type BreakdownResult struct {
    Entries []BreakdownEntry
    Total   int
}
```

- Aggregation functions return `BreakdownResult` — widgets consume this type
- Colors are hex strings — widget converts to Qt color internally
- No Qt or miqt imports in `aggregate.go` — pure Go only

### Null & Edge Case Handling Rules

**Mandatory — all aggregation functions follow these:**

| Data condition | Behavior |
|---|---|
| Null/empty color on bottle | Treated as `"autre"` |
| Null/empty designation on bottle | Grouped as `"Sans appellation"` |
| Zero bottles | All breakdowns return empty `BreakdownResult` with `Total: 0` |
| ≤8 distinct designations | No "Autres" grouping — show all |
| >8 distinct designations | Top 8 by count, remaining summed into `"Autres"` entry |
| Single color in inventory | Pie chart renders full circle (single slice at 360°) |

### Process Patterns

**Logging (existing convention — mandatory):**
- All logging via `log/slog`
- Accept `*slog.Logger` as dependency
- Debug level for widget lifecycle events (create, data load, render)
- No logging in pure aggregation functions

**Error handling:**
- gRPC call errors: log via slog, let existing manager error notification handle display
- No panics in widget code
- Aggregation functions never error — pure computation on in-memory data

**Async pattern (existing convention — mandatory):**
- gRPC calls via `doAsync()` — never block Qt main thread
- Widget data updates happen on Qt main thread (inside the `doAsync` callback)
- Widget `update()` / `repaint()` called after data is set

**Testing — mandatory edge cases for `aggregate_test.go`:**
- Zero bottles → empty results
- Bottles with null/empty designation → "Sans appellation"
- Bottles with null/empty color → "autre"
- Exactly 8 designations → no "Autres" grouping
- 9+ designations → top 8 + "Autres" sums correctly
- Single color → single entry with correct total
- All bottles same designation → single entry

### Enforcement Guidelines

**All AI agents implementing this feature MUST:**
- Follow existing `screen.Ctx` callback pattern — never import one screen from another
- Use `doAsync()` for all gRPC calls — never call gRPC synchronously on main thread
- Use `log/slog` for all logging — never `fmt.Println` or `log.Println`
- Prefix dashboard CSS roles with `dashboard-` — never reuse existing role names
- Keep aggregation functions pure — no Qt imports, no side effects
- Construct widgets empty, populate via `SetData()` — never pass data to constructor
- Call `setMouseTracking(true)` in PieChartWidget constructor

**Anti-Patterns:**
- ❌ Importing `screen` package from `widget` package (dependency must be one-way)
- ❌ Storing gRPC client in widget — widgets receive data, not connections
- ❌ Using Qt signals for widget communication — use Go callback functions
- ❌ Hardcoding French strings in widget code — keep labels in dashboard screen, pass to widgets as parameters
- ❌ Using `map[string]int` for aggregation results — use `BreakdownResult` struct
- ❌ Importing `color` or Qt packages in `aggregate.go` — hex strings only
- ❌ Widgets referencing each other directly — even within the widget package, pie and legend stay independent; dashboard.go wires them

## Project Structure & Boundaries

### New & Modified Files

```
internal/manager/
├── widget/                          # NEW PACKAGE — reusable dashboard widgets
│   ├── aggregate.go                 # Aggregation types (BreakdownEntry, BreakdownResult)
│   │                                # + pure functions: AggregateByColor, AggregateByDesignation
│   │                                # + designation color palette + maxDesignationSlices constant
│   ├── aggregate_test.go            # Unit tests for aggregation edge cases
│   ├── pie_chart.go                 # PieChartWidget — QPainter rendering, hover, click
│   ├── legend.go                    # LegendWidget — synced label list with hover/click
│   ├── hero_count.go                # HeroCountWidget — large number + subtitle label
│   └── dashboard_panel.go           # DashboardPanel — bordered container with title
│
├── screen/
│   ├── dashboard.go                 # NEW — Dashboard screen, composes widgets, wires data
│   ├── ctx.go                       # MODIFIED — add NavigateToInventoryWithFilter callback
│   └── inventory.go                 # MODIFIED — add SetFilter()/ApplyFilter() method
│
├── manager.go                       # MODIFIED — register dashboard sidebar entry,
│                                    #            implement NavigateToInventoryWithFilter callback
│
└── assets/
    └── stylesheet.css               # MODIFIED — append dashboard-specific CSS selectors
```

### Architectural Boundaries

**Widget ↔ Screen boundary:**
- `widget/` package exports types and widget constructors only
- `widget/` never imports `screen/` — one-way dependency
- `screen/dashboard.go` imports `widget/` to compose the dashboard
- Widgets receive data via `SetData()`, emit events via Go callbacks (`OnSliceClicked`)

**Widget ↔ Widget boundary (within widget package):**
- PieChartWidget and LegendWidget are independent — they do NOT reference each other
- `dashboard.go` wires them: `pie.OnSliceHovered = func(id string) { legend.HighlightRow(id) }` and vice versa
- Same pattern as screen.Ctx — the compositor owns the wiring, components are unaware of each other

**Screen ↔ Manager boundary (existing pattern):**
- Screens communicate through `screen.Ctx` callbacks — never reference each other
- `dashboard.go` calls `ctx.NavigateToInventoryWithFilter()` for drill-down
- `manager.go` implements this callback: switches to Inventory screen + calls `SetFilter()`

**Aggregation boundary:**
- `aggregate.go` is pure Go — no miqt/Qt imports
- Accepts `[]*v1.Bottle` (gRPC proto types), returns `BreakdownResult`
- Dashboard screen calls aggregation functions, passes results to widgets

**Designation color palette (in `aggregate.go`):**
```go
var designationPalette = []string{
    "#7eb26d", "#eab839", "#6ed0e0", "#ef843c",
    "#e24d42", "#1f78c4", "#ba43a9", "#705da0",
}
```
- `AggregateByDesignation` assigns colors from palette by index (wraps around if >8 before grouping)
- "Autres" entry always gets `#95a5a6` (muted grey)

**DashboardPanel child composition:**
- Each breakdown panel contains two widgets (pie chart + legend) stacked vertically
- `dashboard.go` creates an intermediate `QWidget` with `QVBoxLayout` holding both pie and legend
- This container widget is passed as the single `child` to `NewDashboardPanel(title, container, parent)`

### Requirements to Structure Mapping

| FR | File(s) |
|---|---|
| FR1-2: Dashboard navigation | `manager.go` (sidebar entry), `screen/dashboard.go` |
| FR3: Stock count | `widget/hero_count.go`, `screen/dashboard.go` |
| FR4: Color breakdown | `widget/aggregate.go` (AggregateByColor), `widget/pie_chart.go`, `widget/legend.go` |
| FR5: Designation breakdown | `widget/aggregate.go` (AggregateByDesignation), `widget/pie_chart.go`, `widget/legend.go` |
| FR6-7: Interactive drill-down | `screen/ctx.go`, `manager.go`, `screen/inventory.go` |
| FR8-9: Data freshness | `screen/dashboard.go` (doAsync ListBottles on screen open) |
| FR10: Empty state | `widget/pie_chart.go` (grey circle), `widget/hero_count.go` ("0") |

### Data Flow

```
User clicks "Tableau de bord"
  → manager.go switches to dashboard screen
  → dashboard.go.onShow() calls doAsync(ListBottles)
  → gRPC response arrives on main thread
  → dashboard.go calls AggregateByColor(bottles) → BreakdownResult
  → dashboard.go calls AggregateByDesignation(bottles) → BreakdownResult
  → colorPie.SetData(colorResult)
  → colorLegend.SetData(colorResult)
  → designationPie.SetData(designationResult)
  → designationLegend.SetData(designationResult)
  → heroCount.SetCount(len(inStockBottles))
  → widgets repaint

User clicks pie slice or legend row
  → widget fires OnSliceClicked("rouge") callback
  → dashboard.go calls ctx.NavigateToInventoryWithFilter("color", "rouge")
  → manager.go switches to inventory screen + calls inventory.SetFilter("color", "rouge")
  → inventory.SetFilter triggers fresh ListBottles + applies filter client-side
  → inventory screen displays filtered view
```

### SetFilter Behavior on Inventory Screen

- `SetFilter(filterType, filterValue string)` triggers a fresh `ListBottles` gRPC call via `doAsync()`
- Filter is applied client-side to the fresh results
- Zero matching bottles shows the normal inventory empty table state
- Filter is cleared when user navigates away from inventory and returns normally (not persisted)

### Filter Integration Test Scenarios (Manual)

| Scenario | Expected Result |
|---|---|
| Dashboard → click rouge slice → inventory | Inventory shows only rouge bottles |
| Dashboard → click "Bordeaux" designation → inventory | Inventory shows only Bordeaux bottles |
| Filtered inventory → click "Tableau de bord" → return to dashboard | Dashboard shows full (unfiltered) data |
| Filtered inventory → click another sidebar item → click inventory | Inventory shows all bottles (filter cleared) |
| Dashboard → click color with 0 bottles | Should not be clickable (zero-count cursor rule) |
| Dashboard → click designation matching 1 bottle | Inventory shows single bottle |

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:** All decisions use the existing Go + miqt + gRPC stack — no new dependencies, no version conflicts. Widget package cleanly separates concerns. screen.Ctx extension is backward-compatible.

**Pattern Consistency:** Naming follows existing codebase conventions. Callback-based communication is consistent throughout. CSS role prefixing prevents namespace collisions. Logging pattern matches all existing code.

**Structure Alignment:** One-way dependency (screen → widget) enforced. Widget independence consistent with screen.Ctx pattern. File placement follows existing organization.

### Requirements Coverage ✅

All 10 FRs mapped to specific files with architectural support. NFRs covered: performance (client-side aggregation — trivially fast), no UI blocking (doAsync enforced), cross-platform (Qt6 layout managers + QPainter).

### Implementation Readiness ✅

- All critical decisions documented with concrete file paths and type signatures
- Aggregation types fully specified with constants
- Null handling rules explicit for all edge cases
- Widget lifecycle, hover wiring, and panel composition clarified
- Anti-patterns listed to prevent common mistakes
- Three rounds of party-mode review caught 11 additional specifics

### Final Clarifications (from validation review)

**Filter type constants (in `screen/ctx.go`):**
```go
const (
    FilterByColor       = "color"
    FilterByDesignation = "designation"
)
```
- Dashboard passes these as `filterType` to `NavigateToInventoryWithFilter`
- An agent must never pass the filter *value* (e.g., "rouge") as the filterType

**ListBottles call parameters:**
- Dashboard calls `ListBottles` with default parameters (`include_consumed` = false)
- Never request consumed bottles — dashboard shows in-stock inventory only

**"Autres" designation entry:**
- The synthetic "Autres" grouping entry is **non-clickable**
- Default cursor (arrow), no `OnSliceClicked` callback fired
- Consistent with zero-count cursor rule — no meaningful filter can be applied
- Same applies to the "Autres" pie slice — no pop-out on hover, no click

**No live refresh:**
- Dashboard does **not** subscribe to the server event stream
- Data is fetched once on screen open; stale-until-revisit is by design (FR8)
- An agent must not add event subscription or auto-refresh logic to the dashboard

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — small, well-scoped feature building entirely on established patterns. Three rounds of multi-agent review.

**First Implementation Priority:**
1. `internal/manager/widget/aggregate.go` + `aggregate_test.go` — types, functions, tests (no Qt dependency, immediately testable)
2. Custom widgets (pie_chart, legend, hero_count, dashboard_panel)
3. `screen/dashboard.go` — compose and wire everything
4. `screen/ctx.go` + `manager.go` + `screen/inventory.go` — filter integration
5. `assets/stylesheet.css` — dashboard CSS
