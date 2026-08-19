package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type PingResponse struct {
	OK      bool   `json:"ok"`
	Version string `json:"version"`
}

type SessionBeginResponse struct {
	SessionID          string `json:"session_id"`
	OriginalTheme      string `json:"original_theme"`
	OriginalBackground string `json:"original_background"`
}

type SessionRecord struct {
	SessionID          string    `json:"session_id"`
	OriginalTheme      string    `json:"original_theme"`
	OriginalBackground string    `json:"original_background"`
	CreatedAt          time.Time `json:"created_at"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "missing command")
		os.Exit(2)
	}

	switch os.Args[1] {
	case "ping":
		handlePing()
	case "session":
		handleSession(os.Args[2:])
	default:
		fatalf(2, "unkown command %s", os.Args[1])
	}
}

func handlePing() {
	writeJSON(PingResponse{
		OK:      true,
		Version: "dev",
	})
}

func handleSession(args []string) {
	if len(args) < 1 {
		fatalf(2, "missing session subcommand")
	}

	switch args[0] {
	case "begin":
		handleSessionBegin()
	default:
		fatalf(2, "unkown session subcommand: %s", args[0])
	}
}

func handleSessionBegin() {
	theme, err := readCurrentTheme()
	if err != nil {
		fatalf(1, "read current theme: %v", err)
	}

	background, err := readCurrentBackground()
	if err != nil {
		fatalf(1, "read current theme: %v", err)
	}

	sessionId, err := newSessionID()
	if err != nil {
		fatalf(1, "create sessions id: %v", err)
	}

	record := SessionRecord{
		SessionID:          sessionId,
		OriginalTheme:      theme,
		OriginalBackground: background,
		CreatedAt:          time.Now().UTC(),
	}

	if err := persistSession(record); err != nil {
		fatalf(1, "persist session: %v", err)
	}

	writeJSON(SessionBeginResponse{
		record.SessionID,
		record.OriginalTheme,
		record.OriginalBackground,
	})
}

func newSessionID() (string, error) {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}

	ts := time.Now().UTC().UTC().Format("2006102T1504052")
	pid := os.Getpid()
	suffix := hex.EncodeToString(b[:])

	return fmt.Sprintf("%s-%d-%s", ts, pid, suffix), nil
}

func persistSession(record SessionRecord) error {
	cacheRoot, err := os.UserCacheDir()
	if err != nil {
		return err
	}

	dir := filepath.Join(cacheRoot, "omagen", "sessions", record.SessionID)

	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	tmpPath := filepath.Join(dir, "session.json.tmp")
	finalPath := filepath.Join(dir, "session.json")

	f, err := os.OpenFile(tmpPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}

	enc := json.NewEncoder(f)
	enc.SetIndent("", " ")
	if err := enc.Encode(record); err != nil {
		_ = f.Close()
		return err
	}

	if err := f.Close(); err != nil {
		return err
	}

	return os.Rename(tmpPath, finalPath)
}

func readCurrentTheme() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}

	path := filepath.Join(home,
		".local",
		"state",
		"omarchy",
		"current",
		"theme.name")

	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}

	theme := strings.TrimSpace(string(data))
	if theme == "" {
		return "", fmt.Errorf("theme.name is empty")
	}
	return theme, nil
}

func readCurrentBackground() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}

	path := filepath.Join(home, ".local", "state", "omarchy", "current", "background")

	resolved, err := filepath.EvalSymlinks(path)
	if err == nil {
		return resolved, nil
	}

	info, statErr := os.Stat(path)
	if statErr == nil && !info.IsDir() {
		abs, absErr := filepath.Abs(path)
		if absErr != nil {
			return "", absErr
		}
		return abs, nil
	}
	return "", err
}

func writeJSON(v any) {
	enc := json.NewEncoder(os.Stdout)
	if err := enc.Encode(v); err != nil {
		fatalf(1, "write json: %v", err)
	}
}

func fatalf(code int, format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(code)
}
