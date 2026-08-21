package cli

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/apply"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/settings"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

func TestRunCommandValidation(t *testing.T) {
	for _, tc := range []struct {
		args    []string
		code    int
		message string
	}{
		{nil, 2, "missing command"}, {[]string{"unknown"}, 2, "unknown command"},
		{[]string{"session"}, 2, "missing session subcommand"}, {[]string{"session", "unknown"}, 2, "unknown session subcommand"},
		{[]string{"session", "cancel"}, 2, "usage:"}, {[]string{"generate"}, 2, "usage:"},
	} {
		t.Run(strings.Join(tc.args, "_"), func(t *testing.T) {
			var out, err bytes.Buffer
			if code := Run(tc.args, &out, &err); code != tc.code || !strings.Contains(err.String(), tc.message) {
				t.Fatalf("code=%d stderr=%q", code, err.String())
			}
		})
	}
}

func TestParseGenerateArgs(t *testing.T) {
	for _, args := range [][]string{
		{"session", "image", "--harmony", "triadic"},
		{"session", "image", "--harmony=triadic"},
	} {
		request, err := parseGenerateArgs(args)
		if err != nil {
			t.Fatal(err)
		}
		if request.Overrides.ColorTheory.Harmony == nil || string(*request.Overrides.ColorTheory.Harmony) != "triadic" {
			t.Fatalf("got harmony override %#v", request.Overrides.ColorTheory.Harmony)
		}
	}
}

func TestParseGenerateArgsRejectsInvalidOptions(t *testing.T) {
	for _, args := range [][]string{
		{"session", "image", "--harmony"},
		{"session", "image", "--harmony", "random"},
		{"session", "image", "--harmony=triadic", "--harmony", "auto"},
		{"session", "image", "--unknown"},
	} {
		if _, err := parseGenerateArgs(args); err == nil {
			t.Fatalf("expected args %v to fail", args)
		}
	}
}

func TestRunPing(t *testing.T) {
	var out, err bytes.Buffer
	if code := Run([]string{"ping"}, &out, &err); code != 0 {
		t.Fatalf("code=%d err=%q", code, err.String())
	}
	if !strings.Contains(out.String(), `"ok":true`) || !strings.Contains(out.String(), `"version":"1.0.0"`) {
		t.Fatalf("output=%q", out.String())
	}
}

func TestHelp(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if code := Run([]string{"--help"}, &stdout, &stderr); code != 0 {
		t.Fatalf("exit code = %d", code)
	}
	if !strings.Contains(stdout.String(), "image-based Omarchy theme generator") {
		t.Fatalf("unexpected stdout: %q", stdout.String())
	}
	if stderr.Len() != 0 {
		t.Fatalf("unexpected stderr: %q", stderr.String())
	}
}

func TestHelpAlias(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if code := Run([]string{"help"}, &stdout, &stderr); code != 0 {
		t.Fatalf("exit code = %d", code)
	}
}

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) { return 0, errWrite }

var errWrite = &writeError{}

type writeError struct{}

func (*writeError) Error() string { return "write failed" }

func TestOutputHelpers(t *testing.T) {
	var stderr bytes.Buffer
	if code := writeJSON(failingWriter{}, &stderr, map[string]string{"x": "y"}); code != 1 || !strings.Contains(stderr.String(), "write json") {
		t.Fatal(stderr.String())
	}
	if code := fail(&stderr, 7, "problem %d", 3); code != 7 || !strings.Contains(stderr.String(), "problem 3") {
		t.Fatal(stderr.String())
	}
}

type cliOmarchy struct{}

func (cliOmarchy) ApplyTheme(string, string) error { return nil }
func (cliOmarchy) CurrentTheme() (string, error)   { return "theme", nil }
func (cliOmarchy) CurrentBackground() (session.BackgroundRef, error) {
	return session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}, nil
}
func (cliOmarchy) RestoreThemeFast(string, string) error         { return nil }
func (cliOmarchy) RestoreBackground(session.BackgroundRef) error { return nil }

func TestSessionHandlers(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	service := session.NewService(store, cliOmarchy{})
	var out, stderr bytes.Buffer
	if code := runSession([]string{"begin"}, service, nil, &out, &stderr); code != 0 {
		t.Fatalf("begin code=%d err=%q", code, stderr.String())
	}
	if code := runSession([]string{"cancel", "missing"}, service, nil, &out, &stderr); code != 1 {
		t.Fatalf("cancel code=%d", code)
	}
	if code := runGenerate([]string{"too-few"}, nil, &out, &stderr); code != 2 {
		t.Fatalf("generate code=%d", code)
	}
}

func TestSessionResumeRecoversPendingApplyBeforeInspectingWorkspace(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, "cache"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, "state"))
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "resume-apply",
		OriginalTheme:      "original",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/background"},
		ApplyPhase:         session.ApplyPhaseCommitted,
		AppliedTheme:       "applied-theme",
		AppliedGeneration:  "generation-1",
		AppliedVariant:     "source",
		AppliedDisplayName: "Applied theme",
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: time.Now().UTC()}); err != nil {
		t.Fatal(err)
	}
	service := session.NewService(store, cliOmarchy{})
	applyService, err := apply.NewService(store, cliOmarchy{})
	if err != nil {
		t.Fatal(err)
	}
	var out, stderr bytes.Buffer
	if code := runSessionWithDependencies([]string{"resume"}, service, nil, applyService, nil, nil, nil, &out, &stderr); code != 0 {
		t.Fatalf("resume code=%d stderr=%q", code, stderr.String())
	}
	var result struct {
		Active bool `json:"active"`
	}
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.Active {
		t.Fatalf("resume returned an unresolved active session: %s", out.String())
	}
	if _, err := os.Stat(store.SessionDir(record.SessionID)); !os.IsNotExist(err) {
		t.Fatalf("pending apply session still exists, err=%v", err)
	}
}

func TestSessionResumeRemainsRecoverableWhenGenerationArtifactsAreMissing(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, "cache"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, "state"))
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "broken-generation",
		OriginalTheme:      "original",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/background"},
		GenerationID:       "missing-generation",
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: time.Now().UTC()}); err != nil {
		t.Fatal(err)
	}
	settingsStore, err := settings.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	generationService := generation.NewService(store, settingsStore)
	service := session.NewService(store, cliOmarchy{})
	var out, stderr bytes.Buffer
	if code := runSessionWithDependencies([]string{"resume"}, service, nil, nil, nil, nil, generationService, &out, &stderr); code != 0 {
		t.Fatalf("resume code=%d stderr=%q", code, stderr.String())
	}
	var result resumeResponse
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if !result.Active || result.WorkspaceResumable {
		t.Fatalf("resume=%#v, want active but not workspace resumable", result)
	}
}
