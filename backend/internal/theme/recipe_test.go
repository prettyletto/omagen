package theme

import (
	"os"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/session"
)

func TestRecipeRoundTrip(t *testing.T) {
	dir := t.TempDir()
	palette := Palette{Mode: "dark", Accent: "#FF0000", Selection: "#FF0000", Muted: "#777777", Background: "#111111", DarkBackground: "#0A0A0A", DarkerBackground: "#050505", LighterBackground: "#222222", Foreground: "#FFFFFF", DarkForeground: "#AAAAAA", LightForeground: "#DDDDDD", BrightForeground: "#FFFFFF", Red: "#FF0000", Yellow: "#FFFF00", Orange: "#FF8800", Green: "#00FF00", Cyan: "#00FFFF", Blue: "#0000FF", Magenta: "#FF00FF", Brown: "#996633", BrightRed: "#FF4444", BrightYellow: "#FFFF44", BrightGreen: "#44FF44", BrightCyan: "#44FFFF", BrightBlue: "#4444FF", BrightMagenta: "#FF44FF"}
	recipe := Recipe{ThemeName: "Example", SourceTheme: "source", SourceKind: "stock", ManagedScopes: []string{"shell-bar"}, Palette: palette, Shell: session.DefaultShellStyle(), Desktop: session.DefaultDesktopStyle(), Bar: session.DefaultBarStyle(), Animations: session.DefaultAnimationsStyle(), LookFeel: session.DefaultLookFeelDocument(), Terminal: session.DefaultTerminalTranslucency()}
	if err := WriteRecipe(dir, recipe); err != nil {
		t.Fatal(err)
	}
	got, err := ReadRecipe(dir)
	if err != nil {
		t.Fatal(err)
	}
	if got.ThemeName != recipe.ThemeName || len(got.ManagedScopes) != 1 || got.ManagedScopes[0] != "shell-bar" {
		t.Fatalf("recipe = %#v", got)
	}
	if _, err := os.Stat(dir + "/" + RecipeFile); err != nil {
		t.Fatal(err)
	}
}

func TestRecipeRejectsUnknownOrRepeatedManagedScopes(t *testing.T) {
	base := Recipe{
		SchemaVersion: RecipeSchemaVersion, Kind: RecipeKind, ThemeName: "Example",
		Palette: Palette{Mode: "dark", Accent: "#FF0000", Selection: "#FF0000", Muted: "#777777", Background: "#111111", DarkBackground: "#0A0A0A", DarkerBackground: "#050505", LighterBackground: "#222222", Foreground: "#FFFFFF", DarkForeground: "#AAAAAA", LightForeground: "#DDDDDD", BrightForeground: "#FFFFFF", Red: "#FF0000", Yellow: "#FFFF00", Orange: "#FF8800", Green: "#00FF00", Cyan: "#00FFFF", Blue: "#0000FF", Magenta: "#FF00FF", Brown: "#996633", BrightRed: "#FF4444", BrightYellow: "#FFFF44", BrightGreen: "#44FF44", BrightCyan: "#44FFFF", BrightBlue: "#4444FF", BrightMagenta: "#FF44FF"},
		Shell:   session.DefaultShellStyle(), Desktop: session.DefaultDesktopStyle(), Bar: session.DefaultBarStyle(), Animations: session.DefaultAnimationsStyle(), LookFeel: session.DefaultLookFeelDocument(), Terminal: session.DefaultTerminalTranslucency(),
	}
	for _, scopes := range [][]string{{"unknown"}, {"terminal", "terminal"}} {
		recipe := base
		recipe.ManagedScopes = scopes
		if err := recipe.Validate(); err == nil {
			t.Fatalf("accepted invalid managed scopes %v", scopes)
		}
	}
}
