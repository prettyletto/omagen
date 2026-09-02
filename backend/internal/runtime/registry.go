package runtime

import "github.com/prettyletto/omagen/backend/internal/barprofile"

// NewDefaultAdapterRegistry is the production registry. Keeping construction
// here gives native Shell, Bar, Window, and Animations adapters one explicit
// place to join the runtime without changing the hook or manifest protocol.
func NewDefaultAdapterRegistry() (*AdapterRegistry, error) {
	store, err := barprofile.NewStore()
	if err != nil {
		return nil, err
	}
	barAdapter, err := NewBarAdapter(store)
	if err != nil {
		return nil, err
	}
	shellAdapter, err := NewShellAdapter()
	if err != nil {
		return nil, err
	}
	windowAdapter, err := NewHyprlandAdapter(FeatureWindow)
	if err != nil {
		return nil, err
	}
	animationsAdapter, err := NewHyprlandAdapter(FeatureAnimations)
	if err != nil {
		return nil, err
	}
	return NewAdapterRegistry(shellAdapter, barAdapter, windowAdapter, animationsAdapter)
}
