package theme

import (
	"fmt"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
)

// WriteLookFeelMetadata stores the composition identity alongside the native
// theme artifacts. The file is inspectable provenance; no runtime reads it.
func WriteLookFeelMetadata(themeDir string, document session.LookFeelDocument) error {
	document = session.NormalizeLookFeelDocument(document)
	if document.SchemaVersion != 1 || document.PresetRevision < 1 || document.Preset == "" {
		return fmt.Errorf("invalid Look & Feel document")
	}
	path := filepath.Join(themeDir, "omagen.look-feel.json")
	if err := fsutil.AtomicWriteJSON(path, document, 0o644); err != nil {
		return fmt.Errorf("write Look & Feel metadata: %w", err)
	}
	return nil
}

// WriteTerminalTranslucency stores bounded adapter intent for the later
// terminal materializer. Keeping this separate from the native terminal files
// makes the staged contract inspectable and preserves a no-op native path.
func WriteTerminalTranslucency(themeDir string, spec session.TerminalTranslucency) error {
	spec = session.NormalizeTerminalTranslucency(spec)
	if err := spec.Validate(); err != nil {
		return err
	}
	path := filepath.Join(themeDir, "omagen.terminal.json")
	if err := fsutil.AtomicWriteJSON(path, spec, 0o644); err != nil {
		return fmt.Errorf("write terminal translucency metadata: %w", err)
	}
	return nil
}
