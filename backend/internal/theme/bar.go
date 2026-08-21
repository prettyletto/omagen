package theme

import (
	"fmt"
	"strings"
)

// appendBarOverrides composes bar choices into the theme's single shell.toml.
// Quattro does not load sidecar files such as shell.bar.toml.
func appendBarOverrides(b *strings.Builder, p Palette, surface, density, attention string) error {
	if !validChoice(surface, "native", "dark", "light", "accent") || !validChoice(density, "native", "compact", "comfortable") || !validChoice(attention, "semantic", "accent") {
		return fmt.Errorf("invalid bar style")
	}
	if surface == "native" && density == "native" && attention == "semantic" {
		return nil
	}

	b.WriteString("\n[bar]\n")
	switch surface {
	case "dark":
		fmt.Fprintf(b, "background = %q\ntext = %q\n", p.DarkBackground, p.Foreground)
	case "light":
		// LighterBackground can still be nearly black in a dark palette.  The
		// foreground neutral is the palette's actual light surface, and paired
		// text keeps the native bar legible.
		fmt.Fprintf(b, "background = %q\ntext = %q\n", p.Foreground, p.Background)
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
