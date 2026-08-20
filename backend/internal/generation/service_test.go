package generation

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/session"
)

func generationStore(t *testing.T) *session.Store {
	t.Helper()
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	store, err := session.NewStore()
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
	image := filepath.Join(t.TempDir(), "source.png")
	if err := os.WriteFile(image, []byte("image"), 0o644); err != nil {
		t.Fatal(err)
	}
	result, err := NewService(store).Generate(context.Background(), Request{SessionID: "session", SourceImage: image})
	if err != nil {
		t.Fatal(err)
	}
	if result.GenerationID == "" || len(result.Variants) != len(orderedVariants) {
		t.Fatalf("bad result: %#v", result)
	}
	for _, variant := range result.Variants {
		if info, err := os.Stat(variant.Path); err != nil || !info.IsDir() {
			t.Fatalf("variant %s missing: %v", variant.Variant, err)
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

	image := filepath.Join(t.TempDir(), "source.png")
	if err := os.WriteFile(image, []byte("image"), 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := NewService(store).Generate(context.Background(), Request{
		SessionID:   "session",
		SourceImage: image,
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
	svc := NewService(store)
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
	if err := runJobs(cancelled, t.TempDir()); err == nil {
		t.Fatal("expected cancelled jobs error")
	}
	if err := (job{variant: Source}).run(context.Background(), filepath.Join(t.TempDir(), "missing", "nested")); err == nil {
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
	result := buildResult("id", "/root")
	if result.Variants[0].Path != filepath.Join("/root", string(Source)) || !strings.Contains(result.GenerationID, "id") {
		t.Fatalf("bad result: %#v", result)
	}
}
