package cleanup

type Result struct {
	OK                    bool     `json:"ok"`
	ActiveSession         string   `json:"active_session,omitempty"`
	PreviewAliasesRemoved int      `json:"preview_aliases_removed"`
	TempDirsRemoved       int      `json:"temp_dirs_removed"`
	DemoDirsRemoved       int      `json:"demo_dirs_removed"`
	SessionDirsRemoved    int      `json:"session_dirs_removed"`
	Warnings              []string `json:"warnings,omitempty"`
}
