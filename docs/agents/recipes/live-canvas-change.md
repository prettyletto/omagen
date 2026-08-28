# Live Canvas or Studio change

Read `docs/architecture/frontend.md`,
`docs/architecture/contracts/qml-backend.md`,
`docs/architecture/contracts/qml-controllers.md`,
`docs/architecture/contracts/engine.md`, and the target parts of
`LiveCanvasPanel.qml`, `AdvancedStyleEditor.qml`,
`qml/controllers/PreviewController.qml`, `qml/controllers/DemoController.qml`,
and `backend/internal/studio`.

Keep editor state, preview requests, Demo, and Apply as separate concerns.
Normally edit the Live Canvas view/components plus the narrow gateway seam; do
not reimplement preview, Apply, recovery, or palette algorithms in QML.

Run `go test ./internal/studio ./internal/preview ./internal/cli` and the QML
gate. Manually validate Test Live, changing variant, Back, Demo, Cancel, and
Apply if those flows are affected. Common trap: style JSON used by Test Live
must remain complete and equivalent to generation/Apply input.
