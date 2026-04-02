package widget

import qt "github.com/mappu/miqt/qt6"

// DashboardPanel is a Grafana-style bordered container with a title header.
type DashboardPanel struct {
	frame *qt.QFrame
}

// NewDashboardPanel creates a bordered panel with a title and a child widget.
// The panel is styled via the CSS role "dashboard-panel".
// If tooltip is non-empty, an info icon "ⓘ" is shown to the left of the title
// that displays the tooltip on hover.
func NewDashboardPanel(title, tooltip string, child *qt.QWidget, parent *qt.QWidget) *DashboardPanel {
	d := &DashboardPanel{}

	if parent != nil {
		d.frame = qt.NewQFrame(parent)
	} else {
		d.frame = qt.NewQFrame2()
	}
	d.frame.QWidget.QObject.SetProperty("role", qt.NewQVariant11("dashboard-panel"))

	layout := qt.NewQVBoxLayout(d.frame.QWidget)
	layout.QLayout.SetContentsMargins(0, 0, 0, 0)
	layout.SetSpacing(8)

	// Title row — optional info icon + title label.
	titleRow := qt.NewQWidget2()
	titleRowLayout := qt.NewQHBoxLayout(titleRow)
	titleRowLayout.QLayout.SetContentsMargins(0, 0, 0, 0)
	titleRowLayout.SetSpacing(6)

	if tooltip != "" {
		infoIcon := qt.NewQLabel3("ⓘ")
		infoIcon.QWidget.QObject.SetProperty("role", qt.NewQVariant11("panel-info-icon"))
		infoIcon.SetToolTip(tooltip)
		titleRowLayout.QBoxLayout.AddWidget(infoIcon.QWidget)
	}

	titleLabel := qt.NewQLabel3(title)
	titleLabel.QWidget.QObject.SetProperty("role", qt.NewQVariant11("section-header"))
	titleRowLayout.QBoxLayout.AddWidget(titleLabel.QWidget)

	titleRowLayout.AddStretch()

	layout.QBoxLayout.AddWidget(titleRow)

	// Child widget fills remaining space.
	if child != nil {
		layout.QBoxLayout.AddWidget2(child, 1)
	}

	return d
}

// Widget returns the underlying QWidget for layout embedding.
func (d *DashboardPanel) Widget() *qt.QWidget {
	return d.frame.QWidget
}
