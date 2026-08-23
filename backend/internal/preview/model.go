package preview

import "github.com/prettyletto/omagen/backend/internal/generation"

type Request struct {
	SessionID         string
	GenerationID      string
	Variant           generation.Variant
	RetintRun         string
	RetintSkip        string
	Scope             string
	WaitMode          string
	AllowTrustedHooks bool
}

type Result struct {
	SessionID          string             `json:"session_id"`
	GenerationID       string             `json:"generation_id"`
	Variant            generation.Variant `json:"variant"`
	ThemeName          string             `json:"theme_name"`
	PID                int                `json:"pid,omitempty"`
	AlreadyActive      bool               `json:"already_active"`
	LogPath            string             `json:"log_path"`
	ProtocolOperation  string             `json:"protocol_operation,omitempty"`
	ProtocolCheckpoint string             `json:"protocol_checkpoint,omitempty"`
	ProtocolEvents     string             `json:"protocol_events,omitempty"`
	ProtocolSocket     string             `json:"protocol_socket,omitempty"`
}
