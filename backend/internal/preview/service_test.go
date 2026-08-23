package preview

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/protocol"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/testenv"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type previewApplier struct{}

func (previewApplier) ApplyThemePreview(string, string) (int, bool, error) { return 0, false, nil }

func TestApplyPublishesProtocolOperationAndCheckpoint(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "protocol-preview-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
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
	if err := os.WriteFile(filepath.Join(candidate, "colors.toml"), []byte("background = \"#000000\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(candidate, "backgrounds", "wallpaper.png"), []byte("not-an-image"), 0o644); err != nil {
		t.Fatal(err)
	}

	service := newServiceWithThemeRoot(store, previewApplier{}, t.TempDir())
	result, err := service.Apply(Request{SessionID: record.SessionID, GenerationID: "generation-1", Variant: generation.Variant("source")})
	if err != nil {
		t.Fatal(err)
	}
	if result.ProtocolOperation == "" || result.ProtocolCheckpoint == "" || result.ProtocolSocket == "" {
		t.Fatalf("protocol metadata = %#v", result)
	}

	journal, err := protocol.Open(result.ProtocolEvents)
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err := journal.Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if len(snapshot.Operations) != 3 || snapshot.Operations[0].Status != protocol.StatusSucceeded || len(snapshot.Operations[0].Children) != 2 {
		t.Fatalf("protocol operations = %#v", snapshot.Operations)
	}
	if snapshot.CurrentCheckpointID != result.ProtocolCheckpoint {
		t.Fatalf("protocol cursor = %#v", snapshot)
	}
	if len(snapshot.Checkpoints) != 1 || snapshot.Checkpoints[0].Name != "source" {
		t.Fatalf("protocol checkpoints = %#v", snapshot.Checkpoints)
	}
	events, err := journal.Events(0)
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 9 || events[2].Type != protocol.EventOperationProgress || events[7].Type != protocol.EventCheckpointCreated {
		t.Fatalf("protocol events = %#v", events)
	}
}

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
	styles := &StyleOverrides{
		Shell:   session.ShellStyle{Surface: "contrast", Detail: "focus", Tooltip: "accent", Notifications: "accent"},
		Desktop: session.DesktopStyle{BorderStyle: "neon", BorderSize: 2, Shape: "rounded", Spacing: "airy", Depth: "shadow", Inactive: "blur"},
		Bar:     session.BarStyle{Surface: "dark", Density: "comfortable", Attention: "accent", Form: "docked", Visibility: "islands"},
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
	for _, want := range []string{"border_size = 2", "rounding = 8", "inactive_opacity = 0.58", "blur = { enabled = true"} {
		if !strings.Contains(string(hyprland), want) {
			t.Errorf("live composition hyprland.lua missing %q:\n%s", want, hyprland)
		}
	}
	for name, want := range map[string]string{
		"shell.popups.toml":  `background = "#777777"`,
		"shell.tooltip.toml": `border = "accent"`,
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
	if updated.DesktopStyle.Inactive != "blur" || updated.BarStyle.Form != "docked" || updated.ShellStyle.Detail != "focus" {
		t.Fatalf("session did not retain live composition: %#v", updated)
	}
}
