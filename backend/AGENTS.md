# Backend agent guide

Start with `docs/agents/recipes/backend-command-change.md` for CLI work or
the recipe named by `docs/agents/context-map.yaml` for a domain change.

`internal/cli` adapts argv to domain packages and owns the wire contract.
`session`, `apply`, `preview`, and `cleanup` own durable lifecycle safety.
`imageanalysis`, `colorspace`, `palette`, and `contrast` are protected
deterministic engine code. `runtime` and `omarchy` are native integration
seams. Keep tests beside the package they protect.

Run `go test ./...`, `go test -race ./...`, and `go vet ./...` from this
directory. Do not move transaction or cleanup ownership into QML.
