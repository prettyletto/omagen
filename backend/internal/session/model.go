package session

import "time"

type ShellStyle struct {
	Surface string `json:"surface"`
	Detail  string `json:"detail"`
}

// DesktopStyle remains the window-level configuration used by existing
// themes. ShellStyle is additive and only controls Quattro shell.toml.
type DesktopStyle struct {
	BorderStyle string `json:"border_style"`
	Shape       string `json:"shape"`
	Spacing     string `json:"spacing"`
	Depth       string `json:"depth"`
}
type BarStyle struct {
	Surface   string `json:"surface"`
	Density   string `json:"density"`
	Attention string `json:"attention"`
}

func DefaultBarStyle() BarStyle {
	return BarStyle{Surface: "native", Density: "native", Attention: "semantic"}
}
func (s BarStyle) Valid() bool {
	return validChoice(s.Surface, "native", "dark", "light", "accent") && validChoice(s.Density, "native", "compact", "comfortable") && validChoice(s.Attention, "semantic", "accent")
}

func DefaultDesktopStyle() DesktopStyle {
	return DesktopStyle{BorderStyle: "solid", Shape: "native", Spacing: "native", Depth: "native"}
}
func (s DesktopStyle) Valid() bool {
	return validChoice(s.BorderStyle, "solid", "split", "split_top", "split_bottom", "blend", "neon") && validChoice(s.Shape, "native", "soft", "rounded") && validChoice(s.Spacing, "native", "compact", "airy") && validChoice(s.Depth, "native", "flat", "shadow")
}

func DefaultShellStyle() ShellStyle {
	return ShellStyle{Surface: "flat", Detail: "native"}
}

func (s ShellStyle) Valid() bool {
	return validChoice(s.Surface, "flat", "layered", "contrast", "accent") &&
		validChoice(s.Detail, "native", "framed", "edge", "focus")
}

func validChoice(value string, choices ...string) bool {
	for _, choice := range choices {
		if value == choice {
			return true
		}
	}
	return false
}

type ApplyPhase string

const (
	ApplyPhaseNone      ApplyPhase = ""
	ApplyPhasePrepared  ApplyPhase = "prepared"
	ApplyPhaseCommitted ApplyPhase = "committed"
)

type BackgroundRef struct {
	Kind string `json:"kind"`
	Path string `json:"path"`
}

type Record struct {
	SessionID          string        `json:"session_id"`
	OriginalTheme      string        `json:"original_theme"`
	OriginalBackground BackgroundRef `json:"original_background"`
	CreatedAt          time.Time     `json:"created_at"`
	SourceImage        string        `json:"source_image,omitempty"`
	ExtraConfigs       bool          `json:"extra_configs,omitempty"`
	ShellStyle         ShellStyle    `json:"shell_style,omitempty"`
	DesktopStyle       DesktopStyle  `json:"desktop_style,omitempty"`
	BarStyle           BarStyle      `json:"bar_style,omitempty"`
	GenerationID       string        `json:"generation_id,omitempty"`
	PreviewVariant     string        `json:"preview_variant,omitempty"`
	ApplyPhase         ApplyPhase    `json:"apply_phase,omitempty"`
	AppliedTheme       string        `json:"applied_theme,omitempty"`
	AppliedGeneration  string        `json:"applied_generation,omitempty"`
	AppliedVariant     string        `json:"applied_variant,omitempty"`
	AppliedDisplayName string        `json:"applied_display_name,omitempty"`
}

type BeginResult struct {
	SessionID          string        `json:"session_id"`
	OriginalTheme      string        `json:"original_theme"`
	OriginalBackground BackgroundRef `json:"original_background"`
	ShellStyle         ShellStyle    `json:"shell_style"`
	DesktopStyle       DesktopStyle  `json:"desktop_style"`
	BarStyle           BarStyle      `json:"bar_style"`
	ExtraConfigs       bool          `json:"extra_configs"`
}

type ActiveRecord struct {
	SessionID string    `json:"session_id"`
	CreatedAt time.Time `json:"created_at"`
}

type StatusResult struct {
	Active             bool           `json:"active"`
	SessionID          string         `json:"session_id,omitempty"`
	Recoverable        bool           `json:"recoverable"`
	CreatedAt          time.Time      `json:"created_at,omitempty"`
	OriginalTheme      string         `json:"original_theme,omitempty"`
	OriginalBackground *BackgroundRef `json:"original_background,omitempty"`
}

type RecoverResult struct {
	Recovered bool   `json:"recovered"`
	SessionID string `json:"session_id,omitempty"`
}
