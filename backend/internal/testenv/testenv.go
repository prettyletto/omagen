// Package testenv contains shared process-environment setup for filesystem
// backed Omagen tests. Keeping all XDG roots under one temporary directory
// prevents tests from ever writing to the developer's real Omagen state.
package testenv

import (
	"path/filepath"
	"testing"
)

func Isolate(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	t.Setenv("HOME", root)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(root, "config"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(root, "cache"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	return root
}
