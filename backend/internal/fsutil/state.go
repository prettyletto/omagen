package fsutil

import (
	"fmt"
	"os"
	"path/filepath"
)

func UserStateDir(app string) (string, error) {
	if app == "" || filepath.Base(app) != app {
		return "", fmt.Errorf("invalid state application name %q", app)
	}
	if stateHome := os.Getenv("XDG_STATE_HOME"); stateHome != "" && filepath.IsAbs(stateHome) {
		return filepath.Join(stateHome, app), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolve home directory: %w", err)
	}
	return filepath.Join(home, ".local", "state", app), nil
}
