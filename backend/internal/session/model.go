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
}

type BeginResult struct {
	SessionID          string        `json:"session_id"`
	OriginalTheme      string        `json:"original_theme"`
	OriginalBackground BackgroundRef `json:"original_background"`
}
