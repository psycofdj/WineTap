package widget

import (
	"fmt"
	"testing"

	"winetap/internal/client"
)

func makeBottle(color int32, designation string) client.Bottle {
	return client.Bottle{
		Cuvee: client.Cuvee{
			Color:           color,
			DesignationName: designation,
		},
	}
}

func makeBottleWithRegion(region string) client.Bottle {
	return client.Bottle{
		Cuvee: client.Cuvee{
			Color:  client.ColorRouge,
			Region: region,
		},
	}
}

func makeBottleWithPrice(price *float64) client.Bottle {
	return client.Bottle{PurchasePrice: price}
}

func makeBottleWithDrinkBefore(year *int32) client.Bottle {
	return client.Bottle{DrinkBefore: year}
}

func int32Ptr(v int32) *int32 { return &v }
func floatPtr(v float64) *float64 { return &v }

func TestAggregateByColor_EmptyList(t *testing.T) {
	result := AggregateByColor(nil)
	if result.Total != 0 {
		t.Errorf("Total = %d, want 0", result.Total)
	}
	if len(result.Entries) != 5 {
		t.Fatalf("Entries count = %d, want 5", len(result.Entries))
	}
	for _, e := range result.Entries {
		if e.Count != 0 {
			t.Errorf("Entry %q Count = %d, want 0", e.Label, e.Count)
		}
	}
}

func TestAggregateByColor_SingleRouge(t *testing.T) {
	bottles := []client.Bottle{makeBottle(client.ColorRouge, "Bordeaux")}
	result := AggregateByColor(bottles)
	if result.Total != 1 {
		t.Errorf("Total = %d, want 1", result.Total)
	}
	if len(result.Entries) != 5 {
		t.Fatalf("Entries count = %d, want 5", len(result.Entries))
	}
	// First entry should be Rouge with count 1
	if result.Entries[0].Label != "Rouge" || result.Entries[0].Count != 1 {
		t.Errorf("First entry = %+v, want Rouge with Count 1", result.Entries[0])
	}
	// Others should be 0
	for _, e := range result.Entries[1:] {
		if e.Count != 0 {
			t.Errorf("Entry %q Count = %d, want 0", e.Label, e.Count)
		}
	}
}

func TestAggregateByColor_MixedColors(t *testing.T) {
	bottles := []client.Bottle{
		makeBottle(client.ColorRouge, ""),
		makeBottle(client.ColorRouge, ""),
		makeBottle(client.ColorBlanc, ""),
		makeBottle(client.ColorRose, ""),
		makeBottle(client.ColorEffervescent, ""),
		makeBottle(client.ColorAutre, ""),
	}
	result := AggregateByColor(bottles)
	if result.Total != 6 {
		t.Errorf("Total = %d, want 6", result.Total)
	}

	expected := map[string]int{
		"Rouge": 2, "Blanc": 1, "Rosé": 1, "Effervescent": 1, "Autre": 1,
	}
	for _, e := range result.Entries {
		if e.Count != expected[e.Label] {
			t.Errorf("Entry %q Count = %d, want %d", e.Label, e.Count, expected[e.Label])
		}
	}
}

func TestAggregateByColor_NilCuvee(t *testing.T) {
	bottles := []client.Bottle{{}} // zero-value Cuvee, color = 0 (unspecified)
	result := AggregateByColor(bottles)
	if result.Total != 1 {
		t.Errorf("Total = %d, want 1", result.Total)
	}
	// Should be counted as "autre"
	for _, e := range result.Entries {
		if e.Label == "Autre" && e.Count != 1 {
			t.Errorf("Autre Count = %d, want 1", e.Count)
		} else if e.Label != "Autre" && e.Count != 0 {
			t.Errorf("Entry %q Count = %d, want 0", e.Label, e.Count)
		}
	}
}

func TestAggregateByColor_UnspecifiedColor(t *testing.T) {
	bottles := []client.Bottle{makeBottle(client.ColorUnspecified, "")}
	result := AggregateByColor(bottles)
	if result.Total != 1 {
		t.Errorf("Total = %d, want 1", result.Total)
	}
	for _, e := range result.Entries {
		if e.Label == "Autre" && e.Count != 1 {
			t.Errorf("Autre Count = %d, want 1", e.Count)
		} else if e.Label != "Autre" && e.Count != 0 {
			t.Errorf("Entry %q Count = %d, want 0", e.Label, e.Count)
		}
	}
}

func TestAggregateByColor_AllSameColor(t *testing.T) {
	bottles := []client.Bottle{
		makeBottle(client.ColorBlanc, ""),
		makeBottle(client.ColorBlanc, ""),
		makeBottle(client.ColorBlanc, ""),
	}
	result := AggregateByColor(bottles)
	if result.Total != 3 {
		t.Errorf("Total = %d, want 3", result.Total)
	}
	for _, e := range result.Entries {
		if e.Label == "Blanc" && e.Count != 3 {
			t.Errorf("Blanc Count = %d, want 3", e.Count)
		} else if e.Label != "Blanc" && e.Count != 0 {
			t.Errorf("Entry %q Count = %d, want 0", e.Label, e.Count)
		}
	}
}

func TestAggregateByColor_UnknownEnumValue(t *testing.T) {
	bottles := []client.Bottle{
		{Cuvee: client.Cuvee{Color: 99}}, // future/unknown color value
		makeBottle(client.ColorRouge, ""),
	}
	result := AggregateByColor(bottles)
	if result.Total != 2 {
		t.Errorf("Total = %d, want 2", result.Total)
	}
	// Unknown should be counted as "autre"
	for _, e := range result.Entries {
		if e.Label == "Autre" && e.Count != 1 {
			t.Errorf("Autre Count = %d, want 1", e.Count)
		}
		if e.Label == "Rouge" && e.Count != 1 {
			t.Errorf("Rouge Count = %d, want 1", e.Count)
		}
	}
	// Total should equal sum of entry counts
	sum := 0
	for _, e := range result.Entries {
		sum += e.Count
	}
	if result.Total != sum {
		t.Errorf("Total %d != sum of counts %d", result.Total, sum)
	}
}

func TestAggregateByColor_EntryFields(t *testing.T) {
	bottles := []client.Bottle{makeBottle(client.ColorRouge, "")}
	result := AggregateByColor(bottles)
	rouge := result.Entries[0]
	if rouge.Label != "Rouge" {
		t.Errorf("Label = %q, want %q", rouge.Label, "Rouge")
	}
	if rouge.Identifier != "rouge" {
		t.Errorf("Identifier = %q, want %q", rouge.Identifier, "rouge")
	}
	if rouge.Color != "#c0392b" {
		t.Errorf("Color = %q, want %q", rouge.Color, "#c0392b")
	}
}

// --- AggregateByDesignation tests ---

func TestAggregateByDesignation_EmptyList(t *testing.T) {
	result := AggregateByDesignation(nil)
	if result.Total != 0 {
		t.Errorf("Total = %d, want 0", result.Total)
	}
	if len(result.Entries) != 0 {
		t.Errorf("Entries count = %d, want 0", len(result.Entries))
	}
}

func TestAggregateByDesignation_SingleDesignation(t *testing.T) {
	bottles := []client.Bottle{
		makeBottle(client.ColorRouge, "Bordeaux"),
		makeBottle(client.ColorRouge, "Bordeaux"),
	}
	result := AggregateByDesignation(bottles)
	if result.Total != 2 {
		t.Errorf("Total = %d, want 2", result.Total)
	}
	if len(result.Entries) != 1 {
		t.Fatalf("Entries count = %d, want 1", len(result.Entries))
	}
	if result.Entries[0].Label != "Bordeaux" {
		t.Errorf("Label = %q, want %q", result.Entries[0].Label, "Bordeaux")
	}
	if result.Entries[0].Count != 2 {
		t.Errorf("Count = %d, want 2", result.Entries[0].Count)
	}
	if result.Entries[0].Color != designationPalette[0] {
		t.Errorf("Color = %q, want %q", result.Entries[0].Color, designationPalette[0])
	}
}

func TestAggregateByDesignation_EmptyDesignation(t *testing.T) {
	bottles := []client.Bottle{
		makeBottle(client.ColorRouge, ""),
		makeBottle(client.ColorBlanc, ""),
	}
	result := AggregateByDesignation(bottles)
	if len(result.Entries) != 1 {
		t.Fatalf("Entries count = %d, want 1", len(result.Entries))
	}
	if result.Entries[0].Label != "Sans appellation" {
		t.Errorf("Label = %q, want %q", result.Entries[0].Label, "Sans appellation")
	}
	if result.Entries[0].Count != 2 {
		t.Errorf("Count = %d, want 2", result.Entries[0].Count)
	}
}

func TestAggregateByDesignation_NilCuvee(t *testing.T) {
	bottles := []client.Bottle{{}} // zero-value Cuvee, empty DesignationName
	result := AggregateByDesignation(bottles)
	if len(result.Entries) != 1 {
		t.Fatalf("Entries count = %d, want 1", len(result.Entries))
	}
	if result.Entries[0].Label != "Sans appellation" {
		t.Errorf("Label = %q, want %q", result.Entries[0].Label, "Sans appellation")
	}
}

func TestAggregateByDesignation_Exactly8(t *testing.T) {
	var bottles []client.Bottle
	names := []string{"A", "B", "C", "D", "E", "F", "G", "H"}
	for i, name := range names {
		// Give each a different count so sort order is deterministic
		for j := 0; j <= i; j++ {
			bottles = append(bottles, makeBottle(client.ColorRouge, name))
		}
	}
	result := AggregateByDesignation(bottles)
	if len(result.Entries) != 8 {
		t.Fatalf("Entries count = %d, want 8", len(result.Entries))
	}
	// No "Autres" entry
	for _, e := range result.Entries {
		if e.Label == "Autres" {
			t.Error("Found 'Autres' entry with ≤8 designations")
		}
	}
	// All palette colors used
	for i, e := range result.Entries {
		if e.Color != designationPalette[i] {
			t.Errorf("Entry %d Color = %q, want %q", i, e.Color, designationPalette[i])
		}
	}
	// Sorted by count descending
	for i := 1; i < len(result.Entries); i++ {
		if result.Entries[i].Count > result.Entries[i-1].Count {
			t.Errorf("Entry %d Count %d > Entry %d Count %d — not sorted descending",
				i, result.Entries[i].Count, i-1, result.Entries[i-1].Count)
		}
	}
}

func TestAggregateByDesignation_MoreThan8(t *testing.T) {
	var bottles []client.Bottle
	names := []string{"A", "B", "C", "D", "E", "F", "G", "H", "I", "J"}
	for i, name := range names {
		for j := 0; j <= i; j++ {
			bottles = append(bottles, makeBottle(client.ColorRouge, name))
		}
	}
	result := AggregateByDesignation(bottles)
	// maxDesignationSlices = 0 means no limit — all 10 entries returned individually.
	if len(result.Entries) != 10 {
		t.Fatalf("Entries count = %d, want 10", len(result.Entries))
	}
	// No "Autres" entry.
	for _, e := range result.Entries {
		if e.Label == "Autres" {
			t.Error("Found 'Autres' entry — no grouping expected when maxDesignationSlices = 0")
		}
	}
	// Total = sum of all entry counts.
	sum := 0
	for _, e := range result.Entries {
		sum += e.Count
	}
	if result.Total != sum {
		t.Errorf("Total %d != sum of counts %d", result.Total, sum)
	}
}

func TestAggregateByDesignation_AllSame(t *testing.T) {
	bottles := []client.Bottle{
		makeBottle(client.ColorRouge, "Champagne"),
		makeBottle(client.ColorBlanc, "Champagne"),
		makeBottle(client.ColorRose, "Champagne"),
	}
	result := AggregateByDesignation(bottles)
	if result.Total != 3 {
		t.Errorf("Total = %d, want 3", result.Total)
	}
	if len(result.Entries) != 1 {
		t.Fatalf("Entries count = %d, want 1", len(result.Entries))
	}
	if result.Entries[0].Label != "Champagne" {
		t.Errorf("Label = %q, want %q", result.Entries[0].Label, "Champagne")
	}
}

func TestAggregateByDesignation_SortedDescending(t *testing.T) {
	bottles := []client.Bottle{
		makeBottle(client.ColorRouge, "Bordeaux"),
		makeBottle(client.ColorRouge, "Champagne"),
		makeBottle(client.ColorRouge, "Champagne"),
		makeBottle(client.ColorRouge, "Champagne"),
		makeBottle(client.ColorRouge, "Bourgogne"),
		makeBottle(client.ColorRouge, "Bourgogne"),
	}
	result := AggregateByDesignation(bottles)
	if len(result.Entries) != 3 {
		t.Fatalf("Entries count = %d, want 3", len(result.Entries))
	}
	// Champagne=3, Bourgogne=2, Bordeaux=1
	if result.Entries[0].Label != "Champagne" || result.Entries[0].Count != 3 {
		t.Errorf("First entry = %+v, want Champagne:3", result.Entries[0])
	}
	if result.Entries[1].Label != "Bourgogne" || result.Entries[1].Count != 2 {
		t.Errorf("Second entry = %+v, want Bourgogne:2", result.Entries[1])
	}
	if result.Entries[2].Label != "Bordeaux" || result.Entries[2].Count != 1 {
		t.Errorf("Third entry = %+v, want Bordeaux:1", result.Entries[2])
	}
}

// --- CountDrinkBeforePast tests ---

func TestCountDrinkBeforePast_NilDrinkBefore(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithDrinkBefore(nil),
		makeBottleWithDrinkBefore(nil),
	}
	if got := CountDrinkBeforePast(bottles, 2026); got != 0 {
		t.Errorf("got %d, want 0", got)
	}
}

func TestCountDrinkBeforePast_AllPast(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithDrinkBefore(int32Ptr(2020)),
		makeBottleWithDrinkBefore(int32Ptr(2023)),
		makeBottleWithDrinkBefore(int32Ptr(2025)),
	}
	if got := CountDrinkBeforePast(bottles, 2026); got != 3 {
		t.Errorf("got %d, want 3", got)
	}
}

func TestCountDrinkBeforePast_CurrentYearNotCounted(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithDrinkBefore(int32Ptr(2026)),
		makeBottleWithDrinkBefore(int32Ptr(2025)),
	}
	if got := CountDrinkBeforePast(bottles, 2026); got != 1 {
		t.Errorf("got %d, want 1", got)
	}
}

func TestCountDrinkBeforePast_FutureNotCounted(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithDrinkBefore(int32Ptr(2030)),
		makeBottleWithDrinkBefore(int32Ptr(2027)),
	}
	if got := CountDrinkBeforePast(bottles, 2026); got != 0 {
		t.Errorf("got %d, want 0", got)
	}
}

func TestCountDrinkBeforePast_EmptyList(t *testing.T) {
	if got := CountDrinkBeforePast(nil, 2026); got != 0 {
		t.Errorf("got %d, want 0", got)
	}
}

// --- CountDrinkBeforeThisYear tests ---

func TestCountDrinkBeforeThisYear_NilDrinkBefore(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithDrinkBefore(nil),
		makeBottleWithDrinkBefore(nil),
	}
	if got := CountDrinkBeforeThisYear(bottles, 2026); got != 0 {
		t.Errorf("got %d, want 0", got)
	}
}

func TestCountDrinkBeforeThisYear_MatchingYear(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithDrinkBefore(int32Ptr(2026)),
		makeBottleWithDrinkBefore(int32Ptr(2026)),
		makeBottleWithDrinkBefore(int32Ptr(2025)),
		makeBottleWithDrinkBefore(int32Ptr(2027)),
	}
	if got := CountDrinkBeforeThisYear(bottles, 2026); got != 2 {
		t.Errorf("got %d, want 2", got)
	}
}

func TestCountDrinkBeforeThisYear_NoMatch(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithDrinkBefore(int32Ptr(2025)),
		makeBottleWithDrinkBefore(int32Ptr(2027)),
	}
	if got := CountDrinkBeforeThisYear(bottles, 2026); got != 0 {
		t.Errorf("got %d, want 0", got)
	}
}

func TestCountDrinkBeforeThisYear_EmptyList(t *testing.T) {
	if got := CountDrinkBeforeThisYear(nil, 2026); got != 0 {
		t.Errorf("got %d, want 0", got)
	}
}

// --- TotalPrice tests ---

func TestTotalPrice_EmptyList(t *testing.T) {
	if got := TotalPrice(nil); got != 0 {
		t.Errorf("TotalPrice(nil) = %f, want 0", got)
	}
}

func TestTotalPrice_AllWithPrices(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithPrice(floatPtr(10.50)),
		makeBottleWithPrice(floatPtr(25.00)),
		makeBottleWithPrice(floatPtr(7.99)),
	}
	got := TotalPrice(bottles)
	want := 43.49
	if got != want {
		t.Errorf("TotalPrice = %f, want %f", got, want)
	}
}

func TestTotalPrice_NilPricesCountAsZero(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithPrice(floatPtr(10.00)),
		makeBottleWithPrice(nil),
		makeBottleWithPrice(floatPtr(5.00)),
		makeBottleWithPrice(nil),
	}
	got := TotalPrice(bottles)
	want := 15.00
	if got != want {
		t.Errorf("TotalPrice = %f, want %f", got, want)
	}
}

func TestTotalPrice_AllNilPrices(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithPrice(nil),
		makeBottleWithPrice(nil),
	}
	if got := TotalPrice(bottles); got != 0 {
		t.Errorf("TotalPrice = %f, want 0", got)
	}
}

// --- AggregateByRegion tests ---

func TestAggregateByRegion_EmptyList(t *testing.T) {
	result := AggregateByRegion(nil)
	if result.Total != 0 {
		t.Errorf("Total = %d, want 0", result.Total)
	}
	if len(result.Entries) != 0 {
		t.Errorf("Entries count = %d, want 0", len(result.Entries))
	}
}

func TestAggregateByRegion_SingleRegion(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithRegion("Bordeaux"),
		makeBottleWithRegion("Bordeaux"),
	}
	result := AggregateByRegion(bottles)
	if result.Total != 2 {
		t.Errorf("Total = %d, want 2", result.Total)
	}
	if len(result.Entries) != 1 {
		t.Fatalf("Entries count = %d, want 1", len(result.Entries))
	}
	if result.Entries[0].Label != "Bordeaux" {
		t.Errorf("Label = %q, want %q", result.Entries[0].Label, "Bordeaux")
	}
	if result.Entries[0].Identifier != "Bordeaux" {
		t.Errorf("Identifier = %q, want %q", result.Entries[0].Identifier, "Bordeaux")
	}
	if result.Entries[0].Count != 2 {
		t.Errorf("Count = %d, want 2", result.Entries[0].Count)
	}
}

func TestAggregateByRegion_EmptyRegionGrouped(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithRegion(""),
		makeBottleWithRegion(""),
	}
	result := AggregateByRegion(bottles)
	if len(result.Entries) != 1 {
		t.Fatalf("Entries count = %d, want 1", len(result.Entries))
	}
	if result.Entries[0].Label != "Sans région" {
		t.Errorf("Label = %q, want %q", result.Entries[0].Label, "Sans région")
	}
}

func TestAggregateByRegion_SortedDescending(t *testing.T) {
	bottles := []client.Bottle{
		makeBottleWithRegion("Alsace"),
		makeBottleWithRegion("Bordeaux"),
		makeBottleWithRegion("Bordeaux"),
		makeBottleWithRegion("Bordeaux"),
		makeBottleWithRegion("Bourgogne"),
		makeBottleWithRegion("Bourgogne"),
	}
	result := AggregateByRegion(bottles)
	if len(result.Entries) != 3 {
		t.Fatalf("Entries count = %d, want 3", len(result.Entries))
	}
	if result.Entries[0].Label != "Bordeaux" || result.Entries[0].Count != 3 {
		t.Errorf("First entry = %+v, want Bordeaux:3", result.Entries[0])
	}
	if result.Entries[1].Label != "Bourgogne" || result.Entries[1].Count != 2 {
		t.Errorf("Second entry = %+v, want Bourgogne:2", result.Entries[1])
	}
	if result.Entries[2].Label != "Alsace" || result.Entries[2].Count != 1 {
		t.Errorf("Third entry = %+v, want Alsace:1", result.Entries[2])
	}
}

func TestAggregateByRegion_AllRegionsShown(t *testing.T) {
	// Create 20 distinct regions — all should appear (no "Autres" grouping).
	var bottles []client.Bottle
	for i := 0; i < 20; i++ {
		bottles = append(bottles, makeBottleWithRegion(fmt.Sprintf("Region%02d", i)))
	}
	result := AggregateByRegion(bottles)
	if len(result.Entries) != 20 {
		t.Fatalf("Entries count = %d, want 20", len(result.Entries))
	}
	for _, e := range result.Entries {
		if e.Label == "Autres" {
			t.Error("Found 'Autres' entry — AggregateByRegion should show all regions")
		}
	}
	// Total should equal sum.
	sum := 0
	for _, e := range result.Entries {
		sum += e.Count
	}
	if result.Total != sum {
		t.Errorf("Total %d != sum of counts %d", result.Total, sum)
	}
}

func TestAggregateByRegion_PaletteWraps(t *testing.T) {
	// More regions than palette entries — colors should wrap.
	var bottles []client.Bottle
	for i := 0; i < len(regionPalette)+3; i++ {
		bottles = append(bottles, makeBottleWithRegion(fmt.Sprintf("R%02d", i)))
	}
	result := AggregateByRegion(bottles)
	if len(result.Entries) != len(regionPalette)+3 {
		t.Fatalf("Entries count = %d, want %d", len(result.Entries), len(regionPalette)+3)
	}
	// Entry beyond palette length should wrap to beginning.
	last := result.Entries[len(regionPalette)]
	if last.Color != regionPalette[0] {
		t.Errorf("Wrapped color = %q, want %q", last.Color, regionPalette[0])
	}
}
