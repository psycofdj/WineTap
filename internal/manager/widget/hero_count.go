package widget

import (
	"fmt"

	qt "github.com/mappu/miqt/qt6"
)

// HeroCountWidget displays a single large number with a subtitle label.
// Used for the dashboard stock count.
type HeroCountWidget struct {
	widget       *qt.QWidget
	countLabel   *qt.QLabel
	subtitleLabel *qt.QLabel
}

// NewHeroCountWidget creates a hero count widget with the given subtitle.
// Displays "0" by default. Call SetCount to update.
func NewHeroCountWidget(label string, parent *qt.QWidget) *HeroCountWidget {
	h := &HeroCountWidget{}

	if parent != nil {
		h.widget = qt.NewQWidget(parent)
	} else {
		h.widget = qt.NewQWidget2()
	}

	layout := qt.NewQVBoxLayout(h.widget)
	layout.QLayout.SetContentsMargins(0, 0, 0, 0)
	layout.SetSpacing(4)

	// Count label — styled via CSS role.
	h.countLabel = qt.NewQLabel3("0")
	h.countLabel.QWidget.QObject.SetProperty("role", qt.NewQVariant11("dashboard-hero-number"))
	h.countLabel.SetAlignment(qt.AlignCenter)
	layout.QBoxLayout.AddWidget(h.countLabel.QWidget)

	// Subtitle label — styled via CSS role.
	h.subtitleLabel = qt.NewQLabel3(label)
	h.subtitleLabel.QWidget.QObject.SetProperty("role", qt.NewQVariant11("dashboard-hero-label"))
	h.subtitleLabel.SetAlignment(qt.AlignCenter)
	layout.QBoxLayout.AddWidget(h.subtitleLabel.QWidget)

	return h
}

// SetCount updates the displayed number.
func (h *HeroCountWidget) SetCount(n int) {
	h.countLabel.SetText(fmt.Sprintf("%d", n))
}

// SetText updates the displayed text to an arbitrary string.
func (h *HeroCountWidget) SetText(s string) {
	h.countLabel.SetText(s)
}

// Widget returns the underlying QWidget for layout embedding.
func (h *HeroCountWidget) Widget() *qt.QWidget {
	return h.widget
}
