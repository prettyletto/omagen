# QML ↔ Go contract

QML invokes the bundled `bin/omagen` executable with command-shaped argv. The
backend writes one JSON value on stdout for successful commands and human
readable diagnostics on stderr for failures. Exit code `0` means success,
`1` means an operational failure, and `2` means invalid command usage unless a
specific command documents otherwise.

`qml/gateways/BackendCommand.qml` owns the shared bounded stdout/stderr and
JSON/exit handling. `SessionGateway`, `GenerationGateway`, `PreviewGateway`,
`ApplyGateway`, `DemoGateway`, `LookFeelGateway`, and `RuntimeGateway` own their
command families. `qml/services/BackendService.qml`
is the compatibility façade used by the composition root; it forwards gateway
signals without becoming a second domain implementation.

`ThemeGateway` owns the additive `theme list` and `theme edit <theme-id>`
commands. An edit response identifies an initial source workspace; the normal
generation seam can then derive the five non-source directions directly from
its authored `colors.toml` without requiring a new image. The authored source
plus those five directions preserve the six-variant contract. Apply may append
`--replace-source` only when the selected edit keeps its trusted source slug.

New gateway code must preserve command names, argument ordering, JSON field
names, bounded stdout/stderr handling, and signal payloads. Views should call a
gateway/service method and react to a signal; they should not instantiate
arbitrary backend processes.

The authoritative implementation is `backend/internal/cli` plus the owning
domain package. Use `backend/internal/cli/*_test.go` and the QML callers as the
wire-contract test surface.
