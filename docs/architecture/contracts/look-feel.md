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
