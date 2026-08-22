package demo

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

func TestOpenRejectsPendingApplyBeforeTouchingDemoWorkspace(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "demo-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ApplyPhase:         session.ApplyPhasePrepared,
		AppliedTheme:       "theme-name",
		AppliedGeneration:  "generation-1",
		AppliedVariant:     "source",
		AppliedDisplayName: "Theme Name",
		CreatedAt:          time.Now().UTC(),
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	service := NewService(store)
	if _, err := service.Open(record.SessionID); !errors.Is(err, session.ErrApplyInProgress) {
		t.Fatalf("error=%v, want ErrApplyInProgress", err)
	}
}

func TestLoadStateRejectsOversizedStateFile(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	service := NewService(store)
	statePath := service.statePath("oversized-demo")
	if err := os.MkdirAll(filepath.Dir(statePath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(statePath, []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(statePath, fsutil.MaxStateFileBytes+1); err != nil {
		t.Fatal(err)
	}
	if _, err := service.loadState("oversized-demo"); !errors.Is(err, fsutil.ErrFileTooLarge) {
		t.Fatalf("loadState() error = %v, want ErrFileTooLarge", err)
	}
}

func TestDemoStateCommitRejectsCancellationWonRace(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "demo-race",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: time.Now().UTC()}); err != nil {
		t.Fatal(err)
	}
	if err := store.ClearActive(record.SessionID); err != nil {
		t.Fatal(err)
	}
	state := State{SessionID: record.SessionID, Workspace: "workspace", Windows: map[Slot]string{}}
	if err := NewService(store).saveStateIfActive(state); !errors.Is(err, session.ErrSessionNotActive) {
		t.Fatalf("error=%v, want ErrSessionNotActive", err)
	}
	if _, err := os.Stat(filepath.Join(store.SessionDir(record.SessionID), "demo-state.json")); !os.IsNotExist(err) {
		t.Fatalf("demo state was persisted after cancellation, err=%v", err)
	}
}

func TestReopenDemoCleansWindowsCreatedBeforeCancellation(t *testing.T) {
	testenv.Isolate(t)
	bin := t.TempDir()
	newWindow := filepath.Join(t.TempDir(), "new-window")
	closedWindow := filepath.Join(t.TempDir(), "closed-window")
	counterPath := filepath.Join(t.TempDir(), "dispatch-count")
	hyprctl := `#!/bin/sh
if [ "$1" = "-j" ] && [ "$2" = "monitors" ]; then
  printf '%s\n' '[{"name":"fake","width":1920,"height":1080,"x":0,"y":0,"scale":1,"transform":0,"focused":true,"reserved":[0,0,0,0],"activeWorkspace":{"id":1,"name":"1"}}]'
  exit 0
fi
if [ "$1" = "-j" ] && [ "$2" = "clients" ]; then
  if [ -f "$FAKE_NEW_WINDOW" ] && [ ! -f "$FAKE_CLOSED_WINDOW" ]; then
    printf '%s\n' '[{"address":"editor","class":"org.omagen.demo.reopen-race.editor","initialClass":"org.omagen.demo.reopen-race.editor","title":"","initialTitle":"","pid":100,"workspace":{"id":1,"name":"1"}},{"address":"btop","class":"org.omagen.demo.reopen-race.btop","initialClass":"org.omagen.demo.reopen-race.btop","title":"","initialTitle":"","pid":101,"workspace":{"id":1,"name":"1"}},{"address":"shell","class":"org.omagen.demo.reopen-race.shell","initialClass":"org.omagen.demo.reopen-race.shell","title":"","initialTitle":"","pid":102,"workspace":{"id":1,"name":"1"}},{"address":"new-files","class":"org.omagen.demo.reopen-race.files","initialClass":"org.omagen.demo.reopen-race.files","title":"","initialTitle":"","pid":103,"workspace":{"id":1,"name":"1"}}]'
  else
    printf '%s\n' '[{"address":"editor","class":"org.omagen.demo.reopen-race.editor","initialClass":"org.omagen.demo.reopen-race.editor","title":"","initialTitle":"","pid":100,"workspace":{"id":1,"name":"1"}},{"address":"btop","class":"org.omagen.demo.reopen-race.btop","initialClass":"org.omagen.demo.reopen-race.btop","title":"","initialTitle":"","pid":101,"workspace":{"id":1,"name":"1"}},{"address":"shell","class":"org.omagen.demo.reopen-race.shell","initialClass":"org.omagen.demo.reopen-race.shell","title":"","initialTitle":"org.omagen.demo.reopen-race.shell","pid":102,"workspace":{"id":1,"name":"1"}}]'
  fi
  exit 0
fi
if [ "$1" = "dispatch" ]; then
  expression="$2"
  if printf '%s' "$expression" | /usr/bin/grep -q 'window.move'; then
    count=0
    [ -f "$FAKE_COUNTER" ] && count=$(/bin/cat "$FAKE_COUNTER")
    count=$((count + 1))
    printf '%s\n' "$count" > "$FAKE_COUNTER"
    if [ "$count" -eq "$FAKE_CANCEL_AFTER" ]; then /bin/rm -f "$FAKE_ACTIVE"; fi
  fi
  if printf '%s' "$expression" | /usr/bin/grep -q 'window.close'; then /usr/bin/touch "$FAKE_CLOSED_WINDOW"; fi
  exit 0
fi
exit 2
`
	launcher := `#!/bin/sh
	/usr/bin/touch "$FAKE_NEW_WINDOW"
	/bin/sleep 2
`
	if err := os.WriteFile(filepath.Join(bin, "hyprctl"), []byte(hyprctl), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(bin, "omarchy-launch-tui"), []byte(launcher), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	t.Setenv("FAKE_NEW_WINDOW", newWindow)
	t.Setenv("FAKE_CLOSED_WINDOW", closedWindow)
	t.Setenv("FAKE_COUNTER", counterPath)
	t.Setenv("FAKE_CANCEL_AFTER", "8")
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{SessionID: "reopen-race", OriginalTheme: "theme", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: time.Now().UTC()}); err != nil {
		t.Fatal(err)
	}
	t.Setenv("FAKE_ACTIVE", store.ActivePath())
	service := NewService(store)
	state := State{SessionID: record.SessionID, Workspace: "__omagen_demo_reopen-race", DemoMonitor: "fake", OriginMonitor: "fake", OriginWorkspaceID: 1, OriginWorkspaceName: "1", DemoDir: t.TempDir(), OwnerToken: "reopen-race", Windows: map[Slot]string{SlotEditor: "editor", SlotBtop: "btop", SlotShell: "shell"}}
	if err := service.saveState(state); err != nil {
		t.Fatal(err)
	}
	if _, err := service.reopenDemo(state); err == nil {
		count, _ := os.ReadFile(counterPath)
		t.Fatalf("reopen unexpectedly succeeded after cancellation; dispatches=%s active=%t", count, fileExists(store.ActivePath()))
	}
	clientsAfter, err := exec.Command("hyprctl", "-j", "clients").Output()
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(clientsAfter), "new-files") || !fileExists(closedWindow) {
		t.Fatalf("recreated files window survived cancellation: clients=%s closed=%t", clientsAfter, fileExists(closedWindow))
	}
	persisted, err := service.loadState(record.SessionID)
	if err != nil {
		t.Fatal(err)
	}
	if persisted.Windows[SlotFiles] != "" {
		t.Fatalf("recreated window was persisted after cancellation: %#v", persisted.Windows)
	}
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
