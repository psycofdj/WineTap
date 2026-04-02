# Story 2.3: Sidebar Registration and Navigation

Status: review

## Story

As a user,
I want a "Tableau de bord" entry in the manager sidebar,
so that I can navigate to the dashboard from anywhere in the application.

## Acceptance Criteria

1. "Tableau de bord" sidebar entry appears in the sidebar
2. Clicking it activates the dashboard screen and data loading begins (FR1)
3. User can navigate away and click "Tableau de bord" again to return with fresh data (FR2)
4. Dashboard follows the same activation pattern as all other screens (navigate → OnActivate)

## Tasks / Subtasks

- [x] Task 1: Add dashboard field and index to Manager struct (AC: #4)
  - [x] Add `dash *screen.DashboardScreen` field to Manager struct (after `cfg` field, line ~49)
  - [x] Add `idxDash int` field (after `idxCfg`, line ~56)

- [x] Task 2: Build and register dashboard screen in buildUI (AC: #4)
  - [x] In `buildUI()`, after existing screen builds (line ~332): add `m.dash = screen.BuildDashboardScreen(ctx)`
  - [x] Add `m.idxDash = m.stack.AddWidget(m.dash.Widget)` (after existing AddWidget calls, line ~338)

- [x] Task 3: Add dashboard to navigate switch (AC: #2, #3)
  - [x] In `navigate()` switch (line ~273): add `case m.idxDash: m.dash.OnActivate()`

- [x] Task 4: Add sidebar entry (AC: #1)
  - [x] In `buildSidebar()`: add a "TABLEAU DE BORD" section + "Tableau de bord" item BEFORE the "CATALOGUE" section
  - [x] Use existing `addSection` and `addItem` helpers
  - [x] Wire: `addItem("Tableau de bord", func() { m.navigate(m.idxDash) })`

- [x] Task 5: Verify compilation and regression
  - [x] Build: `go build ./internal/manager/`
  - [x] Run: `go test ./...`

## Dev Notes

### Exact Modification Points in manager.go

**1. Struct fields (line ~49):**
```go
// Screens
inv   *screen.InventoryScreen
desig *screen.DesignationsScreen
doms  *screen.DomainsScreen
cuvs  *screen.CuveesScreen
cfg   *screen.SettingsScreen
dash  *screen.DashboardScreen  // ← ADD THIS
```

**2. Index field (line ~56):**
```go
idxCfg   int
idxDash  int  // ← ADD THIS
```

**3. buildUI screen construction (line ~332):**
```go
m.cfg = screen.BuildSettingsScreen(ctx)
m.dash = screen.BuildDashboardScreen(ctx)  // ← ADD THIS

m.idxCfg = m.stack.AddWidget(m.cfg.Widget)
m.idxDash = m.stack.AddWidget(m.dash.Widget)  // ← ADD THIS
```

**4. navigate switch (line ~273):**
```go
case m.idxCfg:
    m.cfg.OnActivate()
case m.idxDash:       // ← ADD THIS
    m.dash.OnActivate()  // ← ADD THIS
```

**5. buildSidebar — insert BEFORE "CATALOGUE" section (line ~363):**
```go
addSection("TABLEAU DE BORD")
addItem("Tableau de bord", func() { m.navigate(m.idxDash) })

addSection("CATALOGUE")  // existing
```

### Sidebar Placement Rationale

Dashboard goes FIRST in the sidebar (before Catalogue) because:
- It's the overview/landing screen — primary navigation target
- Users should see it first when they open the app
- Consistent with dashboard-first layouts in other apps

### Architecture Constraints

- ONLY modify `internal/manager/manager.go` — do NOT modify screen files or widget files
- Follow exact same pattern as existing screens (inv, desig, doms, cuvs, cfg)
- `screen` package is already imported in manager.go — no new imports needed
- DashboardScreen.Widget and OnActivate() match the existing screen interface pattern

### No New Imports

manager.go already imports `winetap/internal/manager/screen` — DashboardScreen is in that package. No import changes needed.

### References

- [Source: internal/manager/manager.go:23-56 — Manager struct fields]
- [Source: internal/manager/manager.go:270-285 — navigate() switch]
- [Source: internal/manager/manager.go:326-338 — buildUI() screen construction]
- [Source: internal/manager/manager.go:341-376 — buildSidebar()]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.3]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Added `dash *screen.DashboardScreen` and `idxDash int` fields to Manager struct
- Built and registered DashboardScreen in buildUI via BuildDashboardScreen(ctx) + stack.AddWidget
- Added navigate switch case for idxDash → dash.OnActivate()
- Added "TABLEAU DE BORD" section + "Tableau de bord" sidebar item BEFORE "CATALOGUE" section
- Dashboard is now first sidebar entry — primary navigation target
- No new imports needed — screen package already imported
- Compiles cleanly, all tests pass

### Change Log

- 2026-03-30: Story 2.3 implemented — dashboard registered in sidebar and navigation

### File List

- `internal/manager/manager.go` (MODIFIED — 5 insertions: struct fields, buildUI, navigate, sidebar)
