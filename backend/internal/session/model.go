package session

import "time"

type ShellStyle struct {
	Surface       string `json:"surface"`
	Detail        string `json:"detail"`
	Tooltip       string `json:"tooltip"`
	Notifications string `json:"notifications"`
}

// DesktopStyle remains the window-level configuration used by existing
// themes. ShellStyle is additive and only controls Quattro shell.toml.
type DesktopStyle struct {
	BorderStyle    string `json:"border_style"`
	BorderSize     int    `json:"border_size"`
	BorderSizeMode string `json:"border_size_mode"`
	BorderSpeed    int    `json:"border_speed"`
	Shape          string `json:"shape"`
	Spacing        string `json:"spacing"`
	Depth          string `json:"depth"`
	Inactive       string `json:"inactive_style"`
}
type BarStyle struct {
	Surface    string `json:"surface"`
	Density    string `json:"density"`
	Attention  string `json:"attention"`
	Form       string `json:"form"`
	Visibility string `json:"visibility"`
}

func DefaultBarStyle() BarStyle {
	return BarStyle{Surface: "native", Density: "native", Attention: "semantic", Form: "continuous", Visibility: "native"}
}

// NormalizeBarStyle keeps sessions written before Bar Form was introduced
// valid. Missing form values are the backwards-compatible Continuous mode.
func NormalizeBarStyle(s BarStyle) BarStyle {
	if s.Surface == "" {
		s.Surface = "native"
	}
	if s.Density == "" {
		s.Density = "native"
	}
	if s.Attention == "" {
		s.Attention = "semantic"
	}
	if s.Form == "" {
		s.Form = "continuous"
	}
	if s.Visibility == "" {
		s.Visibility = "native"
	}
	return s
}

func (s BarStyle) Valid() bool {
	return validChoice(s.Surface, "native", "dark", "light", "accent") &&
		validChoice(s.Density, "native", "compact", "comfortable") &&
		validChoice(s.Attention, "semantic", "accent") &&
		validChoice(s.Form, "continuous", "docked") &&
		validChoice(s.Visibility, "native", "islands")
}

func DefaultDesktopStyle() DesktopStyle {
	return DesktopStyle{BorderStyle: "solid", BorderSize: -1, BorderSizeMode: "default", BorderSpeed: 36, Shape: "native", Spacing: "native", Depth: "native", Inactive: "native"}
}

// NormalizeDesktopStyle keeps sessions written before border-size modes and
// inactive-window modes were introduced compatible with the native behavior.
func NormalizeDesktopStyle(s DesktopStyle) DesktopStyle {
	if s.BorderSizeMode == "" {
		// Before border-size modes existed, zero meant "do not override the
		// theme". Migrate that legacy representation to Default. Positive
		// values remain explicit fixed sizes.
		if s.BorderSize == 0 {
			s.BorderSize = -1
			s.BorderSizeMode = "default"
		} else if s.BorderSize < 0 {
			s.BorderSizeMode = "default"
		} else {
			s.BorderSizeMode = "fixed"
		}
	}
	switch s.BorderSizeMode {
	case "default":
		s.BorderSize = -1
	case "none":
		s.BorderSize = 0
	case "fixed":
		if s.BorderSize < 1 {
			s.BorderSize = 1
		}
	}
	if s.BorderSpeed == 0 {
		s.BorderSpeed = 36
	}
	if s.Inactive == "" {
		s.Inactive = "native"
	}
	return s
}

func (s DesktopStyle) Valid() bool {
	return validChoice(s.BorderStyle, "solid", "split", "split_top", "split_bottom", "blend", "neon", "spin") &&
		validChoice(s.BorderSizeMode, "default", "none", "fixed") &&
		s.BorderSize >= -1 && s.BorderSize <= 24 &&
		((s.BorderSizeMode == "default" && s.BorderSize == -1) ||
			(s.BorderSizeMode == "none" && s.BorderSize == 0) ||
			(s.BorderSizeMode == "fixed" && s.BorderSize >= 1)) &&
		s.BorderSpeed >= 10 && s.BorderSpeed <= 100 &&
		validChoice(s.Shape, "native", "subtle", "soft", "rounded", "pill") &&
		validChoice(s.Spacing, "native", "compact", "airy") &&
		validChoice(s.Depth, "native", "flat", "shadow") &&
		validChoice(s.Inactive, "native", "shadow", "blur")
}

func DefaultShellStyle() ShellStyle {
	return ShellStyle{Surface: "flat", Detail: "native", Tooltip: "native", Notifications: "native"}
}

// NormalizeShellStyle keeps sessions written before feedback-surface controls
// were introduced compatible with the native Quattro behavior.
func NormalizeShellStyle(s ShellStyle) ShellStyle {
	if s.Surface == "" {
		s.Surface = "flat"
	}
	if s.Detail == "" {
		s.Detail = "native"
	}
	if s.Tooltip == "" {
		s.Tooltip = "native"
	}
	if s.Notifications == "" {
		s.Notifications = "native"
	}
	return s
}

func (s ShellStyle) Valid() bool {
	return validChoice(s.Surface, "flat", "layered", "contrast", "accent") &&
		validChoice(s.Detail, "native", "framed", "edge", "focus") &&
		validChoice(s.Tooltip, "native", "accent") &&
		validChoice(s.Notifications, "native", "accent")
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
