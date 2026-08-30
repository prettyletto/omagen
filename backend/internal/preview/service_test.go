package preview

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/testenv"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type previewApplier struct{}

func (previewApplier) ApplyThemePreview(string, string) (int, bool, error) { return 0, false, nil }

func TestApplyRejectsPendingTransactionBeforePublishingPreview(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "preview-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ApplyPhase:         session.ApplyPhasePrepared,
		AppliedTheme:       "theme-name",
		AppliedGeneration:  "generation-1",
		AppliedVariant:     "source",
		AppliedDisplayName: "Theme Name",
		CreatedAt:          time.Now().UTC(),
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	service := newServiceWithThemeRoot(store, previewApplier{}, t.TempDir())
	_, err = service.Apply(Request{SessionID: record.SessionID, GenerationID: "generation-1", Variant: generation.Variant("source")})
	if !errors.Is(err, session.ErrApplyInProgress) {
		t.Fatalf("error=%v, want ErrApplyInProgress", err)
	}
}

func TestApplyMaterializesColorOverrideWithoutMutatingPreset(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "color-preview-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ExtraConfigs:       true,
		ShellStyle:         session.ShellStyle{Surface: "layered", Detail: "edge", Tooltip: "native", Notifications: "native"},
		BarStyle:           session.BarStyle{Surface: "dark", Density: "comfortable", Attention: "accent", Form: "continuous", Visibility: "native"},
		CreatedAt:          time.Now().UTC(),
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	candidate := filepath.Join(store.SessionDir(record.SessionID), "generations", "generation-1", "source")
	if err := os.MkdirAll(filepath.Join(candidate, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	palette := theme.Palette{
		Mode: "dark", Accent: "#111111", Selection: "#222222", Muted: "#333333",
		Background: "#444444", DarkBackground: "#555555", DarkerBackground: "#666666", LighterBackground: "#777777",
		Foreground: "#888888", DarkForeground: "#999999", LightForeground: "#AAAAAA", BrightForeground: "#BBBBBB",
		Red: "#CC0000", Yellow: "#CCAA00", Orange: "#CC6600", Green: "#00CC00", Cyan: "#00CCCC", Blue: "#0000CC", Magenta: "#CC00CC", Brown: "#996633",
		BrightRed: "#FF0000", BrightYellow: "#FFFF00", BrightGreen: "#00FF00", BrightCyan: "#00FFFF", BrightBlue: "#0000FF", BrightMagenta: "#FF00FF",
	}
	if err := theme.WriteColors(candidate, palette); err != nil {
		t.Fatal(err)
	}
	if err := theme.WriteShell(candidate, palette, "layered", "edge", "native", "native", "dark", "comfortable", "accent", "continuous", "native"); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(candidate, "backgrounds", "wallpaper.png"), []byte("not-an-image"), 0o644); err != nil {
		t.Fatal(err)
	}
	themeRoot := t.TempDir()
	service := newServiceWithThemeRoot(store, previewApplier{}, themeRoot)
	result, err := service.Apply(Request{
		SessionID: record.SessionID, GenerationID: "generation-1", Variant: generation.Source,
		ColorOverrides: map[string]string{
			"accent":             "#D06B91",
			"dark_background":    "#121212",
			"lighter_background": "#222222",
			"selection":          "#333333",
			"foreground":         "#F0F0F0",
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.ThemeName == "" || result.ThemeName == "omagen-preview-color-preview-session-generation-1-source" {
		t.Fatalf("theme name did not identify color override: %q", result.ThemeName)
	}
	original, err := theme.ReadColors(candidate)
	if err != nil {
		t.Fatal(err)
	}
	if original.Accent != "#111111" {
		t.Fatalf("source preset was mutated: %s", original.Accent)
	}
	target, err := os.Readlink(filepath.Join(themeRoot, result.ThemeName))
	if err != nil {
		t.Fatal(err)
	}
	overridden, err := theme.ReadColors(target)
	if err != nil {
		t.Fatal(err)
	}
	if overridden.Accent != "#D06B91" {
		t.Fatalf("override was not materialized: %s", overridden.Accent)
	}
	for name, wants := range map[string][]string{
		"shell.popups.toml":   {`background = "#121212"`},
		"shell.menu.toml":     {`selected-background = "#333333"`},
		"shell.controls.toml": {`normal-color = "#222222"`},
		"shell.bar.toml":      {`background = "#121212"`, `text = "#F0F0F0"`, `active = "#D06B91"`},
	} {
		data, err := os.ReadFile(filepath.Join(target, name))
		if err != nil {
			t.Fatalf("read overridden %s: %v", name, err)
		}
		for _, want := range wants {
			if !strings.Contains(string(data), want) {
				t.Errorf("overridden %s missing %q:\n%s", name, want, data)
			}
		}
	}
}

func TestHyprlandOverridePreservesNativeRulesWithoutDuplication(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "hyprland.lua"), []byte("-- native custom rule\nhl.window_rule({ match = { class = \"example\" } })\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	styles := StyleOverrides{ManagedScopes: []string{"window-motion"}, Desktop: session.DefaultDesktopStyle(), Animations: session.DefaultAnimationsStyle(), Shell: session.DefaultShellStyle()}
	p := theme.Palette{Accent: "#aa33cc", Foreground: "#eeeeee", DarkForeground: "#888888", Background: "#101010", Blue: "#3366ff", Magenta: "#ff33aa"}
	spec := bar.Default()
	if err := writeHyprlandOverridePreservingNative(dir, p, styles, spec); err != nil {
		t.Fatal(err)
	}
	// A new materialization starts from the immutable source snapshot again.
	if err := os.WriteFile(filepath.Join(dir, "hyprland.lua"), []byte("-- native custom rule\nhl.window_rule({ match = { class = \"example\" } })\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := writeHyprlandOverridePreservingNative(dir, p, styles, spec); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "native custom rule") || strings.Count(string(data), "-- Generated by Omagen.") != 1 {
		t.Fatalf("native rule or generated block was duplicated/lost:\n%s", data)
	}
}

func TestApplyMaterializesLiveCompositionWithoutMutatingPreset(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "composition-preview-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ExtraConfigs:       true,
		CreatedAt:          time.Now().UTC(),
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	candidate := filepath.Join(store.SessionDir(record.SessionID), "generations", "generation-1", "source")
	if err := os.MkdirAll(filepath.Join(candidate, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	p := theme.Palette{
		Mode: "dark", Accent: "#111111", Selection: "#222222", Muted: "#333333",
		Background: "#444444", DarkBackground: "#555555", DarkerBackground: "#666666", LighterBackground: "#777777",
		Foreground: "#888888", DarkForeground: "#999999", LightForeground: "#AAAAAA", BrightForeground: "#BBBBBB",
		Red: "#CC0000", Yellow: "#CCAA00", Orange: "#CC6600", Green: "#00CC00", Cyan: "#00CCCC", Blue: "#0000CC", Magenta: "#CC00CC", Brown: "#996633",
		BrightRed: "#FF0000", BrightYellow: "#FFFF00", BrightGreen: "#00FF00", BrightCyan: "#00FFFF", BrightBlue: "#0000FF", BrightMagenta: "#FF00FF",
	}
	if err := theme.WriteColors(candidate, p); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(candidate, "backgrounds", "wallpaper.png"), []byte("not-an-image"), 0o644); err != nil {
		t.Fatal(err)
	}
	themeRoot := t.TempDir()
	service := newServiceWithThemeRoot(store, previewApplier{}, themeRoot)
	dockSpec, err := bar.Preset("dock")
	if err != nil {
		t.Fatal(err)
	}
	styles := &StyleOverrides{
		Shell: session.ShellStyle{
			Surface: "contrast", Detail: "focus", Tooltip: "accent", Notifications: "accent",
			Overrides: map[string]string{
				"bar.background": "#123456", "bar.text": "#FEDCBA", "bar.active": "#FF3366",
			},
		},
		Desktop: session.DesktopStyle{BorderStyle: "neon", BorderSize: 2, Shape: "rounded", Spacing: "airy", Depth: "shadow", Inactive: "frosted_balanced"},
		Animations: session.AnimationsStyle{
			Version: 1, Preset: "custom", Window: "spring", WindowOpen: "popin", WindowClose: "fade",
			WindowMove: "spring", WindowAmount: 74, WindowSpeed: 5, Workspace: "slidefade", WorkspaceAxis: "vertical",
			WorkspaceTravel: 24, Special: "fade", Focus: "smooth", Layers: "slide", Curve: "spring", Border: "spin", BorderSpeed: 42,
		},
		Bar: session.BarStyle{
			Surface: "dark", Density: "comfortable", Attention: "accent", Form: "docked", Visibility: "islands", Spec: &dockSpec,
		},
		LookFeel: &session.LookFeelDocument{SchemaVersion: 1, Preset: "glass-blur", PresetRevision: 1, Customized: map[string]bool{"window": true, "shell": false, "bar": true, "animations": false, "terminal": false}},
		Terminal: &session.TerminalTranslucency{SchemaVersion: 1, Mode: "preset", Opacity: 0.82, CellMode: "background"},
	}
	result, err := service.Apply(Request{SessionID: record.SessionID, GenerationID: "generation-1", Variant: generation.Source, Styles: styles})
	if err != nil {
		t.Fatal(err)
	}
	target, err := os.Readlink(filepath.Join(themeRoot, result.ThemeName))
	if err != nil {
		t.Fatal(err)
	}
	hyprland, err := os.ReadFile(filepath.Join(target, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"border_size = 2", "rounding = 8", "dim_inactive = true, dim_strength = 0.26", "blur = { enabled = true",
		`hl.curve("omagenSpring", { type = "spring", mass = 1, stiffness = 85, dampening = 17 })`,
		`style = "popin 74%"`, `style = "slidefadevert 24%"`,
		`hl.animation({ leaf = "specialWorkspace", enabled = true`,
		`hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 2.4, bezier = "easeOutQuint" })`,
		`hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })`,
	} {
		if !strings.Contains(string(hyprland), want) {
			t.Errorf("live composition hyprland.lua missing %q:\n%s", want, hyprland)
		}
	}
	for name, want := range map[string]string{
		"shell.popups.toml":  `background = "#777777"`,
		"shell.tooltip.toml": `border = "accent"`,
		"shell.bar.toml":     "active = \"#FF3366\"\nbackground = \"#123456\"\ntext = \"#FEDCBA\"",
		"omagen.bar.toml":    `form = "docked"`,
	} {
		data, err := os.ReadFile(filepath.Join(target, name))
		if err != nil {
			t.Fatalf("read live composition %s: %v", name, err)
		}
		if !strings.Contains(string(data), want) {
			t.Errorf("live composition %s missing %q:\n%s", name, want, data)
		}
	}
	updated, err := store.Load(record.SessionID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.DesktopStyle.Inactive != "frosted_balanced" || updated.ShellStyle.Detail != "focus" || updated.BarStyle.Form != "docked" || updated.AnimationsStyle.WorkspaceAxis != "vertical" || updated.AnimationsStyle.WindowAmount != 74 {
		t.Fatalf("session did not retain live composition: %#v", updated)
	}
	if updated.BarStyle.Spec == nil || updated.BarStyle.Spec.Topology != bar.TopologyDock || updated.BarStyle.Spec.Geometry.LengthMode != "content" {
		t.Fatalf("session dropped live BarSpec: %#v", updated.BarStyle.Spec)
	}
	if updated.LookFeel.Preset != "glass-blur" || updated.TerminalTranslucency.Opacity != 0.82 {
		t.Fatalf("session dropped Look & Feel metadata: %#v %#v", updated.LookFeel, updated.TerminalTranslucency)
	}
	for name := range map[string]bool{"omagen.look-feel.json": true, "omagen.terminal.json": true} {
		if _, err := os.Stat(filepath.Join(target, name)); err != nil {
			t.Fatalf("live composition metadata %s missing: %v", name, err)
		}
	}
}
