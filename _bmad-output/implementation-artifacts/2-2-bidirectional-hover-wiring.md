# Story 2.2: Bidirectional Hover Wiring

Status: review

## Story

As a user,
I want hovering a pie slice to highlight the matching legend row and vice versa,
so that I can clearly see which category I'm interacting with.

## Acceptance Criteria

1. Hovering a pie slice highlights the corresponding legend row automatically
2. Hovering a legend row highlights the corresponding pie slice (pop-out)
3. Moving mouse away from both widgets clears all highlights
4. Wiring done in dashboard.go — PieChartWidget and LegendWidget remain independent (no cross-references)
5. Both color and designation breakdown panels are wired

## Tasks / Subtasks

- [x] Task 1: Wire color breakdown bidirectional hover (AC: #1, #2, #3, #4)
  - [x] In `BuildDashboardScreen`, after creating `s.colorPie` and `s.colorLegend`:
  - [x] Set `s.colorPie.OnSliceHovered = func(id string) { s.colorLegend.HighlightRow(id) }`
  - [x] Set `s.colorPie.OnSliceUnhovered = func() { s.colorLegend.ClearHighlight() }`
  - [x] Set `s.colorLegend.OnRowHovered = func(id string) { s.colorPie.HighlightSlice(id) }`
  - [x] Set `s.colorLegend.OnRowUnhovered = func() { s.colorPie.ClearHighlight() }`

- [x] Task 2: Wire designation breakdown bidirectional hover (AC: #1, #2, #3, #4, #5)
  - [x] In `BuildDashboardScreen`, after creating `s.desigPie` and `s.desigLegend`:
  - [x] Set `s.desigPie.OnSliceHovered = func(id string) { s.desigLegend.HighlightRow(id) }`
  - [x] Set `s.desigPie.OnSliceUnhovered = func() { s.desigLegend.ClearHighlight() }`
  - [x] Set `s.desigLegend.OnRowHovered = func(id string) { s.desigPie.HighlightSlice(id) }`
  - [x] Set `s.desigLegend.OnRowUnhovered = func() { s.desigPie.ClearHighlight() }`

- [x] Task 3: Verify compilation (AC: #4)
  - [x] Build: `go build ./internal/manager/screen/`
  - [x] Run: `go test ./...`

## Dev Notes

### Exact Code Location

Modify `internal/manager/screen/dashboard.go` — insert callback wiring in `BuildDashboardScreen` after widget creation but before layout composition. The exact insertion points:

**Color wiring — insert after line 52** (`s.colorLegend = widget.NewLegendWidget(nil)`):
```go
// Wire color bidirectional hover.
s.colorPie.OnSliceHovered = func(id string) { s.colorLegend.HighlightRow(id) }
s.colorPie.OnSliceUnhovered = func() { s.colorLegend.ClearHighlight() }
s.colorLegend.OnRowHovered = func(id string) { s.colorPie.HighlightSlice(id) }
s.colorLegend.OnRowUnhovered = func() { s.colorPie.ClearHighlight() }
```

**Designation wiring — insert after line 66** (`s.desigLegend = widget.NewLegendWidget(nil)`):
```go
// Wire designation bidirectional hover.
s.desigPie.OnSliceHovered = func(id string) { s.desigLegend.HighlightRow(id) }
s.desigPie.OnSliceUnhovered = func() { s.desigLegend.ClearHighlight() }
s.desigLegend.OnRowHovered = func(id string) { s.desigPie.HighlightSlice(id) }
s.desigLegend.OnRowUnhovered = func() { s.desigPie.ClearHighlight() }
```

### Widget Callback APIs (from Stories 1.3/1.4)

**PieChartWidget callbacks:**
- `OnSliceHovered func(identifier string)` — fires when hovering a clickable slice
- `OnSliceUnhovered func()` — fires when leaving all slices
- `HighlightSlice(identifier string)` — externally highlight a slice (bidirectional from legend)
- `ClearHighlight()` — clear all highlights

**LegendWidget callbacks:**
- `OnRowHovered func(identifier string)` — fires on enter event of a clickable row
- `OnRowUnhovered func()` — fires on leave event
- `HighlightRow(identifier string)` — externally highlight a row (bidirectional from pie)
- `ClearHighlight()` — clear all row highlights

### Architecture Constraints

- ONLY modify `internal/manager/screen/dashboard.go` — do NOT modify widget files
- Widgets stay independent — they don't know about each other
- dashboard.go owns the wiring (same pattern as screen.Ctx owning screen callbacks)
- OnSliceClicked/OnRowClicked are NOT wired here — that's Story 2.4 (drill-down)

### This is a Small Story

8 lines of callback wiring. The complexity lives in the widget implementations (Stories 1.3/1.4) — this story just connects them. Quick implementation.

### References

- [Source: internal/manager/screen/dashboard.go — current state from Story 2.1]
- [Source: internal/manager/widget/pie_chart.go — OnSliceHovered/OnSliceUnhovered/HighlightSlice/ClearHighlight]
- [Source: internal/manager/widget/legend.go — OnRowHovered/OnRowUnhovered/HighlightRow/ClearHighlight]
- [Source: _bmad-output/planning-artifacts/architecture.md#Widget ↔ Widget boundary]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Added 8 lines of callback wiring in BuildDashboardScreen
- Color: pie.OnSliceHovered → legend.HighlightRow, pie.OnSliceUnhovered → legend.ClearHighlight, and vice versa
- Designation: same bidirectional pattern
- Widgets remain independent — dashboard.go owns all wiring
- Compiles cleanly, all tests pass

### Change Log

- 2026-03-30: Story 2.2 implemented — bidirectional hover wiring between pie charts and legends

### File List

- `internal/manager/screen/dashboard.go` (MODIFIED — added 8 callback wiring lines)
