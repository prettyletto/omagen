package cli

import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/apply"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/cleanup"
	"github.com/prettyletto/omagen/backend/internal/demo"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/omarchy"
	"github.com/prettyletto/omagen/backend/internal/preview"
	"github.com/prettyletto/omagen/backend/internal/session"
	settingspkg "github.com/prettyletto/omagen/backend/internal/settings"
)

type dependencies struct {
	store             *session.Store
	settingsStore     *settingspkg.Store
	omarchyClient     *omarchy.Client
	barStore          *barprofile.Store
	sessionService    *session.Service
	previewService    *preview.Service
	applyService      *apply.Service
	cleanupService    *cleanup.Service
	generationService *generation.Service
	demoService       *demo.Service
}

func newDependencies(stderr io.Writer) (dependencies, error) {
	store, err := session.NewStore()
	if err != nil {
		return dependencies{}, fmt.Errorf("initialize session store: %w", err)
	}
	settingsStore, err := settingspkg.NewStore()
	if err != nil {
		return dependencies{}, fmt.Errorf("initialize settings store: %w", err)
	}
	omarchyClient := omarchy.NewClient(stderr)
	barStore, err := barprofile.NewStore()
	if err != nil {
		return dependencies{}, fmt.Errorf("initialize bar profile store: %w", err)
	}
	sessionService := session.NewService(store, omarchyClient, barStore)
	previewService, err := preview.NewService(store, omarchyClient, barStore)
	if err != nil {
		return dependencies{}, fmt.Errorf("initialize preview service: %w", err)
	}
	applyService, err := apply.NewService(store, omarchyClient, barStore)
	if err != nil {
		return dependencies{}, fmt.Errorf("initialize apply service: %w", err)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return dependencies{}, fmt.Errorf("resolve user home: %w", err)
	}
	cleanupService := cleanup.NewService(store, filepath.Join(home, ".config", "omarchy", "themes"))
	generationService := generation.NewServiceWithBaselineRestorer(store, settingsStore, omarchyClient)
	demoService := demo.NewService(store)

	return dependencies{
		store:             store,
		settingsStore:     settingsStore,
		omarchyClient:     omarchyClient,
		barStore:          barStore,
		sessionService:    sessionService,
		previewService:    previewService,
		applyService:      applyService,
		cleanupService:    cleanupService,
		generationService: generationService,
		demoService:       demoService,
	}, nil
}
