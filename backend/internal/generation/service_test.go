package generation

import (
	"bytes"
	"context"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/settings"
)

func generationStore(t *testing.T) *session.Store {
	t.Helper()
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
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

func TestGenerate(t *testing.T) {
	store := generationStore(t)
	record := session.Record{SessionID: "session", OriginalTheme: "theme", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
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

func TestGenerateWritesSixNativePalettes(t *testing.T) {
	store := generationStore(t)
	if err := store.Save(session.Record{
		SessionID:          "session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
	}); err != nil {
		t.Fatal(err)
	}

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

func TestGenerateComposesShellAndBarIntoShellTOML(t *testing.T) {
	store := generationStore(t)
	if err := store.Save(session.Record{
		SessionID:          "styled-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ExtraConfigs:       true,
		ShellStyle:         session.ShellStyle{Surface: "accent", Detail: "edge"},
		DesktopStyle:       session.DefaultDesktopStyle(),
		BarStyle:           session.BarStyle{Surface: "accent", Density: "comfortable", Attention: "accent", Form: "docked"},
	}); err != nil {
		t.Fatal(err)
	}

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
	data, err := os.ReadFile(filepath.Join(sourceDir, "shell.toml"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{"[popups]", "[bar]", `form = "docked"`, "size-horizontal = 30", "size-vertical = 32", "active = "} {
		if !strings.Contains(text, want) {
			t.Errorf("generated shell.toml missing %q:\n%s", want, text)
		}
	}
	if strings.Count(text, "[bar]") != 1 {
		t.Fatalf("expected exactly one bar table:\n%s", text)
	}
	if _, err := os.Stat(filepath.Join(sourceDir, "shell.bar.toml")); !os.IsNotExist(err) {
		t.Fatalf("unexpected shell.bar.toml sidecar: %v", err)
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
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
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
	}, settings.Defaults(), session.ShellStyle{}, session.DesktopStyle{}, session.BarStyle{}); err == nil {
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
