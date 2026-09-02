package theme

import (
	"encoding/json"
	"fmt"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
)

const (
	RecipeSchemaVersion = 1
	RecipeKind          = "omagen.theme.recipe"
	RecipeFile          = "omagen.theme-recipe.json"
)

// Recipe is the durable, portable description of Omagen-owned intent inside a
// theme. Native files remain the runtime source of truth; this sidecar lets a
// later edit reopen exact palette/style choices without reverse-engineering
// generated TOML or Lua.
type Recipe struct {
	SchemaVersion     int                          `json:"schema_version"`
	Kind              string                       `json:"kind"`
	ThemeName         string                       `json:"theme_name"`
	SourceTheme       string                       `json:"source_theme,omitempty"`
	SourceKind        string                       `json:"source_kind,omitempty"`
	SourceFingerprint string                       `json:"source_fingerprint,omitempty"`
	ManagedScopes     []string                     `json:"managed_scopes,omitempty"`
	Palette           Palette                      `json:"palette"`
	Shell             session.ShellStyle           `json:"shell"`
	Desktop           session.DesktopStyle         `json:"desktop"`
	Bar               session.BarStyle             `json:"bar"`
	Animations        session.AnimationsStyle      `json:"animations"`
	LookFeel          session.LookFeelDocument     `json:"look_feel"`
	Terminal          session.TerminalTranslucency `json:"terminal"`
}

func (r Recipe) Validate() error {
	if r.SchemaVersion != RecipeSchemaVersion {
		return fmt.Errorf("unsupported theme recipe schema version %d", r.SchemaVersion)
	}
	if r.Kind != RecipeKind {
		return fmt.Errorf("invalid theme recipe kind %q", r.Kind)
	}
	if r.ThemeName == "" {
		return fmt.Errorf("theme recipe has no theme name")
	}
	seenScopes := make(map[string]struct{}, len(r.ManagedScopes))
	for _, scope := range r.ManagedScopes {
		if scope != "shell-bar" && scope != "window-motion" && scope != "terminal" {
			return fmt.Errorf("theme recipe has unknown managed scope %q", scope)
		}
		if _, exists := seenScopes[scope]; exists {
			return fmt.Errorf("theme recipe repeats managed scope %q", scope)
		}
		seenScopes[scope] = struct{}{}
	}
	if err := r.Palette.Validate(); err != nil {
		return fmt.Errorf("invalid theme recipe palette: %w", err)
	}
	if !session.NormalizeShellStyle(r.Shell).Valid() || !session.NormalizeDesktopStyle(r.Desktop).Valid() || !session.NormalizeBarStyle(r.Bar).Valid() || !session.NormalizeAnimationsStyle(r.Animations).Valid() {
		return fmt.Errorf("invalid theme recipe style")
	}
	if !session.NormalizeLookFeelDocument(r.LookFeel).Valid() {
		return fmt.Errorf("invalid theme recipe Look & Feel")
	}
	if !session.NormalizeTerminalTranslucency(r.Terminal).Valid() {
		return fmt.Errorf("invalid theme recipe terminal intent")
	}
	return nil
}

func WriteRecipe(themeDir string, recipe Recipe) error {
	recipe.SchemaVersion = RecipeSchemaVersion
	recipe.Kind = RecipeKind
	recipe.Shell = session.NormalizeShellStyle(recipe.Shell)
	recipe.Desktop = session.NormalizeDesktopStyle(recipe.Desktop)
	recipe.Bar = session.NormalizeBarStyle(recipe.Bar)
	recipe.Animations = session.NormalizeAnimationsStyle(recipe.Animations)
	recipe.LookFeel = session.NormalizeLookFeelDocument(recipe.LookFeel)
	recipe.Terminal = session.NormalizeTerminalTranslucency(recipe.Terminal)
	if err := recipe.Validate(); err != nil {
		return err
	}
	return fsutil.AtomicWriteJSON(filepath.Join(themeDir, RecipeFile), recipe, 0o644)
}

func ReadRecipe(themeDir string) (Recipe, error) {
	data, err := fsutil.ReadFileLimited(filepath.Join(themeDir, RecipeFile), fsutil.MaxStateFileBytes)
	if err != nil {
		return Recipe{}, err
	}
	var recipe Recipe
	if err := json.Unmarshal(data, &recipe); err != nil {
		return Recipe{}, fmt.Errorf("decode theme recipe: %w", err)
	}
	if err := recipe.Validate(); err != nil {
		return Recipe{}, err
	}
	return recipe, nil
}
