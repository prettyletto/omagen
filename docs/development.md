# Development

The repository is itself the Omarchy plugin package. A checkout must remain
runnable as a plugin without requiring a separate build tree or installation
script at runtime.

## Branch lifecycle

Omagen moves through three explicit branches:

- `nightly` is experimental development. It may contain incomplete work and
  does not carry a required hosted CI gate on every push.
- `dev` is the protected integration branch. Pull requests targeting it run
  the full validation and marketplace-preflight gates and may produce release
  candidates.
- `main` is the stable product branch. It receives reviewed promotions from
  `dev`, stable release tags, and the exact commit submitted to the Omarchy
  plugin marketplace.

The only supported promotion path is `nightly → dev → main`. Never promote
nightly directly to the stable branch.

See [the release process](development/release-process.md) for branch
protection, candidate tags, exact-commit validation, and marketplace updates.

## First contribution

Read the root `AGENTS.md`, run `scripts/agent-context <domain>`, and follow one
recipe under `docs/agents/recipes/` before editing. Inspect the target and its
direct callers, run focused checks first, then the full gate. Keep branch names
and stability claims accurate: `nightly` experiments, `dev` integrates, and
`main` releases. Do not introduce historical branch or deleted-path assumptions
into new documentation.

## Repository layout

~~~text
manifest.json             Omarchy plugin contract
bar-manifest.json          Separate full-bar plugin contract
preview.png               Optional marketplace listing preview
Omagen.qml                Overlay entry point
OmagenBarWidget.qml       Bar-widget entry point
OmagenBar.qml              Full replacement bar entry point
qml/                      QML views, components, services, and state
backend/                  Go backend and internal services
bin/omagen                Bundled runtime backend binary
demo/                     Deterministic Demo workspace assets
assets/                   README and documentation media
docs/                     User and contributor guides
docs/product/             Canonical product README, assets, demos, and release docs
docs/development/         Focused developer runbooks and health notes
scripts/v1-check.sh       Full validation gate
scripts/promote-product-docs.py  Stable README projection and link validation
dev-install.sh            Local development installer
uninstall.sh              Complete local/plugin-state uninstaller
~~~

The plugin manifest declares the ID <code>pretty.omagen</code>, the
<code>overlay</code> and <code>bar-widget</code> kinds, the two QML entry points,
and the default right-side bar section. See the root
[manifest.json](../manifest.json).

The separate <code>pretty.omagen.bar</code> manifest owns the full bar; keep
the two plugin payloads and their ownership boundaries separate.

Before deleting code, search production callers, dynamic QML loads, manifests,
install payloads, tests, and documentation. Compatibility and ownership code
can look obsolete while still protecting user state.

## Bundled backend provenance

The runtime binary is intentionally checked into the plugin because users do
not need Go installed to use Omagen. It must be produced from the reviewed
backend sources with the canonical builder:

~~~sh
./scripts/build-backend.sh
./scripts/verify-bundled-backend.sh
~~~

The builder pins the source-to-binary settings that affect reproducibility:
the exact Go toolchain declared by <code>backend/go.mod</code>, the Linux
<code>amd64</code>/<code>GOAMD64=v1</code> target, <code>CGO_ENABLED=0</code>,
the Go <code>nodwarf5</code> experiment used by that pinned toolchain,
<code>-trimpath</code>, disabled VCS stamping, a cleared Go build ID, and
read-only module resolution. The verifier rebuilds into a temporary directory
and compares the result byte-for-byte with <code>bin/omagen</code>.

The same verifier runs on pull requests targeting `dev` or `main`, and on
pushes to those protected branches. A binary change without a matching source
build fails the check. Candidate and stable commits also receive the
marketplace-preflight report described in [the release process](development/release-process.md).

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

To install a tester checkout without requiring Go, first clone and inspect the
repository, then execute the branch bootstrap at an exact commit. The checked-
in backend is used as-is:

~~~sh
git clone https://github.com/prettyletto/omagen.git /tmp/omagen-review
cd /tmp/omagen-review
git show --stat --oneline <full-40-character-commit-sha>
OMAGEN_TEST_BRANCH=nightly OMAGEN_TEST_COMMIT=<full-40-character-commit-sha> \
  ./scripts/install-branch.sh
~~~

The bootstrap refuses to execute a mutable branch head. It initializes an
empty checkout, fetches only the requested full commit, checks it out detached,
and only then runs `dev-install.sh --skip-build`. `OMAGEN_TEST_COMMIT` is the
source-of-truth selector and `OMAGEN_TEST_BRANCH` is retained only as an
informational tester hint. This marketplace-scanned bootstrap intentionally
fetches the Omagen repository itself; test a fork from a separate checkout.

The regular `install.sh` still builds the backend by default. Pass
`--skip-build` only when the checked-in binary is the intended artifact, as in
the tester bootstrap.

The normal user installation remains the Omarchy plugin-manager command from
the stable `main` README. Do not ask users to build Go or run this development
helper.

## Studio preview retint policy

Studio Preview and Studio Apply run all reviewed application adapters by
default, matching the native Omarchy post-theme command list, except for the
keyboard adapter. Keyboard retint is an explicit opt-in; arbitrary user theme
hooks remain disabled. A narrower policy can be selected without changing QML
by setting
<code>OMAGEN_STUDIO_PREVIEW_APPS</code> in the environment inherited by the
backend:

~~~sh
OMAGEN_STUDIO_PREVIEW_APPS=terminal,browser,helix
~~~

The accepted policies are <code>none</code>, <code>terminal</code>,
<code>all</code>, or a comma-separated list of reviewed adapters. The current
default is <code>all</code> with <code>keyboard</code> skipped. The current
adapter names are
<code>hyprland</code>, <code>btop</code>,
<code>opencode</code>, <code>helix</code>, <code>foot</code>,
<code>tmux</code>, <code>gnome</code>, <code>pi</code>,
<code>claude</code>, <code>browser</code>, <code>vscode</code>,
<code>obsidian</code>, and <code>keyboard</code>, in addition to
<code>terminal</code>.

The same policy can be passed directly to the installed driver for a focused
manual check:

~~~sh
~/.config/omarchy/plugins/pretty.omagen/bin/studio-theme-set \
  preview <candidate> --no-hooks --run terminal,browser --skip helix
~~~

The backend CLI exposes the same controls for a session Preview or an explicit
Studio Apply:

~~~sh
bin/omagen preview apply <session> <generation> <variant> \
  --run terminal,browser --skip hyprland
bin/omagen apply <session> <generation> <variant> <theme-name> \
  --run terminal,browser --skip hyprland
~~~

Studio driver requests also accept `--allow-trusted-hooks` as an explicit
opt-in. Hooks remain disabled by default. The source-derived driver supports
`preview`, `apply`, `restore`, and read-only `inspect` modes; `--scope` limits
theme, shell, Hyprland, application, and background work, while `--wait`
selects critical, full, or fire-and-forget post-commit completion.

Theme promotion and shell/background updates remain serialized. Selected
retint adapters run in parallel after that critical section. Missing optional
commands are reported as skipped, command failures are reported per adapter,
and retint failures are non-fatal after the core theme transaction commits.
An adapter cannot strand Apply in the prepared state. Arbitrary user theme
hooks remain excluded from Studio-controlled Preview and Apply.

Filesystem-heavy application retints and permanent-Apply cache warmers run at
background CPU/I/O priority so they do not compete with Quickshell's scene
update or Hyprland's first frames after the handoff. The short terminal signal
and required Hyprland reload retain normal priority. Cache warming is
single-flight: rapid Apply/re-Apply requests do not stack selector scans or
thumbnail generation, and a stale worker does not start the next theme-specific
cache stage.

Apply returns after the critical theme promotion and shell/background update;
the selected post-commit retint adapters continue in parallel. This keeps the
UI responsive even when an application-specific helper is slow or unavailable.

Preview and Apply are single-flight from the Studio UI. Rapid changes retain
only the newest pending appearance, and an already-live request is completed as
a no-op so it cannot leave Apply waiting for a process that was intentionally
deduplicated. Deferred retint/runtime work is fenced to the activation that
created it; if a newer theme is current, the older job exits without repainting
the desktop. The installed post-theme runtime hook performs the same active-name
check because native Omarchy releases its theme lock before invoking user hooks;
a superseded hook reports a no-op instead of interpreting the newer theme tree
under its stale argument.
Permanent Apply also starts the native theme-selector and background cache
warmers in a single low-priority background worker after the new user theme is
visible. Test Live does not warm these caches because its temporary preview
alias is removed or renamed immediately afterward.

When Apply follows a matching successful Test Live for the same session,
generation, and variant, Omagen promotes the already-materialized live preview
instead of running the theme transaction again. It preserves the live shell,
background, and application state, changes only the permanent theme name, and
publishes the generated preview contents as the persistent user theme. Apply
falls back to a full Studio Apply when there is no matching live preview or
when optional unlock/preview assets or an explicit retint policy require new
work.

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

See [Backend CLI reference](development/cli.md) for command families,
session lifecycle, and safe inspection/mutation guidance.

The repository also contains QtTest files under `qml/tests/`. They are separate
from `qmllint`: `qmllint` checks syntax and static QML issues, while
`qmltestrunner` executes behavioral tests. When a supported Qt test environment
is available, run the suite from the repository root with the runner's input
directory option, for example:

~~~sh
QT_QPA_PLATFORM=offscreen qmltestrunner -input qml/tests
~~~

The exact platform setup is host-dependent. The current restricted development
environment has `qmltestrunner` installed but cannot execute it because its GTK
display setup is unavailable. Do not claim QML behavior coverage from `qmllint`
or the Go gate alone.

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
- A byte-for-byte deterministic rebuild of <code>bin/omagen</code> from
  <code>backend/</code>.
- Manifest and binary version consistency.
- Deterministic marketplace preflight bound to the checked-out full commit.
- Native <code>omarchy plugin validate</code> when Omarchy is available.
- Required plugin files and deterministic Demo assets.
- Absence of plugin symlinks.
- QML syntax when <code>qmllint</code> is available.

The expected final line is:

~~~text
V1 automated regression gate: PASS
~~~

## Real desktop UI testing

Use the repository-local host-side helper for visual and interaction checks
against the running Omarchy/Hyprland session. It covers shell summon/hide,
JSON client and layer lookup, focused-monitor screenshots, keyboard/text input,
and safe waits; see [Real desktop UI testing](development/ui-testing.md).

## Repository health notes

For the behavior-preserving architecture audit, confirmed dead-code candidates,
size-warning guidance, lifecycle risks, coverage signals, and prioritized
follow-up work, see
[Repository health and architecture notes](development/architecture-health.md).


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
