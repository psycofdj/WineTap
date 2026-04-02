# Story 1.4: LegendWidget

Status: review

## Story

As a developer,
I want a legend widget that displays labeled category rows synced with a pie chart,
so that breakdown data is shown with exact counts and percentages alongside the visualization.

## Acceptance Criteria

1. `NewLegendWidget(parent)` constructs an empty legend widget
2. `SetData(BreakdownResult)` displays one row per entry: color swatch (12x12px) + label + count (bold) + percentage
3. Hovering a non-zero legend row: background changes to #d5dbdb, cursor to PointingHandCursor, `OnRowHovered` callback fires
4. Clicking a non-zero legend row: `OnRowClicked` callback fires with Identifier
5. `HighlightRow(identifier)` externally highlights a row (for bidirectional sync with pie chart)
6. "Autres" (Identifier="") and zero-count rows: default cursor, no click callback
7. Widget provides `Widget() *qt.QWidget` for layout embedding

## Tasks / Subtasks

- [x] Task 1: Create LegendWidget struct and constructor (AC: #1, #7)
  - [x] Create `internal/manager/widget/legend.go`
  - [x] Define `LegendWidget` struct with: `widget *qt.QWidget`, `layout *qt.QVBoxLayout`, `rows []legendRow` (internal), `data BreakdownResult`, callback fields `OnRowClicked func(string)`, `OnRowHovered func(string)`, `OnRowUnhovered func()`
  - [x] Define internal `legendRow` struct: `container *qt.QWidget`, `index int`
  - [x] Implement `NewLegendWidget(parent *qt.QWidget) *LegendWidget`
  - [x] Create root QWidget with QVBoxLayout, spacing=2, zero margins

- [x] Task 2: Implement SetData to build legend rows (AC: #2)
  - [x] `func (l *LegendWidget) SetData(data BreakdownResult)` — clears existing rows, rebuilds
  - [x] For each entry: create a row QWidget with QHBoxLayout containing:
    - Color swatch: QFrame 12x12px with background-color set via SetStyleSheet
    - Label: QLabel with entry.Label
    - Count: QLabel bold with entry.Count
    - Percentage: QLabel with "(XX%)" computed from entry.Count/data.Total
  - [x] Store row references in `rows` slice for hover highlight access
  - [x] Handle Total=0 edge case: show "0%" for all entries

- [x] Task 3: Implement row hover and click interactions (AC: #3, #4, #6)
  - [x] For each row widget: register `OnEnterEvent` and `OnLeaveEvent`
  - [x] OnEnterEvent for non-zero, non-"Autres" row: set background to #d5dbdb via SetStyleSheet, set PointingHandCursor, call `OnRowHovered(identifier)`
  - [x] OnLeaveEvent: clear background, reset cursor to ArrowCursor, call `OnRowUnhovered()`
  - [x] Register `OnMousePressEvent` on each row widget
  - [x] OnMousePress for non-zero, non-"Autres" row: call `OnRowClicked(identifier)`
  - [x] "Autres" (Identifier="") and zero-count rows: skip hover/click registration

- [x] Task 4: Implement HighlightRow and ClearHighlight (AC: #5)
  - [x] `func (l *LegendWidget) HighlightRow(identifier string)` — finds matching row, sets background to #d5dbdb
  - [x] `func (l *LegendWidget) ClearHighlight()` — clears background on all rows
  - [x] `func (l *LegendWidget) Widget() *qt.QWidget` — returns root widget

## Dev Notes

### Previous Story Intelligence

**From Story 1.3 (PieChartWidget):**
- Use `SetMinimumSize2(w, h)` not `SetMinimumSize(w, h)` — miqt quirk
- Use `SetFixedSize2(w, h)` for the color swatch
- Cursor: `qt.NewQCursor2(qt.PointingHandCursor)` / `qt.NewQCursor2(qt.ArrowCursor)` + `widget.SetCursor(cursor)` + `cursor.Delete()`
- isClickable pattern: check both Count > 0 AND Identifier != "" to block "Autres" and zero-count
- All Qt objects must be properly deleted after use in event handlers

**From Stories 1.1/1.2:**
- `BreakdownResult.Total` is sum of entry counts
- `BreakdownEntry.Identifier` is "" for "Autres" entries
- Percentage calculation: `entry.Count * 100 / data.Total` (integer division is fine for display)

### miqt API Reference for LegendWidget

**Layout construction:**
```go
root := qt.NewQWidget2()                    // or qt.NewQWidget(parent)
layout := qt.NewQVBoxLayout(root)           // QVBoxLayout attached to root
layout.SetSpacing(2)
layout.QLayout.SetContentsMargins(0, 0, 0, 0)
```

**Row construction:**
```go
row := qt.NewQWidget2()
rowLayout := qt.NewQHBoxLayout(row)
rowLayout.QLayout.SetContentsMargins(4, 2, 4, 2)

// Color swatch
swatch := qt.NewQFrame2()
swatch.QWidget.SetFixedSize2(12, 12)
swatch.QWidget.SetStyleSheet("background-color: " + entry.Color + ";")
rowLayout.QBoxLayout.AddWidget(swatch.QWidget)

// Label
label := qt.NewQLabel3(entry.Label)
rowLayout.QBoxLayout.AddWidget(label.QWidget)

// Count (bold)
countLabel := qt.NewQLabel3(fmt.Sprintf("%d", entry.Count))
countLabel.QWidget.SetStyleSheet("font-weight: bold;")
rowLayout.QBoxLayout.AddWidget(countLabel.QWidget)

// Percentage
pctLabel := qt.NewQLabel3(fmt.Sprintf("(%d%%)", pct))
rowLayout.QBoxLayout.AddWidget(pctLabel.QWidget)

layout.QBoxLayout.AddWidget(row)
```

**Hover via enter/leave events:**
```go
row.OnEnterEvent(func(super func(ev *qt.QEnterEvent), ev *qt.QEnterEvent) {
    super(ev)
    row.SetStyleSheet("background-color: #d5dbdb;")
    cursor := qt.NewQCursor2(qt.PointingHandCursor)
    row.SetCursor(cursor)
    cursor.Delete()
})
row.OnLeaveEvent(func(super func(ev *qt.QEvent), ev *qt.QEvent) {
    super(ev)
    row.SetStyleSheet("")
    cursor := qt.NewQCursor2(qt.ArrowCursor)
    row.SetCursor(cursor)
    cursor.Delete()
})
```

**Click via mouse press:**
```go
row.OnMousePressEvent(func(super func(ev *qt.QMouseEvent), ev *qt.QMouseEvent) {
    super(ev)
    // fire callback
})
```

### Clearing Existing Rows on SetData

When `SetData` is called again (data refresh), existing row widgets must be removed from the layout. Use:
```go
// Remove all children from layout
for layout.QBoxLayout.QLayout.Count() > 0 {
    item := layout.QBoxLayout.QLayout.TakeAt(0)
    if item.Widget() != nil {
        item.Widget().DeleteLater()
    }
    item.Delete()
}
```

### Architecture Constraints

- File: `internal/manager/widget/legend.go` — NEW file
- Import: `qt "github.com/mappu/miqt/qt6"`, `"fmt"` for sprintf
- Callback fields (OnRowClicked, etc.) are Go function fields, NOT Qt signals
- Widget does NOT import `screen` package
- LegendWidget and PieChartWidget are independent — dashboard.go wires them

### Testing Notes

- LegendWidget is NOT unit-testable (requires Qt display)
- Visual testing happens in Story 2.1

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Widget Data Lifecycle Pattern]
- [Source: _bmad-output/planning-artifacts/architecture.md#Component Strategy - LegendWidget]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX Consistency Patterns - Cursor Patterns]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.4]
- [Source: _bmad-output/implementation-artifacts/1-3-piechartwidget.md#Completion Notes — miqt API learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Created `legend.go` with LegendWidget struct, constructor, and all interaction logic
- SetData: clears existing rows via TakeAt/DeleteLater loop, rebuilds from BreakdownResult entries
- Each row: QWidget with QHBoxLayout containing color swatch (QFrame 12x12), label (QLabel stretch=1), count (QLabel bold), percentage (QLabel)
- Hover: OnEnterEvent sets background #d5dbdb + PointingHandCursor, OnLeaveEvent clears both
- Click: OnMousePressEvent fires OnRowClicked callback
- Non-clickable rows (Identifier="" or Count=0): no event handlers registered
- HighlightRow/ClearHighlight for bidirectional sync with PieChartWidget
- Percentage: integer division (entry.Count*100/data.Total), 0% when Total=0
- All Qt objects properly managed — cursors created/deleted in event handlers
- Compiles cleanly, all 16 existing tests pass, no regressions
- NOT unit-testable (requires Qt display) — visual testing in Story 2.1

### Change Log

- 2026-03-30: Story 1.4 implemented — LegendWidget with hover/click interactions and bidirectional highlight sync

### File List

- `internal/manager/widget/legend.go` (NEW)
