package imageanalysis

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
)

func TestAnalysisValidate(t *testing.T) {
	validImage := image.NewRGBA(image.Rect(0, 0, 2, 3))

	tests := []struct {
		name     string
		analysis *Analysis
		wantErr  string
	}{
		{name: "nil", wantErr: "analysis is nil"},
		{
			name:     "nil image",
			analysis: &Analysis{Width: 1, Height: 1, Format: "png"},
			wantErr:  "decoded image is nil",
		},
		{
			name:     "invalid dimensions",
			analysis: &Analysis{Image: validImage, Width: 0, Height: 1, Format: "png"},
			wantErr:  "invalid dimensions 0x1",
		},
		{
			name:     "empty format",
			analysis: &Analysis{Image: validImage, Width: 2, Height: 3, Samples: []Sample{{}}},
			wantErr:  "image format is empty",
		},
		{
			name:     "empty samples",
			analysis: &Analysis{Image: validImage, Width: 2, Height: 3, Format: "png"},
			wantErr:  "image has no usable pixel samples",
		},
		{
			name: "valid",
			analysis: &Analysis{
				Image: validImage, Width: 2, Height: 3, Format: "png",
				Samples: []Sample{{}}, Representatives: []RepresentativeColor{{}},
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := test.analysis.Validate()
			if test.wantErr == "" {
				if err != nil {
					t.Fatalf("Validate() error = %v", err)
				}
				return
			}

			if err == nil || err.Error() != test.wantErr {
				t.Fatalf("Validate() error = %v, want %q", err, test.wantErr)
			}
		})
	}
}

func TestAnalysisExtension(t *testing.T) {
	tests := []struct {
		format    string
		extension string
	}{
		{format: "jpeg", extension: ".jpg"},
		{format: "png", extension: ".png"},
		{format: "gif", extension: ".gif"},
		{format: "webp", extension: ".webp"},
		{format: "bmp", extension: ".bmp"},
		{format: "tiff", extension: ".tiff"},
	}

	for _, test := range tests {
		t.Run(test.format, func(t *testing.T) {
			extension, err := (&Analysis{Format: test.format}).Extension()
			if err != nil {
				t.Fatal(err)
			}
			if extension != test.extension {
				t.Fatalf("Extension() = %q, want %q", extension, test.extension)
			}
		})
	}

	if _, err := (&Analysis{Format: "unknown"}).Extension(); err == nil {
		t.Fatal("expected unsupported format error")
	}
}

func TestDecodeFile(t *testing.T) {
	tests := []struct {
		name   string
		format string
		write  func(*bytes.Buffer) error
	}{
		{
			name:   "png",
			format: "png",
			write: func(buffer *bytes.Buffer) error {
				return png.Encode(buffer, testImage())
			},
		},
		{
			name:   "jpeg",
			format: "jpeg",
			write: func(buffer *bytes.Buffer) error {
				return jpeg.Encode(buffer, testImage(), &jpeg.Options{Quality: 100})
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var data bytes.Buffer
			if err := test.write(&data); err != nil {
				t.Fatal(err)
			}

			path := filepath.Join(t.TempDir(), "source."+test.name)
			if err := os.WriteFile(path, data.Bytes(), 0o644); err != nil {
				t.Fatal(err)
			}

			analysis, err := DecodeFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if err := analysis.Validate(); err != nil {
				t.Fatalf("decoded analysis is invalid: %v", err)
			}
			if analysis.Width != 2 || analysis.Height != 3 {
				t.Fatalf("dimensions = %dx%d, want 2x3", analysis.Width, analysis.Height)
			}
			if analysis.Format != test.format {
				t.Fatalf("format = %q, want %q", analysis.Format, test.format)
			}
			if len(analysis.Samples) == 0 {
				t.Fatal("decoded analysis has no samples")
			}
			if len(analysis.Representatives) == 0 {
				t.Fatal("decoded analysis has no representatives")
			}
		})
	}
}

func TestDecodeFileErrors(t *testing.T) {
	tests := []struct {
		name    string
		data    []byte
		wantErr string
	}{
		{name: "missing", wantErr: "open image:"},
		{name: "malformed", data: []byte("not an image"), wantErr: "unsupported or invalid image:"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "source.png")
			if test.data != nil {
				if err := os.WriteFile(path, test.data, 0o644); err != nil {
					t.Fatal(err)
				}
			}

			_, err := DecodeFile(path)
			if err == nil || !strings.Contains(err.Error(), test.wantErr) {
				t.Fatalf("DecodeFile() error = %v, want containing %q", err, test.wantErr)
			}
		})
	}
}

func TestValidateDimensions(t *testing.T) {
	tests := []struct {
		name          string
		width, height int
		wantErr       string
	}{
		{name: "zero width", width: 0, height: 1, wantErr: "invalid image dimensions 0x1"},
		{name: "zero height", width: 1, height: 0, wantErr: "invalid image dimensions 1x0"},
		{name: "maximum", width: 8_000, height: 5_000},
		{name: "too large", width: 8_001, height: 5_000, wantErr: "image is too large"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateDimensions(test.width, test.height)
			if test.wantErr == "" {
				if err != nil {
					t.Fatalf("validateDimensions() error = %v", err)
				}
				return
			}
			if err == nil || !strings.Contains(err.Error(), test.wantErr) {
				t.Fatalf("validateDimensions() error = %v, want containing %q", err, test.wantErr)
			}
		})
	}
}

func TestSamplePixels(t *testing.T) {
	picture := image.NewNRGBA(image.Rect(10, 20, 14, 21))
	for x := 10; x < 14; x++ {
		picture.SetNRGBA(x, 20, color.NRGBA{R: uint8(x), A: 255})
	}

	samples, err := samplePixels(picture)
	if err != nil {
		t.Fatal(err)
	}
	if len(samples) != 4 {
		t.Fatalf("sample count = %d, want 4", len(samples))
	}
	for index, sample := range samples {
		if sample.R != uint8(10+index) || sample.A != 255 {
			t.Fatalf("sample %d = %#v, want R=%d A=255", index, sample, 10+index)
		}
		wantLab := colorspace.FromSRGB8(sample.R, sample.G, sample.B)
		if sample.Lab != wantLab {
			t.Fatalf("sample %d Lab = %#v, want %#v", index, sample.Lab, wantLab)
		}
	}

	first, err := samplePixels(picture)
	if err != nil {
		t.Fatal(err)
	}
	if len(first) != len(samples) {
		t.Fatal("sampling is not deterministic")
	}
	for index := range samples {
		if first[index] != samples[index] {
			t.Fatal("sampling is not deterministic")
		}
	}
}

func TestSamplePixelsCapAndTransparency(t *testing.T) {
	picture := image.NewNRGBA(image.Rect(0, 0, maxSamples+100, 1))
	for x := 1; x < maxSamples+100; x++ {
		picture.SetNRGBA(x, 0, color.NRGBA{R: 1, A: 255})
	}

	samples, err := samplePixels(picture)
	if err != nil {
		t.Fatal(err)
	}
	if len(samples) != maxSamples-1 {
		t.Fatalf("sample count = %d, want %d", len(samples), maxSamples-1)
	}

	transparent := image.NewNRGBA(image.Rect(0, 0, 2, 2))
	if _, err := samplePixels(transparent); err == nil || !strings.Contains(err.Error(), "no visible pixels") {
		t.Fatalf("samplePixels() error = %v, want no visible pixels", err)
	}
}

func testImage() image.Image {
	picture := image.NewRGBA(image.Rect(0, 0, 2, 3))
	for y := 0; y < 3; y++ {
		for x := 0; x < 2; x++ {
			picture.Set(x, y, color.RGBA{R: uint8(x * 100), G: uint8(y * 80), A: 255})
		}
	}
	return picture
}
