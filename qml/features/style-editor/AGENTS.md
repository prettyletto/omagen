# Style-editor feature guide

Start with `docs/agents/recipes/style-editor-change.md` and
`docs/architecture/contracts/style-editor.md`.

The JavaScript files in this directory are pure transformations for staged
style documents. `WindowEditor.qml` and `AnimationsEditor.qml` own their
feature-local controls; `AdvancedStyleEditor.qml` owns tab composition and
the shared staged-output handoff. Keep transformations deterministic and
side-effect free. Do not add backend calls, filesystem writes, session state,
or generic control frameworks here.

Bar controls edit staged BarSpec/profile data; they do not own bar host layout,
workspace/input ownership, or lifecycle transactions. Keep the staged
`stylesChanged` payload complete for Preview and Apply.

Run `qmllint` on the editor and helpers when available, then the repository
gate. Manually check the affected Live Canvas tab, reset behavior, staged
preview, and Apply path. If topology or orientation changes, follow the Bar
recipe too.
