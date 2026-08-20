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

	"github.com/prettyletto/omagen/backend/internal/session"
)

type Service struct {
	sessions *session.Store
}

func NewService(
	sessions *session.Store,
) *Service {
	return &Service{
		sessions: sessions,
	}
}

func (s *Service) Generate(
	ctx context.Context,
	request Request,
) (Result, error) {
	if _, err := s.sessions.Load(
		request.SessionID,
	); err != nil {
		return Result{}, fmt.Errorf(
			"load session: %w",
			err,
		)
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

	if err := os.MkdirAll(
		generationsRoot,
		0o755,
	); err != nil {
		return Result{}, fmt.Errorf(
			"create generations directory: %w",
			err,
		)
	}

	tmpRoot := filepath.Join(
		generationsRoot,
		"."+generationID+".tmp",
	)

	finalRoot := filepath.Join(
		generationsRoot,
		generationID,
	)

	if err := os.Mkdir(
		tmpRoot,
		0o755,
	); err != nil {
		return Result{}, fmt.Errorf(
			"create temporary generation: %w",
			err,
		)
	}

	committed := false

	defer func() {
		if !committed {
			_ = os.RemoveAll(tmpRoot)
		}
	}()

	cachedSource, err := cacheSourceImage(
		tmpRoot,
		request.SourceImage,
	)
	if err != nil {
		return Result{}, err
	}

	if err := runJobs(
		ctx,
		tmpRoot,
		cachedSource,
	); err != nil {
		return Result{}, err
	}

	if err := os.Rename(
		tmpRoot,
		finalRoot,
	); err != nil {
		return Result{}, fmt.Errorf(
			"commit generation: %w",
			err,
		)
	}

	committed = true

	return buildResult(
		generationID,
		finalRoot,
	), nil
}

type jobResult struct {
	variant Variant
	err     error
}

func runJobs(
	ctx context.Context,
	generationRoot string,
	sourceImage string,
) error {
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
				variant: variant,
			}).run(
				ctx,
				generationRoot,
				sourceImage,
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

	var cancellationError error

	for result := range results {
		if result.err == nil {
			continue
		}

		wrapped := fmt.Errorf(
			"%s job: %w",
			result.variant,
			result.err,
		)

		if !errors.Is(
			result.err,
			context.Canceled,
		) {
			return wrapped
		}

		if cancellationError == nil {
			cancellationError = wrapped
		}
	}

	return cancellationError
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
) Result {
	result := Result{
		GenerationID: generationID,
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
