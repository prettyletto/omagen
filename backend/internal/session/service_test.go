package session

import (
	"strings"
	"testing"
)

type fakeOmarchy struct {
	theme                                                          string
	background                                                     BackgroundRef
	themeErr, backgroundErr, restoreThemeErr, restoreBackgroundErr error
	restoredTheme                                                  string
	restoredDir                                                    string
	restoredBackground                                             BackgroundRef
	keepThemeAfterRestore                                          bool
	keepBackgroundAfterRestore                                     bool
}

func (f *fakeOmarchy) CurrentTheme() (string, error) { return f.theme, f.themeErr }
func (f *fakeOmarchy) CurrentBackground() (BackgroundRef, error) {
	return f.background, f.backgroundErr
}
func (f *fakeOmarchy) RestoreThemeFast(theme, dir string) error {
	f.restoredTheme, f.restoredDir = theme, dir
	if f.restoreThemeErr == nil && !f.keepThemeAfterRestore {
		f.theme = theme
	}
	return f.restoreThemeErr
}
func (f *fakeOmarchy) RestoreBackground(background BackgroundRef) error {
	f.restoredBackground = background
	if f.restoreBackgroundErr == nil && !f.keepBackgroundAfterRestore {
		f.background = background
	}
	return f.restoreBackgroundErr
}

func TestServiceBeginAndCancel(t *testing.T) {
	s := testStore(t)
	fake := &fakeOmarchy{theme: "theme", background: BackgroundRef{Kind: "theme", Path: "bg.png"}}
	svc := NewService(s, fake)
	begin, err := svc.Begin()
	if err != nil {
		t.Fatal(err)
	}
	if begin.OriginalTheme != "theme" || begin.SessionID == "" {
		t.Fatalf("bad begin result: %#v", begin)
	}
	if err := svc.Cancel(begin.SessionID); err != nil {
		t.Fatal(err)
	}
	if fake.restoredTheme != "theme" || fake.restoredBackground.Path != "bg.png" {
		t.Fatalf("restore calls missing: %#v", fake)
	}
	if _, err := s.Load(begin.SessionID); err == nil {
		t.Fatal("session was not deleted")
	}
}

func TestServiceBeginNormalizesDesktopStyleDefaultsBeforeValidation(t *testing.T) {
	s := testStore(t)
	fake := &fakeOmarchy{theme: "theme", background: BackgroundRef{Kind: "theme", Path: "bg.png"}}
	svc := NewService(s, fake)

	begin, err := svc.Begin(
		DefaultShellStyle(),
		DesktopStyle{BorderStyle: "solid", BorderSize: -1, BorderSizeMode: "default", Shape: "native", Spacing: "native", Depth: "native", Inactive: "native"},
		DefaultBarStyle(),
	)
	if err != nil {
		t.Fatalf("default desktop style was rejected: %v", err)
	}
	if begin.DesktopStyle.BorderSpeed != 36 || begin.DesktopStyle.BorderSize != -1 || begin.DesktopStyle.BorderSizeMode != "default" {
		t.Fatalf("desktop speed was not normalized: %#v", begin.DesktopStyle)
	}
	if err := svc.Cancel(begin.SessionID); err != nil {
		t.Fatal(err)
	}
}

func TestNormalizeDesktopStyleMigratesLegacyBackdropBlur(t *testing.T) {
	style := NormalizeDesktopStyle(DesktopStyle{
		BorderStyle: "solid", BorderSize: -1, BorderSizeMode: "default", BorderSpeed: 36,
		Shape: "native", Spacing: "native", Depth: "native", Inactive: "blur",
	})
	if style.Inactive != "frosted_balanced" {
		t.Fatalf("legacy blur was not migrated to the balanced frosted profile: %#v", style)
	}
	if !style.Valid() {
		t.Fatalf("migrated frosted profile is not valid: %#v", style)
	}
}

func TestCancelAfterRegenerationRestoresInitialBaseline(t *testing.T) {
	s := testStore(t)
	record := testRecord("regenerated")
	if err := s.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := s.SaveActive(ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}

	updated := record
	updated.SourceImage = "/tmp/reconfigured.png"
	updated.GenerationID = "generation-2"
	updated.PreviewVariant = "vibrant"
	updated.ExtraConfigs = true
	updated.ShellStyle = ShellStyle{Surface: "accent", Detail: "edge", Tooltip: "accent", Notifications: "accent"}
	updated.DesktopStyle = DesktopStyle{BorderStyle: "spin", BorderSize: 4, Shape: "rounded", Spacing: "airy", Depth: "shadow", Inactive: "blur"}
	updated.BarStyle = BarStyle{Surface: "accent", Density: "compact", Attention: "accent", Form: "docked", Visibility: "islands"}
	if err := s.Save(updated); err != nil {
		t.Fatal(err)
	}

	fake := &fakeOmarchy{
		theme:      "omagen-preview-regenerated-vibrant",
		background: BackgroundRef{Kind: "external", Path: "/tmp/reconfigured.png"},
	}
	if err := NewService(s, fake).Cancel(record.SessionID); err != nil {
		t.Fatal(err)
	}
	if fake.restoredTheme != record.OriginalTheme || fake.restoredBackground != record.OriginalBackground {
		t.Fatalf("cancel restored the latest preview instead of the initial baseline: %#v", fake)
	}
	if _, exists, err := s.LoadActive(); err != nil || exists {
		t.Fatalf("cancel did not return to state zero: exists=%t err=%v", exists, err)
	}
	if _, err := s.Load(record.SessionID); err == nil {
		t.Fatal("cancel left the durable session behind")
	}
}

func TestCancelCommittedApplyOnlyFinishesCleanup(t *testing.T) {
	s := testStore(t)
	fake := &fakeOmarchy{theme: "permanent", background: BackgroundRef{Kind: "external", Path: "/tmp/permanent.png"}}
	record := testRecord("committed")
	record.ApplyPhase = ApplyPhaseCommitted
	record.AppliedTheme = "permanent"
	record.AppliedGeneration = "generation-1"
	record.AppliedVariant = "source"
	record.AppliedDisplayName = "Permanent"
	if err := s.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := s.SaveActive(ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	if err := NewService(s, fake).Cancel(record.SessionID); err != nil {
		t.Fatal(err)
	}
	if fake.restoredTheme != "" || fake.restoredBackground.Path != "" {
		t.Fatalf("committed apply was rolled back: %#v", fake)
	}
	if _, exists, err := s.LoadActive(); err != nil || exists {
		t.Fatalf("active marker remains: exists=%t err=%v", exists, err)
	}
}

func TestServiceErrors(t *testing.T) {
	cases := []struct {
		name  string
		fake  *fakeOmarchy
		begin bool
		want  string
	}{
		{"theme", &fakeOmarchy{themeErr: errTest}, true, "read current theme"},
		{"background", &fakeOmarchy{theme: "x", backgroundErr: errTest}, true, "read current background"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := NewService(testStore(t), tc.fake).Begin()
			if err == nil || !contains(err.Error(), tc.want) {
				t.Fatalf("error = %v", err)
			}
		})
	}
	s := testStore(t)
	fake := &fakeOmarchy{restoreThemeErr: errTest}
	if err := NewService(s, fake).Cancel("missing"); err != nil {
		t.Fatalf("missing inactive session should be idempotent: %v", err)
	}
	record := testRecord("id")
	if err := s.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := NewService(s, fake).Cancel("id"); err == nil || !contains(err.Error(), "restore theme") {
		t.Fatalf("error = %v", err)
	}
	fake.restoreThemeErr = nil
	fake.restoreBackgroundErr = errTest
	if err := NewService(s, fake).Cancel("id"); err == nil || !contains(err.Error(), "restore background") {
		t.Fatalf("error = %v", err)
	}
	fake.restoreBackgroundErr = nil
	if err := NewService(s, fake).Cancel("id"); err != nil {
		t.Fatalf("retry cancel = %v", err)
	}
}

func TestCancelVerificationFailuresKeepSessionActive(t *testing.T) {
	t.Run("theme", func(t *testing.T) {
		s := testStore(t)
		record := testRecord("verify-theme")
		if err := s.Save(record); err != nil {
			t.Fatal(err)
		}
		if err := s.SaveActive(ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
			t.Fatal(err)
		}
		fake := &fakeOmarchy{theme: "different", keepThemeAfterRestore: true}
		if err := NewService(s, fake).Cancel(record.SessionID); err == nil || !contains(err.Error(), "got") {
			t.Fatalf("expected theme verification error, got %v", err)
		}
		if _, exists, err := s.LoadActive(); err != nil || !exists {
			t.Fatalf("active marker changed: exists=%t err=%v", exists, err)
		}
	})

	t.Run("background", func(t *testing.T) {
		s := testStore(t)
		record := testRecord("verify-background")
		if err := s.Save(record); err != nil {
			t.Fatal(err)
		}
		if err := s.SaveActive(ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
			t.Fatal(err)
		}
		fake := &fakeOmarchy{theme: record.OriginalTheme, background: BackgroundRef{Kind: "external", Path: "/different"}, keepBackgroundAfterRestore: true}
		if err := NewService(s, fake).Cancel(record.SessionID); err == nil || !contains(err.Error(), "got") {
			t.Fatalf("expected background verification error, got %v", err)
		}
		if _, exists, err := s.LoadActive(); err != nil || !exists {
			t.Fatalf("active marker changed: exists=%t err=%v", exists, err)
		}
	})
}

var errTest = &testError{}

type testError struct{}

func (*testError) Error() string  { return "test error" }
func contains(s, sub string) bool { return strings.Contains(s, sub) }
