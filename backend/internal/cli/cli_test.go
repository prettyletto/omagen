package cli

import (
	"bytes"
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/session"
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
	if !strings.Contains(out.String(), `"ok":true`) || !strings.Contains(out.String(), `"version":"dev"`) {
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

func (cliOmarchy) CurrentTheme() (string, error) { return "theme", nil }
func (cliOmarchy) CurrentBackground() (session.BackgroundRef, error) {
	return session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}, nil
}
func (cliOmarchy) RestoreThemeFast(string, string) error         { return nil }
func (cliOmarchy) RestoreBackground(session.BackgroundRef) error { return nil }

func TestSessionHandlers(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
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
