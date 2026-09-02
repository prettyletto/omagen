package runtime

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const shellConfigFile = "shell.toml"

// ShellAdapter represents the Quickshell side of the advanced contract. The
// native Omarchy reader still owns shell.toml; this adapter validates the
// generated input and reports whether the theme contains Shell-owned values.
// It deliberately does not install a second shell or mutate user config.
type ShellAdapter struct{}

func NewShellAdapter() (*ShellAdapter, error) {
	return &ShellAdapter{}, nil
}

func (a *ShellAdapter) Contract() FeatureContract {
	return FeatureContract{
		Feature:          FeatureShell,
		Owner:            OwnerQuickshell,
		Durable:          false,
		NativeFallback:   true,
		NeedsShellReload: true,
	}
}

func (a *ShellAdapter) Preflight(_ context.Context, request ActivationRequest) error {
	if a == nil {
		return fmt.Errorf("shell runtime adapter is nil")
	}
	_, _, err := readShellConfig(request.ThemeRoot)
	return err
}

func (a *ShellAdapter) Activate(_ context.Context, request ActivationRequest) (FeatureResult, error) {
	if a == nil {
		return FeatureResult{}, fmt.Errorf("shell runtime adapter is nil")
	}
	_, hasShellValues, err := readShellConfig(request.ThemeRoot)
	if err != nil {
		return FeatureResult{}, err
	}
	if !hasShellValues {
		return FeatureResult{
			Feature: FeatureShell,
			Owner:   OwnerQuickshell,
			State:   FeatureSkipped,
			Message: "native Quickshell shell defaults remain authoritative",
		}, nil
	}
	return FeatureResult{
		Feature: FeatureShell,
		Owner:   OwnerQuickshell,
		State:   FeatureReady,
		Message: "native Quickshell consumed the generated Shell preset and tokens",
	}, nil
}

func (a *ShellAdapter) Deactivate(_ context.Context, _ DeactivationRequest) (FeatureResult, error) {
	if a == nil {
		return FeatureResult{}, fmt.Errorf("shell runtime adapter is nil")
	}
	return FeatureResult{
		Feature: FeatureShell,
		Owner:   OwnerQuickshell,
		State:   FeatureInactive,
		Message: "Shell owns no persistent runtime state; native theme fallback remains active",
	}, nil
}

// readShellConfig distinguishes Shell content from a Bar-only shell.toml.
// Bar remains a separate structural feature, so a theme that only changes Bar
// must not be reported as having an active Shell composition.
func readShellConfig(themeRoot string) ([]byte, bool, error) {
	data, err := fsutil.ReadFileLimited(filepath.Join(themeRoot, shellConfigFile), fsutil.MaxStateFileBytes)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, false, nil
		}
		return nil, false, fmt.Errorf("read shell config: %w", err)
	}

	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section := strings.TrimSpace(strings.TrimSuffix(strings.TrimPrefix(line, "["), "]"))
			if section != "" && section != "bar" {
				return data, true, nil
			}
		}
	}
	return data, false, nil
}
