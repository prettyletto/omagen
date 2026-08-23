package settings

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
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
	data, err := fsutil.ReadFileLimited(s.path, fsutil.MaxStateFileBytes)
	if errors.Is(err, os.ErrNotExist) {
		return Defaults(), nil
	}
	if err != nil {
		return Settings{}, fmt.Errorf("open settings: %w", err)
	}

	settings := Defaults()
	if err := decodeStrict(bytes.NewReader(data), &settings); err != nil {
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

	if err := fsutil.AtomicWriteJSON(s.path, settings, 0o644); err != nil {
		return Settings{}, fmt.Errorf("persist settings: %w", err)
	}
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
	if err := fsutil.RemoveFileAndSync(s.path); err != nil {
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
