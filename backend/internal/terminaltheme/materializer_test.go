package terminaltheme

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
)

func TestMaterializeWritesAllSupportedTerminalFilesAndIsIdempotent(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	dir := t.TempDir()
	files := map[string]string{
		"ghostty.conf":   "# keep ghostty comment\nbackground = #101010\n",
		"alacritty.toml": "# keep alacritty comment\n[colors.primary]\nbackground = \"#101010\"\n[window]\n# keep window\n",
		"kitty.conf":     "# keep kitty comment\nforeground #ffffff\n",
		"foot.ini":       "# keep foot comment\n[colors-dark]\nforeground=ffffff\n[main]\nterm=xterm-256color\n",
	}
	for name, data := range files {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(data), 0o640); err != nil {
			t.Fatal(err)
		}
	}
	if err := fsutil.AtomicWriteJSON(filepath.Join(dir, IntentFile), session.TerminalTranslucency{SchemaVersion: 1, Mode: "preset", Opacity: 0.82, CellMode: "painted"}, 0o644); err != nil {
		t.Fatal(err)
	}
	first, err := Materialize(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(first.Outputs) != 4 || first.Opacity != 0.82 || first.CellMode != "painted" {
		t.Fatalf("unexpected materialization report: %#v", first)
	}
	want := map[string][]string{
		"ghostty.conf":   {"background-opacity = 0.820", "background-opacity-cells = true", "# keep ghostty comment"},
		"alacritty.toml": {"[window]", "opacity = 0.820", "[colors]", "transparent_background_colors = true", "# keep alacritty comment"},
		"kitty.conf":     {"background_opacity 0.820", "# keep kitty comment"},
		"foot.ini":       {"alpha=0.820", "alpha-mode=all", "# keep foot comment"},
	}
	for name, needles := range want {
		data, readErr := os.ReadFile(filepath.Join(dir, name))
		if readErr != nil {
			t.Fatal(readErr)
		}
		for _, needle := range needles {
			if !strings.Contains(string(data), needle) {
				t.Errorf("%s missing %q:\n%s", name, needle, data)
			}
		}
	}
	firstBytes := make(map[string][]byte)
	for name := range files {
		firstBytes[name], _ = os.ReadFile(filepath.Join(dir, name))
	}
	second, err := Materialize(dir)
	if err != nil {
		t.Fatal(err)
	}
	for name, before := range firstBytes {
		after, _ := os.ReadFile(filepath.Join(dir, name))
		if string(before) != string(after) {
			t.Errorf("%s changed on second materialization", name)
		}
	}
	for _, output := range second.Outputs {
		if output.Changed {
			t.Errorf("second materialization reported change for %s: %#v", output.Terminal, output)
		}
	}
}

func TestMaterializePreserveDoesNotTouchFiles(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	dir := t.TempDir()
	original := map[string]string{
		"ghostty.conf":   "background-opacity = 0.91\n",
		"alacritty.toml": "[window]\nopacity = 0.91\n",
		"kitty.conf":     "background_opacity 0.91\n",
		"foot.ini":       "[colors-dark]\nalpha=0.91\n",
	}
	for name, data := range original {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(data), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := fsutil.AtomicWriteJSON(filepath.Join(dir, IntentFile), session.DefaultTerminalTranslucency(), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Materialize(dir); err != nil {
		t.Fatal(err)
	}
	for name, want := range original {
		got, _ := os.ReadFile(filepath.Join(dir, name))
		if string(got) != want {
			t.Errorf("Preserve changed %s: got %q want %q", name, got, want)
		}
	}
}

func TestMaterializeRejectsMissingOrInvalidTargetsBeforePartialMutation(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"ghostty.conf", "alacritty.toml", "kitty.conf"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("# untouched\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := fsutil.AtomicWriteJSON(filepath.Join(dir, IntentFile), session.TerminalTranslucency{SchemaVersion: 1, Mode: "preset", Opacity: 0.82, CellMode: "background"}, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Materialize(dir); err == nil || !strings.Contains(err.Error(), "foot") {
		t.Fatalf("missing Foot target error = %v", err)
	}
	for _, name := range []string{"ghostty.conf", "alacritty.toml", "kitty.conf"} {
		data, _ := os.ReadFile(filepath.Join(dir, name))
		if string(data) != "# untouched\n" {
			t.Errorf("partial mutation of %s: %q", name, data)
		}
	}
}

func TestMaterializeReportsCapabilitiesAndTrimmedUserOverride(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"ghostty.conf", "alacritty.toml", "kitty.conf", "foot.ini"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("# candidate\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := fsutil.AtomicWriteJSON(filepath.Join(dir, IntentFile), session.TerminalTranslucency{SchemaVersion: 1, Mode: "preset", Opacity: 0.82, CellMode: "painted"}, 0o644); err != nil {
		t.Fatal(err)
	}
	configHome := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", configHome)
	if err := os.MkdirAll(filepath.Join(configHome, "ghostty"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(configHome, "ghostty", "config"), []byte("background-opacity = 0.90\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	report, err := Materialize(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(report.Capabilities) != 4 {
		t.Fatalf("capability count=%d, report=%#v", len(report.Capabilities), report)
	}
	var ghosttyCapability, kittyCapability *Capability
	for index := range report.Capabilities {
		capability := &report.Capabilities[index]
		switch capability.Terminal {
		case Ghostty:
			ghosttyCapability = capability
		case Kitty:
			kittyCapability = capability
		}
	}
	if ghosttyCapability == nil || ghosttyCapability.UserOverride == nil || ghosttyCapability.UserOverride.Value != "0.90" {
		t.Fatalf("Ghostty override report=%#v", ghosttyCapability)
	}
	if kittyCapability == nil || kittyCapability.CellModeSupported {
		t.Fatalf("Kitty capability=%#v", kittyCapability)
	}
	ghosttyTheme, readErr := os.ReadFile(filepath.Join(dir, "ghostty.conf"))
	if readErr != nil {
		t.Fatal(readErr)
	}
	if strings.Contains(string(ghosttyTheme), "background-opacity =") {
		t.Fatalf("user Ghostty opacity override was shadowed by generated theme: %s", ghosttyTheme)
	}
	if !strings.Contains(string(ghosttyTheme), "background-opacity-cells = true") {
		t.Fatalf("Ghostty cell-mode intent was removed with opacity override: %s", ghosttyTheme)
	}
	for _, output := range report.Outputs {
		if output.Terminal == Ghostty && !strings.Contains(output.Message, "user opacity override retained") {
			t.Fatalf("Ghostty output did not report precedence: %#v", output)
		}
	}
}
