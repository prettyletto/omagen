package demo

import (
	"errors"
	"os/exec"
	"testing"
)

func TestExitedFromTerminalReload(t *testing.T) {
	cmd := exec.Command("/bin/sh", "-c", "kill -USR2 $$")
	err := cmd.Run()
	if err == nil {
		t.Fatal("expected shell to be terminated by SIGUSR2")
	}
	if !exitedFromTerminalReload(err) {
		t.Fatalf("SIGUSR2 exit was not recognized: %v", err)
	}
}

func TestExitedFromTerminalReloadRejectsNormalExit(t *testing.T) {
	cmd := exec.Command("/bin/sh", "-c", "exit 1")
	err := cmd.Run()
	if err == nil {
		t.Fatal("expected non-zero exit")
	}
	if exitedFromTerminalReload(err) {
		t.Fatalf("ordinary exit was misidentified as terminal reload: %v", err)
	}
	if exitedFromTerminalReload(errors.New("not a process exit")) {
		t.Fatal("ordinary error was misidentified as terminal reload")
	}
}
