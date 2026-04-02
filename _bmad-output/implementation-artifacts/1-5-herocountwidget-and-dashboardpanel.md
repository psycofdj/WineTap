# Story 1.5: HeroCountWidget and DashboardPanel

Status: review

## Story

As a developer,
I want a hero count widget and a reusable dashboard panel container,
so that the stock count and breakdown panels can be displayed in Grafana-style bordered cards.

## Acceptance Criteria

1. `NewHeroCountWidget(label, parent)` constructs a widget displaying "0" by default with the given subtitle label
2. `SetCount(n)` updates the displayed number (36px bold centered) with subtitle (14px normal below)
3. `SetCount(0)` displays "0" — no special empty treatment
4. `NewDashboardPanel(title, child, parent)` constructs a bordered container with title header and child widget
5. Panel renders: 1px #bdc3c7 border, border-radius 4px, 16px padding, title as section header
6. Dashboard-specific CSS selectors prefixed with `dashboard-` appended to stylesheet.css
7. No existing CSS selectors are modified

## Tasks / Subtasks

- [x] Task 1: Create HeroCountWidget (AC: #1, #2, #3)
  - [x] Create `internal/manager/widget/hero_count.go`
  - [x] Define `HeroCountWidget` struct with: `widget *qt.QWidget`, `countLabel *qt.QLabel`, `subtitleLabel *qt.QLabel`
  - [x] Implement `NewHeroCountWidget(label string, parent *qt.QWidget) *HeroCountWidget`
  - [x] Create QWidget with QVBoxLayout, center-aligned
  - [x] Count label: QLabel with "0", role="dashboard-hero-number" (styled 36px bold via CSS)
  - [x] Subtitle label: QLabel with provided label text, role="dashboard-hero-label" (styled 14px normal via CSS)
  - [x] Both labels center-aligned via `qt.AlignCenter`
  - [x] `func (h *HeroCountWidget) SetCount(n int)` — updates count label text
  - [x] `func (h *HeroCountWidget) Widget() *qt.QWidget` — returns root widget

- [x] Task 2: Create DashboardPanel (AC: #4, #5)
  - [x] Create `internal/manager/widget/dashboard_panel.go`
  - [x] Define `DashboardPanel` struct with: `widget *qt.QWidget`
  - [x] Implement `NewDashboardPanel(title string, child *qt.QWidget, parent *qt.QWidget) *DashboardPanel`
  - [x] Use QFrame with role="dashboard-panel" (styled via CSS: border, border-radius, padding)
  - [x] QVBoxLayout inside frame: title QLabel with role="section-header" at top, child widget below with stretch
  - [x] `func (d *DashboardPanel) Widget() *qt.QWidget` — returns the frame's QWidget

- [x] Task 3: Append dashboard CSS to stylesheet (AC: #6, #7)
  - [x] Append to `internal/manager/assets/stylesheet.css` — do NOT modify existing selectors
  - [x] Add: `QFrame[role="dashboard-panel"]` — border, border-radius, padding
  - [x] Add: `QLabel[role="dashboard-hero-number"]` — font-size 36px, font-weight bold, color #2c3e50
  - [x] Add: `QLabel[role="dashboard-hero-label"]` — font-size 14px, color #2c3e50
  - [x] Verify: no existing selectors touched, all new selectors prefixed with `dashboard-`

## Dev Notes

### Previous Story Intelligence

**From Stories 1.3/1.4 (miqt API learnings):**
- `SetMinimumSize2(w, h)` / `SetFixedSize2(w, h)` — two-arg variants
- `QWidget.QObject.SetProperty("role", qt.NewQVariant11("value"))` — how existing screens set role properties (see sidebar code in manager.go)
- `QLabel.SetAlignment(qt.AlignCenter)` for centering text
- `QVBoxLayout(parent)` attaches layout to parent widget
- `AddWidget2(widget, stretch)` for stretch factor

**From existing stylesheet.css:**
- Existing roles: `screen-title` (18px bold), `section-header` (bold, margin-top 8px), `form-title` (14px bold, #2c3e50), `inline-box` (border 1px #bdc3c7, radius 4px), `sidebar` (#2c3e50 bg)
- Panel border should match `inline-box` style: `1px solid #bdc3c7; border-radius: 4px`
- Hero number color should match existing text primary: `#2c3e50`

### miqt API Reference

**Setting role property (from existing code pattern):**
```go
widget.QObject.SetProperty("role", qt.NewQVariant11("dashboard-panel"))
```

**QLabel alignment:**
```go
label := qt.NewQLabel3("0")
label.SetAlignment(qt.AlignCenter)
```

**QFrame as container:**
```go
frame := qt.NewQFrame2()
frame.QWidget.QObject.SetProperty("role", qt.NewQVariant11("dashboard-panel"))
layout := qt.NewQVBoxLayout(frame.QWidget)
```

**Updating label text:**
```go
label.SetText(fmt.Sprintf("%d", count))
```

### Stylesheet Additions

Append these selectors after the existing content in stylesheet.css:
```css
/* Dashboard widgets */
QFrame[role="dashboard-panel"]        { border: 1px solid #bdc3c7; border-radius: 4px; padding: 16px; }
QLabel[role="dashboard-hero-number"]  { font-size: 36px; font-weight: bold; color: #2c3e50; }
QLabel[role="dashboard-hero-label"]   { font-size: 14px; color: #2c3e50; }
```

### Architecture Constraints

- Files: `hero_count.go`, `dashboard_panel.go` — NEW files in `internal/manager/widget/`
- Stylesheet: `internal/manager/assets/stylesheet.css` — APPEND only, no modifications
- Import: `qt "github.com/mappu/miqt/qt6"`, `"fmt"`
- These are simple composed widgets — no custom QPainter, no mouse events
- Both follow construct-empty + setter pattern (HeroCountWidget has SetCount, DashboardPanel is static after construction)

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Component Strategy — HeroCountWidget, DashboardPanel]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Visual Design Foundation — Typography System]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Design Direction Decision — DashboardPanel child composition]
- [Source: internal/manager/assets/stylesheet.css — existing role selectors and patterns]
- [Source: internal/manager/manager.go — SetProperty role pattern used for sidebar]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Created `hero_count.go` — HeroCountWidget with count label (36px bold via CSS role) and subtitle label (14px via CSS role), both center-aligned
- SetCount updates text via SetText(fmt.Sprintf), displays "0" by default — no special empty treatment
- Created `dashboard_panel.go` — DashboardPanel using QFrame with role="dashboard-panel", QVBoxLayout with section-header title + stretch child
- Panel uses existing "section-header" role for title (consistent with other screens), new "dashboard-panel" role for border styling
- Appended 3 CSS selectors to stylesheet.css: dashboard-panel (border/radius/padding), dashboard-hero-number (36px bold), dashboard-hero-label (14px)
- All new selectors prefixed with `dashboard-` — no existing selectors modified
- Both widgets follow SetProperty("role", ...) pattern from existing manager.go sidebar code
- Compiles cleanly, all 16 existing tests pass, no regressions

### Change Log

- 2026-03-30: Story 1.5 implemented — HeroCountWidget, DashboardPanel, and dashboard CSS selectors

### File List

- `internal/manager/widget/hero_count.go` (NEW)
- `internal/manager/widget/dashboard_panel.go` (NEW)
- `internal/manager/assets/stylesheet.css` (MODIFIED — appended 3 dashboard selectors)
