package runtime

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const themeSetHook = `#!/bin/sh
# Omagen Advanced Runtime hook
# Installed with explicit user consent. It is deliberately a post-theme hook:
# native Omarchy applies colors.toml and shell.toml before this is reached.
set -eu

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
omagen_bin="${OMAGEN_RUNTIME_BIN:-$config_home/omarchy/plugins/pretty.omagen/bin/omagen}"
[ -x "$omagen_bin" ] || exit 0
exec "$omagen_bin" runtime theme-set "${1:-}"
`

type InstallResult struct {
	Installed bool   `json:"installed"`
	HookPath  string `json:"hook_path"`
}

type ThemeSetResult struct {
	Theme             string                   `json:"theme"`
	Advanced          bool                     `json:"advanced"`
	RuntimeReady      bool                     `json:"runtime_ready"`
	NativeOnly        bool                     `json:"native_only"`
	ActivationPending bool                     `json:"activation_pending"`
	RuntimeState      FeatureState             `json:"runtime_state,omitempty"`
	RuntimeError      string                   `json:"runtime_error,omitempty"`
	Activation        *RuntimeActivationResult `json:"activation,omitempty"`
	Deactivation      *RuntimeActivationResult `json:"deactivation,omitempty"`
}

type FallbackStatus struct {
	Required          bool   `json:"required"`
	Installed         bool   `json:"installed"`
	NativeOnly        bool   `json:"native_only"`
	NotificationShown bool   `json:"notification_shown"`
	NotificationError string `json:"notification_error,omitempty"`
}

func InspectStatus(activeThemeRoot, activeTheme string) (Status, error) {
	_, hookPath, _, err := Paths()
	if err != nil {
		return Status{}, err
	}
	state, err := LoadState()
	if err != nil {
		return Status{}, err
	}
	installed := state.Installed && IsOwnedHook(hookPath)
	manifest := Manifest{}
	advanced := false
	if strings.TrimSpace(activeThemeRoot) != "" {
		var err error
		manifest, advanced, err = ReadManifest(activeThemeRoot)
		if err != nil {
			return Status{}, err
		}
	}
	return Status{
		Installed:       installed,
		HookPath:        hookPath,
		ActiveTheme:     activeTheme,
		AdvancedTheme:   advanced,
		RuntimeRequired: advanced && manifest.RequiresRuntime,
		PromptRequired:  !installed && !state.Prompted,
		RuntimeState:    activationState(state.LastActivation),
		LastActivation:  state.LastActivation,
	}, nil
}

func Install() (InstallResult, error) {
	_, hookPath, _, err := Paths()
	if err != nil {
		return InstallResult{}, err
	}
	_, readErr := os.ReadFile(hookPath)
	hadOwnedHook := readErr == nil && IsOwnedHook(hookPath)
	if existing, readErr := os.ReadFile(hookPath); readErr == nil && !strings.HasPrefix(string(existing), "#!/bin/sh\n# Omagen Advanced Runtime hook\n") {
		return InstallResult{}, fmt.Errorf("refusing to replace an existing non-Omagen theme-set hook: %s", hookPath)
	}
	if err := fsutil.AtomicWriteFile(hookPath, []byte(themeSetHook), 0o700); err != nil {
		return InstallResult{}, fmt.Errorf("install advanced runtime hook: %w", err)
	}
	state, err := LoadState()
	if err != nil {
		return InstallResult{}, err
	}
	state.Installed = true
	state.Prompted = true
	state.HookPath = hookPath
	state.InstalledAt = time.Now().UTC()
	if err := SaveState(state); err != nil {
		if !hadOwnedHook {
			_ = fsutil.RemoveFileAndSync(hookPath)
		}
		return InstallResult{}, fmt.Errorf("save advanced runtime state: %w", err)
	}
	return InstallResult{Installed: true, HookPath: hookPath}, nil
}

func DismissPrompt() error {
	state, err := LoadState()
	if err != nil {
		return err
	}
	state.Prompted = true
	return SaveState(state)
}

func ThemeSet(themeRoot, themeName string) (ThemeSetResult, error) {
	manifest, advanced, err := ReadManifest(themeRoot)
	if err != nil {
		return ThemeSetResult{}, err
	}
	_, hookPath, _, err := Paths()
	if err != nil {
		return ThemeSetResult{}, err
	}
	state, err := LoadState()
	if err != nil {
		return ThemeSetResult{}, err
	}
	result := ThemeSetResult{Theme: themeName, Advanced: advanced, NativeOnly: true}
	if !advanced {
		result.RuntimeState = FeatureInactive
	}
	if advanced && (!state.Installed || !IsOwnedHook(hookPath)) {
		result.RuntimeState = FeatureDegraded
		result.RuntimeError = "advanced runtime is not installed; native theme files remain active"
		return result, nil
	}

	registry, err := NewDefaultAdapterRegistry()
	if err != nil {
		return ThemeSetResult{}, err
	}
	coordinator, err := NewRuntimeCoordinator(registry)
	if err != nil {
		return ThemeSetResult{}, err
	}
	if err := withRuntimeLock(func() error {
		currentState, err := LoadState()
		if err != nil {
			result.RuntimeError = err.Error()
			result.RuntimeState = FeatureDegraded
			return nil
		}
		// A native theme must deactivate any previous advanced activation even
		// when it reuses the same name. This matters when an older runtime
		// contract recorded a degraded activation and the theme was later
		// regenerated without its advanced manifest.
		if currentState.LastActivation != nil && (currentState.LastActivation.Theme != themeName || !advanced) {
			deactivation, deactivationErr := coordinator.Deactivate(context.Background(), DeactivationRequest{
				ThemeName: currentState.LastActivation.Theme,
				Reason:    "theme-set switched away from the advanced theme",
			})
			result.Deactivation = &deactivation
			if deactivationErr != nil {
				result.RuntimeError = deactivationErr.Error()
				result.RuntimeState = FeatureFailed
				return nil
			}
			if deactivation.State == FeatureFailed {
				result.RuntimeError = "previous advanced runtime could not be fully deactivated"
				result.RuntimeState = FeatureFailed
				return nil
			}
			currentState.LastActivation = nil
		}
		if !advanced {
			result.RuntimeState = FeatureInactive
			return nil
		}

		activation, activationErr := coordinator.Activate(context.Background(), ActivationRequest{
			ThemeRoot: themeRoot,
			ThemeName: themeName,
			Manifest:  manifest,
		})
		result.Activation = &activation
		if activationErr != nil {
			result.RuntimeError = activationErr.Error()
			result.RuntimeState = FeatureFailed
			return nil
		}
		result.RuntimeState = activation.State
		result.RuntimeReady = activation.State == FeatureReady
		result.NativeOnly = !result.RuntimeReady
		result.ActivationPending = activation.State == FeaturePending
		return nil
	}); err != nil {
		return ThemeSetResult{}, err
	}
	return result, nil
}

func activationState(result *RuntimeActivationResult) FeatureState {
	if result == nil {
		return FeatureInactive
	}
	return result.State
}

func NotifyNativeFallback(themeName string) error {
	if strings.TrimSpace(themeName) == "" {
		return fmt.Errorf("theme name is empty")
	}
	if _, err := exec.LookPath("omarchy-notification-send"); err != nil {
		return fmt.Errorf("Omarchy notification sender is unavailable: %w", err)
	}
	description := fmt.Sprintf("%s includes advanced Omagen styling. Colors and native shell settings were applied. Install Omagen to enable the complete theme.", themeName)
	command := exec.Command(
		"omarchy-notification-send",
		"--app-name", "Omagen",
		"--urgency", "normal",
		"--glyph", "󰏘",
		"Native theme applied",
		description,
		"--exec", "omarchy-shell", "shell", "summon", "pretty.omagen", `{"action":"advanced-setup"}`,
	)
	if output, err := command.CombinedOutput(); err != nil {
		return fmt.Errorf("send native fallback notification: %w: %s", err, strings.TrimSpace(string(output)))
	}
	return nil
}

// CheckAndNotifyFallback is deliberately best-effort for the notification
// itself. A missing desktop notification service must never turn a successful
// native theme application into a failed Apply transaction.
func CheckAndNotifyFallback(themeRoot, themeName string) (FallbackStatus, error) {
	manifest, advanced, err := ReadManifest(themeRoot)
	if err != nil {
		return FallbackStatus{}, err
	}
	if !advanced || !manifest.RequiresRuntime {
		return FallbackStatus{}, nil
	}
	_, hookPath, _, err := Paths()
	if err != nil {
		return FallbackStatus{}, err
	}
	state, err := LoadState()
	if err != nil {
		return FallbackStatus{Required: true, NativeOnly: true}, err
	}
	installed := state.Installed && IsOwnedHook(hookPath)
	status := FallbackStatus{Required: true, Installed: installed, NativeOnly: !installed}
	if installed || state.LastFallbackNotification == themeName {
		return status, nil
	}
	if err := NotifyNativeFallback(themeName); err != nil {
		status.NotificationError = err.Error()
		return status, nil
	}
	status.NotificationShown = true
	state.LastFallbackNotification = themeName
	if err := SaveState(state); err != nil {
		status.NotificationError = fmt.Sprintf("record fallback notification: %v", err)
		return status, nil
	}
	return status, nil
}

func ActiveThemePaths() (themeRoot, themeName string, err error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", "", fmt.Errorf("resolve home directory: %w", err)
	}
	currentRoot := filepath.Join(home, ".local", "state", "omarchy", "current")
	data, err := fsutil.ReadFileLimited(filepath.Join(currentRoot, "theme.name"), 4096)
	if err != nil {
		return "", "", fmt.Errorf("read active theme name: %w", err)
	}
	themeName = strings.TrimSpace(string(data))
	if themeName == "" || filepath.Base(themeName) != themeName {
		return "", "", fmt.Errorf("active theme name is invalid")
	}
	return filepath.Join(currentRoot, "theme"), themeName, nil
}
