package cli

import (
	"io"

	"github.com/prettyletto/omagen/backend/internal/barprofile"
)

type barInspectResponse struct {
	SchemaVersion int    `json:"schema_version"`
	Theme         string `json:"theme,omitempty"`
	ConfigPath    string `json:"config_path"`
	ConfigExists  bool   `json:"config_exists"`
	ConfigMode    uint32 `json:"config_mode,omitempty"`
	ConfigSHA256  string `json:"config_sha256,omitempty"`
}

func runBar(args []string, store *barprofile.Store, native interface{ CurrentTheme() (string, error) }, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "usage: omagen bar {inspect|apply-profile|restore} ...")
	}
	switch args[0] {
	case "inspect":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen bar inspect")
		}
		theme, err := native.CurrentTheme()
		if err != nil {
			return fail(stderr, 1, "inspect current theme: %v", err)
		}
		snapshot, err := store.Capture(theme)
		if err != nil {
			return fail(stderr, 1, "inspect bar: %v", err)
		}
		return writeJSON(stdout, stderr, barInspectResponse{SchemaVersion: snapshot.SchemaVersion, Theme: snapshot.Theme, ConfigPath: snapshot.ConfigPath, ConfigExists: snapshot.ConfigExists, ConfigMode: snapshot.ConfigMode, ConfigSHA256: snapshot.ConfigSHA256})
	case "apply-profile":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen bar apply-profile <profile.json>")
		}
		profile, err := barprofile.LoadProfile(args[1])
		if err != nil {
			return fail(stderr, 2, "load bar profile: %v", err)
		}
		if err := store.Apply(profile); err != nil {
			return fail(stderr, 1, "apply bar profile: %v", err)
		}
		return writeJSON(stdout, stderr, profile)
	case "restore":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen bar restore <session_id>")
		}
		snapshot, err := store.LoadSnapshot(args[1])
		if err != nil {
			return fail(stderr, 1, "load bar snapshot: %v", err)
		}
		if err := store.Restore(snapshot); err != nil {
			return fail(stderr, 1, "restore bar snapshot: %v", err)
		}
		return writeJSON(stdout, stderr, map[string]any{"restored": true, "session_id": args[1]})
	default:
		return fail(stderr, 2, "unknown bar command: %s", args[0])
	}
}
