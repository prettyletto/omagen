# Style editor contract

`qml/components/AdvancedStyleEditor.qml` is the visual composition for the
Window, Shell, Bar, and Animations tabs used by Live Canvas. It stages complete
style documents and emits `stylesChanged`; it does not write files or call the
backend directly.

The editor has focused implementation seams:

- `qml/features/style-editor/WindowEditor.qml` owns the Window editing surface
  and its local border-size interaction state. Its shared window opacity is a
  0–100 percent steady-state value applied to active and inactive normal
  windows; preset or reopened-theme documents provide the initial and Reset
  value (72% for Glass Blur), while an editor adjustment is a staged override.
- `qml/features/style-editor/WindowStyle.js` owns desktop-style normalization,
  border-size conversion, and Window option transformations.
- `qml/features/style-editor/AnimationsEditor.qml` owns the Animations editing
  surface, while `AnimationStyle.js` owns motion normalization, effect
  defaults, trigger editing, numeric edits, and animation presets.
- `qml/components/ShellLab.qml` owns the cohesive Shell editing surface.
- `qml/components/BarDockControls.qml` and
  `BarWorkspaceControls.qml` own the reusable Bar editing surfaces. BarSpec
  normalization remains governed by the [BarSpec contract](bar-spec.md).

The parent intentionally retains tab navigation, shared colors, scroll/focus
behavior, and the final `stylesChanged` composition. Those concerns cross all
four tabs and are not separate state machines. Future extraction should follow
an actual ownership or protocol seam rather than a line-count target.

Style helpers are pure JavaScript. They must not spawn processes, mutate the
session, write theme files, or introduce a second style-document authority.
Use the [style-editor recipe](../../agents/recipes/style-editor-change.md) for
focused changes.
