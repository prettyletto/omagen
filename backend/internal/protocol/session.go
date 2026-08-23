package protocol

import (
	"fmt"
	"path/filepath"
)

type SessionPaths struct {
	Events string `json:"events"`
	Socket string `json:"socket"`
}

func OpenForSession(stateRoot, sessionID string) (*Journal, SessionPaths, error) {
	if stateRoot == "" || !filepath.IsAbs(stateRoot) {
		return nil, SessionPaths{}, fmt.Errorf("protocol state root must be absolute")
	}
	if sessionID == "" || sessionID == "." || sessionID == ".." || filepath.Base(sessionID) != sessionID {
		return nil, SessionPaths{}, fmt.Errorf("invalid protocol session id")
	}
	paths := SessionPaths{Events: EventsPath(stateRoot, sessionID), Socket: SocketPath(stateRoot, sessionID)}
	journal, err := Open(paths.Events)
	if err != nil {
		return nil, SessionPaths{}, err
	}
	return journal, paths, nil
}
