package theme

import "fmt"

// ApplyColorOverrides applies Studio's stable semantic colour vocabulary to a
// generated palette without changing the source candidate on disk.
func ApplyColorOverrides(palette Palette, overrides map[string]string) (Palette, error) {
	for role, value := range overrides {
		if !validHex(value) {
			return Palette{}, fmt.Errorf("invalid %s color %q", role, value)
		}
		switch role {
		case "accent":
			palette.Accent = value
		case "selection":
			palette.Selection = value
		case "muted":
			palette.Muted = value
		case "background":
			palette.Background = value
		case "dark_background":
			palette.DarkBackground = value
		case "darker_background":
			palette.DarkerBackground = value
		case "lighter_background":
			palette.LighterBackground = value
		case "foreground":
			palette.Foreground = value
		case "dark_foreground":
			palette.DarkForeground = value
		case "light_foreground":
			palette.LightForeground = value
		case "bright_foreground":
			palette.BrightForeground = value
		case "red":
			palette.Red = value
		case "yellow":
			palette.Yellow = value
		case "orange":
			palette.Orange = value
		case "green":
			palette.Green = value
		case "cyan":
			palette.Cyan = value
		case "blue":
			palette.Blue = value
		case "magenta":
			palette.Magenta = value
		case "brown":
			palette.Brown = value
		case "bright_red":
			palette.BrightRed = value
		case "bright_yellow":
			palette.BrightYellow = value
		case "bright_green":
			palette.BrightGreen = value
		case "bright_cyan":
			palette.BrightCyan = value
		case "bright_blue":
			palette.BrightBlue = value
		case "bright_magenta":
			palette.BrightMagenta = value
		default:
			return Palette{}, fmt.Errorf("unsupported color override %q", role)
		}
	}

	if err := palette.Validate(); err != nil {
		return Palette{}, fmt.Errorf("validate overridden palette: %w", err)
	}
	return palette, nil
}
