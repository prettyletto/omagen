package preview

import (
	"errors"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/session"
)

type previewApplier struct{}

func (previewApplier) ApplyThemePreview(string, string) (int, bool, error) { return 0, false, nil }

func TestApplyRejectsPendingTransactionBeforePublishingPreview(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "preview-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ApplyPhase:         session.ApplyPhasePrepared,
		AppliedTheme:       "theme-name",
		AppliedGeneration:  "generation-1",
		AppliedVariant:     "source",
		AppliedDisplayName: "Theme Name",
		CreatedAt:          time.Now().UTC(),
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	service := newServiceWithThemeRoot(store, previewApplier{}, t.TempDir())
	_, err = service.Apply(Request{SessionID: record.SessionID, GenerationID: "generation-1", Variant: generation.Variant("source")})
	if !errors.Is(err, session.ErrApplyInProgress) {
		t.Fatalf("error=%v, want ErrApplyInProgress", err)
	}
}
