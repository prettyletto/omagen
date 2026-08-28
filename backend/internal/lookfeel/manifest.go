package lookfeel

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
)

const (
	ManifestSchemaVersion = 1
	ManifestKind          = "omagen.look-feel.recipe"
)

// Manifest is the portable community boundary. The recipe remains a resolved
// composition of the existing engines, so imported presets and hand-edited
// Advanced values use the same validators and runtime readers.
type Manifest struct {
	SchemaVersion int         `json:"schema_version"`
	Kind          string      `json:"kind"`
	ID            string      `json:"id"`
	Name          string      `json:"name"`
	Author        string      `json:"author"`
	Version       int         `json:"version"`
	Description   string      `json:"description,omitempty"`
	Recipe        Composition `json:"recipe"`
}

func Export(preset string) (Manifest, error) {
	recipe, err := Resolve(preset)
	if err != nil {
		return Manifest{}, err
	}
	entry, ok := catalogEntry(preset)
	if !ok {
		return Manifest{}, fmt.Errorf("preset %q has no catalog metadata", preset)
	}
	manifest := Manifest{
		SchemaVersion: ManifestSchemaVersion, Kind: ManifestKind,
		ID: entry.ID, Name: entry.Name, Author: "Omagen", Version: entry.Revision,
		Description: entry.Description, Recipe: recipe,
	}
	return manifest, manifest.Validate()
}

func (m Manifest) Validate() error {
	if m.SchemaVersion != ManifestSchemaVersion {
		return fmt.Errorf("unsupported recipe manifest schema version %d", m.SchemaVersion)
	}
	if m.Kind != ManifestKind {
		return fmt.Errorf("invalid recipe manifest kind %q", m.Kind)
	}
	if m.ID == "" || m.Name == "" || m.Author == "" || m.Version < 1 {
		return fmt.Errorf("recipe manifest metadata is incomplete")
	}
	if m.Recipe.Preset != m.ID || m.Recipe.PresetRevision != m.Version {
		return fmt.Errorf("recipe identity does not match manifest metadata")
	}
	return m.Recipe.Validate()
}

func DecodeManifest(data []byte) (Manifest, error) {
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var manifest Manifest
	if err := decoder.Decode(&manifest); err != nil {
		return Manifest{}, fmt.Errorf("decode recipe manifest: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return Manifest{}, fmt.Errorf("decode recipe manifest: trailing JSON data")
	}
	if err := manifest.Validate(); err != nil {
		return Manifest{}, err
	}
	return manifest, nil
}

func catalogEntry(id string) (CatalogEntry, bool) {
	for _, entry := range Catalog() {
		if entry.ID == id {
			return entry, true
		}
	}
	return CatalogEntry{}, false
}
