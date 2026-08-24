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
	"github.com/prettyletto/omagen/backend/internal/barprofile"
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

func TestParseGenerateArgsWithConfiguration(t *testing.T) {
	request, err := parseGenerateArgs([]string{
		"session", "image",
		"--shell-style", "accent", "edge", "accent", "native",
		"--desktop-style", "split_top", "2", "rounded", "airy", "shadow", "blur",
		"--bar-style", "accent", "compact", "accent", "docked", "islands",
	})
	if err != nil {
		t.Fatal(err)
	}
	if request.Configuration == nil {
		t.Fatal("configuration was not parsed")
	}
	if request.Configuration.ShellStyle.Surface != "accent" || request.Configuration.DesktopStyle.BorderSize != 2 || request.Configuration.BarStyle.Visibility != "islands" {
		t.Fatalf("unexpected configuration: %#v", request.Configuration)
	}
}

func TestParseGenerateArgsWithThemeBarProfile(t *testing.T) {
	profile := `{"schema_version":1,"ownership":"theme-owned","implementation":"replacement","bar":{"id":"pretty.theme.bar"},"behavior":{"form":"dock","visibility":"auto-hide","reveal":"edge","expansion":"hover","workspace":"dots"}}`
	request, err := parseGenerateArgs([]string{
		"session", "image",
		"--shell-style", "flat", "native", "native", "native",
		"--desktop-style", "solid", "-1", "default", "native", "native", "native", "native",
		"--bar-style", "native", "native", "semantic", "continuous", "native",
		"--bar-profile-json", profile,
	})
	if err != nil {
		t.Fatal(err)
	}
	if request.Configuration == nil || request.Configuration.BarStyle.Profile == nil {
		t.Fatalf("profile was not parsed: %#v", request.Configuration)
	}
	if request.Configuration.BarStyle.Profile.Implementation != barprofile.ImplementationReplacement || request.Configuration.BarStyle.Profile.Behavior.Workspace != "dots" {
		t.Fatalf("unexpected profile: %#v", request.Configuration.BarStyle.Profile)
	}
}

func TestParseGenerateArgsWithBarSpecUsesDefaultCompatibilityStyles(t *testing.T) {
	spec := `{"version":2,"engine":"auto","topology":"minimal","position":"top","surface":{"role":"transparent","opacity":0},"geometry":{"density":"compact"},"attention":{"mode":"semantic"},"behavior":{"visibility":"always","exclusive_zone":"reserve"},"motion":{"preset":"native"}}`
	request, err := parseGenerateArgs([]string{"session", "image", "--bar-spec-json", spec})
	if err != nil {
		t.Fatal(err)
	}
	if request.Configuration == nil || request.Configuration.BarStyle.Spec == nil {
		t.Fatalf("bar spec configuration was not parsed: %#v", request.Configuration)
	}
	if request.Configuration.ShellStyle.Surface != "flat" || request.Configuration.DesktopStyle.BorderStyle != "solid" || request.Configuration.BarStyle.Surface != "native" {
		t.Fatalf("compatibility defaults were not applied: %#v", request.Configuration)
	}
}

func TestParseGenerateArgsWithBorderSizeMode(t *testing.T) {
	request, err := parseGenerateArgs([]string{
		"session", "image",
		"--shell-style", "flat", "native", "native", "native",
		"--desktop-style", "solid", "0", "none", "native", "native", "native", "native",
		"--bar-style", "native", "native", "semantic", "continuous", "native",
	})
	if err != nil {
		t.Fatal(err)
	}
	if request.Configuration == nil || request.Configuration.DesktopStyle.BorderSize != 0 || request.Configuration.DesktopStyle.BorderSizeMode != "none" {
		t.Fatalf("explicit none border mode was not parsed: %#v", request.Configuration)
	}
}

func TestParseGenerateArgsRejectsInvalidOptions(t *testing.T) {
	for _, args := range [][]string{
		{"session", "image", "--harmony"},
		{"session", "image", "--harmony", "random"},
		{"session", "image", "--harmony=triadic", "--harmony", "auto"},
		{"session", "image", "--unknown"},
		{"session", "image", "--shell-style", "flat", "native", "native"},
		{"session", "image", "--desktop-style", "solid", "not-a-number", "native", "native", "native", "native"},
	} {
		if _, err := parseGenerateArgs(args); err == nil {
			t.Fatalf("expected args %v to fail", args)
		}
	}
}

func TestParseRetintOptions(t *testing.T) {
	run, skip, err := parseRetintOptions([]string{"--run", "all", "--skip", "browser,hyprland"})
	if err != nil || run != "all" || skip != "browser,hyprland" {
		t.Fatalf("run=%q skip=%q err=%v", run, skip, err)
	}
	if _, _, err := parseRetintOptions([]string{"--skip"}); err == nil {
		t.Fatal("expected missing --skip value to fail")
	}
	if _, _, err := parseRetintOptions([]string{"--unknown"}); err == nil {
		t.Fatal("expected unknown retint option to fail")
	}
}

func TestParseStudioOptions(t *testing.T) {
	options, err := parseStudioOptions([]string{"--scope", "theme,shell", "--wait", "full", "--run", "terminal", "--allow-trusted-hooks"})
	if err != nil {
		t.Fatal(err)
	}
	if options.Scope != "theme,shell" || options.WaitMode != "full" || options.RetintRun != "terminal" || !options.AllowTrustedHooks {
		t.Fatalf("options=%#v", options)
	}
	if _, err := parseStudioOptions([]string{"--wait", "eventually"}); err == nil {
		t.Fatal("expected invalid wait mode to fail")
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

func TestSessionBeginAcceptsInactiveStyleArgumentShape(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	service := session.NewService(store, cliOmarchy{})
	var out, stderr bytes.Buffer
	args := []string{
		"begin", "--shell-style", "flat", "native",
		"--desktop-style", "invalid", "2", "native", "native", "native", "blur",
		"--bar-style", "native", "native", "semantic", "continuous",
	}
	if code := runSession(args, service, nil, &out, &stderr); code != 1 || strings.Contains(stderr.String(), "usage:") {
		t.Fatalf("inactive-style argument shape was rejected before validation: code=%d stderr=%q", code, stderr.String())
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
