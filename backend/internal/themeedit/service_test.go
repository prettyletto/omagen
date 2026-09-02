package themeedit

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCopyMergedTreeStockThenUserOverlay(t *testing.T) {
	stock := t.TempDir()
	user := t.TempDir()
	destination := t.TempDir()
	write := func(root, name, value string) {
		t.Helper()
		path := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(value), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write(stock, "colors.toml", "stock")
	write(stock, "shell.toml", "native")
	write(stock, "backgrounds/wallpaper.png", "stock-bg")
	write(user, "colors.toml", "overlay")
	write(user, "custom.ini", "preserve")

	if err := copyMergedTree(stock, user, "", destination); err != nil {
		t.Fatal(err)
	}
	for name, want := range map[string]string{
		"colors.toml":               "overlay",
		"shell.toml":                "native",
		"backgrounds/wallpaper.png": "stock-bg",
		"custom.ini":                "preserve",
	} {
		data, err := os.ReadFile(filepath.Join(destination, name))
		if err != nil {
			t.Fatalf("read %s: %v", name, err)
		}
		if string(data) != want {
			t.Fatalf("%s = %q, want %q", name, data, want)
		}
	}
}

func TestCopyTreeRejectsSymlink(t *testing.T) {
	source := t.TempDir()
	destination := t.TempDir()
	target := filepath.Join(source, "outside")
	if err := os.WriteFile(target, []byte("unsafe"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, filepath.Join(source, "link")); err != nil {
		t.Fatal(err)
	}
	if err := copyTree(source, destination); err == nil {
		t.Fatal("copyTree accepted a symlink")
	}
}

func TestFingerprintTreeTracksMergedSnapshotContents(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "colors.toml"), []byte("background = \"#000000\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	first, err := fingerprintTree(root)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "colors.toml"), []byte("background = \"#ffffff\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	second, err := fingerprintTree(root)
	if err != nil {
		t.Fatal(err)
	}
	if first == second {
		t.Fatal("fingerprint did not change when snapshot contents changed")
	}
}
