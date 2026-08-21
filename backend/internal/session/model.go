package session

import "time"

type PanelStyle string

const (
	PanelStyleSolid PanelStyle = "solid"
	PanelStyleSplit PanelStyle = "split"
	PanelStyleCycle PanelStyle = "cycle"
	PanelStyleNeon  PanelStyle = "neon"
)

func ParsePanelStyle(value string) (PanelStyle, bool) {
	style := PanelStyle(value)
	switch style {
	case PanelStyleSolid, PanelStyleSplit, PanelStyleCycle, PanelStyleNeon:
		return style, true
	default:
		return "", false
	}
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
	PanelStyle         PanelStyle    `json:"panel_style,omitempty"`
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
	PanelStyle         PanelStyle    `json:"panel_style"`
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
