package screen

import (
	"context"
	"fmt"
	"math"
	"strings"
	"time"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
	"winetap/internal/manager/widget"
)

// formatPrice formats a price as "1 234,50 €" with French-style grouping.
func formatPrice(v float64) string {
	cents := int64(math.Round(v * 100))
	whole := cents / 100
	frac := cents % 100
	if frac < 0 {
		frac = -frac
	}

	s := fmt.Sprintf("%d", whole)
	if whole < 0 {
		s = s[1:] // handle sign separately
	}

	// Insert space as thousands separator (right to left).
	var parts []string
	for len(s) > 3 {
		parts = append([]string{s[len(s)-3:]}, parts...)
		s = s[:len(s)-3]
	}
	parts = append([]string{s}, parts...)
	grouped := strings.Join(parts, " ")

	if whole < 0 {
		grouped = "-" + grouped
	}

	return fmt.Sprintf("%s,%02d €", grouped, frac)
}

// DashboardScreen displays cellar inventory summaries with interactive breakdowns.
type DashboardScreen struct {
	Widget *qt.QWidget
	ctx    *Ctx

	heroCount         *widget.HeroCountWidget
	heroPrice         *widget.HeroCountWidget
	heroPastDrink     *widget.HeroCountWidget
	heroThisYearDrink *widget.HeroCountWidget
	colorPie          *widget.PieChartWidget
	desigPie          *widget.PieChartWidget
	regionPie         *widget.PieChartWidget
}

// BuildDashboardScreen constructs the dashboard screen with hero count and breakdown panels.
// Layout is organised into rows (QVBoxLayout) each containing cells (QHBoxLayout):
//
//	Row 1: Stock count | Total value
//	Row 2: Color breakdown | Designation breakdown
//	Row 3: Region breakdown (pie + scrollable side legend)
func BuildDashboardScreen(ctx *Ctx) *DashboardScreen {
	s := &DashboardScreen{ctx: ctx}
	s.Widget = qt.NewQWidget2()

	root := qt.NewQVBoxLayout(s.Widget)
	root.QLayout.SetContentsMargins(16, 16, 16, 16)
	root.SetSpacing(16)

	// Screen title.
	title := qt.NewQLabel3("Tableau de bord")
	title.QWidget.QObject.SetProperty("role", qt.NewQVariant11("screen-title"))
	root.QBoxLayout.AddWidget(title.QWidget)

	// ── Row 1: hero stats ─────────────────────────────────────────────────
	row1 := qt.NewQWidget2()
	row1Layout := qt.NewQHBoxLayout(row1)
	row1Layout.QLayout.SetContentsMargins(0, 0, 0, 0)
	row1Layout.SetSpacing(16)

	s.heroCount = widget.NewHeroCountWidget("bouteilles en stock", nil)
	heroPanel := widget.NewDashboardPanel("Stock",
		"Nombre total de bouteilles actuellement en stock dans la cave.",
		s.heroCount.Widget(), nil)
	row1Layout.QBoxLayout.AddWidget2(heroPanel.Widget(), 1)

	s.heroPrice = widget.NewHeroCountWidget("valeur estimée", nil)
	pricePanel := widget.NewDashboardPanel("Valeur",
		"Valeur estimée du stock au prix d'achat.\nLes bouteilles sans prix d'achat renseigné ne sont pas comptabilisées.",
		s.heroPrice.Widget(), nil)
	row1Layout.QBoxLayout.AddWidget2(pricePanel.Widget(), 1)

	s.heroPastDrink = widget.NewHeroCountWidget("bouteilles à consommer (dépassé)", nil)
	pastDrinkPanel := widget.NewDashboardPanel("À boire (passé)",
		"Nombre de bouteilles dont la date de dégustation recommandée est dépassée.",
		s.heroPastDrink.Widget(), nil)
	row1Layout.QBoxLayout.AddWidget2(pastDrinkPanel.Widget(), 1)

	s.heroThisYearDrink = widget.NewHeroCountWidget("bouteilles à consommer (cette année)", nil)
	thisYearDrinkPanel := widget.NewDashboardPanel("À boire (cette année)",
		"Nombre de bouteilles dont la date de dégustation recommandée est cette année.",
		s.heroThisYearDrink.Widget(), nil)
	row1Layout.QBoxLayout.AddWidget2(thisYearDrinkPanel.Widget(), 1)

	root.QBoxLayout.AddWidget(row1)

	// ── Row 2: color + designation breakdowns ─────────────────────────────
	row2 := qt.NewQWidget2()
	row2Layout := qt.NewQHBoxLayout(row2)
	row2Layout.QLayout.SetContentsMargins(0, 0, 0, 0)
	row2Layout.SetSpacing(16)

	// Color breakdown panel (legend below).
	s.colorPie = widget.NewPieChartWidget(widget.LegendRight, nil)
	s.colorPie.OnSliceClicked = func(id string) { s.navigateFiltered(FilterByColor, id) }

	colorPanel := widget.NewDashboardPanel("Par couleur",
		"Répartition des bouteilles en stock par couleur de vin (rouge, blanc, rosé, effervescent, autre).\nCliquez sur une part ou une ligne de légende pour filtrer l'inventaire.",
		s.colorPie.Widget(), nil)
	row2Layout.QBoxLayout.AddWidget2(colorPanel.Widget(), 1)

	// Designation breakdown panel (legend below).
	s.desigPie = widget.NewPieChartWidget(widget.LegendRight, nil)
	s.desigPie.OnSliceClicked = func(id string) { s.navigateFiltered(FilterByDesignation, id) }
	desigPanel := widget.NewDashboardPanel("Par appellation",
		"Répartition des bouteilles en stock par appellation.\nCliquez sur une part ou une ligne de légende pour filtrer l'inventaire.",
		s.desigPie.Widget(), nil)
	row2Layout.QBoxLayout.AddWidget2(desigPanel.Widget(), 1)

	root.QBoxLayout.AddWidget2(row2, 1)

	// ── Row 3: region breakdown (pie + scrollable side legend) ────────────
	row3 := qt.NewQWidget2()
	row3Layout := qt.NewQHBoxLayout(row3)
	row3Layout.QLayout.SetContentsMargins(0, 0, 0, 0)
	row3Layout.SetSpacing(16)

	s.regionPie = widget.NewPieChartWidget(widget.LegendRight, nil)
	s.regionPie.OnSliceClicked = func(id string) { s.navigateFiltered(FilterByRegion, id) }

	regionPanel := widget.NewDashboardPanel("Par région",
		"Répartition des bouteilles en stock par région viticole.\nToutes les régions sont affichées. Cliquez sur une part ou une ligne de légende pour filtrer l'inventaire.",
		s.regionPie.Widget(), nil)
	row3Layout.QBoxLayout.AddWidget2(regionPanel.Widget(), 1)

	root.QBoxLayout.AddWidget2(row3, 1)

	return s
}

// navigateFiltered calls the Ctx callback to navigate to filtered inventory.
func (s *DashboardScreen) navigateFiltered(filterType, filterValue string) {
	if s.ctx.NavigateToInventoryWithFilter != nil {
		s.ctx.NavigateToInventoryWithFilter(filterType, filterValue)
	}
}

// OnActivate fetches bottle data and updates all dashboard widgets.
// Called each time the user navigates to the dashboard screen.
func (s *DashboardScreen) OnActivate() {
	go func() {
		bottles, err := s.ctx.Client.ListBottles(context.Background(), false)
		if err != nil {
			s.ctx.Log.Error("dashboard list bottles", "error", err)
			return
		}

		// Filter to in-stock bottles (safety net — default params already exclude consumed).
		var inStock []client.Bottle
		for _, b := range bottles {
			if b.ConsumedAt == nil {
				inStock = append(inStock, b)
			}
		}

		colorResult := widget.AggregateByColor(inStock)
		desigResult := widget.AggregateByDesignation(inStock)
		regionResult := widget.AggregateByRegion(inStock)
		totalPrice := widget.TotalPrice(inStock)
		currentYear := time.Now().Year()
		pastDrink := widget.CountDrinkBeforePast(inStock, currentYear)
		thisYearDrink := widget.CountDrinkBeforeThisYear(inStock, currentYear)

		mainthread.Start(func() {
			s.heroCount.SetCount(colorResult.Total)
			s.heroPrice.SetText(formatPrice(totalPrice))
			s.heroPastDrink.SetCount(pastDrink)
			s.heroThisYearDrink.SetCount(thisYearDrink)
			s.colorPie.SetData(colorResult)
			s.desigPie.SetData(desigResult)
			s.regionPie.SetData(regionResult)
		})
	}()
}
