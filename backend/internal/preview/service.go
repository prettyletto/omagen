package preview

import (
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/protocol"
	"github.com/prettyletto/omagen/backend/internal/runtime"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

const previewThemePrefix = "omagen-preview-"

type ThemeApplier interface {
	ApplyThemePreview(themeName, logPath string) (pid int, alreadyActive bool, err error)
}

type policyAwareThemeApplier interface {
	ApplyThemePreviewWithPolicy(themeName, logPath, retintRun, retintSkip string) (pid int, alreadyActive bool, err error)
}

type optionsAwareThemeApplier interface {
	ApplyThemePreviewWithOptions(themeName, logPath, retintRun, retintSkip, scope, waitMode string, allowTrustedHooks bool) (pid int, alreadyActive bool, err error)
}

type nativeStateVerifier interface {
	VerifyNativeState(expectedTheme string) (string, error)
}

type Service struct {
	sessions       *session.Store
	applier        ThemeApplier
	userThemesRoot string
	bar            *barprofile.Store
}

func NewService(sessions *session.Store, applier ThemeApplier, barStores ...*barprofile.Store) (*Service, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("resolve user home: %w", err)
	}
	service := newServiceWithThemeRoot(sessions, applier, filepath.Join(home, ".config", "omarchy", "themes"))
	if len(barStores) > 0 {
		service.bar = barStores[0]
	}
	return service, nil
}

func newServiceWithThemeRoot(sessions *session.Store, applier ThemeApplier, root string) *Service {
	return &Service{sessions: sessions, applier: applier, userThemesRoot: root}
}

func (s *Service) applyBarProfile(candidate string, record session.Record) (bool, error) {
	if s.bar == nil {
		return false, nil
	}
	if record.BarSnapshot != nil {
		snapshot, err := s.bar.LoadSnapshot(record.SessionID)
		if err != nil {
			return false, fmt.Errorf("load bar baseline: %w", err)
		}
		if err := s.bar.Restore(snapshot); err != nil {
			return false, fmt.Errorf("restore bar baseline: %w", err)
		}
	}
	profile, err := barprofile.LoadProfile(filepath.Join(candidate, "omagen.bar.json"))
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, s.bar.Apply(profile)
}

func (s *Service) Apply(request Request) (result Result, err error) {
	if err := validateComponent("session id", request.SessionID); err != nil {
		return Result{}, err
	}
	if err := validateComponent("generation id", request.GenerationID); err != nil {
		return Result{}, err
	}
	variant, err := generation.ParseVariant(string(request.Variant))
	if err != nil {
		return Result{}, err
	}
	request.Variant = variant
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return Result{}, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer func() {
		if closeErr := lock.Close(); closeErr != nil {
			err = errors.Join(err, fmt.Errorf("release session mutation lock: %w", closeErr))
		}
	}()
	return s.applyLocked(request)
}

// ApplyCheckpoint reapplies an already-materialized preview candidate without
// creating a new checkpoint. The caller owns protocol cursor movement and can
// therefore commit the cursor only after the native mutation succeeds.
func (s *Service) ApplyCheckpoint(request Request) (result Result, err error) {
	if err := validateComponent("session id", request.SessionID); err != nil {
		return Result{}, err
	}
	if err := validateComponent("generation id", request.GenerationID); err != nil {
		return Result{}, err
	}
	variant, err := generation.ParseVariant(string(request.Variant))
	if err != nil {
		return Result{}, err
	}
	request.Variant = variant
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return Result{}, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer func() {
		if closeErr := lock.Close(); closeErr != nil {
			err = errors.Join(err, fmt.Errorf("release session mutation lock: %w", closeErr))
		}
	}()

	active, exists, err := s.sessions.LoadActive()
	if err != nil {
		return Result{}, fmt.Errorf("load active session: %w", err)
	}
	if !exists || active.SessionID != request.SessionID {
		return Result{}, session.ErrSessionNotActive
	}
	record, err := s.sessions.Load(request.SessionID)
	if err != nil {
		return Result{}, fmt.Errorf("load session: %w", err)
	}
	if record.ApplyPhase != session.ApplyPhaseNone {
		return Result{}, fmt.Errorf("%w: cannot navigate while phase is %q", session.ErrApplyInProgress, record.ApplyPhase)
	}
	candidate, err := s.candidateDir(request)
	if err != nil {
		return Result{}, err
	}
	if err := s.cleanupBrokenAliasesLocked(); err != nil {
		return Result{}, fmt.Errorf("cleanup stale preview aliases: %w", err)
	}
	themeName := previewThemeName(request)
	if err := s.ensureThemeAlias(themeName, candidate); err != nil {
		return Result{}, fmt.Errorf("publish preview theme: %w", err)
	}
	logPath, err := s.newPreviewLog(request)
	if err != nil {
		return Result{}, err
	}
	pid, already, err := s.applyTheme(themeName, logPath, request)
	if err != nil {
		return Result{}, fmt.Errorf("reapply preview theme %s: %w", themeName, err)
	}
	if verifier, ok := s.applier.(nativeStateVerifier); ok {
		if _, err := verifier.VerifyNativeState(themeName); err != nil {
			return Result{}, fmt.Errorf("verify reapplied preview theme %s: %w", themeName, err)
		}
	}
	if _, err := s.applyBarProfile(candidate, record); err != nil {
		return Result{}, fmt.Errorf("apply themed bar profile: %w", err)
	}
	applyStyleOverrides(&record, request.Styles)
	record.PreviewVariant = string(request.Variant)
	if err := s.sessions.Save(record); err != nil {
		return Result{}, fmt.Errorf("persist preview navigation: %w", err)
	}
	return Result{
		SessionID: request.SessionID, GenerationID: request.GenerationID,
		Variant: request.Variant, ThemeName: themeName, PID: pid,
		AlreadyActive: already, LogPath: logPath,
	}, nil
}

func (s *Service) applyLocked(request Request) (result Result, returnErr error) {
	active, exists, err := s.sessions.LoadActive()
	if err != nil {
		return Result{}, fmt.Errorf("load active session: %w", err)
	}
	if !exists {
		return Result{}, fmt.Errorf("%w: no Omagen session is active", session.ErrSessionNotActive)
	}
	if active.SessionID != request.SessionID {
		return Result{}, fmt.Errorf("%w: active=%s requested=%s", session.ErrSessionNotActive, active.SessionID, request.SessionID)
	}
	record, err := s.sessions.Load(request.SessionID)
	if err != nil {
		return Result{}, fmt.Errorf("load session: %w", err)
	}
	if record.ApplyPhase != session.ApplyPhaseNone {
		return Result{}, fmt.Errorf("%w: cannot preview while phase is %q", session.ErrApplyInProgress, record.ApplyPhase)
	}
	journal, protocolPaths, err := protocol.OpenForSession(s.sessions.StateRoot(), request.SessionID)
	if err != nil {
		return Result{}, fmt.Errorf("open preview protocol: %w", err)
	}
	operation, err := journal.StartOperation(protocol.OperationInput{
		Name:         "preview",
		SessionID:    request.SessionID,
		GenerationID: request.GenerationID,
		Variant:      string(request.Variant),
	})
	if err != nil {
		return Result{}, fmt.Errorf("start preview protocol: %w", err)
	}
	defer func() {
		if returnErr != nil {
			_, _ = journal.CompleteOperation(operation.ID, protocol.StatusFailed, returnErr.Error(), "preview operation failed")
		}
	}()
	candidate, err := s.candidateDir(request)
	if err != nil {
		return Result{}, err
	}
	stageOperation, err := journal.StartOperation(protocol.OperationInput{
		ParentID:     operation.ID,
		Name:         "stage candidate",
		SessionID:    request.SessionID,
		GenerationID: request.GenerationID,
		Variant:      string(request.Variant),
	})
	if err != nil {
		return Result{}, fmt.Errorf("start preview staging protocol: %w", err)
	}
	if err := s.cleanupBrokenAliasesLocked(); err != nil {
		return Result{}, fmt.Errorf("cleanup stale preview aliases: %w", err)
	}
	themeName := previewThemeName(request)
	if err := s.ensureThemeAlias(themeName, candidate); err != nil {
		_, _ = journal.CompleteOperation(stageOperation.ID, protocol.StatusFailed, err.Error(), "preview alias was not published")
		return Result{}, fmt.Errorf("publish preview theme: %w", err)
	}
	if _, err := journal.Progress(operation.ID, "candidate staged", "preview alias published", nil); err != nil {
		return Result{}, fmt.Errorf("record preview staging: %w", err)
	}
	if _, err := journal.CompleteOperation(stageOperation.ID, protocol.StatusSucceeded, "candidate staged", "preview alias published"); err != nil {
		return Result{}, fmt.Errorf("complete preview staging protocol: %w", err)
	}
	logPath, err := s.newPreviewLog(request)
	if err != nil {
		return Result{}, err
	}
	driverOperation, err := journal.StartOperation(protocol.OperationInput{
		ParentID:     operation.ID,
		Name:         "native theme driver",
		SessionID:    request.SessionID,
		GenerationID: request.GenerationID,
		Variant:      string(request.Variant),
	})
	if err != nil {
		return Result{}, fmt.Errorf("start preview driver protocol: %w", err)
	}
	pid, already, err := s.applyTheme(themeName, logPath, request)
	if err != nil {
		_, _ = journal.CompleteOperation(driverOperation.ID, protocol.StatusFailed, err.Error(), "native theme driver failed")
		return Result{}, fmt.Errorf("apply preview theme %s: %w", themeName, err)
	}
	driverEvidence := "theme promotion and theme-set lock verified"
	if verifier, ok := s.applier.(nativeStateVerifier); ok {
		driverEvidence, err = verifier.VerifyNativeState(themeName)
		if err != nil {
			_, _ = journal.CompleteOperation(driverOperation.ID, protocol.StatusFailed, err.Error(), "native reader verification failed")
			return Result{}, fmt.Errorf("verify preview theme %s: %w", themeName, err)
		}
	}
	if _, err := s.applyBarProfile(candidate, record); err != nil {
		return Result{}, fmt.Errorf("apply themed bar profile: %w", err)
	}
	if _, err := journal.CompleteOperation(driverOperation.ID, protocol.StatusSucceeded, "native theme driver reached critical state", driverEvidence); err != nil {
		return Result{}, fmt.Errorf("complete preview driver protocol: %w", err)
	}
	if _, err := journal.Progress(operation.ID, "critical live state observed", driverEvidence, nil); err != nil {
		return Result{}, fmt.Errorf("record preview promotion: %w", err)
	}
	state, err := json.Marshal(map[string]any{
		"theme_name":      themeName,
		"generation_id":   request.GenerationID,
		"variant":         string(request.Variant),
		"mode":            "preview",
		"color_overrides": request.ColorOverrides,
		"style_overrides": request.Styles,
	})
	if err != nil {
		return Result{}, fmt.Errorf("encode preview checkpoint: %w", err)
	}
	checkpoint, err := journal.CreateCheckpoint(protocol.CheckpointInput{
		OperationID: operation.ID,
		Name:        string(request.Variant),
		State:       state,
	})
	if err != nil {
		return Result{}, fmt.Errorf("record preview checkpoint: %w", err)
	}
	if _, err := journal.CompleteOperation(operation.ID, protocol.StatusSucceeded, "preview is live", "critical state active; post-commit adapters may still be running"); err != nil {
		return Result{}, fmt.Errorf("complete preview protocol: %w", err)
	}
	applyStyleOverrides(&record, request.Styles)
	record.PreviewVariant = string(request.Variant)
	if err := s.sessions.Save(record); err != nil {
		return Result{}, fmt.Errorf("persist preview progress: %w", err)
	}
	return Result{
		SessionID:          request.SessionID,
		GenerationID:       request.GenerationID,
		Variant:            request.Variant,
		ThemeName:          themeName,
		PID:                pid,
		AlreadyActive:      already,
		LogPath:            logPath,
		ProtocolOperation:  operation.ID,
		ProtocolCheckpoint: checkpoint.ID,
		ProtocolEvents:     protocolPaths.Events,
		ProtocolSocket:     protocolPaths.Socket,
	}, nil
}

func (s *Service) applyTheme(themeName, logPath string, request Request) (int, bool, error) {
	if request.Scope != "" || request.WaitMode != "" || request.AllowTrustedHooks {
		optionsApplier, ok := s.applier.(optionsAwareThemeApplier)
		if !ok {
			return 0, false, fmt.Errorf("preview driver options requested but the theme driver does not support them")
		}
		return optionsApplier.ApplyThemePreviewWithOptions(themeName, logPath, request.RetintRun, request.RetintSkip, request.Scope, request.WaitMode, request.AllowTrustedHooks)
	}
	if request.RetintRun != "" || request.RetintSkip != "" {
		policyApplier, ok := s.applier.(policyAwareThemeApplier)
		if !ok {
			return 0, false, fmt.Errorf("preview retint policy requested but the theme driver does not support it")
		}
		return policyApplier.ApplyThemePreviewWithPolicy(themeName, logPath, request.RetintRun, request.RetintSkip)
	}
	return s.applier.ApplyThemePreview(themeName, logPath)
}

func (s *Service) candidateDir(r Request) (string, error) {
	if strings.HasPrefix(r.GenerationID, ".") {
		return "", fmt.Errorf("temporary generation cannot be previewed")
	}
	sessionDir := s.sessions.SessionDir(r.SessionID)
	generationDir := filepath.Join(sessionDir, "generations", r.GenerationID)
	info, err := os.Lstat(generationDir)
	if err != nil {
		return "", fmt.Errorf("inspect generation: %w", err)
	}
	if !info.IsDir() {
		return "", fmt.Errorf("generation is not a directory")
	}
	candidate := filepath.Join(generationDir, string(r.Variant))
	info, err = os.Lstat(candidate)
	if err != nil {
		return "", fmt.Errorf("inspect candidate %s: %w", r.Variant, err)
	}
	if !info.IsDir() {
		return "", fmt.Errorf("candidate %s is not a directory", r.Variant)
	}
	if err := validateCandidateContents(candidate); err != nil {
		return "", fmt.Errorf("validate candidate %s: %w", r.Variant, err)
	}
	if err := validatePathInside(sessionDir, candidate); err != nil {
		return "", fmt.Errorf("validate candidate ownership: %w", err)
	}
	if len(r.ColorOverrides) > 0 || r.Styles != nil {
		shellStyle, barStyle, rewriteShell, err := s.colorOverrideStyles(r.SessionID)
		if err != nil {
			return "", err
		}
		return s.materializeOverride(sessionDir, candidate, r, shellStyle, barStyle, rewriteShell)
	}
	return filepath.Abs(candidate)
}

func (s *Service) colorOverrideStyles(sessionID string) (session.ShellStyle, session.BarStyle, bool, error) {
	record, err := s.sessions.Load(sessionID)
	if err != nil {
		return session.ShellStyle{}, session.BarStyle{}, false, fmt.Errorf("load session for color override: %w", err)
	}
	if !record.ExtraConfigs {
		return session.ShellStyle{}, session.BarStyle{}, false, nil
	}
	shellStyle := session.NormalizeShellStyle(record.ShellStyle)
	barStyle := session.NormalizeBarStyle(record.BarStyle)
	if !shellStyle.Valid() || !barStyle.Valid() {
		return session.ShellStyle{}, session.BarStyle{}, false, nil
	}
	return shellStyle, barStyle, true, nil
}

func (s *Service) materializeOverride(
	sessionDir, source string,
	request Request,
	shellStyle session.ShellStyle,
	barStyle session.BarStyle,
	rewriteShell bool,
) (string, error) {
	overrideHash, err := overrideHash(request)
	if err != nil {
		return "", fmt.Errorf("hash preview overrides: %w", err)
	}
	base, err := theme.ReadColors(source)
	if err != nil {
		return "", fmt.Errorf("read candidate palette: %w", err)
	}
	overridden := base
	if len(request.ColorOverrides) > 0 {
		overridden, err = theme.ApplyColorOverrides(base, request.ColorOverrides)
		if err != nil {
			return "", err
		}
	}
	root := filepath.Join(sessionDir, "preview-candidates")
	if err := fsutil.EnsureDir(root, 0o755); err != nil {
		return "", fmt.Errorf("create preview candidate directory: %w", err)
	}
	destination := filepath.Join(root, fmt.Sprintf("%s-%s", request.Variant, overrideHash[:16]))
	if info, statErr := os.Stat(destination); statErr == nil && info.IsDir() {
		if err := validateCandidateContents(destination); err != nil {
			return "", fmt.Errorf("validate existing color candidate: %w", err)
		}
		if err := writeOverrideFiles(destination, overridden, request, shellStyle, barStyle, rewriteShell); err != nil {
			return "", err
		}
		return filepath.Abs(destination)
	} else if statErr != nil && !os.IsNotExist(statErr) {
		return "", fmt.Errorf("inspect color candidate: %w", statErr)
	}

	temporary, err := os.MkdirTemp(root, ".color-override-*.tmp")
	if err != nil {
		return "", fmt.Errorf("create temporary color candidate: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = os.RemoveAll(temporary)
		}
	}()

	if err := copyCandidateTree(source, temporary); err != nil {
		return "", fmt.Errorf("copy color candidate: %w", err)
	}
	if err := writeOverrideFiles(temporary, overridden, request, shellStyle, barStyle, rewriteShell); err != nil {
		return "", err
	}
	if _, err := fsutil.RenameAndSyncNoReplace(temporary, destination); err != nil {
		if os.IsExist(err) {
			if validateErr := validateCandidateContents(destination); validateErr == nil {
				if writeErr := writeOverrideFiles(destination, overridden, request, shellStyle, barStyle, rewriteShell); writeErr != nil {
					return "", writeErr
				}
				return filepath.Abs(destination)
			}
		}
		return "", fmt.Errorf("commit color candidate: %w", err)
	}
	committed = true
	return filepath.Abs(destination)
}

func writeOverrideFiles(dir string, palette theme.Palette, request Request, shellStyle session.ShellStyle, barStyle session.BarStyle, rewriteShell bool) error {
	if len(request.ColorOverrides) > 0 {
		if err := theme.WriteColors(dir, palette); err != nil {
			return fmt.Errorf("write overridden palette: %w", err)
		}
	}
	if request.Styles != nil {
		styles := *request.Styles
		styles.Shell = session.NormalizeShellStyle(styles.Shell)
		styles.Desktop = session.NormalizeDesktopStyle(styles.Desktop)
		styles.Bar = session.NormalizeBarStyle(styles.Bar)
		styles.Animations = session.NormalizeAnimationsStyle(styles.Animations)
		spec := styles.Bar.EffectiveBarSpec()
		if err := theme.WriteHyprlandWithAnimationsAndShell(dir, palette, styles.Desktop.BorderStyle, styles.Desktop.BorderSize, styles.Desktop.Shape, styles.Desktop.Spacing, styles.Desktop.Depth, styles.Desktop.Active, styles.Desktop.Inactive, styles.Desktop.BorderSpeed, styles.Animations, styles.Shell.Preset, &spec); err != nil {
			return fmt.Errorf("rewrite overridden hyprland style: %w", err)
		}
		if err := theme.WriteShellWithOverridesAndSpec(dir, palette, styles.Shell.Surface, styles.Shell.Detail, styles.Shell.Tooltip, styles.Shell.Notifications, styles.Bar.Surface, styles.Bar.Density, styles.Bar.Attention, styles.Bar.Form, styles.Bar.Visibility, session.EffectiveShellOverrides(styles.Shell, styles.Bar), &spec); err != nil {
			return fmt.Errorf("rewrite overridden shell sidecars: %w", err)
		}
		if styles.Bar.Profile != nil {
			if err := theme.WriteBarProfile(dir, *styles.Bar.Profile); err != nil {
				return fmt.Errorf("rewrite bar profile: %w", err)
			}
		}
		if err := theme.WriteBarSpec(dir, styles.Bar.EffectiveBarSpec()); err != nil {
			return fmt.Errorf("rewrite bar spec: %w", err)
		}
		if styles.LookFeel != nil {
			if err := theme.WriteLookFeelMetadata(dir, *styles.LookFeel); err != nil {
				return fmt.Errorf("rewrite Look & Feel metadata: %w", err)
			}
		}
		if styles.Terminal != nil {
			if err := theme.WriteTerminalTranslucency(dir, *styles.Terminal); err != nil {
				return fmt.Errorf("rewrite terminal translucency metadata: %w", err)
			}
		}
		if err := runtime.WriteManifest(dir, runtime.AdvancedManifest("shell", "bar", "window", "animations")); err != nil {
			return fmt.Errorf("write Omagen runtime manifest: %w", err)
		}
		return nil
	}
	if !rewriteShell {
		return nil
	}
	spec := barStyle.EffectiveBarSpec()
	if err := theme.WriteShellWithOverridesAndSpec(dir, palette, shellStyle.Surface, shellStyle.Detail, shellStyle.Tooltip, shellStyle.Notifications, barStyle.Surface, barStyle.Density, barStyle.Attention, barStyle.Form, barStyle.Visibility, session.EffectiveShellOverrides(shellStyle, barStyle), &spec); err != nil {
		return fmt.Errorf("rewrite overridden shell sidecars: %w", err)
	}
	if barStyle.Profile != nil {
		if err := theme.WriteBarProfile(dir, *barStyle.Profile); err != nil {
			return fmt.Errorf("rewrite bar profile: %w", err)
		}
	}
	if err := theme.WriteBarSpec(dir, barStyle.EffectiveBarSpec()); err != nil {
		return fmt.Errorf("rewrite bar spec: %w", err)
	}
	if err := runtime.WriteManifest(dir, runtime.AdvancedManifest("shell", "bar", "window", "animations")); err != nil {
		return fmt.Errorf("write Omagen runtime manifest: %w", err)
	}
	return nil
}

func colorOverrideHash(overrides map[string]string) (string, error) {
	payload, err := json.Marshal(overrides)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", sha256.Sum256(payload)), nil
}

func overrideHash(request Request) (string, error) {
	if request.Styles == nil {
		return colorOverrideHash(request.ColorOverrides)
	}
	payload, err := json.Marshal(struct {
		Colors map[string]string `json:"colors,omitempty"`
		Styles *StyleOverrides   `json:"styles,omitempty"`
	}{Colors: request.ColorOverrides, Styles: request.Styles})
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", sha256.Sum256(payload)), nil
}

func copyCandidateTree(source, destination string) error {
	return filepath.WalkDir(source, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		relative, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		target := destination
		if relative != "." {
			target = filepath.Join(destination, relative)
		}
		if entry.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		if !entry.Type().IsRegular() {
			return fmt.Errorf("unsupported candidate entry %s", relative)
		}
		return fsutil.CopyFileAtomic(path, target, 0o644)
	})
}

func validateCandidateContents(dir string) error {
	info, err := os.Stat(filepath.Join(dir, "colors.toml"))
	if err != nil {
		return fmt.Errorf("colors.toml: %w", err)
	}
	if !info.Mode().IsRegular() || info.Size() == 0 {
		return fmt.Errorf("colors.toml is not a non-empty regular file")
	}
	entries, err := os.ReadDir(filepath.Join(dir, "backgrounds"))
	if err != nil {
		return fmt.Errorf("read backgrounds directory: %w", err)
	}
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !supportedBackground(entry.Name()) {
			continue
		}
		if info, err := entry.Info(); err == nil && info.Mode().IsRegular() {
			return nil
		}
	}
	return fmt.Errorf("candidate has no Omarchy-supported background")
}

func supportedBackground(name string) bool {
	switch strings.ToLower(filepath.Ext(name)) {
	case ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp":
		return true
	}
	return false
}

func validatePathInside(base, path string) error {
	base, err := filepath.EvalSymlinks(base)
	if err != nil {
		return fmt.Errorf("resolve session directory: %w", err)
	}
	path, err = filepath.EvalSymlinks(path)
	if err != nil {
		return fmt.Errorf("resolve candidate directory: %w", err)
	}
	rel, err := filepath.Rel(base, path)
	if err != nil {
		return err
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return fmt.Errorf("candidate escapes session directory")
	}
	return nil
}

func (s *Service) ensureThemeAlias(name, target string) error {
	if err := fsutil.EnsureDir(s.userThemesRoot, 0o755); err != nil {
		return err
	}
	path := filepath.Join(s.userThemesRoot, name)
	if err := os.Symlink(target, path); err == nil {
		return fsutil.SyncDir(s.userThemesRoot)
	} else if !os.IsExist(err) {
		return err
	}
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return fmt.Errorf("theme path %s already exists and is not an Omagen symlink", path)
	}
	existing, err := os.Readlink(path)
	if err != nil {
		return err
	}
	if !filepath.IsAbs(existing) {
		existing = filepath.Join(filepath.Dir(path), existing)
	}
	if filepath.Clean(existing) != filepath.Clean(target) {
		return fmt.Errorf("preview alias %s already points somewhere else", name)
	}
	return nil
}

func (s *Service) newPreviewLog(r Request) (string, error) {
	dir := filepath.Join(s.sessions.SessionDir(r.SessionID), "preview-logs")
	if err := fsutil.EnsureDir(dir, 0o755); err != nil {
		return "", fmt.Errorf("create preview log directory: %w", err)
	}
	f, err := os.CreateTemp(dir, fmt.Sprintf("%s-%s-*.log", r.GenerationID, r.Variant))
	if err != nil {
		return "", fmt.Errorf("create preview log: %w", err)
	}
	path := f.Name()
	if err := f.Close(); err != nil {
		return "", fmt.Errorf("close preview log: %w", err)
	}
	return path, nil
}

func previewThemeName(r Request) string {
	name := fmt.Sprintf("%s%s-%s-%s", previewThemePrefix, r.SessionID, r.GenerationID, r.Variant)
	if len(r.ColorOverrides) > 0 || r.Styles != nil {
		hash, _ := overrideHash(r)
		name += "-colors-" + hash[:16]
	}
	return strings.ToLower(name)
}

func applyStyleOverrides(record *session.Record, styles *StyleOverrides) {
	if record == nil || styles == nil {
		return
	}
	record.ShellStyle = session.NormalizeShellStyle(styles.Shell)
	record.DesktopStyle = session.NormalizeDesktopStyle(styles.Desktop)
	record.BarStyle = session.NormalizeBarStyle(styles.Bar)
	record.AnimationsStyle = session.NormalizeAnimationsStyle(styles.Animations)
	if styles.LookFeel != nil {
		record.LookFeel = session.NormalizeLookFeelDocument(*styles.LookFeel)
	}
	if styles.Terminal != nil {
		record.TerminalTranslucency = session.NormalizeTerminalTranslucency(*styles.Terminal)
	}
	record.ExtraConfigs = true
}

func validateComponent(name, value string) error {
	if value == "" || value == "." || value == ".." || filepath.Base(value) != value {
		return fmt.Errorf("invalid %s", name)
	}
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-' || r == '_' || r == '.') {
			return fmt.Errorf("invalid %s", name)
		}
	}
	return nil
}

func (s *Service) CleanupSession(sessionID string) (err error) {
	if err := validateComponent("session id", sessionID); err != nil {
		return err
	}
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer func() {
		if closeErr := lock.Close(); closeErr != nil {
			err = errors.Join(err, closeErr)
		}
	}()
	return s.cleanupSessionLocked(sessionID)
}

func (s *Service) cleanupSessionLocked(sessionID string) error {
	entries, err := os.ReadDir(s.userThemesRoot)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("read user themes: %w", err)
	}
	base := filepath.Clean(s.sessions.SessionDir(sessionID))
	prefix := strings.ToLower(previewThemePrefix + sessionID + "-")
	removed := false
	var errs []error
	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name(), prefix) {
			continue
		}
		path := filepath.Join(s.userThemesRoot, entry.Name())
		info, err := os.Lstat(path)
		if err != nil {
			if !os.IsNotExist(err) {
				errs = append(errs, err)
			}
			continue
		}
		if info.Mode()&os.ModeSymlink == 0 {
			continue
		}
		target, err := os.Readlink(path)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		if !filepath.IsAbs(target) {
			target = filepath.Join(s.userThemesRoot, target)
		}
		if !lexicallyInside(base, target) {
			continue
		}
		if err := os.Remove(path); err != nil {
			errs = append(errs, err)
		} else {
			removed = true
		}
	}
	if removed {
		errs = append(errs, fsutil.SyncDir(s.userThemesRoot))
	}
	return errors.Join(errs...)
}

func (s *Service) cleanupBrokenAliasesLocked() error {
	entries, err := os.ReadDir(s.userThemesRoot)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	removed := false
	var errs []error
	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name(), previewThemePrefix) {
			continue
		}
		path := filepath.Join(s.userThemesRoot, entry.Name())
		info, err := os.Lstat(path)
		if err != nil || info.Mode()&os.ModeSymlink == 0 {
			continue
		}
		target, err := os.Readlink(path)
		if err != nil {
			continue
		}
		if !filepath.IsAbs(target) {
			target = filepath.Join(s.userThemesRoot, target)
		}
		if _, err := os.Stat(target); !os.IsNotExist(err) {
			continue
		}
		if err := os.Remove(path); err != nil {
			errs = append(errs, err)
		} else {
			removed = true
		}
	}
	if removed {
		errs = append(errs, fsutil.SyncDir(s.userThemesRoot))
	}
	return errors.Join(errs...)
}

func lexicallyInside(base, path string) bool {
	rel, err := filepath.Rel(filepath.Clean(base), filepath.Clean(path))
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}
