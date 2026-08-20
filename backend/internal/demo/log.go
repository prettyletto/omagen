package demo

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"
)

// launchLogger writes one append operation per entry so asynchronous launcher
// completion messages can safely arrive after the Open call has returned.
type launchLogger struct {
	path string
	mu   sync.Mutex
}

func newLaunchLogger(path string) (*launchLogger, error) {
	file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0600)
	if err != nil {
		return nil, err
	}
	if err := file.Close(); err != nil {
		return nil, err
	}
	logger := &launchLogger{path: path}
	logger.line("demo launch log started")
	return logger, nil
}

// appendLaunchLogger preserves the launch timeline and lets the shutdown path
// record whether it reached a safe point before a theme restore is attempted.
func appendLaunchLogger(path string) *launchLogger {
	logger := &launchLogger{path: path}
	logger.line("demo shutdown log resumed")
	return logger
}

func (l *launchLogger) line(format string, args ...any) {
	if l == nil {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()

	file, err := os.OpenFile(l.path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		return
	}
	defer file.Close()
	_, _ = fmt.Fprintf(file, "%s %s\n", time.Now().UTC().Format(time.RFC3339Nano), fmt.Sprintf(format, args...))
}

func (l *launchLogger) jsonLine(label string, value any) {
	data, err := json.Marshal(value)
	if err != nil {
		l.line("%s: <json error: %v>", label, err)
		return
	}
	l.line("%s: %s", label, data)
}
