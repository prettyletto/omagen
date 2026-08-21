package theme

import (
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
)

func TestWritePreviewAndUnlockNormalizeToExpectedSizes(t *testing.T) {
	sourcePath := filepath.Join(t.TempDir(), "source.png")
	source := image.NewRGBA(image.Rect(0, 0, 12, 8))
	for y := 0; y < source.Bounds().Dy(); y++ {
		for x := 0; x < source.Bounds().Dx(); x++ {
			if x < 2 || x >= source.Bounds().Dx()-2 {
				source.Set(x, y, color.RGBA{R: 255, A: 255})
			} else {
				source.Set(x, y, color.RGBA{B: 255, A: 255})
			}
		}
	}
	file, err := os.Create(sourcePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(file, source); err != nil {
		_ = file.Close()
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}

	themeDir := t.TempDir()
	if err := WritePreview(themeDir, sourcePath); err != nil {
		t.Fatal(err)
	}
	if err := WriteUnlock(themeDir, sourcePath); err != nil {
		t.Fatal(err)
	}

	for _, test := range []struct {
		name   string
		width  int
		height int
	}{
		{name: "preview.png", width: previewWidth, height: previewHeight},
		{name: "unlock.png", width: unlockWidth, height: unlockHeight},
		{name: "preview-unlock.png", width: unlockPreviewWidth, height: unlockPreviewHeight},
	} {
		file, err := os.Open(filepath.Join(themeDir, test.name))
		if err != nil {
			t.Fatal(err)
		}
		config, err := png.DecodeConfig(file)
		_ = file.Close()
		if err != nil {
			t.Fatal(err)
		}
		if config.Width != test.width || config.Height != test.height {
			t.Fatalf("%s dimensions = %dx%d, want %dx%d", test.name, config.Width, config.Height, test.width, test.height)
		}
	}
}

func TestCenterCrop16x9KeepsCenter(t *testing.T) {
	source := image.NewRGBA(image.Rect(0, 0, 10, 10))
	source.Set(5, 5, color.RGBA{G: 255, A: 255})
	result, err := centerCrop16x9(source)
	if err != nil {
		t.Fatal(err)
	}
	if result.Bounds().Dx() != 10 || result.Bounds().Dy() != 5 {
		t.Fatalf("crop dimensions = %dx%d, want 10x5", result.Bounds().Dx(), result.Bounds().Dy())
	}
	if got := result.At(5, 3); got != (color.RGBA{G: 255, A: 255}) {
		t.Fatalf("center pixel = %#v, want green center pixel", got)
	}
}
