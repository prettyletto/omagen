# Backend command change

Read `docs/architecture/backend.md`,
`docs/architecture/contracts/qml-backend.md`, the relevant
`backend/internal/cli/*_cmd.go` file, and the owning package contract/tests.

Keep command parsing in `backend/internal/cli`; keep behavior in the owning
domain package. Preserve stdout JSON, stderr wording where callers rely on it,
exit code `1` versus `2`, argument aliases, and ordering.

Run focused CLI/domain tests, then from `backend/` run `go test ./...`,
`go test -race ./...`, and `go vet ./...`. If the binary changes, run the
bundled-backend verification. Common trap: changing a command's JSON shape
while only checking that it still exits successfully.
