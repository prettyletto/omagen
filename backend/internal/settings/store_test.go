package settings

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/palette"
)

func testStore(t *testing.T) *Store {
	t.Helper()
	path := filepath.Join(t.TempDir(), "settings.json")
	return &Store{path: path}
}

func TestLoadRejectsOversizedSettingsFile(t *testing.T) {
	store := testStore(t)
	if err := os.WriteFile(store.path, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(store.path, fsutil.MaxStateFileBytes+1); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Load(); !errors.Is(err, fsutil.ErrFileTooLarge) {
		t.Fatalf("Load() error = %v, want ErrFileTooLarge", err)
	}
}

func TestLoadMissingReturnsDefaults(t *testing.T) {
	got, err := testStore(t).Load()
	if err != nil {
		t.Fatal(err)
	}
	if got != Defaults() {
		t.Fatalf("got %#v, want defaults %#v", got, Defaults())
	}
}

func TestUpdateJSONMergesWithCurrentSettings(t *testing.T) {
	store := testStore(t)
	got, err := store.UpdateJSON([]byte(`{"contrast":{"secondary_text":3.5}}`))
	if err != nil {
		t.Fatal(err)
	}
	if got.Contrast.SecondaryText != 3.5 {
		t.Fatalf("got secondary text %.2f", got.Contrast.SecondaryText)
	}
	if got.Contrast.PrimaryText != Defaults().Contrast.PrimaryText {
		t.Fatalf("partial update changed primary text: %.2f", got.Contrast.PrimaryText)
	}
	if _, err := os.Stat(store.path); err != nil {
		t.Fatalf("settings file was not persisted: %v", err)
	}
}

func TestUpdateJSONRejectsUnknownFields(t *testing.T) {
	if _, err := testStore(t).UpdateJSON([]byte(`{"unknown":true}`)); err == nil {
		t.Fatal("expected unknown field error")
	}
}

func TestResetRemovesPersistedSettings(t *testing.T) {
	store := testStore(t)
	if _, err := store.Save(Defaults()); err != nil {
		t.Fatal(err)
	}
	got, err := store.Reset()
	if err != nil {
		t.Fatal(err)
	}
	if got != Defaults() {
		t.Fatalf("got %#v, want defaults %#v", got, Defaults())
	}
	if _, err := os.Stat(store.path); !os.IsNotExist(err) {
		t.Fatalf("settings file still exists: %v", err)
	}
}

func TestApplyOverrides(t *testing.T) {
	base := Defaults()
	harmony := palette.HarmonyTriadic
	got, err := ApplyOverrides(base, Overrides{
		ColorTheory: ColorTheoryOverrides{Harmony: &harmony},
	})
	if err != nil {
		t.Fatal(err)
	}
	if got.ColorTheory.Harmony != harmony {
		t.Fatalf("got harmony %q, want %q", got.ColorTheory.Harmony, harmony)
	}
	if base.ColorTheory.Harmony != palette.HarmonyAuto {
		t.Fatal("override mutated base settings")
	}
}

func TestLoadBackfillsNewContrastDefaults(t *testing.T) {
	store := testStore(t)
	raw := `{
		"schema_version": 1,
		"color_theory": {"harmony": "auto"},
		"contrast": {
			"primary_text": 4.5,
			"bright_text": 7.0,
			"secondary_text": 3.0,
			"ui_element": 3.0,
			"selection_text": 4.5
		}
	}`
	if err := os.WriteFile(store.path, []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}
	got, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	defaults := Defaults()
	if got.Contrast.ANSI != defaults.Contrast.ANSI {
		t.Fatalf("ANSI = %.2f, want default %.2f", got.Contrast.ANSI, defaults.Contrast.ANSI)
	}
	if got.Contrast.BrightANSI != defaults.Contrast.BrightANSI {
		t.Fatalf("BrightANSI = %.2f, want default %.2f", got.Contrast.BrightANSI, defaults.Contrast.BrightANSI)
	}
}
