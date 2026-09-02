# Look & Feel change

Read `docs/architecture/contracts/look-feel.md`, the relevant
`backend/internal/lookfeel` tests, and the QML editor only when presentation is
in scope.

Keep named preset resolution and portable import/export in Go. Normally do not
touch palette algorithms, session transaction code, or full Bar rendering.
Preserve preset identity, revision, normalization, scope customization, and
terminal intent.

Run `go test ./internal/lookfeel ./internal/theme ./internal/cli` plus the full
Go checks as appropriate. Manually inspect preset selection, reset-by-scope,
preview, and serialized import/export when affected. Common trap: changing a
preset default can alter generated artifacts without changing its name.
