package theme

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/bar"
)

func readShellSection(t *testing.T, dir, section string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(dir, "shell."+section+".toml"))
	if err != nil {
		t.Fatalf("read shell.%s.toml: %v", section, err)
	}
	text := string(data)
	if strings.Contains(text, "["+section+"]") {
		t.Fatalf("shell.%s.toml should be a headerless sidecar:\n%s", section, text)
	}
	return text
}

func assertRootShell(t *testing.T, dir string, wants ...string) {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(dir, "shell.toml"))
	if err != nil {
		t.Fatalf("read generated root shell.toml: %v", err)
	}
	text := string(data)
	for _, want := range wants {
		if !strings.Contains(text, want) {
			t.Fatalf("root shell.toml missing %q:\n%s", want, text)
		}
	}
}

func assertNoGeneratedOutputs(t *testing.T, dir string) {
	t.Helper()
	for _, name := range append(generatedShellFiles, generatedOmagenFiles...) {
		if _, err := os.Stat(filepath.Join(dir, name)); !os.IsNotExist(err) {
			t.Fatalf("unexpected generated shell output %s: %v", name, err)
		}
	}
}

func TestWriteShellEmitsSurfaceAndDetailOverrides(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "layered", "edge", "native", "native", "light", "comfortable", "accent", "continuous", "native"); err != nil {
		t.Fatal(err)
	}
	assertRootShell(t, dir, "[bar]\n", "[popups]\n", "[menu]\n", "[controls]\n")

	for section, wants := range map[string][]string{
		"bar":      {`background = "#e5e7eb"`, `text = "#101112"`, "size-horizontal = 30", "size-vertical = 32", `active = "#aa33cc"`},
		"popups":   {`background = "#08090a"`},
		"menu":     {`selected-background = "#334455"`, `selected-border-width = "0 0 0 3"`},
		"launcher": {`selected-background = "#334455"`},
		"controls": {`normal-color = "#222426"`, `selected-color = "#334455"`},
	} {
		text := readShellSection(t, dir, section)
		for _, want := range wants {
			if !strings.Contains(text, want) {
				t.Errorf("shell.%s.toml missing %q:\n%s", section, want, text)
			}
		}
	}
	if _, err := os.Stat(filepath.Join(dir, "shell.notifications.toml")); !os.IsNotExist(err) {
		t.Fatalf("unexpected notifications sidecar for layered edge style: %v", err)
	}

	if err := WriteShell(dir, p, "flat", "native", "native", "native", "native", "native", "semantic", "continuous", "native"); err != nil {
		t.Fatal(err)
	}
	assertNoGeneratedOutputs(t, dir)
}

func TestWriteShellUsesActualAccentForBarSurface(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "flat", "native", "native", "native", "accent", "compact", "semantic", "continuous", "native"); err != nil {
		t.Fatal(err)
	}
	text := readShellSection(t, dir, "bar")
	for _, want := range []string{`background = "#aa33cc"`, `text = "#101112"`, "size-horizontal = 22", "size-vertical = 24"} {
		if !strings.Contains(text, want) {
			t.Errorf("shell.bar.toml missing %q:\n%s", want, text)
		}
	}
}

func TestWriteShellWithSpecDeduplicatesLayeredBarKeys(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	spec := bar.Default()
	spec.Surface.Role = "dark"
	spec.Geometry.Density = "compact"
	if err := WriteShellWithOverridesAndSpec(dir, p, "flat", "native", "native", "native", "dark", "compact", "semantic", "continuous", "native", nil, &spec); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "shell.toml"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	start := strings.Index(text, "[bar]\n")
	end := strings.Index(text[start+len("[bar]\n"):], "\n[")
	if start < 0 {
		t.Fatalf("root shell.toml has no isolated bar section:\n%s", text)
	}
	if end < 0 {
		text = text[start:]
	} else {
		text = text[start : start+len("[bar]\n")+end]
	}
	for _, key := range []string{"background", "size-horizontal", "size-vertical"} {
		if count := strings.Count(text, key+" ="); count != 1 {
			t.Fatalf("root shell.toml contains %d %s assignments:\n%s", count, key, text)
		}
	}
}

func TestWriteShellKeepsLightBarLegibleForLightPalette(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Mode: "light", Background: "#f7f4ec", Foreground: "#24211d", DarkBackground: "#e4dfd5", DarkerBackground: "#d4cec3", LighterBackground: "#fffdf8", Selection: "#d8cfbf", Accent: "#8e5f32"}
	if err := WriteShell(dir, p, "flat", "native", "native", "native", "light", "native", "semantic", "continuous", "native"); err != nil {
		t.Fatal(err)
	}
	text := readShellSection(t, dir, "bar")
	for _, want := range []string{`background = "#f7f4ec"`, `text = "#24211d"`} {
		if !strings.Contains(text, want) {
			t.Errorf("shell.bar.toml missing %q:\n%s", want, text)
		}
	}
}

func TestWriteShellKeepsAccentSurfaceRestrained(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "accent", "focus", "native", "native", "native", "native", "semantic", "continuous", "native"); err != nil {
		t.Fatal(err)
	}
	for section, wants := range map[string][]string{
		"menu":     {`selected-background = "#aa33cc"`, "selected-background-alpha = 0.18"},
		"launcher": {`selected-background = "#aa33cc"`, "selected-background-alpha = 0.18"},
		"controls": {`selected-border = "#aa33cc"`, "selected-fill-alpha = 0.18"},
	} {
		text := readShellSection(t, dir, section)
		for _, want := range wants {
			if !strings.Contains(text, want) {
				t.Errorf("shell.%s.toml missing %q:\n%s", section, want, text)
			}
		}
	}
}

func TestWriteShellEmitsDockedBarFormWithoutChangingOtherBarOptions(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "flat", "native", "native", "native", "dark", "comfortable", "semantic", "docked", "native"); err != nil {
		t.Fatal(err)
	}
	text := readShellSection(t, dir, "bar")
	for _, want := range []string{"background-alpha = 0.0", `background = "#08090a"`, `text = "#e5e7eb"`, "size-horizontal = 30", "size-vertical = 32"} {
		if !strings.Contains(text, want) {
			t.Errorf("shell.bar.toml missing %q:\n%s", want, text)
		}
	}
	if strings.Contains(text, "form =") {
		t.Fatalf("shell.bar.toml should not contain Omagen-owned form metadata:\n%s", text)
	}
	metadata, err := os.ReadFile(filepath.Join(dir, "omagen.bar.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(metadata), `form = "docked"`) {
		t.Fatalf("omagen.bar.toml missing docked form:\n%s", metadata)
	}
	profile, err := os.ReadFile(filepath.Join(dir, "omagen.bar.json"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`"schema_version": 1`, `"ownership": "overlay"`, `"implementation": "adapter"`, `"form": "dock"`} {
		if !strings.Contains(string(profile), want) {
			t.Fatalf("omagen.bar.json missing %q:\n%s", want, profile)
		}
	}
}

func TestWriteShellEmitsFeedbackAndOptInDockedIslands(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "flat", "native", "accent", "accent", "dark", "comfortable", "accent", "docked", "islands"); err != nil {
		t.Fatal(err)
	}
	tooltip := readShellSection(t, dir, "tooltip")
	if !strings.Contains(tooltip, `border = "accent"`) || !strings.Contains(tooltip, "border-alpha = 1.0") {
		t.Fatalf("shell.tooltip.toml missing accent feedback border:\n%s", tooltip)
	}
	notifications := readShellSection(t, dir, "notifications")
	for _, want := range []string{`border = "accent"`, "border-alpha = 1.0", `countdown = "accent"`} {
		if !strings.Contains(notifications, want) {
			t.Errorf("shell.notifications.toml missing %q:\n%s", want, notifications)
		}
	}
	metadata, err := os.ReadFile(filepath.Join(dir, "omagen.bar.toml"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`form = "docked"`, `visibility = "islands"`} {
		if !strings.Contains(string(metadata), want) {
			t.Errorf("omagen.bar.toml missing %q:\n%s", want, metadata)
		}
	}
	profile, err := os.ReadFile(filepath.Join(dir, "omagen.bar.json"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(profile), `"islands": true`) {
		t.Fatalf("omagen.bar.json missing islands behavior:\n%s", profile)
	}
}

func TestWriteShellWithOverridesEmitsOnlyAdditiveReaderValues(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	overrides := map[string]string{
		"font.base-size":                     "15",
		"spacing.scale":                      "1.15",
		"controls.focus-border-width":        "2",
		"notifications.countdown":            "#ffcc00",
		"image-picker.selected-border-alpha": "0.8",
	}
	if err := WriteShellWithOverrides(dir, p, "flat", "native", "native", "native", "native", "native", "semantic", "continuous", "native", overrides); err != nil {
		t.Fatal(err)
	}
	for section, wants := range map[string][]string{
		"font":          {`base-size = "15"`},
		"spacing":       {`scale = "1.15"`},
		"controls":      {`focus-border-width = "2"`},
		"notifications": {`countdown = "#ffcc00"`},
		"image-picker":  {`selected-border-alpha = "0.8"`},
	} {
		text := readShellSection(t, dir, section)
		for _, want := range wants {
			if !strings.Contains(text, want) {
				t.Errorf("shell.%s.toml missing %q:\n%s", section, want, text)
			}
		}
	}
	if err := WriteShellWithOverrides(dir, p, "flat", "native", "native", "native", "native", "native", "semantic", "continuous", "native", map[string]string{"unknown.key": "value"}); err == nil {
		t.Fatal("expected unknown shell section to be rejected")
	}
}

func TestWriteShellWithSpecEmitsNativeSurfacePrimitives(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	spec := bar.Default()
	spec.Topology = bar.TopologyContinuous
	spec.Surface.Role = "accent"
	spec.Surface.Opacity = 0.82
	spec.Geometry.Thickness = 32
	if err := WriteShellWithOverridesAndSpec(dir, p, "flat", "native", "native", "native", "native", "native", "semantic", "continuous", "native", nil, &spec); err != nil {
		t.Fatal(err)
	}
	text := readShellSection(t, dir, "bar")
	for _, want := range []string{`background = "#aa33cc"`, `text = "#101112"`, `background-alpha = 0.820`, `size-horizontal = 32`, `size-vertical = 32`} {
		if !strings.Contains(text, want) {
			t.Errorf("native bar spec missing %q:\n%s", want, text)
		}
	}
}
