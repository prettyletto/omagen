# Omagen source palette preview

This is a dev-only visual harness for the real `Omagen → palette.Source()` pipeline. The browser does not extract or modify colors: it requests JSON from the Go server, which calls `imageanalysis.DecodeFile()` and `palette.Source()` for every corpus image.

From the repository root:

```sh
cd backend
go run ./cmd/palette-preview
```

Then open [http://127.0.0.1:8787](http://127.0.0.1:8787). The server creates the ten PNG corpus images in `dev/palette-preview/corpus/` on startup and regenerates them on each run. Use `-addr` to change the listen address or `-web-dir` when starting from a different working directory.

Each card shows the wallpaper, surface hierarchy, foreground/muted text, accent/selection, normal and bright ANSI colors, plus expandable extraction JSON for debugging.
