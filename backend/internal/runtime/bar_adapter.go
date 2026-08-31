package runtime

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const (
	barProfileFile      = "omagen.bar.json"
	barSpecFile         = "omagen.bar.spec.json"
	activeBarSnapshotID = "runtime-bar-active"
)

// BarAdapter connects the theme-set hook to the existing reversible Bar
// profile store. It does not render a bar or take over Quattro's widget
// layout; the installed Quickshell reader remains responsible for that.
type BarAdapter struct {
	store *barprofile.Store
}

func NewBarAdapter(store *barprofile.Store) (*BarAdapter, error) {
	if store == nil {
		return nil, fmt.Errorf("bar runtime adapter store is nil")
	}
	return &BarAdapter{store: store}, nil
}

func (a *BarAdapter) Contract() FeatureContract {
	return FeatureContract{
		Feature:          FeatureBar,
		Owner:            OwnerQuattro,
		Durable:          true,
		NativeFallback:   true,
		NeedsShellReload: true,
	}
}

func (a *BarAdapter) Preflight(_ context.Context, request ActivationRequest) error {
	if a == nil || a.store == nil {
		return fmt.Errorf("bar runtime adapter is nil")
	}
	if _, _, err := readCompiledBarSpec(request.ThemeRoot); err != nil {
		return err
	}
	profile, exists, err := readBarProfile(request.ThemeRoot)
	if err != nil {
		return err
	}
	if !exists || profile.Ownership == barprofile.OwnershipInherit || len(profile.Bar) == 0 {
		return nil
	}
	if _, _, err := a.loadBaseline(request.ThemeName); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("validate existing bar snapshot: %w", err)
	}
	return nil
}

func (a *BarAdapter) Activate(_ context.Context, request ActivationRequest) (FeatureResult, error) {
	if a == nil || a.store == nil {
		return FeatureResult{}, fmt.Errorf("bar runtime adapter is nil")
	}
	compiled, hasSpec, err := readCompiledBarSpec(request.ThemeRoot)
	if err != nil {
		return FeatureResult{}, err
	}
	profile, hasProfile, err := readBarProfile(request.ThemeRoot)
	if err != nil {
		return FeatureResult{}, err
	}
	if !hasProfile || profile.Ownership == barprofile.OwnershipInherit || profile.Implementation == barprofile.ImplementationNative {
		message := "native Quattro owns this bar; no runtime mutation is required"
		if hasSpec && compiled.Native {
			message = "native Quattro consumed the compiled bar spec"
		}
		return FeatureResult{Feature: FeatureBar, Owner: OwnerQuattro, State: FeatureSkipped, Message: message}, nil
	}
	if len(profile.Bar) == 0 {
		return FeatureResult{
			Feature: FeatureBar,
			Owner:   OwnerQuattro,
			State:   FeatureReady,
			Message: "Quickshell consumes the theme-scoped bar profile and spec",
		}, nil
	}

	snapshot, created, err := a.ensureActiveBaseline(request.ThemeName)
	if err != nil {
		return FeatureResult{}, err
	}
	if err := a.store.ApplyFromSnapshot(snapshot, profile); err != nil {
		if created {
			_ = a.store.DeleteSnapshot(activeBarSnapshotID)
		}
		return FeatureResult{}, fmt.Errorf("apply theme bar profile: %w", err)
	}
	_ = a.store.DeleteSnapshot(barSnapshotID(request.ThemeName))
	return FeatureResult{
		Feature:    FeatureBar,
		Owner:      OwnerQuattro,
		State:      FeatureReady,
		Message:    "theme bar profile applied from the stable native baseline",
		OwnedPaths: []string{a.activeSnapshotPath()},
	}, nil
}

func (a *BarAdapter) Deactivate(_ context.Context, request DeactivationRequest) (FeatureResult, error) {
	if a == nil || a.store == nil {
		return FeatureResult{}, fmt.Errorf("bar runtime adapter is nil")
	}
	legacyID := barSnapshotID(request.ThemeName)
	if request.Preserves(FeatureBar) {
		_ = a.store.DeleteSnapshot(legacyID)
		return FeatureResult{
			Feature: FeatureBar,
			Owner:   OwnerQuattro,
			State:   FeatureInactive,
			Message: "replacement bar preserved for the next advanced theme",
		}, nil
	}
	snapshot, _, err := a.loadBaseline(request.ThemeName)
	if os.IsNotExist(err) {
		return FeatureResult{Feature: FeatureBar, Owner: OwnerQuattro, State: FeatureInactive, Message: "no backend-owned bar snapshot exists"}, nil
	}
	if err != nil {
		return FeatureResult{}, fmt.Errorf("load bar baseline: %w", err)
	}
	if err := a.store.Restore(snapshot); err != nil {
		return FeatureResult{}, fmt.Errorf("restore bar baseline: %w", err)
	}
	if err := a.store.DeleteSnapshot(activeBarSnapshotID); err != nil {
		return FeatureResult{}, fmt.Errorf("delete restored bar baseline: %w", err)
	}
	_ = a.store.DeleteSnapshot(legacyID)
	return FeatureResult{
		Feature:    FeatureBar,
		Owner:      OwnerQuattro,
		State:      FeatureInactive,
		Message:    "native bar baseline restored",
		OwnedPaths: []string{a.activeSnapshotPath()},
	}, nil
}

// PrepareTransition updates a mounted replacement bar directly from the
// stable native baseline. Quattro therefore never observes an intermediate
// shell.json without pretty.omagen.bar during an advanced-to-advanced switch.
func (a *BarAdapter) PrepareTransition(fromTheme string, request ActivationRequest) error {
	if a == nil || a.store == nil {
		return fmt.Errorf("bar runtime adapter is nil")
	}
	profile, exists, err := readBarProfile(request.ThemeRoot)
	if err != nil {
		return err
	}
	if !exists || profile.Implementation != barprofile.ImplementationReplacement || profile.Ownership == barprofile.OwnershipInherit || len(profile.Bar) == 0 {
		return fmt.Errorf("target theme does not provide a compatible replacement bar")
	}
	snapshot, _, err := a.ensureActiveBaseline(fromTheme)
	if err != nil {
		return err
	}
	if err := a.store.ApplyFromSnapshot(snapshot, profile); err != nil {
		return fmt.Errorf("prepare replacement bar handoff: %w", err)
	}
	return nil
}

func (a *BarAdapter) activeSnapshotPath() string {
	return filepath.Join(a.store.StateRoot(), "snapshots", activeBarSnapshotID+".json")
}

func (a *BarAdapter) loadBaseline(themeName string) (barprofile.Snapshot, string, error) {
	snapshot, err := a.store.LoadSnapshot(activeBarSnapshotID)
	if err == nil {
		return snapshot, activeBarSnapshotID, nil
	}
	if !os.IsNotExist(err) {
		return barprofile.Snapshot{}, "", err
	}
	legacyID := barSnapshotID(themeName)
	snapshot, err = a.store.LoadSnapshot(legacyID)
	return snapshot, legacyID, err
}

func (a *BarAdapter) ensureActiveBaseline(themeName string) (barprofile.Snapshot, bool, error) {
	snapshot, sourceID, err := a.loadBaseline(themeName)
	if err == nil {
		if sourceID != activeBarSnapshotID {
			if err := a.store.SaveSnapshot(activeBarSnapshotID, snapshot); err != nil {
				return barprofile.Snapshot{}, false, fmt.Errorf("migrate bar baseline: %w", err)
			}
		}
		return snapshot, sourceID != activeBarSnapshotID, nil
	}
	if !os.IsNotExist(err) {
		return barprofile.Snapshot{}, false, fmt.Errorf("load bar baseline: %w", err)
	}
	snapshot, err = a.store.Capture(themeName)
	if err != nil {
		return barprofile.Snapshot{}, false, fmt.Errorf("capture bar baseline: %w", err)
	}
	if err := a.store.SaveSnapshot(activeBarSnapshotID, snapshot); err != nil {
		return barprofile.Snapshot{}, false, fmt.Errorf("save bar baseline: %w", err)
	}
	return snapshot, true, nil
}

func readBarProfile(themeRoot string) (barprofile.Profile, bool, error) {
	path := filepath.Join(themeRoot, barProfileFile)
	profile, err := barprofile.LoadProfile(path)
	if os.IsNotExist(err) {
		return barprofile.Profile{}, false, nil
	}
	if err != nil {
		return barprofile.Profile{}, false, fmt.Errorf("read bar profile: %w", err)
	}
	return profile, true, nil
}

func readCompiledBarSpec(themeRoot string) (bar.CompileResult, bool, error) {
	path := filepath.Join(themeRoot, barSpecFile)
	data, err := fsutil.ReadFileLimited(path, fsutil.MaxStateFileBytes)
	if os.IsNotExist(err) {
		return bar.CompileResult{}, false, nil
	}
	if err != nil {
		return bar.CompileResult{}, false, fmt.Errorf("read bar spec: %w", err)
	}
	var compiled bar.CompileResult
	if err := json.Unmarshal(data, &compiled); err != nil {
		return bar.CompileResult{}, false, fmt.Errorf("decode bar spec: %w", err)
	}
	expected, err := bar.Compile(compiled.Spec)
	if err != nil {
		return bar.CompileResult{}, false, fmt.Errorf("validate bar spec: %w", err)
	}
	if expected.Engine != compiled.Engine || expected.Native != compiled.Native || expected.Capabilities != compiled.Capabilities {
		return bar.CompileResult{}, false, fmt.Errorf("bar spec compiler result does not match its declared capabilities")
	}
	return compiled, true, nil
}

func barSnapshotID(themeName string) string {
	return "runtime-bar-" + themeName
}

// SeedBarSnapshot carries a session's pre-preview bar baseline into the stable
// runtime namespace. Apply uses this only when a preview has already
// materialized the bar profile; the post-commit hook can then reuse the true
// baseline instead of capturing the themed config as if it were original.
func SeedBarSnapshot(store *barprofile.Store, themeName string, snapshot barprofile.Snapshot) error {
	if store == nil {
		return fmt.Errorf("bar runtime adapter store is nil")
	}
	if !validThemeName(themeName) {
		return fmt.Errorf("invalid theme name %q", themeName)
	}
	id := activeBarSnapshotID
	if _, err := store.LoadSnapshot(id); err == nil {
		return nil
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("inspect existing runtime bar snapshot: %w", err)
	}
	return store.SaveSnapshot(id, snapshot)
}
