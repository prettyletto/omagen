# Development

The repository is itself the Omarchy plugin package. A checkout must remain
runnable as a plugin without requiring a separate build tree or installation
script at runtime.

## Repository layout

~~~text
manifest.json             Omarchy plugin contract
preview.png               Optional marketplace listing preview
Omagen.qml                Overlay entry point
OmagenBarWidget.qml       Bar-widget entry point
qml/                      QML views, components, services, and state
backend/                  Go backend and internal services
bin/omagen                Bundled runtime backend binary
demo/                     Deterministic Demo workspace assets
assets/                   README and documentation media
docs/                     User and contributor guides
scripts/v1-check.sh       Full validation gate
dev-install.sh            Local development installer
~~~

The plugin manifest declares the ID <code>pretty.omagen</code>, the
<code>overlay</code> and <code>bar-widget</code> kinds, the two QML entry points,
and the default right-side bar section. See the root
[manifest.json](../manifest.json).

The root <code>preview.png</code> is a marketplace showcase image. It is not a
runtime entry point and is not required by the Omarchy shell loader; the
community marketplace can resize and optimize it for plugin listings.

## Local development installation

From the repository root:

~~~sh
./dev-install.sh
~~~

This builds the backend, synchronizes the checkout into the active Omarchy
plugin directory, rescans the shell, and restarts the shell for development.
Use it while the desktop is idle because the shell watches the installed QML
files.

The normal user installation remains the Omarchy plugin-manager command from
the root [README](../README.md). Do not ask users to build Go or run this
development helper.

## Backend checks

~~~sh
cd backend
go test ./...
go test -race ./...
go vet ./...
~~~

Focused checks can be run from the backend module, for example:

~~~sh
go test ./internal/demo
~~~

## QML checks

When <code>qmllint</code> is available, run it over the plugin QML files. The
full gate discovers the QML files automatically and runs the check when the
tool is installed.

## Full validation

From the repository root:

~~~sh
GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh
~~~

The gate checks:

- Go formatting, unit tests, race tests, and vet.
- The bundled root <code>bin/omagen</code> binary and CLI smoke commands.
- Manifest and binary version consistency.
- Native <code>omarchy plugin validate</code> when Omarchy is available.
- Required plugin files and deterministic Demo assets.
- Absence of plugin symlinks.
- QML syntax when <code>qmllint</code> is available.

The expected final line is:

~~~text
V1 automated regression gate: PASS
~~~

## Development boundaries

- Keep the bundled runtime binary at the repository root
  <code>bin/omagen</code>.
- Resolve that binary from QML with the plugin-relative path.
- Do not start a second standalone Quickshell process.
- Do not edit packaged Omarchy files under <code>/usr/share/omarchy/</code>.
- Preserve Quattro's native widget layout and input ownership.
- Keep backend session state authoritative for Cancel, Quit, Apply, and
  recovery.
- Report focused test results separately from live desktop or visual
  confirmation.
