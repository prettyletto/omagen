// Package themeedit owns the installed-theme adoption boundary. It resolves
// the native catalog, snapshots the merged stock/user tree into a durable
// Omagen session, and exposes the selected source as a one-variant workspace.
package themeedit

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/omarchy"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type Service struct {
	sessions *session.Store
	session  *session.Service
	native   *omarchy.Client
}

type Result struct {
	SessionID    string            `json:"session_id"`
	Workflow     string            `json:"workflow"`
	Theme        omarchy.ThemeInfo `json:"theme"`
	GenerationID string            `json:"generation_id"`
	Variant      string            `json:"variant"`
	Path         string            `json:"path"`
	Palette      theme.Palette     `json:"palette"`
	Recipe       *theme.Recipe     `json:"recipe,omitempty"`
}

func (s *Service) Resolve(name string) (omarchy.ThemeInfo, error) {
	themes, err := s.List()
	if err != nil {
		return omarchy.ThemeInfo{}, err
	}
	for _, candidate := range themes {
		if candidate.ID == name || candidate.Name == name {
			return candidate, nil
		}
	}
	return omarchy.ThemeInfo{}, fmt.Errorf("theme %q is not in the Omarchy catalog", name)
}

func (s *Service) ExportRecipe(name string) (theme.Recipe, error) {
	selected, err := s.Resolve(name)
	if err != nil {
		return theme.Recipe{}, err
	}
	// A same-name user overlay has native precedence, but a recipe may still
	// live in the stock layer when the overlay only overrides palette/assets.
	// Search the merged source roots in that precedence order.
	paths := []string{selected.UserPath, selected.StockPath, selected.Path}
	for _, path := range paths {
		if path == "" {
			continue
		}
		recipe, err := theme.ReadRecipe(path)
		if err == nil {
			return recipe, nil
		}
		if !os.IsNotExist(err) {
			return theme.Recipe{}, fmt.Errorf("read recipe for theme %q: %w", selected.Name, err)
		}
	}
	return theme.Recipe{}, fmt.Errorf("theme %q has no Omagen recipe", selected.Name)
}

func NewService(sessions *session.Store, sessionService *session.Service, native *omarchy.Client) *Service {
	return &Service{sessions: sessions, session: sessionService, native: native}
}

func (s *Service) List() ([]omarchy.ThemeInfo, error) {
	return s.native.ListThemes()
}

func (s *Service) Open(name string) (Result, error) {
	themes, err := s.List()
	if err != nil {
		return Result{}, err
	}
	var selected *omarchy.ThemeInfo
	for index := range themes {
		if themes[index].ID == name || themes[index].Name == name {
			selected = &themes[index]
			break
		}
	}
	if selected == nil {
		return Result{}, fmt.Errorf("theme %q is not in the Omarchy catalog", name)
	}
	begin, err := s.session.Begin()
	if err != nil {
		return Result{}, err
	}
	generationID, err := newGenerationID()
	if err != nil {
		_ = s.session.Cancel(begin.SessionID)
		return Result{}, err
	}
	candidate := filepath.Join(s.sessions.SessionDir(begin.SessionID), "generations", generationID, "source")
	if err := fsutil.EnsureDir(filepath.Dir(candidate), 0o755); err != nil {
		_ = s.session.Cancel(begin.SessionID)
		return Result{}, fmt.Errorf("create edit workspace: %w", err)
	}
	if err := copyMergedTree(selected.StockPath, selected.UserPath, selected.Path, candidate); err != nil {
		_ = s.session.Cancel(begin.SessionID)
		return Result{}, fmt.Errorf("snapshot theme %q: %w", selected.Name, err)
	}
	palette, err := theme.ReadColors(candidate)
	if err != nil {
		_ = s.session.Cancel(begin.SessionID)
		return Result{}, fmt.Errorf("read theme palette: %w", err)
	}
	if err := validateBackgrounds(candidate); err != nil {
		_ = s.session.Cancel(begin.SessionID)
		return Result{}, fmt.Errorf("validate theme backgrounds: %w", err)
	}
	recipe, recipeErr := theme.ReadRecipe(candidate)
	if recipeErr != nil && !os.IsNotExist(recipeErr) {
		_ = s.session.Cancel(begin.SessionID)
		return Result{}, fmt.Errorf("read theme recipe: %w", recipeErr)
	}
	var recipePtr *theme.Recipe
	fingerprint, fingerprintErr := fingerprintTree(candidate)
	if fingerprintErr != nil {
		_ = s.session.Cancel(begin.SessionID)
		return Result{}, fmt.Errorf("fingerprint theme snapshot: %w", fingerprintErr)
	}
	edit := session.ThemeEdit{SourceID: selected.ID, SourceName: selected.Name, SourcePath: selected.Path, SourceKind: selected.Kind, SourceFingerprint: fingerprint}
	if recipeErr == nil {
		recipePtr = &recipe
		edit.ManagedScopes = append([]string(nil), recipe.ManagedScopes...)
		edit.Shell, edit.Desktop, edit.Bar, edit.Animations, edit.LookFeel, edit.Terminal = recipe.Shell, recipe.Desktop, recipe.Bar, recipe.Animations, recipe.LookFeel, recipe.Terminal
	}
	if err := s.session.MarkThemeEdit(begin.SessionID, edit, generationID); err != nil {
		_ = s.session.Cancel(begin.SessionID)
		return Result{}, fmt.Errorf("persist edit source: %w", err)
	}
	return Result{SessionID: begin.SessionID, Workflow: "theme-edit", Theme: *selected, GenerationID: generationID, Variant: "source", Path: candidate, Palette: palette, Recipe: recipePtr}, nil
}

func fingerprintTree(root string) (string, error) {
	hash := sha256.New()
	const maxFingerprintFiles = 4096
	const maxFingerprintBytes int64 = 256 << 20
	var fileCount int
	var totalBytes int64
	if err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 || !entry.Type().IsRegular() {
			return fmt.Errorf("unsupported theme entry %s", path)
		}
		fileCount++
		if fileCount > maxFingerprintFiles {
			return fmt.Errorf("theme contains more than %d files", maxFingerprintFiles)
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		if _, err := io.WriteString(hash, relative+"\x00"); err != nil {
			return err
		}
		file, err := fsutil.OpenRegularFile(path, fsutil.MaxFileBytes)
		if err != nil {
			return err
		}
		limited := io.LimitReader(file, fsutil.MaxFileBytes+1)
		copied, copyErr := io.Copy(hash, limited)
		totalBytes += copied
		if copyErr == nil && (copied > fsutil.MaxFileBytes || totalBytes > maxFingerprintBytes) {
			copyErr = fmt.Errorf("theme exceeds fingerprint size limit of %d bytes", maxFingerprintBytes)
		}
		closeErr := file.Close()
		if copyErr != nil {
			return copyErr
		}
		return closeErr
	}); err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func newGenerationID() (string, error) {
	var random [12]byte
	if _, err := rand.Read(random[:]); err != nil {
		return "", err
	}
	return "edit-" + hex.EncodeToString(random[:]), nil
}

// copyMergedTree mirrors Omarchy's native precedence: stock first, user
// overlay second. A user-only theme is copied from its preferred root. The
// snapshot intentionally rejects symlinks and special files so preview/apply
// cannot follow an uncontrolled path outside the session.
func copyMergedTree(stockPath, userPath, preferredPath, destination string) error {
	if stockPath == "" && userPath == "" {
		userPath = preferredPath
	}
	if stockPath != "" {
		if err := copyTree(stockPath, destination); err != nil {
			return err
		}
	}
	if userPath != "" {
		if err := copyTree(userPath, destination); err != nil {
			return err
		}
	}
	return nil
}

func copyTree(source, destination string) error {
	return filepath.WalkDir(source, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
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
		if entry.Type()&os.ModeSymlink != 0 || !entry.Type().IsRegular() {
			return fmt.Errorf("unsupported theme entry %s", relative)
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		return fsutil.CopyFileAtomic(path, target, info.Mode().Perm())
	})
}

func validateBackgrounds(candidate string) error {
	entries, err := os.ReadDir(filepath.Join(candidate, "backgrounds"))
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 {
			continue
		}
		ext := strings.ToLower(filepath.Ext(entry.Name()))
		switch ext {
		case ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp":
			if info, statErr := entry.Info(); statErr == nil && info.Mode().IsRegular() && info.Size() > 0 {
				return nil
			}
		}
	}
	return fmt.Errorf("no Omarchy-supported background found")
}
