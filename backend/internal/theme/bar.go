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
		// The native bar keeps its widgets and input surface; Docked only makes
		// its outer background transparent so the additive section-surface
		// renderer can sit underneath those widgets.
		b.WriteString("form = \"docked\"\nbackground-alpha = 0.0\n")
	}
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
