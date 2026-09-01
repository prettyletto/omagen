# Backend agent guide

Start with `docs/agents/recipes/backend-command-change.md` for CLI work or
the recipe named by `docs/agents/context-map.yaml` for a domain change.

Use `scripts/agent-context <domain>` before crossing a package boundary. The
backend is the durable execution side; QML is never the owner of rollback,
recovery, cleanup, or native transaction behavior.

Package route: `internal/cli` adapts argv; `session`, `apply`, `preview`,
`cleanup`, and `fsutil` own lifecycle safety; engine packages own deterministic
palette and six-variant generation; `studio`, `lookfeel`, and `themeedit` own
their domain behavior; `bar`, `barprofile`, `runtime`, `omarchy`, and `demo`
own bar, native, runtime, and session-owned Demo integration.

`internal/cli` adapts argv to domain packages and owns the wire contract.
`session`, `apply`, `preview`, and `cleanup` own durable lifecycle safety.
`imageanalysis`, `colorspace`, `palette`, and `contrast` are protected
deterministic engine code. `runtime` and `omarchy` are native integration
seams. Keep tests beside the package they protect.

Run from this directory:

```zsh
GOCACHE=/tmp/omagen-gocache go test ./...
GOCACHE=/tmp/omagen-gocache go test -race ./...
GOCACHE=/tmp/omagen-gocache go vet ./...
```

If backend sources change, rebuild and verify `../bin/omagen` with
`../scripts/build-backend.sh` and `../scripts/verify-bundled-backend.sh`, then
run the root gate. Preserve aliases, JSON fields, caller-visible stderr, and
exit `1` versus `2`. Do not move transaction or cleanup ownership into QML.
