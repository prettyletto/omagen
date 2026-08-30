package preview

import (
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/session"
)

// StyleOverrides carries the four native composition documents that can be
// staged by Live Canvas.  A palette preview remains independent when this is
// nil; when present, the candidate is regenerated through the real Hyprland
// and Quickshell theme writers before the native theme driver runs.
type StyleOverrides struct {
	Shell      session.ShellStyle            `json:"shell"`
	Desktop    session.DesktopStyle          `json:"desktop"`
	Bar        session.BarStyle              `json:"bar"`
	Animations session.AnimationsStyle       `json:"animations"`
	LookFeel   *session.LookFeelDocument     `json:"look_feel,omitempty"`
	Terminal   *session.TerminalTranslucency `json:"terminal,omitempty"`
}

func (s StyleOverrides) Valid() bool {
	shell := session.NormalizeShellStyle(s.Shell)
	desktop := session.NormalizeDesktopStyle(s.Desktop)
	bar := session.NormalizeBarStyle(s.Bar)
	animations := session.NormalizeAnimationsStyle(s.Animations)
	if !shell.Valid() || !desktop.Valid() || !bar.Valid() || !animations.Valid() {
		return false
	}
	if s.LookFeel != nil {
		document := session.NormalizeLookFeelDocument(*s.LookFeel)
		if document.SchemaVersion != 1 || document.PresetRevision < 1 || document.Preset == "" {
			return false
		}
	}
	return s.Terminal == nil || session.NormalizeTerminalTranslucency(*s.Terminal).Valid()
}

type Request struct {
	SessionID         string
	GenerationID      string
	Variant           generation.Variant
	RetintRun         string
	RetintSkip        string
	Scope             string
	WaitMode          string
	AllowTrustedHooks bool
	ColorOverrides    map[string]string
	Styles            *StyleOverrides
}

type Result struct {
	SessionID     string             `json:"session_id"`
	GenerationID  string             `json:"generation_id"`
	Variant       generation.Variant `json:"variant"`
	ThemeName     string             `json:"theme_name"`
	PID           int                `json:"pid,omitempty"`
	AlreadyActive bool               `json:"already_active"`
	LogPath       string             `json:"log_path"`
}
