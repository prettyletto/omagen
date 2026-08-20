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
}

func (f *fakeOmarchy) CurrentTheme() (string, error) { return f.theme, f.themeErr }
func (f *fakeOmarchy) CurrentBackground() (BackgroundRef, error) {
	return f.background, f.backgroundErr
}
func (f *fakeOmarchy) RestoreThemeFast(theme, dir string) error {
	f.restoredTheme, f.restoredDir = theme, dir
	if f.restoreThemeErr == nil {
		f.theme = theme
	}
	return f.restoreThemeErr
}
func (f *fakeOmarchy) RestoreBackground(background BackgroundRef) error {
	f.restoredBackground = background
	if f.restoreBackgroundErr == nil {
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
}

var errTest = &testError{}

type testError struct{}

func (*testError) Error() string  { return "test error" }
func contains(s, sub string) bool { return strings.Contains(s, sub) }
