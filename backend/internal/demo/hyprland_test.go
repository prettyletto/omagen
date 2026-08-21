package demo

import "testing"

func TestLayoutForMonitorKeepsVisibleGaps(t *testing.T) {
	got := layoutForMonitor(monitorInfo{
		Width:  1920,
		Height: 1080,
		Scale:  1,
	})

	if got.Files.Y-(got.Btop.Y+got.Btop.H) != demoGap {
		t.Fatalf("btop/files gap = %d, want %d", got.Files.Y-(got.Btop.Y+got.Btop.H), demoGap)
	}
	if got.Btop.X-(got.Editor.X+got.Editor.W) != demoGap {
		t.Fatalf("editor/btop gap = %d, want %d", got.Btop.X-(got.Editor.X+got.Editor.W), demoGap)
	}
	if got.Shell.Y-(got.Editor.Y+got.Editor.H) != demoGap {
		t.Fatalf("editor/shell gap = %d, want %d", got.Shell.Y-(got.Editor.Y+got.Editor.H), demoGap)
	}
	if got.Files.X-(got.Shell.X+got.Shell.W) != demoGap {
		t.Fatalf("shell/files gap = %d, want %d", got.Files.X-(got.Shell.X+got.Shell.W), demoGap)
	}
}
