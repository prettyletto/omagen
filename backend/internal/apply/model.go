package apply

import "github.com/prettyletto/omagen/backend/internal/generation"

type Request struct {
	SessionID, GenerationID string
	Variant                 generation.Variant
	ThemeName               string
	GenerateUnlock          bool
	CapturePreview          bool
}
type Result struct {
	SessionID    string             `json:"session_id"`
	GenerationID string             `json:"generation_id"`
	Variant      generation.Variant `json:"variant"`
	ThemeName    string             `json:"theme_name"`
	DisplayName  string             `json:"display_name"`
	ThemePath    string             `json:"theme_path"`
}
