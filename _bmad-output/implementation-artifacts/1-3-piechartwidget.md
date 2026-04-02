# Story 1.3: PieChartWidget

Status: review

## Story

As a developer,
I want a custom QPainter-based pie chart widget,
so that breakdown data can be rendered as interactive Grafana-quality visualizations.

## Acceptance Criteria

1. `NewPieChartWidget(parent)` constructs an empty widget that renders a grey circle by default
2. `setMouseTracking(true)` called in constructor
3. `SetData(BreakdownResult)` populates the chart and triggers repaint
4. Pie slices rendered as filled arcs proportional to each entry's count, with anti-aliasing
5. Hovered slice pops out by 4-6px radial offset; `OnSliceHovered` callback called with Identifier
6. Clicked non-zero slice fires `OnSliceClicked` callback with Identifier; cursor is PointingHandCursor on hover
7. "Autres" (Identifier="") and zero-count slices: no pop-out, no click callback, default cursor

## Tasks / Subtasks

- [x] Task 1: Create PieChartWidget struct and constructor (AC: #1, #2)
  - [x] Create `internal/manager/widget/pie_chart.go`
  - [x] Define `PieChartWidget` struct with fields: `widget *qt.QWidget`, `data BreakdownResult`, `hoveredIndex int` (-1 = none), callback fields `OnSliceClicked func(string)`, `OnSliceHovered func(string)`, `OnSliceUnhovered func()`
  - [x] Implement `NewPieChartWidget(parent *qt.QWidget) *PieChartWidget` constructor
  - [x] Call `widget.SetMouseTracking(true)` in constructor
  - [x] Set minimum size (e.g., 200x200)
  - [x] Register `OnPaintEvent` callback
  - [x] Register `OnMouseMoveEvent` callback
  - [x] Register `OnMousePressEvent` callback

- [x] Task 2: Implement paint logic (AC: #1, #3, #4, #5)
  - [x] In paint event: create `QPainter` via `qt.NewQPainter2(widget.QPaintDevice)`
  - [x] Call `painter.SetRenderHint(qt.QPainter__Antialiasing)`
  - [x] If no data (Total=0): draw grey filled ellipse with "0" text centered, return
  - [x] Calculate bounding rect centered in widget, leaving margin for pop-out offset
  - [x] For each entry with Count > 0: calculate start angle and arc length (in 1/16th degrees, full circle = 5760)
  - [x] For hovered slice: offset the bounding rect by 4-6px in the slice's bisector direction
  - [x] Draw each slice via `painter.DrawPie2(x, y, w, h, startAngle, arcLength)` with brush set to entry's hex color
  - [x] Call `painter.End()` and `defer painter.Delete()`

- [x] Task 3: Implement mouse hit-testing and hover (AC: #5, #6, #7)
  - [x] In `OnMouseMoveEvent`: get mouse position via `ev.Pos()`
  - [x] Calculate angle from widget center to mouse position using `math.Atan2`
  - [x] Convert to Qt angle space (0° = 3 o'clock, counter-clockwise)
  - [x] Calculate distance from center — if outside pie radius, clear hover
  - [x] Walk slice angles to find which slice the mouse is in
  - [x] If hovered slice changed: update `hoveredIndex`, call `widget.Update()` to repaint
  - [x] If entering a non-zero, non-"Autres" slice: set `PointingHandCursor`, call `OnSliceHovered`
  - [x] If leaving all slices or entering zero/"Autres": reset cursor to default, call `OnSliceUnhovered`

- [x] Task 4: Implement click handling (AC: #6, #7)
  - [x] In `OnMousePressEvent`: use same hit-test logic as hover
  - [x] If clicked slice is non-zero and Identifier is non-empty: call `OnSliceClicked(identifier)`
  - [x] If clicked "Autres" (Identifier="") or zero-count or outside pie: do nothing

- [x] Task 5: Implement SetData and HighlightSlice (AC: #3)
  - [x] `func (p *PieChartWidget) SetData(data BreakdownResult)` — stores data, calls `widget.Update()`
  - [x] `func (p *PieChartWidget) HighlightSlice(identifier string)` — sets hoveredIndex to matching entry, calls `widget.Update()` (for bidirectional sync from legend)
  - [x] `func (p *PieChartWidget) ClearHighlight()` — resets hoveredIndex to -1, calls `widget.Update()`
  - [x] `func (p *PieChartWidget) Widget() *qt.QWidget` — returns the underlying QWidget for layout embedding

## Dev Notes

### Previous Story Intelligence

**From Story 1.1/1.2:**
- `BreakdownResult` and `BreakdownEntry` types already defined in `aggregate.go`
- `BreakdownEntry.Color` is a hex string (e.g., "#c0392b") — convert via `qt.NewQColor6(hex)`
- `BreakdownEntry.Identifier` is "" for "Autres" entries — use this to detect non-clickable
- Widget package is `internal/manager/widget/` — this file lives there

### miqt QPainter API Reference (verified from bindings)

**Creating painter on widget:**
```go
painter := qt.NewQPainter2(p.widget.QPaintDevice)
defer painter.Delete()
painter.SetRenderHint(qt.QPainter__Antialiasing)
// ... draw ...
painter.End()
```

**Drawing pie slices:**
```go
// Angles in 1/16th of degrees. Full circle = 5760 (360 * 16)
// 0° = 3 o'clock, positive = counter-clockwise
painter.DrawPie2(x, y, w, h, startAngle, arcLength)
```

**Color from hex string:**
```go
color := qt.NewQColor6("#c0392b")
defer color.Delete()
brush := qt.NewQBrush3(color)
defer brush.Delete()
painter.SetBrush(brush)
```

**Paint event pattern:**
```go
widget.OnPaintEvent(func(super func(ev *qt.QPaintEvent), ev *qt.QPaintEvent) {
    super(ev)
    painter := qt.NewQPainter2(widget.QPaintDevice)
    defer painter.Delete()
    // ... draw ...
    painter.End()
})
```

**Mouse events:**
```go
widget.SetMouseTracking(true)
widget.OnMouseMoveEvent(func(super func(ev *qt.QMouseEvent), ev *qt.QMouseEvent) {
    super(ev)
    pos := ev.Pos() // *QPoint with .X() int, .Y() int
})
widget.OnMousePressEvent(func(super func(ev *qt.QMouseEvent), ev *qt.QMouseEvent) {
    super(ev)
    // same pos access
})
```

**Cursor:**
```go
cursor := qt.NewQCursor2(qt.PointingHandCursor) // CursorShape = 13
defer cursor.Delete()
widget.SetCursor(cursor)

// Reset to default:
defaultCursor := qt.NewQCursor2(qt.ArrowCursor) // CursorShape = 0
defer defaultCursor.Delete()
widget.SetCursor(defaultCursor)
```

**Triggering repaint:**
```go
widget.Update() // schedules a paint event
```

**Empty state rendering:**
```go
// Grey circle for empty state
greyColor := qt.NewQColor6("#95a5a6")
defer greyColor.Delete()
greyBrush := qt.NewQBrush3(greyColor)
defer greyBrush.Delete()
painter.SetBrush(greyBrush)
painter.DrawEllipse2(x, y, w, h)
// Draw "0" text centered
painter.DrawText3(rect, int(qt.AlignCenter), "0")
```

### Angle Math for Hit-Testing

```go
// Mouse angle from center (Go math: 0=right, CCW positive, radians)
dx := float64(mouseX - centerX)
dy := float64(centerY - mouseY) // Qt Y is inverted
angleRad := math.Atan2(dy, dx)
if angleRad < 0 {
    angleRad += 2 * math.Pi
}
angleDeg := angleRad * 180.0 / math.Pi
// Convert to Qt 1/16th degrees for comparison with slice ranges
angleQt := int(angleDeg * 16)
```

### Architecture Constraints

- File: `internal/manager/widget/pie_chart.go` — NEW file
- Import `qt "github.com/mappu/miqt/qt6"` and `"math"` for angle calculation
- Callback fields (`OnSliceClicked`, etc.) are Go function fields, NOT Qt signals
- Widget does NOT import `screen` package
- `defer .Delete()` on ALL Qt objects created in paint/mouse handlers

### Testing Notes

- PieChartWidget is NOT unit-testable (requires Qt display)
- Visual testing happens in Story 2.1 (dashboard screen composition)
- The paint and hit-test logic quality depends on correct math — pay attention to angle calculations

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Widget Data Lifecycle Pattern]
- [Source: _bmad-output/planning-artifacts/architecture.md#PieChartWidget mandatory init]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Pie Chart Interaction Design]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Design Direction Decision]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3]
- [Source: miqt v0.13.0 — qt6/gen_qpainter.go, gen_qwidget.go, gen_qcolor.go, gen_qcursor.go]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Compilation error: `SetMinimumSize` takes `*QSize`, fixed to `SetMinimumSize2(int, int)`

### Completion Notes List

- Created `pie_chart.go` with PieChartWidget struct, constructor, and all interaction logic
- Paint logic: anti-aliased pie slices via QPainter.DrawPie2, grey circle + "0" for empty state
- Pie starts at 12 o'clock (90° in Qt angle space), last non-zero slice gets remainder to avoid rounding gaps
- Hovered slice pop-out: 5px offset along slice bisector direction
- Hit-testing: Atan2-based angle calculation with distance check against pie radius
- angleInRange helper handles wrap-around at 0°/360°
- isClickable checks both Count > 0 and Identifier != "" (blocks "Autres" and zero-count)
- Cursor: PointingHandCursor for clickable slices, ArrowCursor otherwise
- SetData/HighlightSlice/ClearHighlight for external data and sync control
- NoPen on slices for clean rendering without outlines
- All Qt objects (QColor, QBrush, QCursor) properly deleted after use
- Compiles cleanly, all 16 existing tests pass, no regressions
- NOT unit-testable (requires Qt display) — visual testing in Story 2.1

### Change Log

- 2026-03-30: Story 1.3 implemented — PieChartWidget with QPainter rendering, hover pop-out, click callbacks, hit-testing

### File List

- `internal/manager/widget/pie_chart.go` (NEW)
