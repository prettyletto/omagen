# Backend architecture

The Go module under `backend/` is the durable execution side of Omagen. The
CLI is an adapter: it validates argv, constructs domain dependencies, invokes a
domain package, and writes the established JSON/exit contract.

The domain packages are intentionally separate:

- `imageanalysis`, `colorspace`, `palette`, and `contrast` produce the
  deterministic palette pipeline.
- `generation` materializes six theme directions and generation artifacts.
- `session`, `preview`, `apply`, and `cleanup` coordinate durable ownership,
  temporary state, transactions, and safe removal.
- `demo` owns temporary workspace/window behavior and capability fallbacks.
- `lookfeel`, `bar`, `barprofile`, and `theme` model user-selectable style
  documents and generated files.
- `runtime` adapts advanced runtime features; `omarchy` talks to native
  Omarchy commands.
- `settings` and `terminaltheme` are supporting persistence/materialization
  domains.
- `themeedit` adopts merged stock/user themes into source-only editable
  workspaces and writes portable theme recipes.

The package-level tests are the primary contract tests. The CLI must remain
thin enough that command behavior can be located without reading the engine
implementation, while engine changes should remain in the owning package.
