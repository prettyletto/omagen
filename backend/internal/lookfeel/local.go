package lookfeel

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const localPresetDirectory = "look-feels"

// LocalStore owns the user's saved Look & Feel recipes. They are deliberately
// separate from built-in catalog data and from generated theme directories.
type LocalStore struct {
	dir string
}

func NewLocalStore() (*LocalStore, error) {
	configRoot, err := os.UserConfigDir()
	if err != nil {
		return nil, fmt.Errorf("resolve user config directory: %w", err)
	}
	return NewLocalStoreAt(filepath.Join(configRoot, "omagen", localPresetDirectory)), nil
}

func NewLocalStoreAt(dir string) *LocalStore { return &LocalStore{dir: dir} }

func (s *LocalStore) List() ([]CatalogEntry, error) {
	entries := []CatalogEntry{}
	files, err := os.ReadDir(s.dir)
	if os.IsNotExist(err) {
		return entries, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read local Look & Feel presets: %w", err)
	}
	for _, file := range files {
		if file.IsDir() || filepath.Ext(file.Name()) != ".json" {
			continue
		}
		manifest, err := s.readManifest(file.Name())
		if err != nil {
			return nil, err
		}
		entries = append(entries, CatalogEntry{
			ID: manifest.ID, Name: manifest.Name, Description: manifest.Description,
			Revision: manifest.Version, Local: true,
		})
	}
	sort.Slice(entries, func(i, j int) bool { return strings.ToLower(entries[i].Name) < strings.ToLower(entries[j].Name) })
	return entries, nil
}

func (s *LocalStore) Resolve(id string) (Composition, error) {
	manifest, err := s.readManifest(id + ".json")
	if err != nil {
		return Composition{}, err
	}
	return manifest.Recipe, nil
}

func (s *LocalStore) Save(name string, composition Composition) (CatalogEntry, error) {
	name = strings.TrimSpace(name)
	if name == "" || len([]rune(name)) > 64 {
		return CatalogEntry{}, fmt.Errorf("Look & Feel preset name must be between 1 and 64 characters")
	}
	id := localPresetID(name)
	if id == "" {
		return CatalogEntry{}, fmt.Errorf("Look & Feel preset name must contain a letter or number")
	}
	if composition.Preset == "" {
		composition.Preset = PresetNative
	}
	if composition.PresetRevision < 1 {
		composition.PresetRevision = 1
	}
	composition.Customized = map[string]bool{
		"window": true, "shell": true, "bar": true, "animations": true, "terminal": true,
	}
	if err := composition.Validate(); err != nil {
		return CatalogEntry{}, fmt.Errorf("validate Look & Feel preset: %w", err)
	}
	// A saved recipe is a complete standalone document. Its identity must not
	// remain tied to the built-in preset from which the user started editing.
	composition.Preset = id
	composition.PresetRevision = 1
	manifest := Manifest{
		SchemaVersion: ManifestSchemaVersion,
		Kind:          ManifestKind,
		ID:            id,
		Name:          name,
		Author:        "Local",
		Version:       1,
		Description:   "Saved from a custom Omagen composition",
		Recipe:        composition,
	}
	if err := manifest.Validate(); err != nil {
		return CatalogEntry{}, err
	}
	if _, err := os.Stat(filepath.Join(s.dir, id+".json")); err == nil {
		return CatalogEntry{}, fmt.Errorf("local Look & Feel preset %q already exists: %w", name, fs.ErrExist)
	} else if !os.IsNotExist(err) {
		return CatalogEntry{}, fmt.Errorf("inspect local Look & Feel preset %q: %w", name, err)
	}
	if err := fsutil.AtomicWriteJSON(filepath.Join(s.dir, id+".json"), manifest, 0o644); err != nil {
		return CatalogEntry{}, fmt.Errorf("save local Look & Feel preset: %w", err)
	}
	return CatalogEntry{ID: id, Name: name, Description: manifest.Description, Revision: 1, Local: true}, nil
}

func (s *LocalStore) readManifest(filename string) (Manifest, error) {
	if filepath.Base(filename) != filename || filepath.Ext(filename) != ".json" {
		return Manifest{}, fmt.Errorf("invalid local Look & Feel preset filename")
	}
	data, err := fsutil.ReadFileLimited(filepath.Join(s.dir, filename), fsutil.MaxStateFileBytes)
	if err != nil {
		return Manifest{}, err
	}
	manifest, err := DecodeManifest(data)
	if err != nil {
		return Manifest{}, fmt.Errorf("read local Look & Feel preset %q: %w", strings.TrimSuffix(filename, ".json"), err)
	}
	if !strings.HasPrefix(manifest.ID, "local-") {
		return Manifest{}, fmt.Errorf("local Look & Feel preset %q has a non-local ID", manifest.ID)
	}
	if manifest.ID != strings.TrimSuffix(filename, ".json") {
		return Manifest{}, fmt.Errorf("local Look & Feel preset filename does not match manifest ID %q", manifest.ID)
	}
	return manifest, nil
}

var localPresetIDPattern = regexp.MustCompile(`[^a-z0-9]+`)

func localPresetID(name string) string {
	slug := strings.ToLower(strings.TrimSpace(name))
	slug = localPresetIDPattern.ReplaceAllString(slug, "-")
	slug = strings.Trim(slug, "-")
	if slug == "" {
		return ""
	}
	return "local-" + slug
}

// CatalogWithLocal keeps the built-in order stable and appends local recipes.
func CatalogWithLocal() ([]CatalogEntry, error) {
	store, err := NewLocalStore()
	if err != nil {
		return nil, err
	}
	entries := append([]CatalogEntry(nil), Catalog()...)
	local, err := store.List()
	if err != nil {
		return nil, err
	}
	return append(entries, local...), nil
}

func SaveLocal(name string, composition Composition) (CatalogEntry, error) {
	store, err := NewLocalStore()
	if err != nil {
		return CatalogEntry{}, err
	}
	return store.Save(name, composition)
}
