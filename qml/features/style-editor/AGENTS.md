# Style-editor feature guide

Start with `docs/agents/recipes/style-editor-change.md` and
`docs/architecture/contracts/style-editor.md`.

The JavaScript files in this directory are pure transformations for staged
style documents. `WindowEditor.qml` and `AnimationsEditor.qml` own their
feature-local controls; `AdvancedStyleEditor.qml` owns tab composition and
the shared staged-output handoff. Keep transformations deterministic and
side-effect free. Do not add backend calls, filesystem writes, session state,
or generic control frameworks here.

Run `qmllint` on the editor and helpers when available, then the repository
gate. Manually check the affected Live Canvas tab and its preview path.
