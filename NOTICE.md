# Notices

Omagen is distributed under the MIT License; see [`LICENSE`](LICENSE).

The repository includes a bundled Go backend and compiled shader assets so
users do not need Go or shader tooling installed. Their source, deterministic
build settings, and repository licenses remain part of the source tree. The
release process records the toolchain and checksums for each stable artifact.

The Go dependency graph is declared in [`backend/go.mod`](backend/go.mod) and
is built with the pinned toolchain declared there. The checked-in shader source
and QSB artifact hashes are recorded in
[`docs/shader-provenance.json`](docs/shader-provenance.json) and verified by
`scripts/verify-shader-provenance.py`. Release provenance must additionally
record the Qt/qsb version used to produce the QSB files.
