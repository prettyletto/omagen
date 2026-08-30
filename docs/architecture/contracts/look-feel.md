# Look & Feel contract

`backend/internal/lookfeel` resolves a named portable composition into Shell,
Window, Bar, Animations, and terminal intent. The resolved document is passed
through generation/preview/apply without mutating the preset definition.

QML may customize scopes and serialize the resulting document, but the Go
resolver and its tests own preset identity, revisions, normalization, and
portable import/export. `LookFeelControls.qml` is a presentation/editor
surface, not a second resolver.

Interactive editor signals may contain only the field or nested field that
changed. The composition root must recursively merge such patches into the
currently staged document before normalization and preview serialization;
normalizing a partial document directly is not allowed because omitted sibling
settings would become defaults. Explicit whole-scope preset selection and
scope reset actions remain intentional replacements.

## Local saved presets

The final Save & Apply dialog may opt into saving the complete staged
composition as a local preset. Go stores this user-owned recipe under the
Omagen user configuration directory (`omagen/look-feels/`) as a validated
`omagen.look-feel.recipe` manifest. Local IDs use the `local-` namespace and
are appended after built-in catalog entries; they resolve through the same
composition and generation contract. The saved document contains complete
Window, Shell, Bar, Animations, and terminal values, so it is independent of
the built-in recipe from which it was created. Saving it does not write or
claim ownership of a generated theme, native shell files, Hyprland state, or
backgrounds.
