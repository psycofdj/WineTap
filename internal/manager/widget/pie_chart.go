package widget

import (
	"fmt"
	"math"
	"strings"

	qt "github.com/mappu/miqt/qt6"
)

const (
	piePopOutOffset = 5  // pixels to offset hovered slice
	pieMargin       = 10 // margin around pie for pop-out room
)

// LegendPosition controls where the legend is placed relative to the pie.
type LegendPosition int

const (
	// LegendBottom places the legend below the pie chart.
	LegendBottom LegendPosition = iota
	// LegendRight places the legend in a vertically-scrollable area to the
	// right of the pie chart.
	LegendRight
)

// PieChartWidget renders an interactive pie chart with an integrated legend.
// Supports hover highlighting (slice pop-out, legend row highlight) and click
// callbacks for drill-down navigation.
type PieChartWidget struct {
	// root is the outer container returned by Widget().
	root *qt.QWidget

	// pie is the custom-painted pie area.
	pie          *qt.QWidget
	data         BreakdownResult
	hoveredIndex int // -1 = no hover

	// Legend widgets.
	legendContainer *qt.QWidget
	legendLayout    *qt.QVBoxLayout
	legendRows      []legendRow
	// scroll is non-nil only when LegendRight is used; enables EnsureWidgetVisible.
	scroll *qt.QScrollArea

	// Callbacks — set by the screen that composes this widget.
	OnSliceClicked func(identifier string)
	OnSliceHovered func(identifier string)
}

// legendRow tracks a single row widget and its entry index for highlight access.
type legendRow struct {
	container *qt.QWidget
	index     int
}

// NewPieChartWidget creates a pie chart with an integrated legend.
// legendPos controls whether the legend appears below or to the right of the pie.
func NewPieChartWidget(legendPos LegendPosition, parent *qt.QWidget) *PieChartWidget {
	p := &PieChartWidget{
		hoveredIndex: -1,
	}

	// Root container.
	if parent != nil {
		p.root = qt.NewQWidget(parent)
	} else {
		p.root = qt.NewQWidget2()
	}

	// Pie canvas.
	p.pie = qt.NewQWidget2()
	p.pie.SetMinimumSize2(200, 200)
	p.pie.SetMouseTracking(true)

	p.pie.OnPaintEvent(func(super func(ev *qt.QPaintEvent), ev *qt.QPaintEvent) {
		super(ev)
		p.paint()
	})

	p.pie.OnMouseMoveEvent(func(super func(ev *qt.QMouseEvent), ev *qt.QMouseEvent) {
		super(ev)
		pos := ev.Pos()
		p.handleMouseMove(pos.X(), pos.Y())
	})

	p.pie.OnMousePressEvent(func(super func(ev *qt.QMouseEvent), ev *qt.QMouseEvent) {
		super(ev)
		pos := ev.Pos()
		p.handleMousePress(pos.X(), pos.Y())
	})

	// Legend container.
	p.legendContainer = qt.NewQWidget2()
	p.legendLayout = qt.NewQVBoxLayout(p.legendContainer)
	p.legendLayout.SetSpacing(2)
	p.legendLayout.QLayout.SetContentsMargins(0, 0, 0, 0)

	// Assemble layout based on legend position.
	switch legendPos {
	case LegendRight:
		layout := qt.NewQHBoxLayout(p.root)
		layout.QLayout.SetContentsMargins(0, 0, 0, 0)
		layout.SetSpacing(8)
		layout.QBoxLayout.AddWidget2(p.pie, 1)

		scroll := qt.NewQScrollArea2()
		p.scroll = scroll
		scroll.SetWidgetResizable(true)
		scroll.QAbstractScrollArea.QFrame.QWidget.SetStyleSheet(
			"QScrollArea { border: none; background: transparent; }")
		scroll.SetWidget(p.legendContainer)
		scroll.SetHorizontalScrollBarPolicy(qt.ScrollBarAlwaysOff)
		scroll.SetVerticalScrollBarPolicy(qt.ScrollBarAsNeeded)
		layout.QBoxLayout.AddWidget2(scroll.QAbstractScrollArea.QFrame.QWidget, 1)

	default: // LegendBottom
		layout := qt.NewQVBoxLayout(p.root)
		layout.QLayout.SetContentsMargins(0, 0, 0, 0)
		layout.SetSpacing(8)
		layout.QBoxLayout.AddWidget2(p.pie, 1)
		layout.QBoxLayout.AddWidget(p.legendContainer)
	}

	return p
}

// Widget returns the outer container for layout embedding.
func (p *PieChartWidget) Widget() *qt.QWidget {
	return p.root
}

// SetData sets the breakdown data, repaints the pie, and rebuilds legend rows.
func (p *PieChartWidget) SetData(data BreakdownResult) {
	p.data = data
	p.hoveredIndex = -1
	p.pie.Update()
	p.rebuildLegend()
}

// HighlightSlice highlights the slice matching the given identifier (for external sync).
func (p *PieChartWidget) HighlightSlice(identifier string) {
	for i, e := range p.data.Entries {
		if e.Identifier == identifier {
			if p.hoveredIndex != i {
				p.hoveredIndex = i
				p.pie.Update()
				p.highlightLegendRow(identifier)
			}
			return
		}
	}
}

// ClearHighlight removes any slice/legend highlight.
func (p *PieChartWidget) ClearHighlight() {
	if p.hoveredIndex != -1 {
		p.hoveredIndex = -1
		p.pie.Update()
		p.clearLegendHighlight()
	}
}

// ── Legend management ──────────────────────────────────────────────────────

// rebuildLegend clears and rebuilds all legend rows from current data.
func (p *PieChartWidget) rebuildLegend() {
	p.clearLegendRows()
	p.legendRows = make([]legendRow, 0, len(p.data.Entries))

	for i, entry := range p.data.Entries {
		row := p.buildLegendRow(i, entry)
		p.legendRows = append(p.legendRows, legendRow{container: row, index: i})
		p.legendLayout.QBoxLayout.AddWidget(row)
	}
}

// clearLegendRows removes all existing row widgets from the legend layout.
func (p *PieChartWidget) clearLegendRows() {
	for p.legendLayout.QBoxLayout.QLayout.Count() > 0 {
		item := p.legendLayout.QBoxLayout.QLayout.TakeAt(0)
		if w := item.Widget(); w != nil {
			w.QObject.DeleteLater()
		}
		item.Delete()
	}
	p.legendRows = nil
}

// buildLegendRow creates a single legend row with swatch, label, count, and percentage.
func (p *PieChartWidget) buildLegendRow(index int, entry BreakdownEntry) *qt.QWidget {
	row := qt.NewQWidget2()
	rowLayout := qt.NewQHBoxLayout(row)
	rowLayout.QLayout.SetContentsMargins(4, 2, 4, 2)
	rowLayout.SetSpacing(6)

	// Color swatch.
	swatch := qt.NewQFrame2()
	swatch.QWidget.SetFixedSize2(12, 12)
	swatch.QWidget.SetStyleSheet("background-color: " + entry.Color + ";")
	rowLayout.QBoxLayout.AddWidget(swatch.QWidget)

	// Label.
	label := qt.NewQLabel3(entry.Label)
	rowLayout.QBoxLayout.AddWidget2(label.QWidget, 1)

	// Count (bold).
	countLabel := qt.NewQLabel3(fmt.Sprintf("%d", entry.Count))
	countLabel.QWidget.SetStyleSheet("font-weight: bold;")
	rowLayout.QBoxLayout.AddWidget(countLabel.QWidget)

	// Percentage.
	pct := 0
	if p.data.Total > 0 {
		pct = entry.Count * 100 / p.data.Total
	}
	pctLabel := qt.NewQLabel3(fmt.Sprintf("(%d%%)", pct))
	rowLayout.QBoxLayout.AddWidget(pctLabel.QWidget)

	// Register hover and click only for clickable rows.
	if entry.Count > 0 && entry.Identifier != "" {
		p.registerLegendInteractions(row, index, entry.Identifier)
	}

	return row
}

// registerLegendInteractions sets up enter/leave/click events for a clickable legend row.
func (p *PieChartWidget) registerLegendInteractions(row *qt.QWidget, index int, identifier string) {
	row.SetMouseTracking(true)

	row.OnEnterEvent(func(super func(ev *qt.QEnterEvent), ev *qt.QEnterEvent) {
		super(ev)
		row.SetStyleSheet("background-color: #d5dbdb;")
		cursor := qt.NewQCursor2(qt.PointingHandCursor)
		row.SetCursor(cursor)
		cursor.Delete()
		// Sync pie highlight.
		if p.hoveredIndex != index {
			p.hoveredIndex = index
			p.pie.Update()
		}
		if p.OnSliceHovered != nil {
			p.OnSliceHovered(identifier)
		}
	})

	row.OnLeaveEvent(func(super func(ev *qt.QEvent), ev *qt.QEvent) {
		super(ev)
		row.SetStyleSheet("")
		cursor := qt.NewQCursor2(qt.ArrowCursor)
		row.SetCursor(cursor)
		cursor.Delete()
		// Clear pie highlight.
		if p.hoveredIndex != -1 {
			p.hoveredIndex = -1
			p.pie.Update()
		}
	})

	row.OnMousePressEvent(func(super func(ev *qt.QMouseEvent), ev *qt.QMouseEvent) {
		super(ev)
		if p.OnSliceClicked != nil {
			p.OnSliceClicked(identifier)
		}
	})
}

// highlightLegendRow highlights the legend row matching the given identifier
// and, when the legend is in a scroll area, scrolls it into view.
func (p *PieChartWidget) highlightLegendRow(identifier string) {
	for _, r := range p.legendRows {
		if r.index < len(p.data.Entries) && p.data.Entries[r.index].Identifier == identifier {
			r.container.SetStyleSheet("background-color: #d5dbdb;")
			if p.scroll != nil {
				p.scroll.EnsureWidgetVisible(r.container)
			}
		} else {
			r.container.SetStyleSheet("")
		}
	}
}

// clearLegendHighlight removes highlight from all legend rows.
func (p *PieChartWidget) clearLegendHighlight() {
	for _, r := range p.legendRows {
		r.container.SetStyleSheet("")
	}
}

// ── Pie painting ──────────────────────────────────────────────────────────

// pieGeometry computes the pie bounding box centered in the pie widget.
func (p *PieChartWidget) pieGeometry() (centerX, centerY, radius int) {
	w := p.pie.Width()
	h := p.pie.Height()
	centerX = w / 2
	centerY = h / 2
	radius = centerX
	if centerY < radius {
		radius = centerY
	}
	radius -= pieMargin + piePopOutOffset
	if radius < 10 {
		radius = 10
	}
	return
}

// paint renders the pie chart.
func (p *PieChartWidget) paint() {
	painter := qt.NewQPainter2(p.pie.QPaintDevice)
	defer painter.Delete()
	painter.SetRenderHint(qt.QPainter__Antialiasing)

	centerX, centerY, radius := p.pieGeometry()

	if p.data.Total == 0 {
		p.drawEmptyState(painter, centerX, centerY, radius)
		painter.End()
		return
	}

	startAngle := 90 * 16
	for i, entry := range p.data.Entries {
		if entry.Count == 0 {
			continue
		}
		arcLength := int(math.Round(float64(entry.Count) / float64(p.data.Total) * 5760))
		if isLastNonZero(p.data.Entries, i) {
			arcLength = 5760 - (startAngle - 90*16)
			if arcLength <= 0 {
				arcLength += 5760
			}
		}

		ox, oy := centerX-radius, centerY-radius
		d := radius * 2

		hex := entry.Color
		if i == p.hoveredIndex {
			hex = lightenHex(hex)
		}
		color := qt.NewQColor6(hex)

		brush := qt.NewQBrush3(color)
		painter.SetBrush(brush)
		painter.SetPenWithStyle(qt.NoPen)
		painter.DrawPie2(ox, oy, d, d, startAngle, arcLength)
		brush.Delete()
		color.Delete()

		startAngle += arcLength
	}

	painter.End()
}

// drawEmptyState renders a grey circle with "0" centered.
func (p *PieChartWidget) drawEmptyState(painter *qt.QPainter, cx, cy, r int) {
	color := qt.NewQColor6("#95a5a6")
	defer color.Delete()
	brush := qt.NewQBrush3(color)
	defer brush.Delete()

	painter.SetBrush(brush)
	painter.SetPenWithStyle(qt.NoPen)
	painter.DrawEllipse2(cx-r, cy-r, r*2, r*2)

	textColor := qt.NewQColor6("#ffffff")
	defer textColor.Delete()
	painter.SetPen(textColor)
	painter.DrawText7(cx-r, cy-r, r*2, r*2, int(qt.AlignCenter), "0")
}

// ── Hit testing ───────────────────────────────────────────────────────────

// hitTest returns the index of the slice at mouse position (mx, my), or -1 if none.
func (p *PieChartWidget) hitTest(mx, my int) int {
	if p.data.Total == 0 {
		return -1
	}
	centerX, centerY, radius := p.pieGeometry()

	dx := float64(mx - centerX)
	dy := float64(centerY - my)
	dist := math.Sqrt(dx*dx + dy*dy)
	if dist > float64(radius) {
		return -1
	}

	angleRad := math.Atan2(dy, dx)
	if angleRad < 0 {
		angleRad += 2 * math.Pi
	}
	angleDeg16 := int(angleRad * 180.0 / math.Pi * 16)

	start := 90 * 16
	for i, entry := range p.data.Entries {
		if entry.Count == 0 {
			continue
		}
		arcLen := int(math.Round(float64(entry.Count) / float64(p.data.Total) * 5760))
		if isLastNonZero(p.data.Entries, i) {
			arcLen = 5760 - (start - 90*16)
			if arcLen <= 0 {
				arcLen += 5760
			}
		}

		if angleInRange(angleDeg16, start, arcLen) {
			return i
		}
		start += arcLen
	}
	return -1
}

// angleInRange checks if angle is within the arc [start, start+length) in 1/16th degree space (mod 5760).
func angleInRange(angle, start, length int) bool {
	angle = ((angle % 5760) + 5760) % 5760
	start = ((start % 5760) + 5760) % 5760
	end := (start + length) % 5760

	if length >= 5760 {
		return true
	}
	if start < end {
		return angle >= start && angle < end
	}
	return angle >= start || angle < end
}

// isLastNonZero returns true if entries[i] is the last entry with Count > 0.
func isLastNonZero(entries []BreakdownEntry, i int) bool {
	for j := i + 1; j < len(entries); j++ {
		if entries[j].Count > 0 {
			return false
		}
	}
	return true
}

// isClickable returns true if the entry at index i is clickable.
func (p *PieChartWidget) isClickable(i int) bool {
	if i < 0 || i >= len(p.data.Entries) {
		return false
	}
	e := p.data.Entries[i]
	return e.Count > 0 && e.Identifier != ""
}

func (p *PieChartWidget) handleMouseMove(mx, my int) {
	idx := p.hitTest(mx, my)

	if idx == p.hoveredIndex {
		return
	}

	p.hoveredIndex = idx

	if p.isClickable(idx) {
		cursor := qt.NewQCursor2(qt.PointingHandCursor)
		p.pie.SetCursor(cursor)
		cursor.Delete()
	} else {
		cursor := qt.NewQCursor2(qt.ArrowCursor)
		p.pie.SetCursor(cursor)
		cursor.Delete()
	}

	// Update tooltip for the hovered slice.
	if idx >= 0 && idx < len(p.data.Entries) && p.data.Entries[idx].Count > 0 {
		entry := p.data.Entries[idx]
		pct := 0
		if p.data.Total > 0 {
			pct = entry.Count * 100 / p.data.Total
		}
		p.pie.SetToolTip(fmt.Sprintf("%s: %d (%d%%)", entry.Label, entry.Count, pct))
	} else {
		p.pie.SetToolTip("")
	}

	// Sync legend highlight.
	if p.isClickable(idx) {
		p.highlightLegendRow(p.data.Entries[idx].Identifier)
		if p.OnSliceHovered != nil {
			p.OnSliceHovered(p.data.Entries[idx].Identifier)
		}
	} else {
		p.clearLegendHighlight()
	}

	p.pie.Update()
}

func (p *PieChartWidget) handleMousePress(mx, my int) {
	idx := p.hitTest(mx, my)
	if p.isClickable(idx) {
		if p.OnSliceClicked != nil {
			p.OnSliceClicked(p.data.Entries[idx].Identifier)
		}
	}
}

// lightenHex takes a "#rrggbb" hex color and returns a lighter version
// by blending each channel 15% toward white.
func lightenHex(hex string) string {
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) != 6 {
		return "#" + hex
	}
	var r, g, b uint64
	fmt.Sscanf(hex, "%02x%02x%02x", &r, &g, &b)
	r = r + (255-r)*15/100
	g = g + (255-g)*15/100
	b = b + (255-b)*15/100
	return fmt.Sprintf("#%02x%02x%02x", r, g, b)
}
