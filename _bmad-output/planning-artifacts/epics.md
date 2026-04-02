---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
status: complete
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
---

# winetap - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for winetap dashboard feature, decomposing the requirements from the PRD, UX Design, and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR1: User can navigate to the dashboard screen via a "Tableau de bord" entry in the manager sidebar
- FR2: User can return to the dashboard from any other screen via the sidebar
- FR3: User can view the total count of bottles currently in stock
- FR4: User can view the distribution of in-stock bottles by wine color (rouge, blanc, rosé, effervescent, autre)
- FR5: User can view the distribution of in-stock bottles by designation (appellation)
- FR6: User can click a color segment in the color breakdown to navigate to the Inventory screen filtered to that color
- FR7: User can click a designation entry in the designation breakdown to navigate to the Inventory screen filtered to that designation
- FR8: Dashboard data is refreshed from the server each time the user navigates to the dashboard screen
- FR9: Dashboard displays data derived from the existing ListBottles API response (in-stock bottles only)
- FR10: User can see a clear, meaningful empty state when no bottles are in stock

### Non-Functional Requirements

- NFR1: Dashboard screen renders all widgets within 1 second for an inventory of up to 500 bottles
- NFR2: Navigation from dashboard to filtered Inventory screen completes without perceptible delay
- NFR3: Client-side aggregation does not block the Qt UI thread (use existing doAsync() pattern)

### Additional Requirements

- AR1: Create new `internal/manager/widget/` package for reusable custom widgets
- AR2: Custom QPainter-based PieChartWidget with hover pop-out and click detection (setMouseTracking required)
- AR3: LegendWidget with bidirectional hover sync wired by dashboard screen (widgets stay independent)
- AR4: HeroCountWidget for large stock count display (construct empty, SetData pattern)
- AR5: DashboardPanel container with bordered Grafana-style layout
- AR6: Pure aggregation functions in `aggregate.go` using BreakdownEntry/BreakdownResult types, hex color strings, maxDesignationSlices=8
- AR7: Extend screen.Ctx with NavigateToInventoryWithFilter callback using FilterByColor/FilterByDesignation constants
- AR8: Inventory screen SetFilter method triggers fresh ListBottles + applies filter; "Autres" entry non-clickable

### UX Design Requirements

- UX-DR1: Grafana-inspired panel grid layout — hero count (full width top), two breakdown panels (side by side bottom)
- UX-DR2: Wine-semantic color palette for pie chart slices (rouge=#c0392b, blanc=#f1c40f, rosé=#e8a0bf, effervescent=#3498db, autre=#95a5a6) + designation cycling palette
- UX-DR3: Dashboard-specific CSS selectors prefixed with `dashboard-` appended to existing stylesheet.css
- UX-DR4: Pie chart hover: slice pop-out (4-6px radial offset) + tooltip; bidirectional with legend row highlighting
- UX-DR5: Empty state: grey circle with "0" centered, legend shows all categories at 0, hero shows "0"
- UX-DR6: DashboardPanel child composition: intermediate QWidget with QVBoxLayout holding pie + legend, passed as single child

### FR Coverage Map

| Requirement | Epic | Description |
|---|---|---|
| FR1 | Epic 2 | Sidebar navigation entry |
| FR2 | Epic 2 | Return to dashboard via sidebar |
| FR3 | Epic 1 | HeroCountWidget stock count |
| FR4 | Epic 1 | Color breakdown pie + legend |
| FR5 | Epic 1 | Designation breakdown pie + legend |
| FR6 | Epic 2 | Color drill-down to filtered inventory |
| FR7 | Epic 2 | Designation drill-down to filtered inventory |
| FR8 | Epic 1 | Data refresh aggregation logic |
| FR9 | Epic 1 | ListBottles data source |
| FR10 | Epic 1 | Empty state display |
| NFR1-3 | Epic 2 | Performance, async, navigation speed |
| AR1-6 | Epic 1 | Widget package, aggregation, custom widgets |
| AR7-8 | Epic 2 | screen.Ctx, inventory filter |
| UX-DR1-6 | Epic 1 | All visual/interaction design + stylesheet |

## Epic List

### Epic 1: Dashboard Foundation
Build all dashboard building blocks — aggregation logic, custom visualization widgets, and dashboard stylesheet. Deliverable: code-complete widget package with tested aggregation functions.

**FRs covered:** FR3, FR4, FR5, FR8, FR9, FR10
**ARs covered:** AR1, AR2, AR3, AR4, AR5, AR6
**UX-DRs covered:** UX-DR1, UX-DR2, UX-DR3, UX-DR4, UX-DR5, UX-DR6
**Definition of done:** Code-complete, code-reviewed, aggregation unit tests pass. Widgets are not user-verifiable in isolation — visual testing happens in Epic 2.

### Epic 2: Dashboard Experience
Wire everything into a complete, working dashboard — screen composition, sidebar entry, data loading, drill-down navigation to filtered inventory. Deliverable: fully functional dashboard feature.

**FRs covered:** FR1, FR2, FR6, FR7
**ARs covered:** AR7, AR8
**NFRs covered:** NFR1, NFR2, NFR3
**Definition of done:** User can open dashboard, see cellar summary, click any breakdown to drill into filtered inventory. All manual test scenarios pass.

## Epic 1: Dashboard Foundation

Build all dashboard building blocks — aggregation logic, custom visualization widgets, and dashboard stylesheet.

### Story 1.1: Aggregation Types and Color Breakdown

As a developer,
I want pure aggregation functions that compute bottle breakdowns by color,
So that the dashboard can display color distribution data from raw bottle lists.

**Acceptance Criteria:**

**Given** a list of in-stock bottles from ListBottles response
**When** AggregateByColor is called
**Then** it returns a BreakdownResult with one entry per wine color (rouge, blanc, rosé, effervescent, autre) with correct counts, percentages, and hex color strings
**And** bottles with null/empty color are counted as "autre"
**And** the Total field equals the sum of all entry counts
**And** zero-count colors are included in results

**Given** an empty bottle list
**When** AggregateByColor is called
**Then** it returns a BreakdownResult with Total: 0 and all five color entries with Count: 0

**Given** the aggregate.go file
**Then** it contains BreakdownEntry and BreakdownResult types, maxDesignationSlices constant, and designationPalette
**And** it has no miqt/Qt imports — pure Go only

### Story 1.2: Designation Breakdown Aggregation

As a developer,
I want pure aggregation functions that compute bottle breakdowns by designation,
So that the dashboard can display appellation distribution data.

**Acceptance Criteria:**

**Given** a list of in-stock bottles
**When** AggregateByDesignation is called
**Then** it returns a BreakdownResult with entries sorted by count descending
**And** each entry has a color from the designationPalette cycling palette

**Given** bottles with null/empty designation
**When** AggregateByDesignation is called
**Then** those bottles are grouped under "Sans appellation"

**Given** more than 8 distinct designations
**When** AggregateByDesignation is called
**Then** the top 8 by count are returned individually
**And** remaining are summed into an "Autres" entry with color #95a5a6

**Given** 8 or fewer distinct designations
**When** AggregateByDesignation is called
**Then** all designations are returned individually with no "Autres" grouping

**Given** aggregate_test.go
**Then** it covers: zero bottles, null designation, null color, exactly 8 designations, 9+ designations, single color, all same designation

### Story 1.3: PieChartWidget

As a developer,
I want a custom QPainter-based pie chart widget,
So that breakdown data can be rendered as interactive Grafana-quality visualizations.

**Acceptance Criteria:**

**Given** a PieChartWidget constructed with NewPieChartWidget(parent)
**Then** it renders an empty grey circle by default (no data state)
**And** setMouseTracking(true) is called in the constructor

**Given** SetData is called with a BreakdownResult
**When** the widget paints
**Then** it renders filled arc segments proportional to each entry's count
**And** each segment uses the entry's hex color converted to Qt color
**And** anti-aliasing is enabled via QPainter.SetRenderHint

**Given** the user hovers over a pie slice
**When** mouseMoveEvent fires
**Then** the hovered slice pops out by 4-6px radial offset
**And** the OnSliceHovered callback is called with the entry's Identifier

**Given** the user clicks a non-zero pie slice
**When** mousePressEvent fires
**Then** the OnSliceClicked callback is called with the entry's Identifier
**And** cursor is PointingHandCursor when hovering a non-zero slice

**Given** the "Autres" slice or a zero-count slice
**Then** no pop-out on hover, no click callback, default cursor

### Story 1.4: LegendWidget

As a developer,
I want a legend widget that displays labeled category rows synced with a pie chart,
So that breakdown data is shown with exact counts and percentages alongside the visualization.

**Acceptance Criteria:**

**Given** a LegendWidget constructed with NewLegendWidget(parent)
**When** SetData is called with a BreakdownResult
**Then** it displays one row per entry: color swatch (12x12px) + label + count (bold) + percentage

**Given** the user hovers a non-zero legend row
**Then** the row background changes to #d5dbdb
**And** cursor changes to PointingHandCursor
**And** OnRowHovered callback is called with the entry's Identifier

**Given** the user clicks a non-zero legend row
**Then** OnRowClicked callback is called with the entry's Identifier

**Given** HighlightRow(identifier) is called externally
**Then** the matching row highlights as if hovered (for bidirectional sync with pie chart)

**Given** "Autres" or zero-count rows
**Then** default cursor, no click callback

### Story 1.5: HeroCountWidget and DashboardPanel

As a developer,
I want a hero count widget and a reusable dashboard panel container,
So that the stock count and breakdown panels can be displayed in Grafana-style bordered cards.

**Acceptance Criteria:**

**Given** NewHeroCountWidget("bouteilles en stock", parent) is constructed
**When** SetCount(127) is called
**Then** it displays "127" in 36px bold centered, with "bouteilles en stock" in 14px normal below

**Given** SetCount(0) is called
**Then** it displays "0" in the same style — no special empty treatment

**Given** NewDashboardPanel("Par couleur", childWidget, parent) is constructed
**Then** it renders a bordered container (1px #bdc3c7, border-radius 4px, 16px padding) with title "Par couleur" as section header and childWidget below

**Given** the dashboard stylesheet additions
**Then** stylesheet.css contains selectors for dashboard-panel, dashboard-hero-number, dashboard-hero-label prefixed with `dashboard-`
**And** no existing selectors are modified

## Epic 2: Dashboard Experience

Wire everything into a complete, working dashboard — screen composition, sidebar entry, data loading, drill-down navigation to filtered inventory.

### Story 2.1: Dashboard Screen Composition and Data Loading

As a user,
I want to open the dashboard and see my cellar summary with stock count and breakdowns,
So that I instantly understand what's in my cellar without browsing individual bottles.

**Acceptance Criteria:**

**Given** the dashboard screen is created in screen/dashboard.go
**Then** it follows the existing screen.Ctx callback pattern
**And** it composes: 1 HeroCountWidget in a DashboardPanel (full width top), 2 breakdown panels side by side below (each with PieChartWidget + LegendWidget in intermediate QWidget with QVBoxLayout, passed as child to DashboardPanel)

**Given** the user navigates to the dashboard screen
**When** the screen activates
**Then** it calls doAsync(ListBottles) with default parameters (include_consumed=false)
**And** on response: calls AggregateByColor and AggregateByDesignation on the bottle list
**And** calls SetData on all widgets and SetCount on hero widget
**And** the UI thread is never blocked during the gRPC call (NFR3)

**Given** the dashboard screen activates with a loaded inventory of 500 bottles
**Then** all widgets render within 1 second (NFR1)

**Given** the dashboard is opened a second time after navigating away
**When** the screen activates again
**Then** data is re-fetched from the server (FR8) — no stale cache

**Given** the dashboard does not subscribe to the server event stream
**Then** no auto-refresh logic exists — stale-until-revisit by design

### Story 2.2: Bidirectional Hover Wiring

As a user,
I want hovering a pie slice to highlight the matching legend row and vice versa,
So that I can clearly see which category I'm interacting with.

**Acceptance Criteria:**

**Given** the dashboard screen wires PieChartWidget and LegendWidget callbacks
**When** the user hovers a pie slice
**Then** the corresponding legend row highlights automatically
**And** the pie slice pops out

**Given** the user hovers a legend row
**When** OnRowHovered fires
**Then** the corresponding pie slice highlights (via HighlightSlice on PieChartWidget)

**Given** the user moves the mouse away from both widgets
**Then** all highlights are cleared — both widgets return to default state

**Given** the wiring is done in dashboard.go
**Then** PieChartWidget and LegendWidget do not reference each other — they remain independent

### Story 2.3: Sidebar Registration and Navigation

As a user,
I want a "Tableau de bord" entry in the manager sidebar,
So that I can navigate to the dashboard from anywhere in the application.

**Acceptance Criteria:**

**Given** the manager application starts
**Then** a "Tableau de bord" entry appears in the sidebar (QPushButton with role="sidebar-item")

**Given** the user clicks "Tableau de bord" in the sidebar
**When** from any other screen
**Then** the dashboard screen activates and data loading begins (FR1)

**Given** the user is on the dashboard
**When** they click any other sidebar entry
**Then** the other screen activates normally
**And** clicking "Tableau de bord" again returns to the dashboard with fresh data (FR2)

### Story 2.4: Drill-Down Navigation to Filtered Inventory

As a user,
I want to click a color or designation in the dashboard to see those specific bottles in the inventory,
So that I can act on insights without manual searching.

**Acceptance Criteria:**

**Given** screen/ctx.go defines FilterByColor and FilterByDesignation constants
**And** screen.Ctx has a NavigateToInventoryWithFilter(filterType string, filterValue string) callback

**Given** the user clicks a non-zero color slice or legend row on the dashboard
**When** OnSliceClicked fires with the color identifier (e.g., "rouge")
**Then** ctx.NavigateToInventoryWithFilter(FilterByColor, "rouge") is called
**And** the manager switches to the Inventory screen
**And** the Inventory screen displays only bottles matching that color (FR6)
**And** navigation completes without perceptible delay (NFR2)

**Given** the user clicks a non-zero designation slice or legend row
**When** OnSliceClicked fires with the designation identifier (e.g., "Bordeaux")
**Then** ctx.NavigateToInventoryWithFilter(FilterByDesignation, "Bordeaux") is called
**And** the Inventory screen displays only bottles matching that designation (FR7)

**Given** the "Autres" slice/row or a zero-count slice/row
**Then** no navigation occurs — non-clickable by design

### Story 2.5: Inventory Screen Filter Integration

As a user,
I want the inventory screen to display filtered results when navigated from the dashboard,
So that drill-down shows exactly the bottles I'm interested in.

**Acceptance Criteria:**

**Given** inventory.go has a SetFilter(filterType, filterValue string) method
**When** SetFilter is called by the manager's NavigateToInventoryWithFilter callback
**Then** the inventory screen triggers a fresh ListBottles gRPC call via doAsync()
**And** applies the filter client-side to the fresh results
**And** displays only matching bottles

**Given** SetFilter is called with a filter matching zero bottles
**Then** the inventory shows its normal empty table state

**Given** the user navigates away from the filtered inventory to another screen
**When** they return to inventory via the sidebar
**Then** the filter is cleared — inventory shows all bottles (not persisted)

**Given** the user navigates from filtered inventory back to "Tableau de bord"
**Then** the dashboard shows full unfiltered data as always
