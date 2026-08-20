// Command palette-preview runs the development-only source-palette visualizer.
// It deliberately calls the same DecodeFile and palette.Source functions used
// by Omagen; this command only supplies HTTP/JSON around that pipeline.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"

	"github.com/prettyletto/omagen/backend/internal/contrast"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	semanticpalette "github.com/prettyletto/omagen/backend/internal/palette"
	"github.com/prettyletto/omagen/backend/internal/settings"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

const (
	width  = 640
	height = 360
)

type preview struct {
	Name            string                              `json:"name"`
	Harmony         semanticpalette.Harmony             `json:"harmony"`
	Image           string                              `json:"image"`
	Width           int                                 `json:"width"`
	Height          int                                 `json:"height"`
	Representatives []imageanalysis.RepresentativeColor `json:"representatives"`
	Source          theme.Palette                       `json:"source_palette"`
	Calm            theme.Palette                       `json:"calm_palette"`
	Mute            theme.Palette                       `json:"mute_palette"`
	Deep            theme.Palette                       `json:"deep_palette"`
	Vibrant         theme.Palette                       `json:"vibrant_palette"`
	Balanced        theme.Palette                       `json:"balanced_palette"`
}

var previewCorpusFiles = map[string]bool{
	"11-user-audi-quattro.png": true,
	"12-user-pastel-waves.png": true,
}

func main() {
	webDir := flag.String("web-dir", "../dev/palette-preview", "directory containing the preview HTML")
	addr := flag.String("addr", "127.0.0.1:8787", "HTTP listen address")
	flag.Parse()

	corpusDir := filepath.Join(*webDir, "corpus")
	if err := generateCorpus(corpusDir); err != nil {
		log.Fatal(err)
	}

	fs := http.FileServer(http.Dir(*webDir))
	http.HandleFunc("/api/palettes", func(w http.ResponseWriter, r *http.Request) {
		harmonyValue := r.URL.Query().Get("harmony")
		if harmonyValue == "" {
			harmonyValue = string(semanticpalette.HarmonyAuto)
		}
		harmony, err := semanticpalette.ParseHarmony(harmonyValue)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		writePalettes(w, corpusDir, harmony)
	})
	http.HandleFunc("/api/palettes/all", func(w http.ResponseWriter, _ *http.Request) {
		writeAllPalettes(w, corpusDir)
	})
	http.Handle("/", fs)
	log.Printf("palette preview: http://%s", *addr)
	log.Fatal(http.ListenAndServe(*addr, nil))
}

func writeAllPalettes(w http.ResponseWriter, corpusDir string) {
	harmonies := []semanticpalette.Harmony{
		semanticpalette.HarmonyAuto,
		semanticpalette.HarmonyMonochromatic,
		semanticpalette.HarmonyAnalogous,
		semanticpalette.HarmonyComplementary,
		semanticpalette.HarmonySplitComplementary,
		semanticpalette.HarmonyTriadic,
	}
	all := struct {
		ImageCount         int       `json:"image_count"`
		HarmonyCount       int       `json:"harmony_count"`
		VariantsPerHarmony int       `json:"variants_per_harmony"`
		PaletteCount       int       `json:"palette_count"`
		Palettes           []preview `json:"palettes"`
	}{HarmonyCount: len(harmonies), VariantsPerHarmony: 6}
	for _, harmony := range harmonies {
		recorder := httptest.NewRecorder()
		writePalettes(recorder, corpusDir, harmony)
		if recorder.Code != http.StatusOK {
			http.Error(w, recorder.Body.String(), recorder.Code)
			return
		}
		var items []preview
		if err := json.Unmarshal(recorder.Body.Bytes(), &items); err != nil {
			http.Error(w, fmt.Sprintf("decode %s harmony: %v", harmony, err), http.StatusInternalServerError)
			return
		}
		all.Palettes = append(all.Palettes, items...)
	}
	all.ImageCount = len(previewCorpusFiles)
	all.PaletteCount = len(all.Palettes) * all.VariantsPerHarmony
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(all)
}

func writePalettes(w http.ResponseWriter, corpusDir string, harmony semanticpalette.Harmony) {
	w.Header().Set("Content-Type", "application/json")
	entries, err := os.ReadDir(corpusDir)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	result := make([]preview, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || !previewCorpusFiles[entry.Name()] {
			continue
		}
		path := filepath.Join(corpusDir, entry.Name())
		analysis, err := imageanalysis.DecodeFile(path)
		if err != nil {
			http.Error(w, fmt.Sprintf("analyze %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		before, err := semanticpalette.Source(analysis.Representatives, harmony)
		if err != nil {
			http.Error(w, fmt.Sprintf("source palette %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		sourcePalette, err := contrast.Enforce(before, settings.Defaults().Contrast)
		if err != nil {
			http.Error(w, fmt.Sprintf("enforce source contrast %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		calmPalette, err := semanticpalette.Calm(before)
		if err != nil {
			http.Error(w, fmt.Sprintf("build calm palette %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		calmPalette, err = contrast.Enforce(calmPalette, settings.Defaults().Contrast)
		if err != nil {
			http.Error(w, fmt.Sprintf("enforce calm contrast %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		mutePalette, err := semanticpalette.Mute(before)
		if err != nil {
			http.Error(w, fmt.Sprintf("build mute palette %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		mutePalette, err = contrast.Enforce(mutePalette, settings.Defaults().Contrast)
		if err != nil {
			http.Error(w, fmt.Sprintf("enforce mute contrast %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		deepPalette, err := semanticpalette.Deep(before)
		if err != nil {
			http.Error(w, fmt.Sprintf("build deep palette %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		deepPalette, err = semanticpalette.NormalizeSurfaceHierarchy(deepPalette)
		if err != nil {
			http.Error(w, fmt.Sprintf("normalize deep surfaces %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		deepPalette, err = contrast.Enforce(deepPalette, settings.Defaults().Contrast)
		if err != nil {
			http.Error(w, fmt.Sprintf("enforce deep contrast %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		vibrantPalette, err := semanticpalette.Vibrant(before)
		if err != nil {
			http.Error(w, fmt.Sprintf("build vibrant palette %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		vibrantPalette, err = contrast.Enforce(vibrantPalette, settings.Defaults().Contrast)
		if err != nil {
			http.Error(w, fmt.Sprintf("enforce vibrant contrast %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		balancedPalette, err := semanticpalette.Balanced(before)
		if err != nil {
			http.Error(w, fmt.Sprintf("build balanced palette %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		balancedPalette, err = contrast.Enforce(balancedPalette, settings.Defaults().Contrast)
		if err != nil {
			http.Error(w, fmt.Sprintf("enforce balanced contrast %s: %v", entry.Name(), err), http.StatusInternalServerError)
			return
		}
		finalPalettes := []*theme.Palette{&sourcePalette, &calmPalette, &mutePalette, &deepPalette, &vibrantPalette, &balancedPalette}
		for _, paletteValue := range finalPalettes {
			*paletteValue, err = semanticpalette.EnsureANSIDistinctAfterContrast(
				*paletteValue,
				settings.Defaults().Contrast.ANSI,
				settings.Defaults().Contrast.BrightANSI,
			)
			if err != nil {
				http.Error(w, fmt.Sprintf("finalize ANSI palette %s: %v", entry.Name(), err), http.StatusInternalServerError)
				return
			}
		}
		result = append(result, preview{
			Name: trimPNG(entry.Name()), Harmony: harmony, Image: "/corpus/" + entry.Name(), Width: analysis.Width,
			Height: analysis.Height, Representatives: analysis.Representatives, Source: sourcePalette, Calm: calmPalette, Mute: mutePalette, Deep: deepPalette, Vibrant: vibrantPalette, Balanced: balancedPalette,
		})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Name < result[j].Name })
	_ = json.NewEncoder(w).Encode(result)
}

func trimPNG(name string) string { return name[:len(name)-len(filepath.Ext(name))] }

func generateCorpus(dir string) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	for name := range previewCorpusFiles {
		if _, err := os.Stat(filepath.Join(dir, name)); err != nil {
			return fmt.Errorf("preview image %s is missing: %w", name, err)
		}
	}
	return nil

	/*
		corpus := []struct {
			name  string
			paint func(*image.RGBA)
		}{
			{"01-monochromatic-dark-blue", solid("#14233d")},
			{"02-monochromatic-bright-orange", solid("#ff7a28")},
			{"03-grayscale-dark", solid("#303238")},
			{"04-grayscale-light", solid("#e7e8eb")},
			{"05-two-color", split(color.RGBA{22, 37, 69, 255}, color.RGBA{202, 77, 84, 255})},
			{"06-three-color", thirds()},
			{"07-tokyo-night-like", tokyoNight()},
			{"08-highly-colorful", colorful()},
			{"09-pastel", pastel()},
			{"10-very-dark-photo", darkPhoto()},
		}
		for _, item := range corpus {
			img := image.NewRGBA(image.Rect(0, 0, width, height))
			item.paint(img)
			file, err := os.Create(filepath.Join(dir, item.name+".png"))
			if err != nil {
				return err
			}
			err = png.Encode(file, img)
			closeErr := file.Close()
			if err != nil {
				return err
			}
			if closeErr != nil {
				return closeErr
			}
		}
		return nil
	*/
}

func solid(hex string) func(*image.RGBA) {
	c := parseHex(hex)
	return func(img *image.RGBA) { draw.Draw(img, img.Bounds(), &image.Uniform{c}, image.Point{}, draw.Src) }
}
func split(a, b color.RGBA) func(*image.RGBA) {
	return func(img *image.RGBA) {
		draw.Draw(img, image.Rect(0, 0, width/2, height), &image.Uniform{a}, image.Point{}, draw.Src)
		draw.Draw(img, image.Rect(width/2, 0, width, height), &image.Uniform{b}, image.Point{}, draw.Src)
	}
}
func thirds() func(*image.RGBA) {
	return func(img *image.RGBA) {
		split(color.RGBA{26, 35, 55, 255}, color.RGBA{46, 117, 117, 255})(img)
		draw.Draw(img, image.Rect(width*2/3, 0, width, height), &image.Uniform{color.RGBA{188, 91, 121, 255}}, image.Point{}, draw.Src)
	}
}
func tokyoNight() func(*image.RGBA) {
	return func(img *image.RGBA) {
		draw.Draw(img, img.Bounds(), &image.Uniform{parseHex("#1a1b26")}, image.Point{}, draw.Src)
		circle(img, 170, 170, 125, parseHex("#7aa2f7"))
		circle(img, 430, 130, 105, parseHex("#bb9af7"))
		circle(img, 450, 285, 75, parseHex("#f7768e"))
	}
}
func colorful() func(*image.RGBA) {
	return func(img *image.RGBA) {
		draw.Draw(img, img.Bounds(), &image.Uniform{parseHex("#10243b")}, image.Point{}, draw.Src)
		circle(img, 120, 120, 145, parseHex("#ef476f"))
		circle(img, 300, 210, 160, parseHex("#06d6a0"))
		circle(img, 520, 120, 145, parseHex("#ffd166"))
		circle(img, 520, 320, 120, parseHex("#118ab2"))
	}
}
func pastel() func(*image.RGBA) {
	return func(img *image.RGBA) {
		draw.Draw(img, img.Bounds(), &image.Uniform{parseHex("#f5e8dc")}, image.Point{}, draw.Src)
		circle(img, 120, 180, 150, parseHex("#f6b6c8"))
		circle(img, 330, 120, 145, parseHex("#b9d9f2"))
		circle(img, 520, 235, 140, parseHex("#c2e6c2"))
	}
}
func darkPhoto() func(*image.RGBA) {
	return func(img *image.RGBA) {
		draw.Draw(img, img.Bounds(), &image.Uniform{parseHex("#090d14")}, image.Point{}, draw.Src)
		circle(img, 150, 260, 180, parseHex("#152d3d"))
		circle(img, 420, 100, 120, parseHex("#3d263d"))
		circle(img, 510, 295, 100, parseHex("#6b3f22"))
	}
}

func circle(img *image.RGBA, cx, cy, radius int, c color.RGBA) {
	for y := cy - radius; y <= cy+radius; y++ {
		for x := cx - radius; x <= cx+radius; x++ {
			dx, dy := x-cx, y-cy
			if dx*dx+dy*dy <= radius*radius && image.Pt(x, y).In(img.Bounds()) {
				img.SetRGBA(x, y, c)
			}
		}
	}
}
func parseHex(value string) color.RGBA {
	var r, g, b uint8
	_, _ = fmt.Sscanf(value, "#%02x%02x%02x", &r, &g, &b)
	return color.RGBA{r, g, b, 255}
}
