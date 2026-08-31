package theme

import (
	"encoding/binary"
	"hash/crc32"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
)

func TestWritePreviewRejectsOversizedDimensionsBeforeDecode(t *testing.T) {
	sourcePath := filepath.Join(t.TempDir(), "oversized.png")
	if err := os.WriteFile(sourcePath, oversizedPNGHeader(200_001, 200), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := WritePreview(t.TempDir(), sourcePath); err == nil {
		t.Fatal("WritePreview accepted an image larger than the normalization limit")
	}
}

func oversizedPNGHeader(width, height uint32) []byte {
	data := make([]byte, 8+4+4+13+4)
	copy(data[:8], []byte{137, 80, 78, 71, 13, 10, 26, 10})
	binary.BigEndian.PutUint32(data[8:12], 13)
	copy(data[12:16], []byte("IHDR"))
	binary.BigEndian.PutUint32(data[16:20], width)
	binary.BigEndian.PutUint32(data[20:24], height)
	data[24] = 8
	data[25] = 6
	data[26] = 0
	data[27] = 0
	data[28] = 0
	binary.BigEndian.PutUint32(data[29:33], crc32.ChecksumIEEE(data[12:29]))
	return data
}

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
