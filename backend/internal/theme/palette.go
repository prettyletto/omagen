package theme

import (
	"encoding/hex"
	"fmt"
)

type Palette struct {
	Mode string

	Accent    string
	Accent2   string
	Accent3   string
	Accent4   string
	Accent5   string
	Selection string
	Muted     string

	Background        string
	DarkBackground    string
	DarkerBackground  string
	LighterBackground string

	Foreground       string
	DarkForeground   string
	LightForeground  string
	BrightForeground string

	Red     string
	Yellow  string
	Orange  string
	Green   string
	Cyan    string
	Blue    string
	Magenta string
	Brown   string

	BrightRed     string
	BrightYellow  string
	BrightGreen   string
	BrightCyan    string
	BrightBlue    string
	BrightMagenta string
}

func (p Palette) Validate() error {
	if p.Mode != "dark" && p.Mode != "light" {
		return fmt.Errorf("invalid mode %q", p.Mode)
	}

	for _, extra := range []string{p.Accent2, p.Accent3, p.Accent4, p.Accent5} {
		if extra != "" && !validHex(extra) {
			return fmt.Errorf("invalid accent color %q", extra)
		}
	}

	colors := []struct {
		name  string
		value string
	}{
		{"accent", p.Accent},
		{"selection", p.Selection},
		{"muted", p.Muted},

		{"background", p.Background},
		{"dark_background", p.DarkBackground},
		{"darker_background", p.DarkerBackground},
		{"lighter_background", p.LighterBackground},

		{"foreground", p.Foreground},
		{"dark_foreground", p.DarkForeground},
		{"light_foreground", p.LightForeground},
		{"bright_foreground", p.BrightForeground},

		{"red", p.Red},
		{"yellow", p.Yellow},
		{"orange", p.Orange},
		{"green", p.Green},
		{"cyan", p.Cyan},
		{"blue", p.Blue},
		{"magenta", p.Magenta},
		{"brown", p.Brown},

		{"bright_red", p.BrightRed},
		{"bright_yellow", p.BrightYellow},
		{"bright_green", p.BrightGreen},
		{"bright_cyan", p.BrightCyan},
		{"bright_blue", p.BrightBlue},
		{"bright_magenta", p.BrightMagenta},
	}

	for _, color := range colors {
		if !validHex(color.value) {
			return fmt.Errorf(
				"invalid %s color %q",
				color.name,
				color.value,
			)
		}
	}

	return nil
}

// ActiveAccents returns Accent followed by Accent2-5, stopping at the first unset one.
func (p Palette) ActiveAccents() []string {
	accents := []string{p.Accent}
	for _, extra := range []string{p.Accent2, p.Accent3, p.Accent4, p.Accent5} {
		if !validHex(extra) {
			break
		}
		accents = append(accents, extra)
	}
	return accents
}

func validHex(value string) bool {
	if len(value) != 7 || value[0] != '#' {
		return false
	}

	_, err := hex.DecodeString(value[1:])
	return err == nil
}
