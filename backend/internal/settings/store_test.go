package settings

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/palette"
)

func testStore(t *testing.T) *Store {
	t.Helper()
	path := filepath.Join(t.TempDir(), "settings.json")
	return &Store{path: path}
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
	if _, err := ApplyOverrides(base, Overrides{
		ColorTheory: ColorTheoryOverrides{Harmony: &harmony},
	}); err == nil {
		t.Fatal("expected unsupported harmony override to fail")
	}
	if base.ColorTheory.Harmony != palette.HarmonyAuto {
		t.Fatal("override mutated base settings")
	}
}
