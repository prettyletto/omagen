# Look & Feel contract

`backend/internal/lookfeel` resolves a named portable composition into Shell,
Window, Bar, Animations, and terminal intent. The resolved document is passed
through generation/preview/apply without mutating the preset definition.

QML may customize scopes and serialize the resulting document, but the Go
resolver and its tests own preset identity, revisions, normalization, and
portable import/export. `LookFeelControls.qml` is a presentation/editor
surface, not a second resolver.
