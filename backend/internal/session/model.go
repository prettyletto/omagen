package session

import "time"

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
	GenerationID       string        `json:"generation_id,omitempty"`
	PreviewVariant     string        `json:"preview_variant,omitempty"`
	ApplyCommitted     bool          `json:"apply_committed,omitempty"`
	AppliedTheme       string        `json:"applied_theme,omitempty"`
	AppliedGeneration  string        `json:"applied_generation,omitempty"`
	AppliedVariant     string        `json:"applied_variant,omitempty"`
	AppliedDisplayName string        `json:"applied_display_name,omitempty"`
}

type BeginResult struct {
	SessionID          string        `json:"session_id"`
	OriginalTheme      string        `json:"original_theme"`
	OriginalBackground BackgroundRef `json:"original_background"`
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
