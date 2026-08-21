package theme

import (
	"fmt"
	"strings"
)

// appendBarOverrides appends bar choices to a shell.bar.toml sidecar.
func appendBarOverrides(b *strings.Builder, p Palette, surface, density, attention, form string) error {
	if !validChoice(surface, "native", "dark", "light", "accent") || !validChoice(density, "native", "compact", "comfortable") || !validChoice(attention, "semantic", "accent") {
		return fmt.Errorf("invalid bar style")
	}
	if !validChoice(form, "continuous", "docked") {
		return fmt.Errorf("invalid bar form %q", form)
	}
	if surface == "native" && density == "native" && attention == "semantic" && form == "continuous" {
		return nil
	}

	if form == "docked" {
		// The native bar keeps its widgets and input surface; Omagen's additive
		// section-surface renderer sits underneath those widgets.
		b.WriteString("background-alpha = 0.0\n")
	}
	switch surface {
	case "dark":
		fmt.Fprintf(b, "background = %q\ntext = %q\n", p.DarkBackground, p.Foreground)
	case "light":
		// In a dark palette, foreground is the lightest available neutral. In
		// a light palette foreground is intentionally dark, so use the actual
		// light background instead. Pairing these values keeps text glyphs and
		// icons legible in both palette modes.
		background, text := p.Foreground, p.Background
		if p.Mode == "light" {
			background, text = p.Background, p.Foreground
		}
		fmt.Fprintf(b, "background = %q\ntext = %q\n", background, text)
	case "accent":
		fmt.Fprintf(b, "background = %q\ntext = %q\n", p.Accent, p.Background)
	}
	if density == "compact" {
		b.WriteString("size-horizontal = 22\nsize-vertical = 24\n")
	} else if density == "comfortable" {
		b.WriteString("size-horizontal = 30\nsize-vertical = 32\n")
	}
	if attention == "accent" {
		fmt.Fprintf(b, "active = %q\n", p.Accent)
	}
	return nil
}
