package generation

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	"github.com/prettyletto/omagen/backend/internal/session"
	settingspkg "github.com/prettyletto/omagen/backend/internal/settings"
)

type Service struct {
	sessions *session.Store
	settings *settingspkg.Store
}

func NewService(
	sessions *session.Store,
	settings *settingspkg.Store,
) *Service {
	return &Service{
		sessions: sessions,
		settings: settings,
	}
}

func (s *Service) Generate(
	ctx context.Context,
	request Request,
) (Result, error) {
	record, err := s.loadActiveRecord(request.SessionID)
	if err != nil {
		return Result{}, fmt.Errorf(
			"load session: %w",
			err,
		)
	}
	if record.ApplyPhase != session.ApplyPhaseNone {
		return Result{}, fmt.Errorf("%w: cannot generate while phase is %q", session.ErrApplyInProgress, record.ApplyPhase)
	}
	shellStyle := record.ShellStyle
	desktopStyle := record.DesktopStyle
	barStyle := session.NormalizeBarStyle(record.BarStyle)
	if !record.ExtraConfigs {
		shellStyle = session.ShellStyle{}
		desktopStyle = session.DesktopStyle{}
		barStyle = session.BarStyle{}
	} else if !shellStyle.Valid() {
		shellStyle = session.DefaultShellStyle()
	}

	effectiveSettings, err := s.settings.Load()
	if err != nil {
		return Result{}, fmt.Errorf("load settings: %w", err)
	}
	effectiveSettings, err = settingspkg.ApplyOverrides(
		effectiveSettings,
		request.Overrides,
	)
	if err != nil {
		return Result{}, fmt.Errorf("apply generation overrides: %w", err)
	}

	if err := validateSourceImage(
		request.SourceImage,
	); err != nil {
		return Result{}, err
	}

	generationID, err := newGenerationID()
	if err != nil {
		return Result{}, fmt.Errorf(
			"create generation id: %w",
			err,
		)
	}

	generationsRoot := filepath.Join(
		s.sessions.SessionDir(request.SessionID),
		"generations",
	)

	if err := fsutil.EnsureDir(generationsRoot, 0o755); err != nil {
		return Result{}, fmt.Errorf(
			"create generations directory: %w",
			err,
		)
	}
	if err := fsutil.CleanupStaleTempDirs(generationsRoot, 24*time.Hour, time.Now().UTC()); err != nil {
		return Result{}, fmt.Errorf("cleanup stale generations: %w", err)
	}

	tmpRoot := filepath.Join(
		generationsRoot,
		"."+generationID+".tmp",
	)

	finalRoot := filepath.Join(
		generationsRoot,
		generationID,
	)

	if err := fsutil.EnsureDir(tmpRoot, 0o755); err != nil {
		return Result{}, fmt.Errorf(
			"create temporary generation: %w",
			err,
		)
	}

	committed := false

	defer func() {
		if !committed {
			_ = fsutil.RemoveAllAndSync(tmpRoot)
		}
	}()

	cachedSource, err := cacheSourceImage(
		tmpRoot,
		request.SourceImage,
	)
	if err != nil {
		return Result{}, err
	}

	analysis, err := imageanalysis.DecodeFile(
		cachedSource,
	)
	if err != nil {
		return Result{}, fmt.Errorf(
			"analyze source image: %w",
			err,
		)
	}

	if err := runJobs(
		ctx,
		tmpRoot,
		cachedSource,
		analysis,
		effectiveSettings,
		shellStyle,
		desktopStyle,
		barStyle,
	); err != nil {
		return Result{}, err
	}
	if err := fsutil.SyncDir(tmpRoot); err != nil {
		return Result{}, fmt.Errorf("sync temporary generation: %w", err)
	}

	committed, err = s.commitGeneration(tmpRoot, finalRoot, request, generationID)
	if err != nil {
		return Result{}, fmt.Errorf("commit generation: %w", err)
	}
	if !committed {
		return Result{}, fmt.Errorf("commit generation: no changes committed")
	}

	return buildResult(
		generationID,
		finalRoot,
		effectiveSettings,
	), nil
}

func (s *Service) loadActiveRecord(sessionID string) (session.Record, error) {
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return session.Record{}, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer lock.Close()
	active, exists, err := s.sessions.LoadActive()
	if err != nil {
		return session.Record{}, fmt.Errorf("load active session: %w", err)
	}
	if !exists || active.SessionID != sessionID {
		return session.Record{}, session.ErrSessionNotActive
	}
	record, err := s.sessions.Load(sessionID)
	if err != nil {
		return session.Record{}, fmt.Errorf("load session: %w", err)
	}
	if record.ApplyPhase != session.ApplyPhaseNone {
		return session.Record{}, fmt.Errorf("%w: cannot generate while phase is %q", session.ErrApplyInProgress, record.ApplyPhase)
	}
	return record, nil
}

func (s *Service) commitGeneration(tmpRoot, finalRoot string, request Request, generationID string) (bool, error) {
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return false, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer lock.Close()
	active, exists, err := s.sessions.LoadActive()
	if err != nil {
		return false, fmt.Errorf("load active session: %w", err)
	}
	if !exists || active.SessionID != request.SessionID {
		return false, session.ErrSessionNotActive
	}
	record, err := s.sessions.Load(request.SessionID)
	if err != nil {
		return false, fmt.Errorf("reload session after generation: %w", err)
	}
	if record.ApplyPhase != session.ApplyPhaseNone {
		return false, fmt.Errorf("%w: cannot commit generation while phase is %q", session.ErrApplyInProgress, record.ApplyPhase)
	}
	renamed, err := fsutil.RenameAndSyncNoReplace(tmpRoot, finalRoot)
	if !renamed {
		return false, err
	}
	if err != nil {
		_ = fsutil.RemoveAllAndSync(finalRoot)
		return false, err
	}
	record.SourceImage = request.SourceImage
	record.GenerationID = generationID
	record.PreviewVariant = ""
	if err := s.sessions.Save(record); err != nil {
		_ = fsutil.RemoveAllAndSync(finalRoot)
		return false, fmt.Errorf("persist generation progress: %w", err)
	}
	return true, nil
}

type jobResult struct {
	variant Variant
	err     error
}

func runJobs(
	ctx context.Context,
	generationRoot string,
	sourceImage string,
	analysis *imageanalysis.Analysis,
	effectiveSettings settingspkg.Settings,
	shellStyle session.ShellStyle,
	desktopStyle session.DesktopStyle,
	barStyle session.BarStyle,
) error {
	parentCtx := ctx
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	results := make(
		chan jobResult,
		len(orderedVariants),
	)

	var wg sync.WaitGroup

	for _, variant := range orderedVariants {
		variant := variant

		wg.Add(1)

		go func() {
			defer wg.Done()

			err := (job{
				variant:      variant,
				sourceImage:  sourceImage,
				analysis:     analysis,
				settings:     effectiveSettings,
				shellStyle:   shellStyle,
				desktopStyle: desktopStyle,
				barStyle:     barStyle,
			}).run(
				ctx,
				generationRoot,
			)
			if err != nil {
				cancel()
			}

			results <- jobResult{
				variant: variant,
				err:     err,
			}
		}()
	}

	wg.Wait()
	close(results)

	errorsByVariant := make(map[Variant]error, len(orderedVariants))
	for result := range results {
		errorsByVariant[result.variant] = result.err
	}
	parentErr := parentCtx.Err()
	for _, variant := range orderedVariants {
		err := errorsByVariant[variant]
		if err == nil || errors.Is(err, context.Canceled) || (parentErr != nil && errors.Is(err, parentErr)) {
			continue
		}
		return fmt.Errorf("%s job: %w", variant, err)
	}
	if parentErr != nil {
		return parentErr
	}
	for _, variant := range orderedVariants {
		if err := errorsByVariant[variant]; err != nil {
			return fmt.Errorf("%s job: %w", variant, err)
		}
	}
	return nil
}

func validateSourceImage(
	path string,
) error {
	if path == "" {
		return fmt.Errorf(
			"source image is required",
		)
	}

	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf(
			"stat source image: %w",
			err,
		)
	}

	if !info.Mode().IsRegular() {
		return fmt.Errorf(
			"source image is not a regular file",
		)
	}

	return nil
}

func newGenerationID() (string, error) {
	var random [4]byte

	if _, err := rand.Read(
		random[:],
	); err != nil {
		return "", err
	}

	return fmt.Sprintf(
		"%s-%s",
		time.Now().UTC().Format(
			"20060102T150405Z",
		),
		hex.EncodeToString(random[:]),
	), nil
}

func buildResult(
	generationID string,
	root string,
	effectiveSettings settingspkg.Settings,
) Result {
	result := Result{
		GenerationID: generationID,
		Settings:     effectiveSettings,
		Variants: make(
			[]VariantResult,
			0,
			len(orderedVariants),
		),
	}

	for _, variant := range orderedVariants {
		result.Variants = append(
			result.Variants,
			VariantResult{
				Variant: variant,
				Path: filepath.Join(
					root,
					string(variant),
				),
			},
		)
	}

	return result
}
