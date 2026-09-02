package apply

import "github.com/prettyletto/omagen/backend/internal/generation"

type Request struct {
	SessionID, GenerationID string
	Variant                 generation.Variant
	ThemeName               string
	GenerateUnlock          bool
	CapturePreview          bool
	RetintRun               string
	RetintSkip              string
	Scope                   string
	WaitMode                string
	AllowTrustedHooks       bool
	DestinationPolicy       string
	SaveLookFeelPresetName  string
}
type Result struct {
	SessionID                 string             `json:"session_id"`
	GenerationID              string             `json:"generation_id"`
	Variant                   generation.Variant `json:"variant"`
	ThemeName                 string             `json:"theme_name"`
	DisplayName               string             `json:"display_name"`
	ThemePath                 string             `json:"theme_path"`
	AdvancedRuntimeRequired   bool               `json:"advanced_runtime_required,omitempty"`
	AdvancedRuntimeInstalled  bool               `json:"advanced_runtime_installed,omitempty"`
	NativeOnlyFallback        bool               `json:"native_only_fallback,omitempty"`
	FallbackNotificationShown bool               `json:"fallback_notification_shown,omitempty"`
}
