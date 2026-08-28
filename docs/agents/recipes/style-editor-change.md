# Style editor change

Read:

- `docs/architecture/contracts/style-editor.md`
- `docs/architecture/contracts/bar-spec.md` for BarSpec changes
- `qml/components/AdvancedStyleEditor.qml`
- `qml/features/style-editor/WindowStyle.js` or `AnimationStyle.js` for the
  affected transformation boundary
- `qml/components/ShellLab.qml` and the focused Bar controls only when the
  change crosses those surfaces

Normally avoid `qml/controllers`, backend lifecycle packages, palette and
generation code, Bar runtime host code, and `docs/plans/**`.

Keep helpers pure and preserve the staged `stylesChanged` contract. Run
`qmllint qml/components/AdvancedStyleEditor.qml` when available,
`GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh`, and
`git diff --check`. Manually exercise the affected Live Canvas tab, preview,
and Apply path when a Quickshell session is available.
