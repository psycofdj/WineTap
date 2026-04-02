package screen

import "testing"

func TestFormatPrice(t *testing.T) {
	tests := []struct {
		input float64
		want  string
	}{
		{0, "0,00 €"},
		{1.5, "1,50 €"},
		{42.99, "42,99 €"},
		{999.00, "999,00 €"},
		{1234.56, "1 234,56 €"},
		{12345.00, "12 345,00 €"},
		{1234567.89, "1 234 567,89 €"},
	}
	for _, tt := range tests {
		got := formatPrice(tt.input)
		if got != tt.want {
			t.Errorf("formatPrice(%v) = %q, want %q", tt.input, got, tt.want)
		}
	}
}
