package barprofile

import (
	"encoding/json"
	"fmt"
)

const SchemaVersion = 1

type Ownership string

const (
	OwnershipInherit    Ownership = "inherit"
	OwnershipOverlay    Ownership = "overlay"
	OwnershipThemeOwned Ownership = "theme-owned"
)

type Implementation string

const (
	ImplementationNative      Implementation = "native"
	ImplementationAdapter     Implementation = "adapter"
	ImplementationReplacement Implementation = "replacement"
)

// Profile is the theme-scoped bar contract. Bar is intentionally kept as raw
// JSON: shell.json is user-owned and can gain fields that this version of
// Omagen does not know about. Overlay profiles merge only the keys they carry;
// theme-owned profiles replace the complete bar object and are restored from a
// snapshot when the theme leaves.
type Profile struct {
	SchemaVersion  int             `json:"schema_version"`
	Ownership      Ownership       `json:"ownership"`
	Implementation Implementation  `json:"implementation"`
	Bar            json.RawMessage `json:"bar,omitempty"`
	Behavior       Behavior        `json:"behavior,omitempty"`
}

type Behavior struct {
	Form       string `json:"form,omitempty"`
	Visibility string `json:"visibility,omitempty"`
	Reveal     string `json:"reveal,omitempty"`
	Expansion  string `json:"expansion,omitempty"`
	Workspace  string `json:"workspace,omitempty"`
	Islands    bool   `json:"islands,omitempty"`
}

func DefaultProfile() Profile {
	return Profile{
		SchemaVersion:  SchemaVersion,
		Ownership:      OwnershipInherit,
		Implementation: ImplementationNative,
		Behavior: Behavior{
			Form:       "continuous",
			Visibility: "always",
			Reveal:     "edge",
			Expansion:  "none",
			Workspace:  "native",
		},
	}
}

func (p Profile) Normalize() Profile {
	if p.SchemaVersion == 0 {
		p.SchemaVersion = SchemaVersion
	}
	if p.Ownership == "" {
		p.Ownership = OwnershipInherit
	}
	if p.Implementation == "" {
		p.Implementation = ImplementationNative
	}
	defaults := DefaultProfile().Behavior
	if p.Behavior.Form == "" {
		p.Behavior.Form = defaults.Form
	}
	if p.Behavior.Visibility == "" {
		p.Behavior.Visibility = defaults.Visibility
	}
	if p.Behavior.Reveal == "" {
		p.Behavior.Reveal = defaults.Reveal
	}
	if p.Behavior.Expansion == "" {
		p.Behavior.Expansion = defaults.Expansion
	}
	if p.Behavior.Workspace == "" {
		p.Behavior.Workspace = defaults.Workspace
	}
	return p
}

func (p Profile) Validate() error {
	p = p.Normalize()
	if p.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported bar profile schema version %d", p.SchemaVersion)
	}
	switch p.Ownership {
	case OwnershipInherit, OwnershipOverlay, OwnershipThemeOwned:
	default:
		return fmt.Errorf("invalid bar profile ownership %q", p.Ownership)
	}
	switch p.Implementation {
	case ImplementationNative, ImplementationAdapter, ImplementationReplacement:
	default:
		return fmt.Errorf("invalid bar profile implementation %q", p.Implementation)
	}
	if p.Implementation == ImplementationReplacement && p.Ownership == OwnershipInherit {
		return fmt.Errorf("replacement bar profile cannot inherit bar ownership")
	}
	if len(p.Bar) > 0 && !json.Valid(p.Bar) {
		return fmt.Errorf("bar profile bar payload is invalid JSON")
	}
	if !choice(p.Behavior.Form, "continuous", "floating", "sections", "split", "islands", "dock", "minimal", "notch", "rail") {
		return fmt.Errorf("invalid bar profile form %q", p.Behavior.Form)
	}
	if !choice(p.Behavior.Visibility, "always", "auto-hide", "fullscreen-only", "intelligent") {
		return fmt.Errorf("invalid bar profile visibility %q", p.Behavior.Visibility)
	}
	if !choice(p.Behavior.Reveal, "edge", "hover-zone", "hotkey") {
		return fmt.Errorf("invalid bar profile reveal %q", p.Behavior.Reveal)
	}
	if !choice(p.Behavior.Expansion, "none", "hover", "focus", "adaptive") {
		return fmt.Errorf("invalid bar profile expansion %q", p.Behavior.Expansion)
	}
	if !choice(p.Behavior.Workspace, "native", "dots", "numbers", "labels", "segmented", "window-aware", "overview") {
		return fmt.Errorf("invalid bar profile workspace %q", p.Behavior.Workspace)
	}
	return nil
}

func (p Profile) Valid() bool { return p.Validate() == nil }

func choice(value string, values ...string) bool {
	for _, candidate := range values {
		if value == candidate {
			return true
		}
	}
	return false
}
