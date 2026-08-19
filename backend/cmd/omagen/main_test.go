package main

import (
	"bytes"
	"os"
	"strings"
	"testing"
)

func TestRun(t *testing.T) {
	var out, err bytes.Buffer
	if code := run([]string{"ping"}, &out, &err); code != 0 {
		t.Fatalf("code=%d err=%q", code, err.String())
	}
	if !strings.Contains(out.String(), `"ok":true`) {
		t.Fatalf("output=%q", out.String())
	}
}

func TestMain(t *testing.T) {
	originalArgs, originalExit := os.Args, exit
	defer func() { os.Args, exit = originalArgs, originalExit }()
	os.Args = []string{"omagen", "ping"}
	var code int
	exit = func(got int) { code = got }
	main()
	if code != 0 {
		t.Fatalf("exit code=%d", code)
	}
}
