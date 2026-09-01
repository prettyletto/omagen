package demo

import "time"

const workspacePrefix = "__omagen_demo_"

const (
	ModeFull   = "full"
	ModeWindow = "window"
	ModeShell  = "shell"
	ModeBar    = "bar"
)

type Slot string

const (
	SlotEditor Slot = "editor"
	SlotBtop   Slot = "btop"
	SlotShell  Slot = "shell"
	SlotFiles  Slot = "files"
)

type State struct {
	SessionID           string          `json:"session_id"`
	Mode                string          `json:"mode,omitempty"`
	Workspace           string          `json:"workspace"`
	DemoMonitor         string          `json:"demo_monitor"`
	OriginMonitor       string          `json:"origin_monitor"`
	OriginWorkspaceID   int             `json:"origin_workspace_id"`
	OriginWorkspaceName string          `json:"origin_workspace_name"`
	DemoDir             string          `json:"demo_dir"`
	OwnerToken          string          `json:"owner_token"`
	Windows             map[Slot]string `json:"windows"`
	CreatedAt           time.Time       `json:"created_at"`
}

func makeOwnerToken(sessionID string) string {
	if value := shortID(sessionID); value != "" {
		return value
	}
	return "session"
}

type OpenResult struct {
	OK        bool            `json:"ok"`
	SessionID string          `json:"session_id"`
	Mode      string          `json:"mode"`
	Workspace string          `json:"workspace"`
	Monitor   string          `json:"monitor"`
	DemoDir   string          `json:"demo_dir"`
	LogPath   string          `json:"log_path"`
	Reused    bool            `json:"reused"`
	Windows   map[Slot]string `json:"windows"`
}

type CloseResult struct {
	OK        bool   `json:"ok"`
	SessionID string `json:"session_id"`
	Closed    bool   `json:"closed"`
}

type CaptureResult struct {
	OK          bool   `json:"ok"`
	SessionID   string `json:"session_id"`
	PreviewPath string `json:"preview_path"`
}

type SessionStatus struct {
	Active  bool   `json:"active"`
	Mode    string `json:"mode,omitempty"`
	Monitor string `json:"monitor,omitempty"`
}

func normalizeMode(mode string) string {
	switch mode {
	case ModeWindow, ModeShell, ModeBar:
		return mode
	default:
		return ModeFull
	}
}
