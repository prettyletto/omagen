package apply

import "testing"

func TestParseThemeName(t *testing.T) {
	for _, test := range []struct{ input, display, slug string }{
		{"Quattro", "Quattro", "quattro"},
		{" Audi Sunset ", "Audi Sunset", "audi-sunset"},
		{"Audi_Sunset 2", "Audi_Sunset 2", "audi-sunset-2"},
	} {
		got, err := parseThemeName(test.input)
		if err != nil {
			t.Fatalf("parseThemeName(%q): %v", test.input, err)
		}
		if got.Display != test.display || got.Slug != test.slug {
			t.Errorf("parseThemeName(%q) = %#v", test.input, got)
		}
	}
}

func TestParseThemeNameRejectsUnusableNames(t *testing.T) {
	for _, input := range []string{"", "   ", "!!!"} {
		if _, err := parseThemeName(input); err == nil {
			t.Errorf("parseThemeName(%q) unexpectedly succeeded", input)
		}
	}
}
