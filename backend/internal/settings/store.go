package settings

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

type Store struct {
	path string
}

func NewStore() (*Store, error) {
	configRoot, err := os.UserConfigDir()
	if err != nil {
		return nil, fmt.Errorf("resolve user config directory: %w", err)
	}

	return &Store{path: filepath.Join(configRoot, "omagen", "settings.json")}, nil
}

func (s *Store) Load() (Settings, error) {
	file, err := os.Open(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return Defaults(), nil
	}
	if err != nil {
		return Settings{}, fmt.Errorf("open settings: %w", err)
	}
	defer file.Close()

	settings := Defaults()
	if err := decodeStrict(file, &settings); err != nil {
		return Settings{}, fmt.Errorf("decode settings: %w", err)
	}
	if err := settings.Validate(); err != nil {
		return Settings{}, err
	}
	return settings, nil
}

func (s *Store) Save(settings Settings) (Settings, error) {
	if err := settings.Validate(); err != nil {
		return Settings{}, err
	}

	dir := filepath.Dir(s.path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return Settings{}, fmt.Errorf("create settings directory: %w", err)
	}

	tmp, err := os.CreateTemp(dir, ".settings-*.tmp")
	if err != nil {
		return Settings{}, fmt.Errorf("create temporary settings file: %w", err)
	}
	tmpPath := tmp.Name()
	committed := false
	defer func() {
		_ = tmp.Close()
		if !committed {
			_ = os.Remove(tmpPath)
		}
	}()

	if err := tmp.Chmod(0o644); err != nil {
		return Settings{}, fmt.Errorf("set settings permissions: %w", err)
	}
	encoder := json.NewEncoder(tmp)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(settings); err != nil {
		return Settings{}, fmt.Errorf("encode settings: %w", err)
	}
	if err := tmp.Sync(); err != nil {
		return Settings{}, fmt.Errorf("sync settings: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return Settings{}, fmt.Errorf("close settings: %w", err)
	}
	if err := os.Rename(tmpPath, s.path); err != nil {
		return Settings{}, fmt.Errorf("commit settings: %w", err)
	}
	committed = true
	return settings, nil
}

func (s *Store) UpdateJSON(raw []byte) (Settings, error) {
	current, err := s.Load()
	if err != nil {
		return Settings{}, err
	}
	if err := decodeStrict(bytes.NewReader(raw), &current); err != nil {
		return Settings{}, fmt.Errorf("decode settings update: %w", err)
	}
	if err := current.Validate(); err != nil {
		return Settings{}, err
	}
	return s.Save(current)
}

func (s *Store) Reset() (Settings, error) {
	err := os.Remove(s.path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return Settings{}, fmt.Errorf("remove settings: %w", err)
	}
	return Defaults(), nil
}

func decodeStrict(reader io.Reader, target any) error {
	decoder := json.NewDecoder(reader)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	var trailing any
	err := decoder.Decode(&trailing)
	if err == io.EOF {
		return nil
	}
	if err != nil {
		return err
	}
	return fmt.Errorf("settings contain multiple JSON values")
}
