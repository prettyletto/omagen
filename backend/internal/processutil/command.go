// Package processutil contains the narrow subprocess safeguards shared by
// Omagen's user-level adapters. It never invokes a shell implicitly.
package processutil

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os/exec"
)

const DefaultOutputLimit int64 = 64 * 1024

var ErrOutputLimit = errors.New("subprocess output exceeded the safety limit")

// LimitedBuffer retains only a bounded prefix while still consuming the
// child's pipe. Returning len(p) after truncation prevents a child from
// blocking on a full pipe; callers can inspect Truncated and fail closed.
type LimitedBuffer struct {
	bytes.Buffer
	limit     int64
	truncated bool
}

func NewLimitedBuffer(limit int64) *LimitedBuffer {
	return &LimitedBuffer{limit: limit}
}

func (b *LimitedBuffer) Write(p []byte) (int, error) {
	if b.limit <= 0 || int64(b.Len()) >= b.limit {
		b.truncated = true
		return len(p), nil
	}
	remaining := b.limit - int64(b.Len())
	if int64(len(p)) > remaining {
		_, _ = b.Buffer.Write(p[:remaining])
		b.truncated = true
		return len(p), nil
	}
	return b.Buffer.Write(p)
}

func (b *LimitedBuffer) Truncated() bool { return b.truncated }

// Resolve returns the absolute executable selected from PATH. The caller can
// then execute that exact path instead of resolving PATH again at Start time.
func Resolve(name string) (string, error) {
	path, err := exec.LookPath(name)
	if err != nil {
		return "", err
	}
	return path, nil
}

// Run executes one already-declared executable with bounded stdout/stderr.
// It is intended for short, read-only adapters such as version and compositor
// queries. The caller owns the context timeout.
func Run(ctx context.Context, name string, args ...string) (stdout, stderr string, err error) {
	return RunWithEnv(ctx, nil, name, args...)
}

func RunWithEnv(ctx context.Context, environment []string, name string, args ...string) (stdout, stderr string, err error) {
	path, err := Resolve(name)
	if err != nil {
		return "", "", fmt.Errorf("resolve %q: %w", name, err)
	}
	command := exec.CommandContext(ctx, path, args...)
	if environment != nil {
		command.Env = environment
	}
	stdoutBuffer := NewLimitedBuffer(DefaultOutputLimit)
	stderrBuffer := NewLimitedBuffer(DefaultOutputLimit)
	command.Stdout = stdoutBuffer
	command.Stderr = stderrBuffer
	err = command.Run()
	if stdoutBuffer.Truncated() || stderrBuffer.Truncated() {
		if err == nil {
			err = ErrOutputLimit
		} else {
			err = errors.Join(err, ErrOutputLimit)
		}
	}
	return stdoutBuffer.String(), stderrBuffer.String(), err
}
