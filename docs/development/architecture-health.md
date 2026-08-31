# Repository health and architecture notes

This document records the behavior-preserving repository health audit completed
on 2026-08-31. It is a developer reference for deciding what is safe to clean
up, what needs deeper design work, and which contracts must not move casually.

The audit itself was read-only. The checkout already contained unrelated edits
before the audit began; those edits were not reviewed as if they were audit
changes and were not modified. The behavior-neutral cleanup described in
`Applied behavior-neutral cleanup` was performed afterward.

## Executive summary

The repository has a strong documented ownership model and a healthy Go test,
vet, architecture-routing, and documentation-link baseline. The first cleanup
pass also removed several unreachable QML editor/preview modules and one
unreferenced developer helper without changing the product contracts.

The audit's highest-confidence maintenance candidates were small and
behavior-neutral, and they have now been applied:

1. Remove or test-scope the unused `parseRetintOptions` helper.
2. Remove or test-scope the unused `runSession` forwarding wrapper.
3. Remove the tracked Python bytecode artifact and ignore future bytecode.
4. Avoid copying `qml/tests/` into installed runtime plugin directories.

The highest-leverage architecture opportunity is to deepen the shared candidate
materialization seam used by Generation and Preview. The next most valuable
opportunity is a CLI-local parser for the style/configuration grammar shared by
`generate` and `session begin`. Both require characterization tests first;
neither should be treated as a mechanical file split.

There are also two findings that deserve explicit engineering follow-up because
they touch safety or lifecycle behavior:

- a timing-sensitive Preview test around detached post-commit work;
- Demo cleanup trusting a persisted directory path without proving that it is
  inside the session-owned directory.

Those findings are documented here, not fixed by this audit.

## Contracts to preserve

Before changing any module, read the route in [`AGENTS.md`](../../AGENTS.md),
the relevant recipe under [`docs/agents/recipes/`](../agents/recipes/), and the
current architecture document under [`docs/architecture/`](../architecture/README.md).

The following contracts are load-bearing:

- The durable backend session record is authoritative for baseline capture,
  rollback, interrupted Apply state, and recovery. QML is a view and request
  coordinator, not a second durable authority.
- Apply, Cancel, Quit, recovery, Preview cleanup, and Demo cleanup must prove
  Omagen ownership before removing resources. User theme files, native
  `shell.json`, Hyprland state, and backgrounds are not Omagen-owned unless a
  session transaction recorded exact ownership.
- The six-variant palette and generation semantics, colorspace behavior, and
  contrast enforcement are protected contracts.
- QML must use the existing Go JSON wire contract. Command names, argv order,
  JSON fields, stdout/stderr behavior, and exit codes are compatibility
  surfaces.
- `pretty.omagen` is the overlay/bar-widget plugin and `pretty.omagen.bar` is
  the full bar plugin. Their manifests and ownership remain separate.
- Omarchy/Quattro owns native shell and widget layout. Omagen's bar, runtime
  bridge, and shell effects are additive or explicitly opted into.

## Current architecture map

The backend is the durable execution side. The CLI is an adapter that parses
argv, constructs dependencies, invokes a domain module, and writes the stable
JSON/exit contract.

| Area | Primary modules | Maintainer concern |
| --- | --- | --- |
| Palette | `imageanalysis`, `colorspace`, `palette`, `contrast` | Preserve deterministic colors and semantic contrast. |
| Generation | `generation`, `theme`, `terminaltheme` | Keep six variants and generated-file ownership stable. |
| Lifecycle | `session`, `preview`, `apply`, `cleanup` | Preserve durable authority, ownership markers, and recovery ordering. |
| Native integration | `omarchy`, `runtime` | Keep native theme transaction and post-commit adapters distinct. |
| Demo | `demo` | Resolve capabilities, own only session Demo resources, and clean up safely. |
| QML seam | `qml/gateways`, `qml/services` | Preserve the Go command wire contract. |
| QML state | `qml/controllers`, `qml/state`, `Omagen.qml` | Controllers own operation state; the composition root owns routing and wiring. |
| Bar | `bar`, `OmagenBar.qml`, `OmagenBarWidget.qml`, `barprofile` | Preserve the full-bar vs bar-widget split and Quattro ownership. |
| Installed-theme editing | `themeedit`, `ThemeGateway.qml`, `ThemeEditController.qml` | Keep stock/user precedence and managed-scope ownership explicit. |

The installed-theme editing workflow is implemented and has a contract in
[`theme-edit.md`](../architecture/contracts/theme-edit.md), but it is not yet a
first-class domain in `docs/agents/context-map.yaml`. Until that routing gap is
closed, start with the contract and inspect the direct callers listed above.

## Applied behavior-neutral cleanup

The following audit findings have now been applied in the current worktree:

- Removed the unused `parseRetintOptions` helper and its obsolete test-only
  coverage. The active `parseStudioOptions` path, including the `--apps` alias,
  remains covered.
- Removed the unused `runSession` forwarding wrapper and updated tests to call
  the dependency-aware handler directly.
- Removed the tracked Python bytecode artifact and added `__pycache__/` and
  `*.pyc` ignore rules.
- Kept `qml/tests/` in the source checkout while excluding it from the
  production plugin payload copied by `install.sh`.
- Rebuilt `bin/omagen` and `bin/omagen-studio` from the updated sources so the
  checked-in artifacts still satisfy the repository provenance contract.

These changes remove maintenance noise without changing the active CLI wire
contract or runtime QML behavior. The remaining sections describe findings and
architecture work that still require separately scoped changes.

## Confirmed cleanup candidates from the audit

These were confirmed by repository search, not guesses about code that merely
looked old. They are retained here as the evidence behind the applied changes
and as a pattern for future cleanup. Any similar cleanup should still be made
in a separate change with focused tests and a fresh full validation run.

### Unused CLI helpers

The former `parseRetintOptions` helper in
[`backend/internal/cli/preview_cmd.go`](../../backend/internal/cli/preview_cmd.go)
had no production caller. The active path uses `parseStudioOptions`, which
already handles the current `--run`, `--apps`, and `--skip` options plus scope,
wait, hook, color, and style options. At audit time, its remaining callers were
tests.

The former `runSession` wrapper in
[`backend/internal/cli/session_cmd.go`](../../backend/internal/cli/session_cmd.go)
only forwarded to `runSessionWithDependencies`; production dispatch called the
dependency-aware function directly. At audit time, the remaining callers were
tests.

The applied change used this safe approach:

- first preserve the active parser's `--apps` alias and all error behavior;
- update or move tests before deleting a wrapper;
- run focused CLI tests, then the full Go and package checks;
- do not move command parsing into a domain module: the CLI adapter is the
  correct seam for argv grammar.

### Tracked generated bytecode

The tracked artifact `bin/__pycache__/omagen-file-selectcpython-314.pyc`
was not referenced by the installer or runtime. The source
script, [`bin/omagen-file-select`](../../bin/omagen-file-select), is the runtime
input. The artifact was removed in the cleanup change, and `__pycache__/` and
`*.pyc` are now in the repository ignore rules.

### QML test payload in installed packages

[`install.sh`](../../install.sh) recursively copies `qml/`, including the seven
files under `qml/tests/`, into the installed plugin. The manifest exposes the
two production entry points and does not require the test files at runtime.

This is packaging maintenance rather than dead source code: the tests remain in
the source checkout and are now excluded from installation. A future
package-content assertion would make this rule explicit in the validation gate.

## Suspicious, but not proven dead

Do not delete these from a static audit alone.

### GLSL sources beside compiled QSB files

[`qml/components/glitch.frag`](../../qml/components/glitch.frag) and
[`qml/components/glitch.vert`](../../qml/components/glitch.vert) are not loaded
directly; runtime QML loads the paired `.qsb` files. The GLSL files may still be
the intended source of truth. The missing compiler/version/provenance path is
the problem. Keep the sources until the project explicitly chooses a different
authority, and document or automate GLSL-to-QSB generation.

### Test-only packages and bundled binaries

`internal/contract` and `internal/testenv` are test-only support packages. They
remain in the source checkout because they protect service contracts and
isolated filesystem behavior; they are not runtime plugin payload. Empty
command directories and bundled binaries are not evidence of dead production
behavior. Check callers and packaging before removing any of them.

## Architecture opportunities

The architecture skill's vocabulary is intentional here: a module is deep when
its interface provides substantial leverage over a concentrated implementation.
Use the deletion test before extracting anything: if deleting a module causes
the same complexity to reappear across several callers, the seam is earning
its keep.

### Strong: deepen candidate materialization

Generation and Preview each materialize most of the same candidate files:

- [`backend/internal/generation/job.go`](../../backend/internal/generation/job.go)
- [`backend/internal/preview/service.go`](../../backend/internal/preview/service.go)
- [`backend/internal/theme/shell.go`](../../backend/internal/theme/shell.go)
- [`backend/internal/theme/hyprland.go`](../../backend/internal/theme/hyprland.go)

The repeated concern includes colors, shell files, Bar profile/spec, runtime
metadata, Hyprland output, Look & Feel, terminal metadata, and backgrounds.
The behavior-preserving direction is a shared internal candidate-materialization
module with characterization tests for file sets, bytes, ordering, and cleanup.
Individual writers can remain behind their current seams. The goal is locality
and one source of truth, not a new public bounded context.

### Worth exploring: deepen the CLI style grammar

[`generation_cmd.go`](../../backend/internal/cli/generation_cmd.go) and
[`session_cmd.go`](../../backend/internal/cli/session_cmd.go) parse overlapping
Shell, Desktop, Bar, animation, Look & Feel, terminal, profile, spec, override,
and harmony options.

Extract a CLI-local parser module only after capturing exact flag precedence,
aliases, malformed-input behavior, usage text, and exit code `2`. Keep
command-specific validation, usage strings, response formatting, and lifecycle
invocation at the outer CLI seam. Do not move argv grammar into `session` or
`generation`.

### Worth exploring later: separate style policy from durable session state

`session` correctly owns durable identity, baseline, Apply phase, and recovery,
but its model also owns many Shell, Desktop, Animation, Look & Feel, Bar, and
terminal style definitions. This is a coupling leak, not a reason to weaken
ADR-0001. Consider an internal style module only when there is a concrete second
adapter or consumer and characterization tests protect persisted records.

### Worth exploring: QML state ownership and controller tests

`Omagen.qml`, `SessionState.qml`, and feature controllers currently carry
overlapping session, style, busy, Demo, Apply, and route state. The existing
split is documented, but not structurally enforced.

Classify each value as one of:

- durable backend mirror;
- staged style document;
- controller operation state; or
- derived route state.

Then add fake-backend QML tests for Apply, Demo, Cancel, Quit, recovery, and
stale responses. Extract a state model only where it creates a real seam with a
small interface and better tests; do not split files just to lower a line-count
warning.

### Worth exploring: prove the runtime/bar ownership sequence

Unit tests cover pieces of Apply, runtime, and bar-profile restoration, but not
the complete sequence from original `shell.json` through Preview, owned runtime
activation, Apply, and later Cancel/recovery. Add one integration-level test
around that seam before changing lock or snapshot ordering.

### Speculative: private seams inside `omarchy`

`omarchy.Client` is not shallow: deleting it would spread native command,
locking, timeout, logging, rollback, and restoration semantics across several
callers. Do not create a new public bounded context now. If maintenance pressure
grows, private seams for catalog discovery, theme-set transaction execution,
background restoration, and terminal reload synchronization may improve
locality. ADR-0005's parity conditions still apply.

## Safety and lifecycle findings

These are not cleanup suggestions. They are behavior-sensitive risks to address
only in separately scoped changes.

### Preview detached-work timing

An independent audit run observed a timing-sensitive failure in
`internal/omarchy` where the critical Preview path waited about 445 ms against a
400 ms assertion while an optional post-commit adapter left a child process
running. A later cached/full run passed, so treat this as flaky evidence rather
than a deterministic failure.

Before changing implementation, reproduce with a controlled adapter that spawns
grandchildren and inherits stdout/stderr descriptors. Cover Preview and Apply
with `--run`, `--skip`, `--wait critical`, and `--wait full`. The contract is
that optional post-commit work cannot strand the critical transaction.

### Demo cleanup ownership proof

`demo.Service` checks the session identity before cleanup, then removes the
persisted `DemoDir`. The cleanup path should also prove that the directory is
inside the session-owned directory and has the expected Demo shape before any
recursive removal. Add a refusal test for a corrupted or malicious persisted
path before changing the implementation.

### Prepared session without the active marker

Cleanup normally treats all non-active session directories as stale, while the
transaction ordering makes a prepared Apply recoverable through the active
marker. The repository does not currently document or test the case where the
session record survives but the marker is missing or corrupt. Decide whether
that state is intentionally unrecoverable; then encode the decision in a test
and an ADR if it is load-bearing.

## Test and validation baseline

Use the temporary cache in managed or restricted environments:

```sh
cd backend
GOCACHE=/tmp/omagen-gocache go test ./...
GOCACHE=/tmp/omagen-gocache go test -race ./...
GOCACHE=/tmp/omagen-gocache go vet ./...
```

From the repository root, the canonical package gate is:

```sh
GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh
```

The gate covers formatting, architecture/context checks, documentation links,
Go tests, race tests, vet, bundled backend provenance, CLI smoke commands,
manifest/version consistency, required files, Demo assets, symlink rejection,
and QML syntax when `qmllint` is installed.

### Current audit evidence

- `go test ./...` with the temporary cache: pass.
- `go test -race ./...` with the temporary cache: pass.
- `go vet ./...` with the temporary cache: pass.
- `scripts/architecture-check.sh`: pass, with five size warnings.
- Documentation link and context-integrity checks: pass.
- `qmllint`: available and passed over the repository QML during the audit.
- `qml/tests/` contains seven QtTest files, but the full gate does not execute
  them and the repository has no CI job for them.
- `qmltestrunner` was present but could not run in this desktop-restricted
  environment because its GTK/display setup failed. Treat QML behavior tests as
  a separate environment requirement until a supported headless invocation is
  established.

### Coverage signals

Coverage is a prioritization signal, not a quality score. The audit observed:

| Package | Coverage | Follow-up |
| --- | ---: | --- |
| `internal/themeedit` | 29.0% | Add service tests for catalog, merged trees, backgrounds, and recipe export. |
| `internal/cli` | 41.2% | Add adapter tests for Bar, Cleanup, Demo, and shared style grammar. |
| `internal/demo` | 41.4% | Cover native command and cleanup error paths. |
| `internal/preview` | 49.7% | Cover ownership, validation, and failure branches. |
| `internal/fsutil` | 49.1% | Cover filesystem error paths and ownership assumptions. |
| `internal/apply` | 55.3% | Cover recovery and commit edge cases. |
| `internal/settings` | 67.9% | Reasonable baseline; extend only for changed behavior. |
| `internal/studio` | 83.0% | Model coverage is good; command entrypoint remains thin. |

## Size warnings are review prompts

After the cleanup above, the architecture checker currently reports:

- `Omagen.qml` — about 2,000 lines;
- `qml/components/AdvancedStyleEditor.qml` — about 1,094 lines;
- `qml/components/ShellLab.qml` — about 842 lines;

These warnings do not authorize a split. Before extracting a module, record:

1. the caller/callee seam and its interface;
2. state ownership and signal/argv preservation;
3. the contract tests that protect the seam;
4. the manual validation required for UI, lifecycle, or native integration;
5. why the extracted module has more depth and locality than the original.

The relevant check is [`scripts/architecture-check.sh`](../../scripts/architecture-check.sh),
which intentionally reports warnings rather than failing the gate.

## Developer documentation backlog

The following documentation work is worth keeping visible:

- Add `theme-edit` to `docs/agents/context-map.yaml`, add a dedicated recipe,
  and list `ThemeEditController.qml` in the QML controller contract.
- Add a concise CLI reference covering read-only vs mutating commands, active
  session requirements, JSON/stderr behavior, exit codes, and safe inspection.
- Document the QML QtTest suite separately from `qmllint`, including the
  supported runner and headless prerequisites once established.
- Add documentation-only validation to CI, or at least include `README.md`,
  `SUMMARY.md`, `docs/**`, `book.toml`, and `AGENTS.md` in the relevant pull
  request paths.
- Document shader source/compiler provenance and the status of the compiled
  QSB assets.
- Explain the runtime/native transaction lock relationship and which steps are
  critical, post-commit, or independently recoverable.
- Add a release checklist for source changes, deterministic rebuild, both
  bundled executables, manifest/version consistency, package validation, and
  promotion between branches.

## Suggested order of work

1. Make the confirmed cleanup candidates their own small, behavior-neutral
   changes with focused tests and package assertions.
2. Stabilize and characterize the Preview detached-work contract.
3. Add Demo path-ownership tests and decide the prepared-session marker policy.
4. Add missing theme-edit routing and the developer CLI/QML testing guides.
5. Characterize Generation/Preview outputs, then deepen candidate materialization.
6. Extract the CLI-local shared style parser with exact wire and error contract
   tests.
7. Revisit QML state ownership and the `session` style-language split only when
   a concrete seam offers measurable leverage.

This order keeps deletion and documentation work separate from behavior changes,
and makes each future refactor reviewable against a preserved contract.
