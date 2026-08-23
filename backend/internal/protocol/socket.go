package protocol

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const (
	WireReady      = "ready"
	WireSnapshot   = "snapshot"
	WireEvent      = "event"
	WireNavigation = "navigation"
	WireError      = "error"
)

type Request struct {
	Command      string `json:"command"`
	After        uint64 `json:"after,omitempty"`
	Buffer       int    `json:"buffer,omitempty"`
	CheckpointID string `json:"checkpoint_id,omitempty"`
}

type WireMessage struct {
	Type       string            `json:"type"`
	Event      *Event            `json:"event,omitempty"`
	Snapshot   *Snapshot         `json:"snapshot,omitempty"`
	Navigation *NavigationResult `json:"navigation,omitempty"`
	Error      string            `json:"error,omitempty"`
}

type Server struct {
	journal      *Journal
	socketPath   string
	pollInterval time.Duration
}

func NewServer(journal *Journal, socketPath string, pollInterval time.Duration) *Server {
	if pollInterval <= 0 {
		pollInterval = 100 * time.Millisecond
	}
	return &Server{journal: journal, socketPath: socketPath, pollInterval: pollInterval}
}

func (s *Server) Serve(ctx context.Context) error {
	if s == nil || s.journal == nil {
		return fmt.Errorf("protocol server has no journal")
	}
	if s.socketPath == "" || !filepath.IsAbs(s.socketPath) {
		return fmt.Errorf("protocol socket path must be absolute")
	}
	if err := fsutil.EnsureDir(filepath.Dir(s.socketPath), 0o755); err != nil {
		return fmt.Errorf("prepare protocol socket: %w", err)
	}
	if info, err := os.Lstat(s.socketPath); err == nil {
		if info.Mode()&os.ModeSocket == 0 {
			return fmt.Errorf("protocol socket path is not a socket")
		}
		if err := os.Remove(s.socketPath); err != nil {
			return fmt.Errorf("remove stale protocol socket: %w", err)
		}
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("inspect protocol socket: %w", err)
	}

	listener, err := net.Listen("unix", s.socketPath)
	if err != nil {
		return fmt.Errorf("listen on protocol socket: %w", err)
	}
	defer os.Remove(s.socketPath)
	defer listener.Close()

	var workers sync.WaitGroup
	stopAccept := make(chan struct{})
	go func() {
		select {
		case <-ctx.Done():
			_ = listener.Close()
		case <-stopAccept:
		}
	}()
	defer close(stopAccept)

	for {
		_ = listener.(*net.UnixListener).SetDeadline(time.Now().Add(s.pollInterval))
		connection, acceptErr := listener.Accept()
		if acceptErr != nil {
			if ctx.Err() != nil || errors.Is(acceptErr, net.ErrClosed) {
				break
			}
			if netErr, ok := acceptErr.(net.Error); ok && netErr.Timeout() {
				_, _ = s.journal.Refresh()
				continue
			}
			return fmt.Errorf("accept protocol connection: %w", acceptErr)
		}
		workers.Add(1)
		go func() {
			defer workers.Done()
			defer connection.Close()
			s.handle(ctx, connection)
		}()
	}
	workers.Wait()
	return nil
}

func (s *Server) handle(ctx context.Context, connection net.Conn) {
	decoder := json.NewDecoder(bufio.NewReader(connection))
	var request Request
	if err := decoder.Decode(&request); err != nil {
		_ = writeWire(connection, WireMessage{Type: WireError, Error: err.Error()})
		return
	}
	switch request.Command {
	case "ping":
		_ = writeWire(connection, WireMessage{Type: WireReady})
	case "snapshot":
		snapshot, err := s.journal.Snapshot()
		if err != nil {
			_ = writeWire(connection, WireMessage{Type: WireError, Error: err.Error()})
			return
		}
		_ = writeWire(connection, WireMessage{Type: WireSnapshot, Snapshot: &snapshot})
	case "back":
		navigation, err := s.journal.Back()
		s.writeNavigation(connection, navigation, err)
	case "forward":
		navigation, err := s.journal.Forward(request.CheckpointID)
		s.writeNavigation(connection, navigation, err)
	case "subscribe":
		s.subscribe(ctx, connection, request.After, request.Buffer)
	default:
		_ = writeWire(connection, WireMessage{Type: WireError, Error: fmt.Sprintf("unknown protocol command %q", request.Command)})
	}
}

func (s *Server) subscribe(ctx context.Context, connection net.Conn, after uint64, buffer int) {
	snapshot, err := s.journal.Snapshot()
	if err != nil {
		_ = writeWire(connection, WireMessage{Type: WireError, Error: err.Error()})
		return
	}
	if after > snapshot.LastSequence {
		_ = writeWire(connection, WireMessage{Type: WireError, Error: fmt.Sprintf("protocol sequence %d is newer than snapshot %d", after, snapshot.LastSequence)})
		return
	}
	subscription, err := s.journal.Subscribe(snapshot.LastSequence, buffer)
	if err != nil {
		_ = writeWire(connection, WireMessage{Type: WireError, Error: err.Error()})
		return
	}
	defer subscription.Close()
	if err := writeWire(connection, WireMessage{Type: WireSnapshot, Snapshot: &snapshot}); err != nil {
		return
	}
	for {
		select {
		case <-ctx.Done():
			return
		case event, ok := <-subscription.Events:
			if !ok {
				return
			}
			if err := writeWire(connection, WireMessage{Type: WireEvent, Event: &event}); err != nil {
				return
			}
		case subscriptionErr, ok := <-subscription.Errors:
			if ok && subscriptionErr != nil {
				_ = writeWire(connection, WireMessage{Type: WireError, Error: subscriptionErr.Error()})
			}
			return
		}
	}
}

func (s *Server) writeNavigation(connection net.Conn, navigation NavigationResult, err error) {
	if err != nil {
		_ = writeWire(connection, WireMessage{Type: WireError, Error: err.Error()})
		return
	}
	_ = writeWire(connection, WireMessage{Type: WireNavigation, Navigation: &navigation})
}

func writeWire(connection net.Conn, message WireMessage) error {
	encoded, err := json.Marshal(message)
	if err != nil {
		return err
	}
	_, err = connection.Write(append(encoded, '\n'))
	return err
}

func EventsPath(stateRoot, sessionID string) string {
	return filepath.Join(stateRoot, "protocol", sessionID, "events.jsonl")
}

func SocketPath(stateRoot, sessionID string) string {
	return filepath.Join(stateRoot, "protocol", sessionID, "events.sock")
}
