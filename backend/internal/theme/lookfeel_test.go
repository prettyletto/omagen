package theme

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/lookfeel"
	"github.com/prettyletto/omagen/backend/internal/session"
)

func TestWriteLookFeelMetadataRoundTrips(t *testing.T) {
	dir := t.TempDir()
	composition, err := lookfeel.Resolve(lookfeel.PresetGlassBlur)
	if err != nil {
		t.Fatal(err)
	}
	if err := WriteLookFeelMetadata(dir, session.LookFeelDocument{SchemaVersion: composition.SchemaVersion, Preset: composition.Preset, PresetRevision: composition.PresetRevision, Customized: composition.Customized}); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "omagen.look-feel.json"))
	if err != nil {
		t.Fatal(err)
	}
	var got session.LookFeelDocument
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatal(err)
	}
	if got.Preset != lookfeel.PresetGlassBlur || got.PresetRevision != 7 || got.Customized["window"] {
		t.Fatalf("metadata = %#v", got)
	}
}

func TestWriteTerminalTranslucencyRejectsInvalidSpec(t *testing.T) {
	err := WriteTerminalTranslucency(t.TempDir(), session.TerminalTranslucency{SchemaVersion: 1, Mode: "custom", Opacity: 0.2, CellMode: "background"})
	if err == nil {
		t.Fatal("invalid terminal opacity was accepted")
	}
}
