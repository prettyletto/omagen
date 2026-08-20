package session

import "errors"

var (
	ErrActiveSession        = errors.New("another Omagen session is already active")
	ErrSessionNotActive     = errors.New("session is not the active Omagen session")
	ErrActiveSessionCorrupt = errors.New("active Omagen session cannot be recovered safely")
)
