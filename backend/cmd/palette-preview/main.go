// Command palette-preview runs the development-only source-palette visualizer.
// It deliberately calls the same DecodeFile and palette.Source functions used
// by Omagen; this command only supplies HTTP/JSON around that pipeline.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
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
}
