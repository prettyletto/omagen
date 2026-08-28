package runtime

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const (
	ManifestFileName = "omagen.runtime.json"
	StateFileName    = "advanced-runtime.json"
	HookFileName     = "omagen-theme-set"
	ManifestVersion  = 1
	StateVersion     = 1
)

// Manifest is a small, data-only declaration inside a generated theme. Its
// presence is the explicit boundary between the native fast path and an
// Omagen-owned runtime path. Native Omarchy ignores this file.
type Manifest struct {
	SchemaVersion   int      `json:"schema_version"`
	Mode            string   `json:"mode"`
	Runtime         string   `json:"runtime"`
	RequiresRuntime bool     `json:"requires_runtime"`
	Features        []string `json:"features,omitempty"`
}

func AdvancedManifest(features ...string) Manifest {
	return Manifest{
		SchemaVersion:   ManifestVersion,
		Mode:            "advanced",
		Runtime:         "pretty.omagen",
		RequiresRuntime: true,
		Features:        append([]string(nil), features...),
	}
}

func (m Manifest) Validate() error {
	if m.SchemaVersion != ManifestVersion {
		return fmt.Errorf("unsupported Omagen runtime manifest schema version %d", m.SchemaVersion)
	}
	if m.Mode != "advanced" {
		return fmt.Errorf("invalid Omagen runtime mode %q", m.Mode)
	}
	if m.Runtime != "pretty.omagen" {
		return fmt.Errorf("invalid Omagen runtime %q", m.Runtime)
	}
	if !m.RequiresRuntime {
		return fmt.Errorf("advanced Omagen runtime manifest must require a runtime")
	}
	if len(m.Features) == 0 {
		return fmt.Errorf("advanced Omagen runtime manifest declares no features")
	}
	seen := make(map[string]struct{}, len(m.Features))
	for _, feature := range m.Features {
		if !validIdentifier(feature) {
			return fmt.Errorf("invalid advanced runtime feature %q", feature)
		}
		if _, exists := seen[feature]; exists {
			return fmt.Errorf("duplicate advanced runtime feature %q", feature)
		}
		seen[feature] = struct{}{}
	}
	return nil
}

type State struct {
	SchemaVersion            int                      `json:"schema_version"`
	Installed                bool                     `json:"installed"`
	Prompted                 bool                     `json:"prompted"`
	HookPath                 string                   `json:"hook_path,omitempty"`
	InstalledAt              time.Time                `json:"installed_at,omitempty"`
	LastFallbackNotification string                   `json:"last_fallback_notification,omitempty"`
	LastActivation           *RuntimeActivationResult `json:"last_activation,omitempty"`
}

func (s State) Normalize() State {
	if s.SchemaVersion == 0 {
		s.SchemaVersion = StateVersion
	}
	return s
}

func (s State) Validate() error {
	if s.SchemaVersion != StateVersion {
		return fmt.Errorf("unsupported advanced runtime state schema version %d", s.SchemaVersion)
	}
	if s.LastActivation != nil {
		if err := s.LastActivation.Validate(); err != nil {
			return fmt.Errorf("validate last runtime activation: %w", err)
		}
	}
	return nil
}

type Status struct {
	Installed       bool                     `json:"installed"`
	HookPath        string                   `json:"hook_path"`
	ActiveTheme     string                   `json:"active_theme,omitempty"`
	AdvancedTheme   bool                     `json:"advanced_theme"`
	RuntimeRequired bool                     `json:"runtime_required"`
	PromptRequired  bool                     `json:"prompt_required"`
	RuntimeState    FeatureState             `json:"runtime_state,omitempty"`
	LastActivation  *RuntimeActivationResult `json:"last_activation,omitempty"`
}

func Paths() (home, hookPath, statePath string, err error) {
	home, err = os.UserHomeDir()
	if err != nil {
		return "", "", "", fmt.Errorf("resolve home directory: %w", err)
	}
	configHome, err := os.UserConfigDir()
	if err != nil {
		return "", "", "", fmt.Errorf("resolve config directory: %w", err)
	}
	stateRoot, err := fsutil.UserStateDir("omagen")
	if err != nil {
		return "", "", "", err
	}
	return home,
		filepath.Join(configHome, "omarchy", "hooks", "theme-set.d", HookFileName),
		filepath.Join(stateRoot, StateFileName),
		nil
}

func LoadState() (State, error) {
	_, _, path, err := Paths()
	if err != nil {
		return State{}, err
	}
	data, err := fsutil.ReadFileLimited(path, fsutil.MaxStateFileBytes)
	if os.IsNotExist(err) {
		return State{SchemaVersion: StateVersion}, nil
	}
	if err != nil {
		return State{}, fmt.Errorf("read advanced runtime state: %w", err)
	}
	var state State
	if err := json.Unmarshal(data, &state); err != nil {
		return State{}, fmt.Errorf("decode advanced runtime state: %w", err)
	}
	state = state.Normalize()
	if err := state.Validate(); err != nil {
		return State{}, err
	}
	return state, nil
}

func SaveState(state State) error {
	_, _, path, err := Paths()
	if err != nil {
		return err
	}
	state = state.Normalize()
	if err := state.Validate(); err != nil {
		return err
	}
	return fsutil.AtomicWriteJSON(path, state, 0o600)
}

func ReadManifest(themeRoot string) (Manifest, bool, error) {
	if filepath.IsAbs(themeRoot) == false || filepath.Clean(themeRoot) != themeRoot {
		return Manifest{}, false, fmt.Errorf("theme root must be a clean absolute path")
	}
	path := filepath.Join(themeRoot, ManifestFileName)
	data, err := fsutil.ReadFileLimited(path, fsutil.MaxStateFileBytes)
	if os.IsNotExist(err) {
		return Manifest{}, false, nil
	}
	if err != nil {
		return Manifest{}, false, fmt.Errorf("read Omagen runtime manifest: %w", err)
	}
	var manifest Manifest
	if err := json.Unmarshal(data, &manifest); err != nil {
		return Manifest{}, false, fmt.Errorf("decode Omagen runtime manifest: %w", err)
	}
	if err := manifest.Validate(); err != nil {
		return Manifest{}, false, err
	}
	return manifest, true, nil
}

func WriteManifest(themeRoot string, manifest Manifest) error {
	if err := manifest.Validate(); err != nil {
		return err
	}
	return fsutil.AtomicWriteJSON(filepath.Join(themeRoot, ManifestFileName), manifest, 0o644)
}

func IsOwnedHook(path string) bool {
	data, err := os.ReadFile(path)
	return err == nil && strings.HasPrefix(string(data), "#!/bin/sh\n# Omagen Advanced Runtime hook\n")
}
