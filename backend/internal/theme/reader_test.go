package theme

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReadSharedWindowOpacityRecoversMatchingHyprlandValues(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "hyprland.lua"), []byte(`
hl.config({
  decoration = {
    active_opacity = 0.72,
    inactive_opacity = 0.72,
  },
})
`), 0o644); err != nil {
		t.Fatal(err)
	}

	opacity, err := ReadSharedWindowOpacity(dir)
	if err != nil {
		t.Fatal(err)
	}
	if opacity == nil || *opacity != 72 {
		t.Fatalf("window opacity = %#v, want 72", opacity)
	}
}

func TestReadSharedWindowOpacityLeavesAsymmetricOrMissingValuesUntouched(t *testing.T) {
	for name, source := range map[string]string{
		"asymmetric": "active_opacity = 0.72,\\ninactive_opacity = 0.60,\\n",
		"missing":    "active_opacity = 0.72,\\n",
	} {
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			if err := os.WriteFile(filepath.Join(dir, "hyprland.lua"), []byte(source), 0o644); err != nil {
				t.Fatal(err)
			}
			opacity, err := ReadSharedWindowOpacity(dir)
			if err != nil {
				t.Fatal(err)
			}
			if opacity != nil {
				t.Fatalf("window opacity = %d, want no shared value", *opacity)
			}
		})
	}
}
