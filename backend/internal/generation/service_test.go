package generation

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/settings"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

func generationStore(t *testing.T) *session.Store {
	t.Helper()
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	return store
}

func generationSettingsStore(t *testing.T) *settings.Store {
	t.Helper()
	store, err := settings.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	return store
}

func saveGenerationRecord(t *testing.T, store *session.Store, record session.Record) {
	t.Helper()
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: time.Now().UTC()}); err != nil {
		t.Fatal(err)
	}
}

type discardBaselineOmarchy struct {
	theme              string
	background         session.BackgroundRef
	restoredTheme      string
	restoredBackground session.BackgroundRef
}

func (f *discardBaselineOmarchy) CurrentTheme() (string, error) { return f.theme, nil }
func (f *discardBaselineOmarchy) CurrentBackground() (session.BackgroundRef, error) {
	return f.background, nil
}
func (f *discardBaselineOmarchy) RestoreThemeFast(theme, _ string) error {
	f.restoredTheme = theme
	f.theme = theme
	return nil
}
func (f *discardBaselineOmarchy) RestoreBackground(background session.BackgroundRef) error {
	f.restoredBackground = background
	f.background = background
	return nil
}

func TestGenerate(t *testing.T) {
	store := generationStore(t)
	record := session.Record{SessionID: "session", OriginalTheme: "theme", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}}
	saveGenerationRecord(t, store, record)
	imagePath := filepath.Join(t.TempDir(), "source.xyz")
	imageData := testPNG(t)
	if err := os.WriteFile(imagePath, imageData, 0o644); err != nil {
		t.Fatal(err)
	}
	result, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{SessionID: "session", SourceImage: imagePath})
	if err != nil {
		t.Fatal(err)
	}
	if result.GenerationID == "" || len(result.Variants) != len(orderedVariants) {
		t.Fatalf("bad result: %#v", result)
	}
	if result.Settings != settings.Defaults() {
		t.Fatalf("generation returned unexpected effective settings: %#v", result.Settings)
	}
	for _, variant := range result.Variants {
		if info, err := os.Stat(variant.Path); err != nil || !info.IsDir() {
			t.Fatalf("variant %s missing: %v", variant.Variant, err)
		}
		background := filepath.Join(variant.Path, "backgrounds", "wallpaper.png")
		if content, err := os.ReadFile(background); err != nil || !bytes.Equal(content, imageData) {
			t.Fatalf("variant %s has bad background: %v", variant.Variant, err)
		}
	}
}

func TestGenerateRejectsOversizedSourceBeforeCreatingGenerationState(t *testing.T) {
	store := generationStore(t)
	record := session.Record{SessionID: "oversized-source", OriginalTheme: "theme", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}}
	saveGenerationRecord(t, store, record)
	imagePath := filepath.Join(t.TempDir(), "source.png")
	if err := os.WriteFile(imagePath, testPNG(t), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(imagePath, fsutil.MaxFileBytes+1); err != nil {
		t.Fatal(err)
	}

	_, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{SessionID: record.SessionID, SourceImage: imagePath})
	if !errors.Is(err, fsutil.ErrFileTooLarge) {
		t.Fatalf("Generate() error = %v, want ErrFileTooLarge", err)
	}
	if _, statErr := os.Stat(filepath.Join(store.SessionDir(record.SessionID), "generations")); !os.IsNotExist(statErr) {
		t.Fatalf("generation state was created before source rejection: %v", statErr)
	}
}

func TestRegenerateCommitsConfigurationWithoutReplacingActiveSession(t *testing.T) {
	store := generationStore(t)
	record := session.Record{
		SessionID:          "reconfigure",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ExtraConfigs:       true,
		ShellStyle:         session.DefaultShellStyle(),
		DesktopStyle:       session.DefaultDesktopStyle(),
		BarStyle:           session.DefaultBarStyle(),
	}
	saveGenerationRecord(t, store, record)
	imagePath := filepath.Join(t.TempDir(), "source.png")
	if err := os.WriteFile(imagePath, testPNG(t), 0o644); err != nil {
		t.Fatal(err)
	}
	configuration := &Configuration{
		ShellStyle:      session.ShellStyle{Preset: session.ShellPresetDefault, Surface: "accent", Detail: "edge", Tooltip: "accent", Notifications: "accent"},
		DesktopStyle:    session.DesktopStyle{BorderStyle: "split_top", BorderSize: 2, BorderSizeMode: "fixed", BorderSpeed: 36, Shape: "rounded", Spacing: "airy", Depth: "shadow", Active: "native", Inactive: "frosted_balanced"},
		BarStyle:        session.BarStyle{Surface: "accent", Density: "compact", Attention: "accent", Form: "docked", Visibility: "islands"},
		AnimationsStyle: session.DefaultAnimationsStyle(),
		LookFeel:        session.LookFeelDocument{SchemaVersion: 1, Preset: "glass-blur", PresetRevision: 1, Customized: map[string]bool{"window": false, "shell": false, "bar": false, "animations": false, "terminal": false}},
		Terminal:        session.TerminalTranslucency{SchemaVersion: 1, Mode: "preset", Opacity: 0.82, CellMode: "background"},
	}

	result, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{
		SessionID:     record.SessionID,
		SourceImage:   imagePath,
		Configuration: configuration,
	})
	if err != nil {
		t.Fatal(err)
	}
	updated, err := store.Load(record.SessionID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.GenerationID != result.GenerationID || updated.SourceImage != imagePath {
		t.Fatalf("generation progress not updated: %#v", updated)
	}
	if updated.OriginalTheme != record.OriginalTheme || updated.OriginalBackground != record.OriginalBackground || !updated.CreatedAt.Equal(record.CreatedAt) {
		t.Fatalf("regeneration replaced the session baseline: %#v", updated)
	}
	if !updated.ExtraConfigs || !reflect.DeepEqual(updated.ShellStyle, configuration.ShellStyle) ||
		!reflect.DeepEqual(updated.DesktopStyle, configuration.DesktopStyle) ||
		!reflect.DeepEqual(updated.BarStyle, configuration.BarStyle) ||
		!reflect.DeepEqual(updated.LookFeel, configuration.LookFeel) ||
		!reflect.DeepEqual(updated.TerminalTranslucency, configuration.Terminal) {
		t.Fatalf("configuration not committed: %#v", updated)
	}
	sourceDir := filepath.Join(store.SessionDir(record.SessionID), "generations", result.GenerationID, string(Source))
	metadata, err := os.ReadFile(filepath.Join(sourceDir, "omagen.bar.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(metadata), `form = "docked"`) || !strings.Contains(string(metadata), `visibility = "islands"`) {
		t.Fatalf("replacement generation did not use updated bar configuration:\n%s", metadata)
	}
	for _, name := range []string{"omagen.look-feel.json", "omagen.terminal.json"} {
		if _, err := os.Stat(filepath.Join(sourceDir, name)); err != nil {
			t.Fatalf("generated %s missing: %v", name, err)
		}
	}
	if _, err := os.Stat(filepath.Join(sourceDir, "shell.notifications.toml")); err != nil {
		t.Fatalf("replacement generation did not use updated notification configuration: %v", err)
	}
	if _, err := os.Stat(filepath.Join(sourceDir, "omagen.runtime.json")); err != nil {
		t.Fatalf("advanced generation did not declare its runtime requirement: %v", err)
	}
	active, exists, err := store.LoadActive()
	if err != nil || !exists || active.SessionID != record.SessionID {
		t.Fatalf("active session changed: active=%#v exists=%t err=%v", active, exists, err)
	}
}

func TestFailedRegenerationPreservesPreviousConfiguration(t *testing.T) {
	store := generationStore(t)
	record := session.Record{
		SessionID:          "failed-reconfigure",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ExtraConfigs:       true,
		ShellStyle:         session.DefaultShellStyle(),
		DesktopStyle:       session.DefaultDesktopStyle(),
		BarStyle:           session.DefaultBarStyle(),
		GenerationID:       "generation-old",
	}
	saveGenerationRecord(t, store, record)
	_, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{
		SessionID:   record.SessionID,
		SourceImage: filepath.Join(t.TempDir(), "missing.png"),
		Configuration: &Configuration{
			ShellStyle:      session.ShellStyle{Surface: "accent", Detail: "edge", Tooltip: "accent", Notifications: "accent"},
			DesktopStyle:    session.DesktopStyle{BorderStyle: "split_top", BorderSize: 2, BorderSpeed: 36, Shape: "rounded", Spacing: "airy", Depth: "shadow", Inactive: "blur"},
			BarStyle:        session.BarStyle{Surface: "accent", Density: "compact", Attention: "accent", Form: "docked", Visibility: "islands"},
			AnimationsStyle: session.DefaultAnimationsStyle(),
		},
	})
	if err == nil {
		t.Fatal("expected regeneration to fail")
	}
	updated, loadErr := store.Load(record.SessionID)
	if loadErr != nil {
		t.Fatal(loadErr)
	}
	if !reflect.DeepEqual(updated, record) {
		t.Fatalf("failed regeneration changed durable record:\n got %#v\nwant %#v", updated, record)
	}
}

func TestDiscardClearsWorkspaceButPreservesActiveSessionAndBaseline(t *testing.T) {
	store := generationStore(t)
	record := session.Record{
		SessionID:          "discard-generation",
		OriginalTheme:      "original-theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/original.png"},
		SourceImage:        "/tmp/source.png",
		ExtraConfigs:       true,
		ShellStyle:         session.DefaultShellStyle(),
		DesktopStyle:       session.DefaultDesktopStyle(),
		BarStyle:           session.DefaultBarStyle(),
		GenerationID:       "generation-old",
		PreviewVariant:     "vibrant",
	}
	saveGenerationRecord(t, store, record)

	result, err := NewService(store, generationSettingsStore(t)).Discard(record.SessionID, record.GenerationID)
	if err != nil {
		t.Fatal(err)
	}
	if !result.OK || result.SessionID != record.SessionID || result.GenerationID != record.GenerationID {
		t.Fatalf("unexpected discard result: %#v", result)
	}
	updated, err := store.Load(record.SessionID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.GenerationID != "" || updated.PreviewVariant != "" {
		t.Fatalf("discard left generated workspace current: %#v", updated)
	}
	if updated.OriginalTheme != record.OriginalTheme || updated.OriginalBackground != record.OriginalBackground ||
		updated.SourceImage != record.SourceImage || !reflect.DeepEqual(updated.ShellStyle, record.ShellStyle) ||
		!reflect.DeepEqual(updated.DesktopStyle, record.DesktopStyle) || !reflect.DeepEqual(updated.BarStyle, record.BarStyle) {
		t.Fatalf("discard changed session baseline or configuration: %#v", updated)
	}
	active, exists, err := store.LoadActive()
	if err != nil || !exists || active.SessionID != record.SessionID {
		t.Fatalf("discard ended active session: active=%#v exists=%t err=%v", active, exists, err)
	}
}

func TestDiscardRestoresBaselineThemeAndBackgroundBeforeReturningToConfiguration(t *testing.T) {
	store := generationStore(t)
	record := session.Record{
		SessionID:          "discard-restores-baseline",
		OriginalTheme:      "original-theme",
		OriginalBackground: session.BackgroundRef{Kind: "theme", Path: "backgrounds/wallpaper.jpg"},
		GenerationID:       "generation-current",
		PreviewVariant:     "vibrant",
	}
	saveGenerationRecord(t, store, record)
	fake := &discardBaselineOmarchy{
		theme:      "omagen-preview-discard-restores-baseline-vibrant",
		background: session.BackgroundRef{Kind: "theme", Path: "backgrounds/wallpaper.png"},
	}

	result, err := NewServiceWithBaselineRestorer(store, generationSettingsStore(t), fake).Discard(record.SessionID, record.GenerationID)
	if err != nil {
		t.Fatal(err)
	}
	if !result.OK {
		t.Fatalf("discard result was not successful: %#v", result)
	}
	if fake.restoredTheme != record.OriginalTheme || fake.restoredBackground != record.OriginalBackground {
		t.Fatalf("discard did not restore the original baseline: %#v", fake)
	}
	updated, err := store.Load(record.SessionID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.GenerationID != "" || updated.PreviewVariant != "" {
		t.Fatalf("discard left generated workspace current: %#v", updated)
	}
	if _, exists, err := store.LoadActive(); err != nil || !exists {
		t.Fatalf("discard ended the active session: exists=%t err=%v", exists, err)
	}
}

func TestGenerateRejectsPendingApply(t *testing.T) {
	store := generationStore(t)
	record := session.Record{
		SessionID:          "pending",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ApplyPhase:         session.ApplyPhaseCommitted,
		AppliedTheme:       "theme-name",
		AppliedGeneration:  "generation-1",
		AppliedVariant:     "source",
		AppliedDisplayName: "Theme Name",
	}
	saveGenerationRecord(t, store, record)
	_, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{SessionID: record.SessionID, SourceImage: "missing"})
	if !errors.Is(err, session.ErrApplyInProgress) {
		t.Fatalf("error=%v, want ErrApplyInProgress", err)
	}
}

func TestCommitGenerationDiscardsWhenSessionWasCancelled(t *testing.T) {
	store := generationStore(t)
	record := session.Record{SessionID: "cancelled", OriginalTheme: "theme", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}}
	saveGenerationRecord(t, store, record)
	generationsRoot := filepath.Join(store.SessionDir(record.SessionID), "generations")
	tmpRoot := filepath.Join(generationsRoot, ".generation.tmp")
	finalRoot := filepath.Join(generationsRoot, "generation-1")
	if err := os.MkdirAll(tmpRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := store.ClearActive(record.SessionID); err != nil {
		t.Fatal(err)
	}
	if _, err := NewService(store, generationSettingsStore(t)).commitGeneration(tmpRoot, finalRoot, Request{SessionID: record.SessionID, SourceImage: "source"}, "generation-1"); !errors.Is(err, session.ErrSessionNotActive) {
		t.Fatalf("error=%v, want ErrSessionNotActive", err)
	}
	if _, err := os.Stat(finalRoot); !os.IsNotExist(err) {
		t.Fatalf("cancelled generation was published, err=%v", err)
	}
}

func TestGenerateWritesSixNativePalettes(t *testing.T) {
	store := generationStore(t)
	saveGenerationRecord(t, store, session.Record{
		SessionID:          "session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
	})

	imagePath := filepath.Join(t.TempDir(), "source.xyz")
	imageData := testPNG(t)
	if err := os.WriteFile(imagePath, imageData, 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{
		SessionID:   "session",
		SourceImage: imagePath,
	})
	if err != nil {
		t.Fatal(err)
	}

	generationRoot := filepath.Join(
		store.SessionDir("session"),
		"generations",
		result.GenerationID,
	)
	files, err := filepath.Glob(filepath.Join(generationRoot, "*", "colors.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 6 {
		t.Fatalf("expected exactly six colors.toml files, got %d: %v", len(files), files)
	}

	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatalf("read %s: %v", file, err)
		}
		for _, key := range []string{
			"mode = ",
			"background = ",
			"foreground = ",
			"red = ",
			"bright_blue = ",
		} {
			if !strings.Contains(string(content), key) {
				t.Errorf("%s is missing native palette key %q", file, key)
			}
		}
	}

	source, err := os.ReadFile(filepath.Join(generationRoot, string(Source), "colors.toml"))
	if err != nil {
		t.Fatal(err)
	}
	deep, err := os.ReadFile(filepath.Join(generationRoot, string(Deep), "colors.toml"))
	if err != nil {
		t.Fatal(err)
	}

	sourceBackground := paletteValue(string(source), "background")
	deepBackground := paletteValue(string(deep), "background")
	if sourceBackground == "" || deepBackground == "" {
		t.Fatalf("missing source or deep background: source=%q deep=%q", sourceBackground, deepBackground)
	}
	if sourceBackground == deepBackground {
		t.Fatalf("source and deep backgrounds should differ: %q", sourceBackground)
	}

	cachedSource, err := os.ReadFile(filepath.Join(generationRoot, "input", "source"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(cachedSource, imageData) {
		t.Fatalf("cached source has unexpected content: %q", cachedSource)
	}
}

func TestThemeEditGenerationDerivesDirectionsFromAuthoredSource(t *testing.T) {
	store := generationStore(t)
	record := session.Record{
		SessionID:          "theme-edit-generation",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
	}
	saveGenerationRecord(t, store, record)

	imagePath := filepath.Join(t.TempDir(), "source.png")
	if err := os.WriteFile(imagePath, testPNG(t), 0o644); err != nil {
		t.Fatal(err)
	}
	initial, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{
		SessionID:   record.SessionID,
		SourceImage: imagePath,
	})
	if err != nil {
		t.Fatal(err)
	}
	authoredSourcePath := filepath.Join(store.SessionDir(record.SessionID), "generations", initial.GenerationID, string(Source), "colors.toml")
	authoredSource, err := os.ReadFile(authoredSourcePath)
	if err != nil {
		t.Fatal(err)
	}

	updated := record
	updated.Workflow = "theme-edit"
	updated.ExtraConfigs = true
	updated.GenerationID = initial.GenerationID
	updated.ThemeEdit = &session.ThemeEdit{SourceID: "theme", SourceName: "Theme", SourcePath: "/themes/theme", SourceKind: "stock"}
	if err := store.Save(updated); err != nil {
		t.Fatal(err)
	}

	derived, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{SessionID: record.SessionID})
	if err != nil {
		t.Fatal(err)
	}
	if len(derived.Variants) != len(orderedVariants) {
		t.Fatalf("expected six derived variants, got %d", len(derived.Variants))
	}
	derivedSource, err := os.ReadFile(filepath.Join(store.SessionDir(record.SessionID), "generations", derived.GenerationID, string(Source), "colors.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(derivedSource, authoredSource) {
		t.Fatal("theme-edit source palette was rewritten while deriving directions")
	}
	for _, variant := range []Variant{Calm, Mute, Deep, Vibrant, Balanced} {
		if _, err := os.Stat(filepath.Join(store.SessionDir(record.SessionID), "generations", derived.GenerationID, string(variant), "colors.toml")); err != nil {
			t.Fatalf("derived %s palette missing: %v", variant, err)
		}
	}
}

func TestGenerateEmitsMergedShellAndSectionOverrides(t *testing.T) {
	store := generationStore(t)
	saveGenerationRecord(t, store, session.Record{
		SessionID:          "styled-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ExtraConfigs:       true,
		ShellStyle:         session.ShellStyle{Surface: "accent", Detail: "edge"},
		DesktopStyle:       session.DefaultDesktopStyle(),
		BarStyle:           session.BarStyle{Surface: "accent", Density: "comfortable", Attention: "accent", Form: "docked"},
	})

	imagePath := filepath.Join(t.TempDir(), "source.png")
	if err := os.WriteFile(imagePath, testPNG(t), 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := NewService(store, generationSettingsStore(t)).Generate(context.Background(), Request{
		SessionID:   "styled-session",
		SourceImage: imagePath,
	})
	if err != nil {
		t.Fatal(err)
	}

	sourceDir := filepath.Join(store.SessionDir("styled-session"), "generations", result.GenerationID, string(Source))
	rootShell, err := os.ReadFile(filepath.Join(sourceDir, "shell.toml"))
	if err != nil {
		t.Fatalf("read generated root shell.toml: %v", err)
	}
	if !strings.Contains(string(rootShell), "[bar]\n") || !strings.Contains(string(rootShell), "[popups]\n") {
		t.Fatalf("generated root shell.toml is missing merged sections:\n%s", rootShell)
	}
	for section, wants := range map[string][]string{
		"bar":      {"background-alpha = 0.0", "size-horizontal = 30", "size-vertical = 32", "active = "},
		"popups":   {"background = "},
		"menu":     {"selected-background = ", "selected-background-alpha = 0.18"},
		"launcher": {"selected-background = ", "selected-background-alpha = 0.18"},
		"controls": {"selected-border = ", "selected-fill-alpha = 0.18"},
	} {
		data, err := os.ReadFile(filepath.Join(sourceDir, "shell."+section+".toml"))
		if err != nil {
			t.Fatalf("read shell.%s.toml: %v", section, err)
		}
		text := string(data)
		if strings.Contains(text, "["+section+"]") {
			t.Fatalf("shell.%s.toml should be headerless:\n%s", section, text)
		}
		for _, want := range wants {
			if !strings.Contains(text, want) {
				t.Errorf("shell.%s.toml missing %q:\n%s", section, want, text)
			}
		}
	}
	metadata, err := os.ReadFile(filepath.Join(sourceDir, "omagen.bar.toml"))
	if err != nil {
		t.Fatalf("read omagen.bar.toml: %v", err)
	}
	if !strings.Contains(string(metadata), `form = "docked"`) {
		t.Fatalf("omagen.bar.toml missing docked form:\n%s", metadata)
	}
	if _, err := os.Stat(filepath.Join(sourceDir, "shell.notifications.toml")); !os.IsNotExist(err) {
		t.Fatalf("unexpected notifications sidecar for accent edge style: %v", err)
	}
}

func testPNG(t *testing.T) []byte {
	t.Helper()

	var buffer bytes.Buffer
	picture := image.NewRGBA(image.Rect(0, 0, 1, 1))
	picture.Set(0, 0, color.RGBA{R: 255, A: 255})
	if err := png.Encode(&buffer, picture); err != nil {
		t.Fatal(err)
	}

	return buffer.Bytes()
}

func paletteValue(content, key string) string {
	prefix := key + " = \""
	start := strings.Index(content, prefix)
	if start < 0 {
		return ""
	}
	start += len(prefix)
	end := strings.IndexByte(content[start:], '"')
	if end < 0 {
		return ""
	}
	return content[start : start+end]
}

func TestGenerateValidationAndJobErrors(t *testing.T) {
	store := generationStore(t)
	svc := NewService(store, generationSettingsStore(t))
	for _, request := range []Request{{SessionID: "missing", SourceImage: "x"}, {SessionID: "missing", SourceImage: ""}} {
		if _, err := svc.Generate(context.Background(), request); err == nil {
			t.Fatal("expected validation error")
		}
	}
	record := session.Record{SessionID: "id", OriginalTheme: "theme", OriginalBackground: session.BackgroundRef{Kind: "x", Path: "y"}}
	saveGenerationRecord(t, store, record)
	if _, err := svc.Generate(context.Background(), Request{SessionID: "id", SourceImage: filepath.Join(t.TempDir(), "none")}); err == nil {
		t.Fatal("expected missing source error")
	}
	cancelled, cancel := context.WithCancel(context.Background())
	cancel()
	if err := runJobs(cancelled, t.TempDir(), "source.png", &imageanalysis.Analysis{
		Image:           image.NewRGBA(image.Rect(0, 0, 1, 1)),
		Width:           1,
		Height:          1,
		Format:          "png",
		Samples:         []imageanalysis.Sample{{R: 255, A: 255}},
		Representatives: []imageanalysis.RepresentativeColor{{Coverage: 1}},
	}, settings.Defaults(), session.ShellStyle{}, session.DesktopStyle{}, session.BarStyle{}, session.AnimationsStyle{}); err == nil {
		t.Fatal("expected cancelled jobs error")
	}
	if err := (job{
		variant:     Source,
		sourceImage: "source.png",
		analysis: &imageanalysis.Analysis{
			Image:           image.NewRGBA(image.Rect(0, 0, 1, 1)),
			Width:           1,
			Height:          1,
			Format:          "png",
			Samples:         []imageanalysis.Sample{{R: 255, A: 255}},
			Representatives: []imageanalysis.RepresentativeColor{{Coverage: 1}},
		},
	}).run(context.Background(), filepath.Join(t.TempDir(), "missing", "nested")); err == nil {
		t.Fatal("expected mkdir error")
	}
}

func TestGenerationHelpers(t *testing.T) {
	for _, path := range []string{"", filepath.Join(t.TempDir(), "dir")} {
		if path != "" {
			if err := os.Mkdir(path, 0o755); err != nil {
				t.Fatal(err)
			}
		}
		if err := validateSourceImage(path); err == nil {
			t.Fatal("expected invalid source")
		}
	}
	result := buildResult("id", "/root", settings.Defaults())
	if result.Variants[0].Path != filepath.Join("/root", string(Source)) || !strings.Contains(result.GenerationID, "id") {
		t.Fatalf("bad result: %#v", result)
	}
}
