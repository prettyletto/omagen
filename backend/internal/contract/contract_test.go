package contract_test

import (
	"context"
	"errors"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/apply"
	"github.com/prettyletto/omagen/backend/internal/cleanup"
	"github.com/prettyletto/omagen/backend/internal/demo"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/preview"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/settings"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

type nativeOmarchy struct {
	theme      string
	background session.BackgroundRef

	restoredTheme      string
	restoredBackground session.BackgroundRef
}

func (n *nativeOmarchy) CurrentTheme() (string, error) { return n.theme, nil }

func (n *nativeOmarchy) CurrentBackground() (session.BackgroundRef, error) {
	return n.background, nil
}

func (n *nativeOmarchy) RestoreThemeFast(theme, _ string) error {
	n.restoredTheme = theme
	n.theme = theme
	return nil
}

func (n *nativeOmarchy) RestoreBackground(background session.BackgroundRef) error {
	n.restoredBackground = background
	n.background = background
	return nil
}

func (n *nativeOmarchy) ApplyThemePreview(theme, _ string) (int, bool, error) {
	n.theme = theme
	return 101, false, nil
}

func (n *nativeOmarchy) ApplyTheme(theme, _ string) error {
	n.theme = theme
	return nil
}

func TestSessionContractPreservesBaselineAcrossPreviewBackAndCancel(t *testing.T) {
	testenv.Isolate(t)
	native := &nativeOmarchy{
		theme:      "original-theme",
		background: session.BackgroundRef{Kind: "external", Path: "/tmp/original.png"},
	}
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	sessionService := session.NewService(store, native)
	begin, err := sessionService.Begin()
	if err != nil {
		t.Fatal(err)
	}

	imagePath := filepath.Join(t.TempDir(), "source.png")
	writeContractPNG(t, imagePath)
	settingsStore, err := settings.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	generationResult, err := generation.NewService(store, settingsStore).Generate(
		context.Background(),
		generation.Request{SessionID: begin.SessionID, SourceImage: imagePath},
	)
	if err != nil {
		t.Fatal(err)
	}

	previewService, err := preview.NewService(store, native)
	if err != nil {
		t.Fatal(err)
	}
	previewResult, err := previewService.Apply(preview.Request{
		SessionID:    begin.SessionID,
		GenerationID: generationResult.GenerationID,
		Variant:      generation.Source,
	})
	if err != nil {
		t.Fatal(err)
	}
	if previewResult.ThemeName == "" || native.theme != previewResult.ThemeName {
		t.Fatalf("preview did not become the active candidate: result=%#v theme=%q", previewResult, native.theme)
	}

	// Configuration Back discards the generated direction but keeps the same
	// rollback boundary so the user can generate again without losing the
	// original desktop state.
	if _, err := generation.NewService(store, settingsStore).Discard(begin.SessionID, generationResult.GenerationID); err != nil {
		t.Fatal(err)
	}
	updated, err := store.Load(begin.SessionID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.GenerationID != "" || updated.PreviewVariant != "" {
		t.Fatalf("Back left generated state attached: %#v", updated)
	}
	if updated.OriginalTheme != begin.OriginalTheme || updated.OriginalBackground != begin.OriginalBackground {
		t.Fatalf("Back changed the rollback baseline: %#v", updated)
	}
	if _, exists, err := store.LoadActive(); err != nil || !exists {
		t.Fatalf("Back ended the active session: exists=%t err=%v", exists, err)
	}

	// Cancel and bar Quit share this restoration contract. Preview cleanup is
	// intentionally called after the durable session has been restored.
	if err := sessionService.Cancel(begin.SessionID); err != nil {
		t.Fatal(err)
	}
	if err := previewService.CleanupSession(begin.SessionID); err != nil {
		t.Fatal(err)
	}
	if native.restoredTheme != begin.OriginalTheme || native.restoredBackground != begin.OriginalBackground {
		t.Fatalf("cancel did not restore the baseline: %#v", native)
	}
	if _, exists, err := store.LoadActive(); err != nil || exists {
		t.Fatalf("cancel did not return to state zero: exists=%t err=%v", exists, err)
	}
	if _, err := store.Load(begin.SessionID); err == nil {
		t.Fatal("cancel left the durable session behind")
	}
}

func TestApplyContractCommitsAndClearsTheSession(t *testing.T) {
	testenv.Isolate(t)
	native := &nativeOmarchy{theme: "original-theme", background: session.BackgroundRef{Kind: "external", Path: "/tmp/original.png"}}
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	sessionService := session.NewService(store, native)
	begin, err := sessionService.Begin()
	if err != nil {
		t.Fatal(err)
	}

	record, err := store.Load(begin.SessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.GenerationID = "generation-1"
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	candidate := filepath.Join(store.SessionDir(begin.SessionID), "generations", "generation-1", "source")
	if err := os.MkdirAll(filepath.Join(candidate, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(candidate, "colors.toml"), []byte("background = \"#000000\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	wallpaper := image.NewRGBA(image.Rect(0, 0, 16, 9))
	wallpaperFile, err := os.Create(filepath.Join(candidate, "backgrounds", "wallpaper.png"))
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(wallpaperFile, wallpaper); err != nil {
		_ = wallpaperFile.Close()
		t.Fatal(err)
	}
	if err := wallpaperFile.Close(); err != nil {
		t.Fatal(err)
	}

	applyService, err := apply.NewService(store, native)
	if err != nil {
		t.Fatal(err)
	}
	result, err := applyService.Apply(apply.Request{
		SessionID:    begin.SessionID,
		GenerationID: record.GenerationID,
		Variant:      generation.Source,
		ThemeName:    "Contract Theme",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.ThemeName != "contract-theme" || native.theme != result.ThemeName {
		t.Fatalf("unexpected committed theme: result=%#v theme=%q", result, native.theme)
	}
	if _, exists, err := store.LoadActive(); err != nil || exists {
		t.Fatalf("Apply left the active session behind: exists=%t err=%v", exists, err)
	}
	if _, err := store.Load(begin.SessionID); err == nil {
		t.Fatal("Apply left the durable session behind")
	}
	if _, err := os.Stat(filepath.Join(result.ThemePath, ".omagen-owner")); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("committed theme retained ownership marker: err=%v", err)
	}
}

func TestRecoveryAndCleanupContractsProtectOwnership(t *testing.T) {
	testenv.Isolate(t)
	native := &nativeOmarchy{theme: "changed-theme", background: session.BackgroundRef{Kind: "external", Path: "/tmp/changed.png"}}
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "recoverable",
		OriginalTheme:      "original-theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/original.png"},
		CreatedAt:          time.Now().UTC(),
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	recovered, err := session.NewService(store, native).RecoverActive()
	if err != nil || !recovered.Recovered {
		t.Fatalf("recovery=%#v err=%v", recovered, err)
	}
	if native.theme != record.OriginalTheme || native.background != record.OriginalBackground {
		t.Fatalf("recovery did not restore the baseline: %#v", native)
	}

	themes := filepath.Join(t.TempDir(), "themes")
	if err := os.MkdirAll(themes, 0o755); err != nil {
		t.Fatal(err)
	}
	stale := session.Record{
		SessionID:          "stale",
		OriginalTheme:      "old",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/old.png"},
		CreatedAt:          time.Now().UTC(),
	}
	if err := store.Save(stale); err != nil {
		t.Fatal(err)
	}
	staleRoot := store.SessionDir(stale.SessionID)
	if err := os.MkdirAll(filepath.Join(staleRoot, "demo-scene"), 0o755); err != nil {
		t.Fatal(err)
	}
	alias := filepath.Join(themes, "omagen-preview-stale-source")
	if err := os.Symlink(filepath.Join(staleRoot, "demo-scene"), alias); err != nil {
		t.Fatal(err)
	}
	cleanupResult, err := cleanup.NewService(store, themes).Run()
	if err != nil {
		t.Fatal(err)
	}
	if cleanupResult.SessionDirsRemoved != 1 || cleanupResult.PreviewAliasesRemoved != 1 {
		t.Fatalf("unexpected cleanup result: %#v", cleanupResult)
	}
	if _, err := os.Stat(staleRoot); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("stale session remains after cleanup: err=%v", err)
	}
	if _, err := os.Lstat(alias); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("stale preview alias remains after cleanup: err=%v", err)
	}
}

func TestDemoContractRejectsMutationDuringApply(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "demo-apply",
		OriginalTheme:      "old",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/old.png"},
		CreatedAt:          time.Now().UTC(),
		ApplyPhase:         session.ApplyPhasePrepared,
		AppliedTheme:       "candidate",
		AppliedGeneration:  "generation-1",
		AppliedVariant:     "source",
		AppliedDisplayName: "Candidate",
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	if _, err := demo.NewService(store).Open(record.SessionID); !errors.Is(err, session.ErrApplyInProgress) {
		t.Fatalf("Demo opened during Apply: err=%v", err)
	}
}

func writeContractPNG(t *testing.T, path string) {
	t.Helper()
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	imageData := image.NewRGBA(image.Rect(0, 0, 4, 3))
	imageData.Set(1, 1, color.RGBA{R: 255, A: 255})
	if err := png.Encode(file, imageData); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
}
