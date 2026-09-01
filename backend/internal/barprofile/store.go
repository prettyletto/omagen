package barprofile

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const maxShellConfigBytes = fsutil.MaxStateFileBytes

type Snapshot struct {
	SchemaVersion      int    `json:"schema_version"`
	Theme              string `json:"theme,omitempty"`
	ConfigPath         string `json:"config_path"`
	ConfigExists       bool   `json:"config_exists"`
	ConfigMode         uint32 `json:"config_mode,omitempty"`
	ConfigSHA256       string `json:"config_sha256,omitempty"`
	Config             []byte `json:"config,omitempty"`
	HiddenTogglePath   string `json:"hidden_toggle_path,omitempty"`
	HiddenToggleExists bool   `json:"hidden_toggle_exists,omitempty"`
}

type Store struct {
	configPath string
	stateRoot  string
	hiddenPath string
}

func NewStore() (*Store, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("resolve home directory: %w", err)
	}
	stateRoot, err := fsutil.UserStateDir("omagen")
	if err != nil {
		return nil, err
	}
	omarchyState, err := fsutil.UserStateDir("omarchy")
	if err != nil {
		return nil, err
	}
	return NewStoreAt(filepath.Join(home, ".config", "omarchy", "shell.json"), filepath.Join(stateRoot, "bar"), filepath.Join(omarchyState, "toggles", "bar-off")), nil
}

func NewStoreAt(configPath, stateRoot string, hiddenPath ...string) *Store {
	hidden := ""
	if len(hiddenPath) > 0 {
		hidden = hiddenPath[0]
	}
	return &Store{configPath: configPath, stateRoot: stateRoot, hiddenPath: hidden}
}

func (s *Store) ConfigPath() string { return s.configPath }
func (s *Store) StateRoot() string  { return s.stateRoot }

func (s *Store) Capture(theme string) (Snapshot, error) {
	snapshot := Snapshot{SchemaVersion: SchemaVersion, Theme: theme, ConfigPath: s.configPath}
	info, err := os.Stat(s.configPath)
	if os.IsNotExist(err) {
		s.captureHiddenToggle(&snapshot)
		return snapshot, nil
	}
	if err != nil {
		return Snapshot{}, fmt.Errorf("inspect bar config: %w", err)
	}
	if !info.Mode().IsRegular() {
		return Snapshot{}, fmt.Errorf("bar config is not a regular file")
	}
	data, err := fsutil.ReadFileLimited(s.configPath, maxShellConfigBytes)
	if err != nil {
		return Snapshot{}, fmt.Errorf("read bar config: %w", err)
	}
	snapshot.ConfigExists = true
	snapshot.ConfigMode = uint32(info.Mode().Perm())
	snapshot.ConfigSHA256 = hash(data)
	snapshot.Config = append([]byte(nil), data...)
	if err := s.captureHiddenToggle(&snapshot); err != nil {
		return Snapshot{}, err
	}
	return snapshot, nil
}

func (s *Store) captureHiddenToggle(snapshot *Snapshot) error {
	if s.hiddenPath == "" {
		return nil
	}
	snapshot.HiddenTogglePath = s.hiddenPath
	if _, hiddenErr := os.Stat(s.hiddenPath); hiddenErr == nil {
		snapshot.HiddenToggleExists = true
	} else if !os.IsNotExist(hiddenErr) {
		return fmt.Errorf("inspect bar hidden toggle: %w", hiddenErr)
	}
	return nil
}

func (s *Store) SaveSnapshot(sessionID string, snapshot Snapshot) error {
	if !validComponent(sessionID) {
		return fmt.Errorf("invalid session id")
	}
	if snapshot.SchemaVersion == 0 {
		snapshot.SchemaVersion = SchemaVersion
	}
	if snapshot.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported bar snapshot schema version %d", snapshot.SchemaVersion)
	}
	return fsutil.AtomicWriteJSON(filepath.Join(s.stateRoot, "snapshots", sessionID+".json"), snapshot, 0o600)
}

func (s *Store) LoadSnapshot(sessionID string) (Snapshot, error) {
	if !validComponent(sessionID) {
		return Snapshot{}, fmt.Errorf("invalid session id")
	}
	data, err := fsutil.ReadFileLimited(filepath.Join(s.stateRoot, "snapshots", sessionID+".json"), maxShellConfigBytes+maxShellConfigBytes/2)
	if err != nil {
		return Snapshot{}, err
	}
	var snapshot Snapshot
	if err := json.Unmarshal(data, &snapshot); err != nil {
		return Snapshot{}, fmt.Errorf("decode bar snapshot: %w", err)
	}
	if snapshot.SchemaVersion != SchemaVersion {
		return Snapshot{}, fmt.Errorf("unsupported bar snapshot schema version %d", snapshot.SchemaVersion)
	}
	if snapshot.ConfigExists && hash(snapshot.Config) != snapshot.ConfigSHA256 {
		return Snapshot{}, fmt.Errorf("bar snapshot checksum mismatch")
	}
	return snapshot, nil
}

func (s *Store) DeleteSnapshot(sessionID string) error {
	if !validComponent(sessionID) {
		return fmt.Errorf("invalid session id")
	}
	return fsutil.RemoveFileAndSync(filepath.Join(s.stateRoot, "snapshots", sessionID+".json"))
}

func LoadProfile(path string) (Profile, error) {
	data, err := fsutil.ReadFileLimited(path, maxShellConfigBytes)
	if err != nil {
		return Profile{}, err
	}
	var profile Profile
	if err := json.Unmarshal(data, &profile); err != nil {
		return Profile{}, fmt.Errorf("decode bar profile: %w", err)
	}
	profile = profile.Normalize()
	if err := profile.Validate(); err != nil {
		return Profile{}, err
	}
	return profile, nil
}

func (s *Store) Restore(snapshot Snapshot) error {
	if snapshot.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported bar snapshot schema version %d", snapshot.SchemaVersion)
	}
	if snapshot.ConfigPath != "" && snapshot.ConfigPath != s.configPath {
		return fmt.Errorf("bar snapshot targets %q, store targets %q", snapshot.ConfigPath, s.configPath)
	}
	if snapshot.ConfigExists {
		if len(snapshot.Config) == 0 || hash(snapshot.Config) != snapshot.ConfigSHA256 {
			return fmt.Errorf("bar snapshot checksum mismatch")
		}
		mode := fs.FileMode(snapshot.ConfigMode)
		if mode == 0 {
			mode = 0o600
		}
		if current, readErr := fsutil.ReadFileLimited(s.configPath, maxShellConfigBytes); readErr == nil {
			if info, statErr := os.Stat(s.configPath); statErr == nil && info.Mode().Perm() == mode && bytes.Equal(current, snapshot.Config) {
				return s.restoreHiddenToggle(snapshot)
			}
		} else if !os.IsNotExist(readErr) {
			return fmt.Errorf("read current bar config: %w", readErr)
		}
		if err := fsutil.AtomicWriteFile(s.configPath, snapshot.Config, mode); err != nil {
			return err
		}
		return s.restoreHiddenToggle(snapshot)
	}
	if err := fsutil.RemoveFileAndSync(s.configPath); err != nil {
		return err
	}
	return s.restoreHiddenToggle(snapshot)
}

func (s *Store) restoreHiddenToggle(snapshot Snapshot) error {
	if s.hiddenPath == "" || snapshot.HiddenTogglePath == "" {
		return nil
	}
	if snapshot.HiddenTogglePath != s.hiddenPath {
		return fmt.Errorf("bar hidden toggle targets %q, store targets %q", snapshot.HiddenTogglePath, s.hiddenPath)
	}
	if snapshot.HiddenToggleExists {
		if err := fsutil.EnsureDir(filepath.Dir(s.hiddenPath), 0o755); err != nil {
			return err
		}
		file, err := os.OpenFile(s.hiddenPath, os.O_CREATE|os.O_WRONLY, 0o600)
		if err != nil {
			return fmt.Errorf("restore bar hidden toggle: %w", err)
		}
		if err := file.Close(); err != nil {
			return err
		}
		return nil
	}
	return fsutil.RemoveFileAndSync(s.hiddenPath)
}

// Apply merges a profile into shell.json while retaining all fields the
// profile does not own. A theme-owned profile replaces the bar object, but the
// caller must have captured a Snapshot first so Restore remains exact.
func (s *Store) Apply(profile Profile) error {
	profile = profile.Normalize()
	if err := profile.Validate(); err != nil {
		return err
	}
	if profile.Ownership == OwnershipInherit || len(profile.Bar) == 0 {
		return nil
	}
	data, err := fsutil.ReadFileLimited(s.configPath, maxShellConfigBytes)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("read bar config for profile: %w", err)
	}
	if os.IsNotExist(err) {
		data = []byte("{}")
	}
	updated, err := applyProfile(data, profile)
	if err != nil {
		return err
	}
	mode := fs.FileMode(0o600)
	if info, statErr := os.Stat(s.configPath); statErr == nil {
		mode = info.Mode().Perm()
	}
	if bytes.Equal(bytes.TrimSpace(data), bytes.TrimSpace(updated)) {
		return nil
	}
	return fsutil.AtomicWriteFile(s.configPath, updated, mode)
}

// ApplyFromSnapshot derives a theme profile from the session's exact bar
// baseline and commits the result in one shell.json replacement. Preview used
// to Restore(snapshot) and then Apply(profile), which exposed Quickshell to two
// successive configurations and could tear down/recreate a replacement bar
// twice for one Test Live operation.
func (s *Store) ApplyFromSnapshot(snapshot Snapshot, profile Profile) error {
	if snapshot.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported bar snapshot schema version %d", snapshot.SchemaVersion)
	}
	if snapshot.ConfigPath != "" && snapshot.ConfigPath != s.configPath {
		return fmt.Errorf("bar snapshot targets %q, store targets %q", snapshot.ConfigPath, s.configPath)
	}
	profile = profile.Normalize()
	if err := profile.Validate(); err != nil {
		return err
	}
	if profile.Ownership == OwnershipInherit || len(profile.Bar) == 0 {
		return s.Restore(snapshot)
	}

	data := []byte("{}")
	mode := fs.FileMode(0o600)
	if snapshot.ConfigExists {
		if len(snapshot.Config) == 0 || hash(snapshot.Config) != snapshot.ConfigSHA256 {
			return fmt.Errorf("bar snapshot checksum mismatch")
		}
		data = snapshot.Config
		mode = fs.FileMode(snapshot.ConfigMode)
		if mode == 0 {
			mode = 0o600
		}
	}
	updated, err := applyProfile(data, profile)
	if err != nil {
		return err
	}
	current, readErr := fsutil.ReadFileLimited(s.configPath, maxShellConfigBytes)
	if readErr == nil && bytes.Equal(bytes.TrimSpace(current), bytes.TrimSpace(updated)) {
		return s.restoreHiddenToggle(snapshot)
	}
	if readErr != nil && !os.IsNotExist(readErr) {
		return fmt.Errorf("read current bar config: %w", readErr)
	}
	if err := fsutil.AtomicWriteFile(s.configPath, updated, mode); err != nil {
		return err
	}
	return s.restoreHiddenToggle(snapshot)
}

func applyProfile(data []byte, profile Profile) ([]byte, error) {
	var root map[string]json.RawMessage
	if err := json.Unmarshal(data, &root); err != nil {
		return nil, fmt.Errorf("decode shell config: %w", err)
	}
	var existing map[string]json.RawMessage
	if raw := root["bar"]; len(raw) > 0 {
		if err := json.Unmarshal(raw, &existing); err != nil {
			return nil, fmt.Errorf("decode shell bar config: %w", err)
		}
	} else {
		existing = make(map[string]json.RawMessage)
	}
	var incoming map[string]json.RawMessage
	if err := json.Unmarshal(profile.Bar, &incoming); err != nil {
		return nil, fmt.Errorf("decode profile bar: %w", err)
	}
	if profile.Ownership == OwnershipThemeOwned {
		existing = incoming
	} else {
		for key, value := range incoming {
			existing[key] = value
		}
	}
	bar, err := json.Marshal(existing)
	if err != nil {
		return nil, fmt.Errorf("encode effective bar: %w", err)
	}
	root["bar"] = bar
	updated, err := json.MarshalIndent(root, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("encode shell config: %w", err)
	}
	updated = append(updated, '\n')
	return updated, nil
}

func hash(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func validComponent(value string) bool {
	return value != "" && value != "." && value != ".." && filepath.Base(value) == value
}
