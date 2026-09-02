package theme

import "testing"

func TestApplyColorOverrides(t *testing.T) {
	base := Palette{
		Mode: "dark", Accent: "#111111", Selection: "#222222", Muted: "#333333",
		Background: "#444444", DarkBackground: "#555555", DarkerBackground: "#666666", LighterBackground: "#777777",
		Foreground: "#888888", DarkForeground: "#999999", LightForeground: "#AAAAAA", BrightForeground: "#BBBBBB",
		Red: "#CC0000", Yellow: "#CCAA00", Orange: "#CC6600", Green: "#00CC00", Cyan: "#00CCCC", Blue: "#0000CC", Magenta: "#CC00CC", Brown: "#996633",
		BrightRed: "#FF0000", BrightYellow: "#FFFF00", BrightGreen: "#00FF00", BrightCyan: "#00FFFF", BrightBlue: "#0000FF", BrightMagenta: "#FF00FF",
	}

	result, err := ApplyColorOverrides(base, map[string]string{"accent": "#D06B91", "foreground": "#F2E9EC"})
	if err != nil {
		t.Fatalf("ApplyColorOverrides() error = %v", err)
	}
	if result.Accent != "#D06B91" || result.Foreground != "#F2E9EC" {
		t.Fatalf("overrides not applied: accent=%s foreground=%s", result.Accent, result.Foreground)
	}
}

func TestApplyColorOverridesRejectsUnknownOrInvalidRoles(t *testing.T) {
	base := Palette{Mode: "dark"}
	for name, overrides := range map[string]map[string]string{
		"unknown role": {"not_a_role": "#D06B91"},
		"invalid hex":  {"accent": "pink"},
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := ApplyColorOverrides(base, overrides); err == nil {
				t.Fatal("ApplyColorOverrides() unexpectedly accepted invalid overrides")
			}
		})
	}
}
