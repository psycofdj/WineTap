package widget

import (
	"sort"

	"winetap/internal/client"
)

const (
	maxDesignationSlices = 0
	maxRegionSlices      = 0
)

// CountDrinkBeforePast returns the number of in-stock bottles whose
// drink_before year is strictly before the given year.
func CountDrinkBeforePast(bottles []client.Bottle, year int) int {
	n := 0
	for _, b := range bottles {
		if b.DrinkBefore != nil && int(*b.DrinkBefore) < year {
			n++
		}
	}
	return n
}

// CountDrinkBeforeThisYear returns the number of in-stock bottles whose
// drink_before year equals the given year.
func CountDrinkBeforeThisYear(bottles []client.Bottle, year int) int {
	n := 0
	for _, b := range bottles {
		if b.DrinkBefore != nil && int(*b.DrinkBefore) == year {
			n++
		}
	}
	return n
}

// TotalPrice returns the sum of PurchasePrice for all bottles.
// Bottles with nil PurchasePrice are counted as 0.
func TotalPrice(bottles []client.Bottle) float64 {
	var total float64
	for _, b := range bottles {
		if b.PurchasePrice != nil {
			total += *b.PurchasePrice
		}
	}
	return total
}

var designationPalette = []string{
	"#7eb26d", "#eab839", "#6ed0e0", "#ef843c",
	"#e24d42", "#1f78c4", "#ba43a9", "#705da0",
}

// BreakdownEntry represents a single category in a pie chart breakdown.
type BreakdownEntry struct {
	Label      string // Display label (e.g., "Rouge", "Bordeaux")
	Identifier string // Filter value for drill-down navigation
	Count      int    // Number of bottles
	Color      string // Hex color string (e.g., "#c0392b")
}

// BreakdownResult holds the complete breakdown for a pie chart widget.
type BreakdownResult struct {
	Entries []BreakdownEntry
	Total   int
}

// Wine color display order and hex values.
var colorOrder = []int32{
	client.ColorRouge,
	client.ColorBlanc,
	client.ColorRose,
	client.ColorEffervescent,
	client.ColorAutre,
}

var wineColorHex = map[int32]string{
	client.ColorRouge:        "#c0392b",
	client.ColorBlanc:        "#f1c40f",
	client.ColorRose:         "#e8a0bf",
	client.ColorEffervescent: "#3498db",
	client.ColorAutre:        "#95a5a6",
}

var wineColorLabel = map[int32]string{
	client.ColorRouge:        "Rouge",
	client.ColorBlanc:        "Blanc",
	client.ColorRose:         "Rosé",
	client.ColorEffervescent: "Effervescent",
	client.ColorAutre:        "Autre",
}

var wineColorIdentifier = map[int32]string{
	client.ColorRouge:        "rouge",
	client.ColorBlanc:        "blanc",
	client.ColorRose:         "rose",
	client.ColorEffervescent: "effervescent",
	client.ColorAutre:        "autre",
}

// AggregateByColor computes a color breakdown from a list of in-stock bottles.
// Always returns exactly 5 entries (one per wine color) in fixed order,
// including zero-count entries. Bottles with unspecified color are counted as "autre".
func AggregateByColor(bottles []client.Bottle) BreakdownResult {
	counts := make(map[int32]int)
	for _, b := range bottles {
		c := b.Cuvee.Color
		if _, known := wineColorHex[c]; !known {
			c = client.ColorAutre
		}
		counts[c]++
	}

	total := 0
	entries := make([]BreakdownEntry, 0, len(colorOrder))
	for _, c := range colorOrder {
		cnt := counts[c]
		total += cnt
		entries = append(entries, BreakdownEntry{
			Label:      wineColorLabel[c],
			Identifier: wineColorIdentifier[c],
			Count:      cnt,
			Color:      wineColorHex[c],
		})
	}

	return BreakdownResult{
		Entries: entries,
		Total:   total,
	}
}

// AggregateByDesignation computes a designation breakdown from a list of in-stock bottles.
// Returns entries sorted by count descending. If more than maxDesignationSlices distinct
// designations exist, the top entries are returned individually and the rest are summed
// into an "Autres" entry. Bottles with empty designation are grouped as "Sans appellation".
func AggregateByDesignation(bottles []client.Bottle) BreakdownResult {
	counts := make(map[string]int)
	for _, b := range bottles {
		name := b.Cuvee.DesignationName
		if name == "" {
			name = "Sans appellation"
		}
		counts[name]++
	}

	// Build entries sorted by count descending.
	type kv struct {
		name  string
		count int
	}
	sorted := make([]kv, 0, len(counts))
	for name, cnt := range counts {
		sorted = append(sorted, kv{name, cnt})
	}
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].count != sorted[j].count {
			return sorted[i].count > sorted[j].count
		}
		return sorted[i].name < sorted[j].name // stable tie-break by name
	})

	total := 0
	var entries []BreakdownEntry

	if maxDesignationSlices == 0 || len(sorted) <= maxDesignationSlices {
		entries = make([]BreakdownEntry, 0, len(sorted))
		for i, s := range sorted {
			total += s.count
			entries = append(entries, BreakdownEntry{
				Label:      s.name,
				Identifier: s.name,
				Count:      s.count,
				Color:      designationPalette[i%len(designationPalette)],
			})
		}
	} else {
		entries = make([]BreakdownEntry, 0, maxDesignationSlices+1)
		autresCount := 0
		for i, s := range sorted {
			total += s.count
			if i < maxDesignationSlices {
				entries = append(entries, BreakdownEntry{
					Label:      s.name,
					Identifier: s.name,
					Count:      s.count,
					Color:      designationPalette[i%len(designationPalette)],
				})
			} else {
				autresCount += s.count
			}
		}
		entries = append(entries, BreakdownEntry{
			Label:      "Autres",
			Identifier: "",
			Count:      autresCount,
			Color:      "#95a5a6",
		})
	}

	return BreakdownResult{
		Entries: entries,
		Total:   total,
	}
}

// regionPalette provides distinct colors for region slices.
var regionPalette = []string{
	"#e6194b", "#3cb44b", "#4363d8", "#f58231", "#911eb4",
	"#42d4f4", "#f032e6", "#bfef45", "#fabed4", "#469990",
	"#dcbeff", "#9a6324", "#800000", "#aaffc3", "#808000",
	"#000075", "#a9a9a9",
}

// AggregateByRegion computes a region breakdown from a list of in-stock bottles.
// All distinct regions are returned (no grouping into "Autres"), sorted by count
// descending. Bottles with empty region are grouped as "Sans région".
func AggregateByRegion(bottles []client.Bottle) BreakdownResult {
	counts := make(map[string]int)
	for _, b := range bottles {
		name := b.Cuvee.Region
		if name == "" {
			name = "Sans région"
		}
		counts[name]++
	}

	type kv struct {
		name  string
		count int
	}
	sorted := make([]kv, 0, len(counts))
	for name, cnt := range counts {
		sorted = append(sorted, kv{name, cnt})
	}
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].count != sorted[j].count {
			return sorted[i].count > sorted[j].count
		}
		return sorted[i].name < sorted[j].name
	})

	total := 0
	entries := make([]BreakdownEntry, 0, len(sorted))
	for i, s := range sorted {
		total += s.count
		entries = append(entries, BreakdownEntry{
			Label:      s.name,
			Identifier: s.name,
			Count:      s.count,
			Color:      regionPalette[i%len(regionPalette)],
		})
	}

	return BreakdownResult{
		Entries: entries,
		Total:   total,
	}
}
