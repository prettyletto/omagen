package protocol

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const (
	maxEventBytes   = 256 * 1024
	maxPayloadBytes = 128 * 1024
)

var (
	ErrOperationNotFound    = errors.New("protocol operation not found")
	ErrCheckpointNotFound   = errors.New("protocol checkpoint not found")
	ErrOperationClosed      = errors.New("protocol operation is closed")
	ErrNoHistory            = errors.New("protocol has no previous checkpoint")
	ErrNoForward            = errors.New("protocol has no forward checkpoint")
	ErrAmbiguousForward     = errors.New("protocol forward navigation requires a checkpoint")
	ErrInvalidPayload       = errors.New("protocol payload is invalid")
	ErrSubscriptionOverflow = errors.New("protocol subscription buffer overflow")
	ErrJournalChanged       = errors.New("protocol journal changed while subscribed")
)

type EventType string

const (
	EventOperationStarted   EventType = "operation.started"
	EventOperationProgress  EventType = "operation.progress"
	EventOperationCompleted EventType = "operation.completed"
	EventCheckpointCreated  EventType = "checkpoint.created"
	EventCursorMoved        EventType = "cursor.moved"
)

type Status string

const (
	StatusRunning   Status = "running"
	StatusSucceeded Status = "succeeded"
	StatusFailed    Status = "failed"
	StatusCancelled Status = "cancelled"
)

type Event struct {
	Sequence           uint64          `json:"sequence"`
	ID                 string          `json:"id"`
	Type               EventType       `json:"type"`
	At                 time.Time       `json:"at"`
	OperationID        string          `json:"operation_id,omitempty"`
	ParentOperationID  string          `json:"parent_operation_id,omitempty"`
	CheckpointID       string          `json:"checkpoint_id,omitempty"`
	ParentCheckpointID string          `json:"parent_checkpoint_id,omitempty"`
	SessionID          string          `json:"session_id,omitempty"`
	GenerationID       string          `json:"generation_id,omitempty"`
	Variant            string          `json:"variant,omitempty"`
	Name               string          `json:"name,omitempty"`
	Status             Status          `json:"status,omitempty"`
	Message            string          `json:"message,omitempty"`
	Evidence           string          `json:"evidence,omitempty"`
	Payload            json.RawMessage `json:"payload,omitempty"`
}

type OperationInput struct {
	ParentID     string
	Name         string
	SessionID    string
	GenerationID string
	Variant      string
}

type Operation struct {
	ID           string    `json:"id"`
	ParentID     string    `json:"parent_id,omitempty"`
	Name         string    `json:"name"`
	SessionID    string    `json:"session_id,omitempty"`
	GenerationID string    `json:"generation_id,omitempty"`
	Variant      string    `json:"variant,omitempty"`
	Status       Status    `json:"status"`
	Message      string    `json:"message,omitempty"`
	Evidence     string    `json:"evidence,omitempty"`
	StartedAt    time.Time `json:"started_at"`
	FinishedAt   time.Time `json:"finished_at,omitempty"`
	Children     []string  `json:"children,omitempty"`
}

type CheckpointInput struct {
	ParentID    string
	OperationID string
	Name        string
	State       json.RawMessage
}

type Checkpoint struct {
	ID          string          `json:"id"`
	ParentID    string          `json:"parent_id,omitempty"`
	OperationID string          `json:"operation_id,omitempty"`
	Name        string          `json:"name,omitempty"`
	State       json.RawMessage `json:"state"`
	CreatedAt   time.Time       `json:"created_at"`
	Children    []string        `json:"children,omitempty"`
}

type Snapshot struct {
	LastSequence        uint64          `json:"last_sequence"`
	Operations          []Operation     `json:"operations"`
	RootOperationIDs    []string        `json:"root_operation_ids,omitempty"`
	Checkpoints         []Checkpoint    `json:"checkpoints"`
	CurrentCheckpointID string          `json:"current_checkpoint_id,omitempty"`
	CurrentState        json.RawMessage `json:"current_state,omitempty"`
}

type NavigationResult struct {
	Direction        string          `json:"direction"`
	FromCheckpointID string          `json:"from_checkpoint_id,omitempty"`
	ToCheckpointID   string          `json:"to_checkpoint_id"`
	Checkpoint       Checkpoint      `json:"checkpoint"`
	State            json.RawMessage `json:"state"`
}

type Journal struct {
	mu sync.Mutex

	path     string
	lockPath string
	events   []Event

	operations        map[string]*Operation
	operationOrder    []string
	checkpoints       map[string]*Checkpoint
	checkpointOrder   []string
	currentCheckpoint string
	currentState      json.RawMessage
	nextOperation     uint64
	nextCheckpoint    uint64

	subscribers      map[uint64]*Subscription
	nextSubscription uint64
}

type Subscription struct {
	Events <-chan Event
	Errors <-chan error

	journal       *Journal
	id            uint64
	eventsChannel chan Event
	errorsChannel chan error
}

func Open(path string) (*Journal, error) {
	if path == "" || !filepath.IsAbs(path) {
		return nil, fmt.Errorf("protocol journal path must be absolute")
	}
	if err := fsutil.EnsureDir(filepath.Dir(path), 0o755); err != nil {
		return nil, fmt.Errorf("prepare protocol journal: %w", err)
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return nil, fmt.Errorf("open protocol journal: %w", err)
	}
	if err := file.Close(); err != nil {
		return nil, fmt.Errorf("close protocol journal: %w", err)
	}

	journal := &Journal{
		path:           path,
		lockPath:       path + ".lock",
		operations:     make(map[string]*Operation),
		checkpoints:    make(map[string]*Checkpoint),
		nextOperation:  1,
		nextCheckpoint: 1,
		subscribers:    make(map[uint64]*Subscription),
	}
	journal.mu.Lock()
	defer journal.mu.Unlock()
	if err := journal.syncFromDiskLocked(false); err != nil {
		return nil, err
	}
	return journal, nil
}

func (j *Journal) Path() string { return j.path }

func (j *Journal) StartOperation(input OperationInput) (Operation, error) {
	if strings.TrimSpace(input.Name) == "" {
		return Operation{}, fmt.Errorf("operation name is required")
	}
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return Operation{}, err
	}
	if input.ParentID != "" {
		parent, ok := j.operations[input.ParentID]
		if !ok {
			return Operation{}, ErrOperationNotFound
		}
		if isOperationClosed(parent.Status) {
			return Operation{}, ErrOperationClosed
		}
	}
	id := fmt.Sprintf("operation-%06d", j.nextOperation)
	j.nextOperation++
	_, err := j.appendLocked(Event{
		Type:              EventOperationStarted,
		OperationID:       id,
		ParentOperationID: input.ParentID,
		SessionID:         input.SessionID,
		GenerationID:      input.GenerationID,
		Variant:           input.Variant,
		Name:              input.Name,
		Status:            StatusRunning,
	})
	if err != nil {
		return Operation{}, err
	}
	return cloneOperation(*j.operations[id]), nil
}

func (j *Journal) Progress(operationID, message, evidence string, payload json.RawMessage) (Event, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return Event{}, err
	}
	operation, ok := j.operations[operationID]
	if !ok {
		return Event{}, ErrOperationNotFound
	}
	if isOperationClosed(operation.Status) {
		return Event{}, ErrOperationClosed
	}
	return j.appendLocked(Event{Type: EventOperationProgress, OperationID: operationID, Message: message, Evidence: evidence, Payload: clonePayload(payload)})
}

func (j *Journal) CompleteOperation(operationID string, status Status, message, evidence string) (Event, error) {
	if !isOperationClosed(status) {
		return Event{}, fmt.Errorf("completion status must be terminal")
	}
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return Event{}, err
	}
	operation, ok := j.operations[operationID]
	if !ok {
		return Event{}, ErrOperationNotFound
	}
	if isOperationClosed(operation.Status) {
		return Event{}, ErrOperationClosed
	}
	return j.appendLocked(Event{Type: EventOperationCompleted, OperationID: operationID, Status: status, Message: message, Evidence: evidence})
}

func (j *Journal) CreateCheckpoint(input CheckpointInput) (Checkpoint, error) {
	if err := validatePayload(input.State); err != nil {
		return Checkpoint{}, err
	}
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return Checkpoint{}, err
	}
	parentID := input.ParentID
	if parentID == "" {
		parentID = j.currentCheckpoint
	}
	if parentID != "" {
		if _, ok := j.checkpoints[parentID]; !ok {
			return Checkpoint{}, ErrCheckpointNotFound
		}
	}
	if input.OperationID != "" {
		if _, ok := j.operations[input.OperationID]; !ok {
			return Checkpoint{}, ErrOperationNotFound
		}
	}
	id := fmt.Sprintf("checkpoint-%06d", j.nextCheckpoint)
	j.nextCheckpoint++
	_, err := j.appendLocked(Event{
		Type:               EventCheckpointCreated,
		OperationID:        input.OperationID,
		CheckpointID:       id,
		ParentCheckpointID: parentID,
		Name:               input.Name,
		Payload:            clonePayload(input.State),
	})
	if err != nil {
		return Checkpoint{}, err
	}
	return cloneCheckpoint(*j.checkpoints[id]), nil
}

func (j *Journal) Back() (NavigationResult, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return NavigationResult{}, err
	}
	target, err := j.navigationTargetLocked("back", "")
	if err != nil {
		return NavigationResult{}, err
	}
	return j.moveCursorLocked("back", target.FromCheckpointID, target.ToCheckpointID)
}

func (j *Journal) Forward(checkpointID string) (NavigationResult, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return NavigationResult{}, err
	}
	target, err := j.navigationTargetLocked("forward", checkpointID)
	if err != nil {
		return NavigationResult{}, err
	}
	return j.moveCursorLocked("forward", target.FromCheckpointID, target.ToCheckpointID)
}

// NavigationTarget returns the adjacent checkpoint without changing the
// cursor. Executors use this to perform the native mutation first and commit
// cursor movement only after the mutation has succeeded.
func (j *Journal) NavigationTarget(direction, checkpointID string) (NavigationResult, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return NavigationResult{}, err
	}
	return j.navigationTargetLocked(direction, checkpointID)
}

// MoveCursor commits movement to an adjacent checkpoint. It is intentionally
// narrower than Back/Forward so an executor cannot jump across the tree or
// commit a stale target after another writer moved the cursor.
func (j *Journal) MoveCursor(checkpointID string) (NavigationResult, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return NavigationResult{}, err
	}
	current, ok := j.checkpoints[j.currentCheckpoint]
	if !ok {
		return NavigationResult{}, ErrNoForward
	}
	target, ok := j.checkpoints[checkpointID]
	if !ok {
		return NavigationResult{}, ErrCheckpointNotFound
	}
	if target.ParentID == current.ID {
		if !contains(current.Children, target.ID) {
			return NavigationResult{}, ErrCheckpointNotFound
		}
		return j.moveCursorLocked("forward", current.ID, target.ID)
	}
	if current.ParentID == target.ID {
		return j.moveCursorLocked("back", current.ID, target.ID)
	}
	return NavigationResult{}, fmt.Errorf("checkpoint %q is not adjacent to current checkpoint %q", checkpointID, current.ID)
}

func (j *Journal) Snapshot() (Snapshot, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return Snapshot{}, err
	}
	return j.snapshotLocked(), nil
}

func (j *Journal) Events(after uint64) ([]Event, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(true); err != nil {
		return nil, err
	}
	result := make([]Event, 0)
	for _, event := range j.events {
		if event.Sequence > after {
			result = append(result, cloneEvent(event))
		}
	}
	return result, nil
}

func (j *Journal) Subscribe(after uint64, buffer int) (*Subscription, error) {
	if buffer < 1 {
		buffer = 1
	}
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.syncFromDiskLocked(false); err != nil {
		return nil, err
	}
	replay := make([]Event, 0)
	for _, event := range j.events {
		if event.Sequence > after {
			replay = append(replay, cloneEvent(event))
		}
	}
	if len(replay)+1 > buffer {
		buffer = len(replay) + 1
	}
	events := make(chan Event, buffer)
	errorsChannel := make(chan error, 1)
	for _, event := range replay {
		events <- event
	}
	j.nextSubscription++
	subscription := &Subscription{Events: events, Errors: errorsChannel, eventsChannel: events, errorsChannel: errorsChannel, journal: j, id: j.nextSubscription}
	j.subscribers[subscription.id] = subscription
	return subscription, nil
}

func (s *Subscription) Close() {
	if s == nil || s.journal == nil {
		return
	}
	s.journal.mu.Lock()
	defer s.journal.mu.Unlock()
	s.journal.closeSubscriptionLocked(s.id, nil)
	s.journal = nil
}

func (j *Journal) Refresh() ([]Event, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	before := len(j.events)
	if err := j.syncFromDiskLocked(true); err != nil {
		return nil, err
	}
	if before == len(j.events) {
		return nil, nil
	}
	result := make([]Event, 0, len(j.events)-before)
	for _, event := range j.events[before:] {
		result = append(result, cloneEvent(event))
	}
	return result, nil
}

func (j *Journal) navigationTargetLocked(direction, checkpointID string) (NavigationResult, error) {
	current, ok := j.checkpoints[j.currentCheckpoint]
	if !ok {
		if direction == "back" {
			return NavigationResult{}, ErrNoHistory
		}
		return NavigationResult{}, ErrNoForward
	}
	targetID := checkpointID
	switch direction {
	case "back":
		if current.ParentID == "" {
			return NavigationResult{}, ErrNoHistory
		}
		targetID = current.ParentID
	case "forward":
		if len(current.Children) == 0 {
			return NavigationResult{}, ErrNoForward
		}
		if targetID == "" {
			if len(current.Children) != 1 {
				return NavigationResult{}, ErrAmbiguousForward
			}
			targetID = current.Children[0]
		}
		if !contains(current.Children, targetID) {
			return NavigationResult{}, ErrCheckpointNotFound
		}
	default:
		return NavigationResult{}, fmt.Errorf("unknown protocol navigation direction %q", direction)
	}
	target, ok := j.checkpoints[targetID]
	if !ok {
		return NavigationResult{}, ErrCheckpointNotFound
	}
	return NavigationResult{
		Direction:        direction,
		FromCheckpointID: current.ID,
		ToCheckpointID:   target.ID,
		Checkpoint:       cloneCheckpoint(*target),
		State:            clonePayload(target.State),
	}, nil
}

func (j *Journal) moveCursorLocked(direction, fromID, toID string) (NavigationResult, error) {
	target, ok := j.checkpoints[toID]
	if !ok {
		return NavigationResult{}, ErrCheckpointNotFound
	}
	if _, err := j.appendLocked(Event{
		Type:               EventCursorMoved,
		CheckpointID:       toID,
		ParentCheckpointID: fromID,
		Status:             StatusSucceeded,
		Message:            direction,
	}); err != nil {
		return NavigationResult{}, err
	}
	return NavigationResult{
		Direction:        direction,
		FromCheckpointID: fromID,
		ToCheckpointID:   toID,
		Checkpoint:       cloneCheckpoint(*target),
		State:            clonePayload(target.State),
	}, nil
}

func (j *Journal) appendLocked(event Event) (Event, error) {
	fileLock, err := fsutil.AcquireFileLock(j.lockPath)
	if err != nil {
		return Event{}, fmt.Errorf("lock protocol journal: %w", err)
	}
	defer fileLock.Close()
	if err := j.syncFromDiskUnlocked(true); err != nil {
		return Event{}, err
	}
	event.Sequence = uint64(len(j.events) + 1)
	event.ID = fmt.Sprintf("event-%06d", event.Sequence)
	event.At = time.Now().UTC()
	if err := validateEvent(event); err != nil {
		return Event{}, err
	}
	encoded, err := json.Marshal(event)
	if err != nil {
		return Event{}, fmt.Errorf("encode protocol event: %w", err)
	}
	if len(encoded) > maxEventBytes {
		return Event{}, fmt.Errorf("protocol event exceeds %d bytes", maxEventBytes)
	}
	file, err := os.OpenFile(j.path, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return Event{}, fmt.Errorf("open protocol journal for append: %w", err)
	}
	if _, err := file.Write(append(encoded, '\n')); err != nil {
		_ = file.Close()
		return Event{}, fmt.Errorf("append protocol event: %w", err)
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		return Event{}, fmt.Errorf("sync protocol event: %w", err)
	}
	if err := file.Close(); err != nil {
		return Event{}, fmt.Errorf("close protocol journal: %w", err)
	}
	if err := j.applyEvent(event); err != nil {
		return Event{}, fmt.Errorf("apply appended protocol event: %w", err)
	}
	j.events = append(j.events, event)
	j.broadcastLocked(event)
	return cloneEvent(event), nil
}

func (j *Journal) syncFromDiskLocked(broadcast bool) error {
	fileLock, err := fsutil.AcquireFileLock(j.lockPath)
	if err != nil {
		return fmt.Errorf("lock protocol journal for read: %w", err)
	}
	defer fileLock.Close()
	return j.syncFromDiskUnlocked(broadcast)
}

func (j *Journal) syncFromDiskUnlocked(broadcast bool) error {
	events, err := readEvents(j.path)
	if err != nil {
		return err
	}
	if sameEventPrefix(j.events, events) {
		for _, event := range events[len(j.events):] {
			if err := j.applyEvent(event); err != nil {
				return fmt.Errorf("replay protocol event %d: %w", event.Sequence, err)
			}
			j.events = append(j.events, event)
			if broadcast {
				j.broadcastLocked(event)
			}
		}
		return nil
	}

	oldEvents := j.events
	j.resetState()
	for _, event := range events {
		if err := j.applyEvent(event); err != nil {
			return fmt.Errorf("rebuild protocol event %d: %w", event.Sequence, err)
		}
	}
	j.events = events
	if broadcast && len(oldEvents) > 0 {
		j.closeSubscribersLocked(ErrJournalChanged)
	}
	return nil
}

func (j *Journal) resetState() {
	j.events = nil
	j.operations = make(map[string]*Operation)
	j.operationOrder = nil
	j.checkpoints = make(map[string]*Checkpoint)
	j.checkpointOrder = nil
	j.currentCheckpoint = ""
	j.currentState = nil
	j.nextOperation = 1
	j.nextCheckpoint = 1
}

func (j *Journal) applyEvent(event Event) error {
	switch event.Type {
	case EventOperationStarted:
		if event.OperationID == "" || event.Name == "" || event.Status != StatusRunning {
			return fmt.Errorf("invalid operation.started event")
		}
		if _, exists := j.operations[event.OperationID]; exists {
			return fmt.Errorf("duplicate operation %s", event.OperationID)
		}
		if event.ParentOperationID != "" {
			parent, exists := j.operations[event.ParentOperationID]
			if !exists {
				return ErrOperationNotFound
			}
			parent.Children = append(parent.Children, event.OperationID)
		}
		j.operations[event.OperationID] = &Operation{
			ID: event.OperationID, ParentID: event.ParentOperationID, Name: event.Name,
			SessionID: event.SessionID, GenerationID: event.GenerationID, Variant: event.Variant,
			Status: event.Status, StartedAt: event.At,
		}
		j.operationOrder = append(j.operationOrder, event.OperationID)
		j.advanceID(&j.nextOperation, event.OperationID, "operation-")
	case EventOperationProgress:
		operation, exists := j.operations[event.OperationID]
		if !exists {
			return ErrOperationNotFound
		}
		if isOperationClosed(operation.Status) {
			return ErrOperationClosed
		}
		operation.Message = event.Message
		operation.Evidence = event.Evidence
	case EventOperationCompleted:
		operation, exists := j.operations[event.OperationID]
		if !exists {
			return ErrOperationNotFound
		}
		if isOperationClosed(operation.Status) {
			return ErrOperationClosed
		}
		if !isOperationClosed(event.Status) {
			return fmt.Errorf("invalid terminal operation status")
		}
		operation.Status = event.Status
		operation.Message = event.Message
		operation.Evidence = event.Evidence
		operation.FinishedAt = event.At
	case EventCheckpointCreated:
		if event.CheckpointID == "" {
			return fmt.Errorf("checkpoint id is required")
		}
		if _, exists := j.checkpoints[event.CheckpointID]; exists {
			return fmt.Errorf("duplicate checkpoint %s", event.CheckpointID)
		}
		if event.ParentCheckpointID != "" {
			parent, exists := j.checkpoints[event.ParentCheckpointID]
			if !exists {
				return ErrCheckpointNotFound
			}
			parent.Children = append(parent.Children, event.CheckpointID)
		}
		if event.OperationID != "" {
			if _, exists := j.operations[event.OperationID]; !exists {
				return ErrOperationNotFound
			}
		}
		checkpoint := &Checkpoint{ID: event.CheckpointID, ParentID: event.ParentCheckpointID, OperationID: event.OperationID, Name: event.Name, State: clonePayload(event.Payload), CreatedAt: event.At}
		j.checkpoints[event.CheckpointID] = checkpoint
		j.checkpointOrder = append(j.checkpointOrder, event.CheckpointID)
		j.currentCheckpoint = event.CheckpointID
		j.currentState = clonePayload(event.Payload)
		j.advanceID(&j.nextCheckpoint, event.CheckpointID, "checkpoint-")
	case EventCursorMoved:
		checkpoint, exists := j.checkpoints[event.CheckpointID]
		if !exists {
			return ErrCheckpointNotFound
		}
		from, exists := j.checkpoints[event.ParentCheckpointID]
		if !exists {
			return ErrCheckpointNotFound
		}
		if event.ParentCheckpointID != j.currentCheckpoint {
			return fmt.Errorf("cursor moved from %q while current checkpoint is %q", event.ParentCheckpointID, j.currentCheckpoint)
		}
		if checkpoint.ParentID != from.ID && from.ParentID != checkpoint.ID && !contains(from.Children, checkpoint.ID) {
			return fmt.Errorf("checkpoint %q is not adjacent to cursor", event.CheckpointID)
		}
		j.currentCheckpoint = checkpoint.ID
		j.currentState = clonePayload(checkpoint.State)
	default:
		return fmt.Errorf("unknown protocol event type %q", event.Type)
	}
	return nil
}

func (j *Journal) advanceID(next *uint64, id, prefix string) {
	number := strings.TrimPrefix(id, prefix)
	var parsed uint64
	if _, err := fmt.Sscanf(number, "%d", &parsed); err == nil && parsed >= *next {
		*next = parsed + 1
	}
}

func (j *Journal) snapshotLocked() Snapshot {
	snapshot := Snapshot{LastSequence: uint64(len(j.events)), CurrentCheckpointID: j.currentCheckpoint, CurrentState: clonePayload(j.currentState)}
	for _, id := range j.operationOrder {
		snapshot.Operations = append(snapshot.Operations, cloneOperation(*j.operations[id]))
		if j.operations[id].ParentID == "" {
			snapshot.RootOperationIDs = append(snapshot.RootOperationIDs, id)
		}
	}
	for _, id := range j.checkpointOrder {
		snapshot.Checkpoints = append(snapshot.Checkpoints, cloneCheckpoint(*j.checkpoints[id]))
	}
	return snapshot
}

func (j *Journal) broadcastLocked(event Event) {
	for id, subscription := range j.subscribers {
		select {
		case subscription.eventsChannel <- cloneEvent(event):
		default:
			j.closeSubscriptionLocked(id, ErrSubscriptionOverflow)
		}
	}
}

func (j *Journal) closeSubscribersLocked(err error) {
	for id := range j.subscribers {
		j.closeSubscriptionLocked(id, err)
	}
}

func (j *Journal) closeSubscriptionLocked(id uint64, err error) {
	subscription, ok := j.subscribers[id]
	if !ok {
		return
	}
	delete(j.subscribers, id)
	if err != nil {
		subscription.errorsChannel <- err
	}
	close(subscription.eventsChannel)
	close(subscription.errorsChannel)
}

func readEvents(path string) ([]Event, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open protocol journal: %w", err)
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 4096), maxEventBytes)
	var events []Event
	var previous uint64
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var event Event
		if err := json.Unmarshal([]byte(line), &event); err != nil {
			return nil, fmt.Errorf("decode protocol event: %w", err)
		}
		if event.Sequence == 0 || event.Sequence != previous+1 || event.ID == "" {
			return nil, fmt.Errorf("invalid protocol event sequence %d", event.Sequence)
		}
		if err := validateEvent(event); err != nil {
			return nil, err
		}
		previous = event.Sequence
		events = append(events, event)
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("read protocol journal: %w", err)
	}
	return events, nil
}

func validateEvent(event Event) error {
	if event.Type == "" || event.At.IsZero() {
		return fmt.Errorf("protocol event is missing type or timestamp")
	}
	if len(event.Payload) > maxPayloadBytes || (len(event.Payload) > 0 && !json.Valid(event.Payload)) {
		return ErrInvalidPayload
	}
	return nil
}

func validatePayload(payload json.RawMessage) error {
	if len(payload) > maxPayloadBytes || (len(payload) > 0 && !json.Valid(payload)) {
		return ErrInvalidPayload
	}
	return nil
}

func isOperationClosed(status Status) bool {
	return status == StatusSucceeded || status == StatusFailed || status == StatusCancelled
}

func sameEventPrefix(previous, current []Event) bool {
	if len(previous) > len(current) {
		return false
	}
	for index, event := range previous {
		if event.Sequence != current[index].Sequence || event.ID != current[index].ID {
			return false
		}
	}
	return true
}

func contains(values []string, wanted string) bool {
	for _, value := range values {
		if value == wanted {
			return true
		}
	}
	return false
}

func cloneEvent(event Event) Event {
	event.Payload = clonePayload(event.Payload)
	return event
}

func cloneOperation(operation Operation) Operation {
	operation.Children = append([]string(nil), operation.Children...)
	return operation
}

func cloneCheckpoint(checkpoint Checkpoint) Checkpoint {
	checkpoint.Children = append([]string(nil), checkpoint.Children...)
	checkpoint.State = clonePayload(checkpoint.State)
	return checkpoint
}

func clonePayload(payload json.RawMessage) json.RawMessage {
	if len(payload) == 0 {
		return nil
	}
	return append(json.RawMessage(nil), payload...)
}
