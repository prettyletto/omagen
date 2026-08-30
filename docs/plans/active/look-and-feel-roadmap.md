# Look & Feel presets implementation roadmap

Status: Slice 5 complete for the Ghostty tracer and four-terminal reader pass;
Slice 6 is next. This document is the implementation source of truth for the
Look & Feel preset layer and terminal translucency support. It replaces the
earlier idea of treating overlapping Window, Shell, Bar, and Animations rules
as independent user-facing preset systems.

## Delivery slices

The implementation is deliberately staged so each slice can be tested before
the next one changes runtime behavior.

| Slice | Status | What is live | What is intentionally deferred |
| --- | --- | --- | --- |
| 1. Resolver contract | Complete | Native and Glass Blur catalog entries, deterministic resolution, bounded terminal intent, and CLI inspection (`look-feel list/resolve`) | UI selection, terminal file writes |
| 2. Composition persistence | Complete | Look & Feel and terminal metadata travel through begin/resume, regeneration, generation candidates, replaceable Live Canvas preview state, and installed QML/backend transport; candidates carry `omagen.look-feel.json` and `omagen.terminal.json` | Terminal materialization, preset cards, terminal controls, live Glass proof |
| 3. Terminal materializer | Complete | Staged, atomic, idempotent opacity writers for Ghostty, Alacritty, Kitty, and Foot; capability/version and read-only user-override reporting; Studio transaction hook before promotion | Preset cards, terminal controls, live Glass proof and reload/effective-state matrix |
| 4. Look & Feel UI | Complete | Backend-backed preset cards, section customization markers/resets, terminal Preserve/Preset/Custom opacity controls, and staged cell-mode controls | Live effective-state/reload matrix and visual Glass proof |
| 5. Runtime validation | Complete (Ghostty tracer + four-terminal reader pass) | Installed plugin and validated reversible Glass Blur preview; current desktop restored to native after rollback; terminal reader checks and user-opacity precedence are proven | Full per-terminal visual/reload matrix remains an explicit follow-up before release |
| 6. Docs/release/expansion | Pending | — | User troubleshooting, release gate, future preset catalog |

Slices 1 and 2 were backend/transport work only. Slices 3 and 4 now materialize
terminal opacity into staged theme artifacts during the existing Studio theme
transaction and expose the controls that edit the same staged composition.
Slice 5 has now exercised that path through a reversible live preview and real
terminal readers; a textured-backdrop blur capture and existing-window reload
matrix remain release-gate evidence rather than inferred success.

## Outcome

Omagen will offer complete **Look & Feel presets** that compose the four
existing styling engines:

1. Window
2. Shell
3. Bar
4. Animations

The user can start with a complete preset and then customize any engine without
losing the rest of the recipe. Look & Feel is an orchestration and provenance
layer; it is not a fifth runtime engine.

Terminal translucency is a supporting adapter attached to the recipe. Glass
Blur uses the adapter at a bounded opacity while keeping the terminal main
configuration outside theme ownership.

~~~text
Look & Feel preset
├── Window engine
├── Shell engine
├── Bar engine
├── Animations engine
└── Supporting adapters
    └── Terminal translucency
        ├── Ghostty
        ├── Alacritty
        ├── Kitty
        └── Foot
~~~

## Product rules

- A Look & Feel preset resolves to a versioned combination of the four engine
  documents plus any supporting adapters.
- Each engine remains independently editable after a preset is selected.
- Editing one engine changes only that engine and marks the complete preset as
  **Customized**. It does not flatten or discard the preset identity.
- Users can reset one field, one engine, one adapter, or the entire composition
  to the selected preset.
- The backend owns preset recipes and resolution. QML presents recipes and
  edits but does not duplicate their values.
- Existing Test Live, Apply, Cancel, Restore, history, crash recovery, and Demo
  behavior remain the only mutation paths.
- Native Omarchy and user-owned configuration retain precedence. Omagen must
  never rewrite a terminal's main user configuration to force opacity.
- Unsupported or overridden effects are reported honestly. A generated file is
  not the same as an effective live result.

## Terminology

**Palette preset**
: A color direction generated from the source image. It owns semantic colors,
  not desktop behavior.

**Look & Feel preset**
: A versioned recipe that combines Window, Shell, Bar, Animations, and optional
  adapters.

**Engine preset**
: A recipe local to one engine, such as Shell Glass or Bar Float Compact.

**Supporting adapter**
: A bounded compiler for a runtime that participates in the visual result but
  is not one of the four core engines. Terminal translucency is the first
  adapter.

**Customized preset**
: A selected Look & Feel preset with one or more explicit engine or adapter
  overrides.

**Effective value**
: The value the real runtime will use after theme output, native defaults, user
  overrides, capability limits, and reload behavior are considered.

## Current preset catalog

The catalog now contains four complete presets. Each one resolves all four
engines plus the terminal adapter before any advanced control is edited.

### Omarchy Native

- Window: inherit current Omarchy/Hyprland behavior.
- Shell: native surfaces and detail language.
- Bar: native layout, material, visibility, and behavior.
- Animations: native compositor animation policy.
- Terminal translucency: Preserve.

This is the safe reset and compatibility path. It must not introduce behavior
files that the active theme did not already own.

### Glass Blur

Revision 6 recipe:

| Area | Recipe intent |
| --- | --- |
| Window | Rounded, 0.72-opacity active/inactive surfaces with Light Hyprland backdrop blur and restrained depth |
| Shell | Glass surface preset with 0.72-alpha core surfaces, Edge detail, and scoped layer blur |
| Bar | Floating compact composition with Glass material; native widget order and input remain intact |
| Animations | Smooth balanced motion with reduced-motion compatibility |
| Terminal adapter | Preset opacity `0.82`, painted-cell mode, all four Omarchy-supported terminal theme outputs |

The exact visual constants must be calibrated once in the preset catalog and
then locked behind `preset_revision: 6`. Later visual tuning becomes a new
revision or migration, not an untracked change to old sessions.

### Focused

Revision 4 recipe:

| Area | Recipe intent |
| --- | --- |
| Window | Fixed 2 px rounded border, shadow depth, native focused surface, and shadow-only inactive treatment |
| Shell | Contrast surfaces with Focus detail; native alpha and no compositor shell blur ownership |
| Bar | Dock topology with a theme-bounded Omagen profile, edge reveal, auto-hide, and hover expansion |
| Animations | Snappy window/workspace motion with quick focus and faded layers |
| Terminal adapter | Preserve the user's existing terminal opacity and cell behavior |

Focused is deliberately grounded: it increases hierarchy and active-state
clarity without forcing terminal translucency or shell opacity values.

### Cyberpunk Glitch

Revision 5 recipe:

| Area | Recipe intent |
| --- | --- |
| Window | Neon 4 px rounded border, shadow depth, and shadow-only inactive treatment |
| Shell | Readable layered dark surfaces with Edge detail, accent tooltip and notification feedback |
| Bar | Readable dark-glass islands with an accent border, segmented workspace presentation, and event-bound signal strips |
| Animations | Digital `gnomed` window entrance with an 82% to normal per-window opacity handshake, sharp slide exit, mechanical focus, spatial workspace/layer motion, plus a selectable Low/Medium/Strong 1250 ms event-triggered Hyprland RGB/tear burst on window open/close, workspace, panel-open, notification, and urgent signals |
| Terminal adapter | Preserve the user's existing terminal opacity and cell behavior |

The glitch treatment is signal-bound rather than continuously animated.
Generated Hyprland Lua listens for window open/close/urgent, workspace, and
native shell `layer.opened` events; the native Wi-Fi, Agents/AI, audio,
Bluetooth, power, and related panels share the `omarchy-keyboard-panel`
namespace, so they all reach the same signal path. For 1250 ms, Hyprland loads
the selected Low, Medium, or Strong `omagen-cyberpunk-glitch.frag` profile as
the whole-desktop screen shader and temporarily
uses full damage tracking so its `time` uniform advances. The timer then clears
the shader and restores the prior compositor settings. Native shell layers use
Hyprland's valid `slide` animation, while Omagen-owned panels and the
replacement bar retain their small local Qt ShaderEffect signal. There is no
always-on desktop shader or continuous border spinner. Related signals coalesce
while a burst is active rather than restarting the strongest attack. Omagen also observes
the native notification service's popup model and maps an empty-input bridge
layer for each newly inserted toast, so repeated notifications retrigger the
same Hyprland-owned pulse even while the notification surface remains mapped.
The compiled
`glitch.vert.qsb` and `glitch.frag.qsb` assets remain installed with both plugin
kinds for the contained Omagen-owned surfaces.

Medium preserves the original curated RGB tear exactly. Low narrows the tear
distance, lowers its frequency, and reduces chromatic mixing. Strong widens and
increases the tear frequency and RGB separation without extending the finite
1250 ms envelope. The entrance opacity is a temporary dynamic-tag rule scoped
to the opening window's address; removing the tag after the opening beat lets
existing active/inactive/fullscreen opacity rules become authoritative again.

Future candidates such as Minimal, High Contrast, Neon, Cinematic, and Low
Power should reuse the same resolver and complete-recipe contract.

### Oriental

Revision 1 recipe:

| Area | Recipe intent |
| --- | --- |
| Window | Restrained 2 px top-split border, soft airy spacing, shadow depth, warm balanced frosted focus, and shadow-only inactive treatment |
| Shell | Glass preset with layered framed surfaces and accent feedback for tooltips and notifications |
| Bar | Split glass sections with comfortable spacing, raised edge, and Japanese Kanji workspace labels (一 through 五) |
| Animations | Custom cinematic window motion: directional slide entrance, fade exit, smooth movement/focus, horizontal slide-fade workspaces, and a soft glass curve |
| Terminal adapter | Preserve the user's existing terminal opacity and cell behavior |

Oriental keeps the signal restrained: there is no always-on shader or RGB tear.
Its identity comes from the Kanagawa-like surface hierarchy, Japanese workspace
labels, and a slow directional settle that remains legible during rapid changes.

## User experience

### Entry point

The In-depth styling surface begins with a Look & Feel section above the four
engine labs. It shows complete preset cards, initially **Omarchy Native** and
**Glass Blur**.

Selecting a card updates all four engine documents and the terminal adapter in
one staged operation. Nothing is applied to the desktop until the existing Test
Live or Apply action is used.

### Customization model

After selecting a preset, the user can open Window, Shell, Bar, or Animations
and change only that section. The header then displays:

~~~text
Glass Blur · Customized
Window: 2 overrides
Shell: preset
Bar: 1 override
Animations: preset
Terminal translucency: preset
~~~

Every section provides **Reset section to Glass Blur**. The Look & Feel header
provides **Reset all to Glass Blur** and **Return to Omarchy Native**.

### Terminal controls

Terminal translucency belongs in the Window/Glass experience because it
completes the client side of compositor blur. It should appear as a clearly
labeled supporting control, not as an Applications lab or fifth main tab.

Modes:

- **Preserve:** emit no Omagen opacity override.
- **Look & Feel preset:** use the selected recipe's opacity; Glass Blur uses
  `0.82` in revision 6.
- **Custom:** allow `0.50`–`1.00`; warn below `0.75` about readability and
  contrast.
- **Cell mode:** Glass Blur uses Painted cells so terminal applications that
  repaint their background still expose the configured opacity. Background
  remains the portable default for Preserve/custom flows where selected.

The UI must explain both incomplete combinations:

- translucency without compositor blur produces a transparent but unblurred
  terminal;
- compositor blur with an opaque terminal exposes no backdrop to blur.

The effective-state panel lists every supported terminal independently, since
reload and override behavior differs between them.

## Data contract

The durable Studio/session document should carry selection, materialized engine
documents, adapter intent, and provenance separately:

~~~json
{
  "look_feel": {
    "schema_version": 1,
    "preset": "glass-blur",
    "preset_revision": 6,
    "customized": {
      "window": false,
      "shell": false,
      "bar": true,
      "animations": false,
      "terminal": false
    }
  },
  "styles": {
    "window": {},
    "shell": {},
    "bar": {},
    "animations": {}
  },
  "adapters": {
    "terminal": {
      "schema_version": 1,
      "mode": "preset",
      "opacity": 0.82,
      "cell_mode": "painted"
    }
  }
}
~~~

The existing engine documents remain the materialized inputs to their current
compilers. `look_feel` records how those documents were composed and how to
reset them. The engine writers must not gain preset-selection logic.

### Resolution rules

Resolution occurs in the backend:

1. Load the preset and exact revision.
2. Materialize its Window, Shell, Bar, Animations, and adapter defaults.
3. Apply explicit per-engine and per-adapter overrides.
4. Normalize every engine with its existing normalizer.
5. Record provenance for each effective field.
6. Validate cross-engine requirements and capability limits.
7. Return a complete resolved composition to QML and generation.

Changing the selected preset replaces preset-derived values but preserves
explicit overrides when they are valid for the new recipe. The UI must offer a
separate “switch and discard overrides” action when the user wants a clean
recipe.

### Compatibility and migration

- A legacy session with no Look & Feel field and no advanced styles migrates to
  Omarchy Native.
- A legacy session with one or more style documents migrates to Custom while
  preserving those documents byte-for-byte through their existing decoders.
- A session with no terminal adapter migrates to Preserve.
- Unknown future preset IDs or revisions load their already-materialized engine
  documents, display an unavailable-preset warning, and remain recoverable.
- Unknown adapter fields are ignored on read and preserved when the existing
  serialization contract supports round-tripping.

## Ownership and generated artifacts

| Area | Source of intent | Generated artifacts | Runtime owner |
| --- | --- | --- | --- |
| Look & Feel | Preset selection and provenance | `omagen.look-feel.json` | Omagen only; no direct runtime reader |
| Window | Existing Window style document | `hyprland.lua`/supported Hyprland theme output | Hyprland |
| Shell | Existing Shell style document | `shell.toml`, `shell.*.toml`, scoped layer rules | Omarchy Quickshell and Hyprland |
| Bar | Existing BarSpec/profile documents | `omagen.bar.spec.json`, `omagen.bar.json`, compatible shell tokens | Native Quattro plus bounded Omagen adapter |
| Animations | Existing Animations style document | Hyprland animation output | Hyprland |
| Terminal translucency | `TerminalTranslucencySpec` | `omagen.terminal.json` plus four terminal theme files | Each terminal and Omarchy retint commands |

`omagen.look-feel.json` and `omagen.terminal.json` are inspectable intent and
provenance sidecars. The native runtimes consume only their materialized files.

## Terminal translucency adapter

The adapter generates theme-bounded values for every terminal supported by
Omarchy, regardless of which terminal is currently selected. This keeps themes
portable when the user changes their default terminal later.

| Terminal | Theme output | Materialized setting | Reload/effective behavior |
| --- | --- | --- | --- |
| Ghostty | `ghostty.conf` | `background-opacity = 0.82`; `background-opacity-cells = true` | Omarchy's terminal restart/reload path uses Ghostty reload support; Ghostty loads this imported theme file after the main config |
| Alacritty | `alacritty.toml` | `[window] opacity = 0.82`; optional `[colors] transparent_background_colors = true` | The generated theme is imported by the main config; file refresh reaches Alacritty's live reload path |
| Kitty | `kitty.conf` | `background_opacity 0.82` | New windows are reliable; changing existing windows is capability-dependent and must not silently enable persistent dynamic opacity |
| Foot | `foot.ini` | `[colors-dark] alpha=0.82`; `alpha-mode=default` or `all` for the background/painted cell contract | The existing Foot retint path is color-oriented, so new windows are the reliable opacity boundary; never kill user Foot sessions to force the result |

### Precedence

Omagen writes only the generated theme files. A terminal's main user config is
outside theme ownership and may be loaded after the generated theme. If it
declares opacity later, it wins.

The adapter should report one of these states per terminal:

- generated and effective;
- generated, live reload pending;
- generated, new windows only;
- generated but overridden by user config;
- unsupported by the installed terminal version;
- Preserve, no override emitted.

Detection must be read-only. Omagen may point to the overriding file and key,
but must not edit, reorder, or remove it.

### Materialization contract

The candidate theme carries `omagen.terminal.json`. During the existing staged
theme-set transaction:

1. Native Omarchy template generation creates the standard terminal files.
2. Omagen's terminal materializer reads `omagen.terminal.json` from the staged
   candidate.
3. It updates only the owned opacity keys in the four staged terminal files.
4. It validates syntax, value bounds, and expected file ownership.
5. The existing transaction promotes the complete candidate.
6. Existing post-theme terminal/Foot retint commands run with their current
   asynchronous behavior.

This ordering preserves native color generation and gives Omagen the narrowest
possible ownership: opacity keys in staged theme artifacts. It does not patch
Omarchy's installed templates or terminal main configs.

Preserve mode removes no arbitrary lines. It simply skips emitting
Omagen-owned opacity keys into newly generated candidates. Cleanup of a
previous Omagen candidate occurs through candidate replacement and the existing
theme transaction, not by editing the active terminal config in place.

## End-to-end transaction

~~~text
Select Look & Feel preset
→ backend resolves four engines + adapters
→ session persists selection, materialized styles, and provenance
→ generation writes the normal candidate and adapter sidecars
→ native Omarchy templates generate application theme files
→ terminal materializer injects bounded opacity into staged terminal files
→ candidate validation
→ Test Live or Apply through the existing Studio transaction
→ native shell/Hyprland/terminal readers reload
→ effective-state and evidence reporting
→ Cancel/Restore uses the existing original-theme checkpoint
~~~

No direct “apply opacity now” command is added. Demo remains explicit and does
not auto-launch when a preset is selected.

## Implementation roadmap

Each phase is a vertical slice with its own tests and evidence. Do not begin a
later engine rewrite to make an earlier phase pass.

### Phase 0 — Freeze the contract and baseline

- [ ] Record the current four engine schemas, normalizers, generated artifacts,
      readers, and rollback ownership.
- [ ] Add fixtures for a Native candidate and a current customized candidate.
- [ ] Capture terminal template/import/reload behavior for the supported
      Ghostty, Alacritty, Kitty, and Foot versions.
- [ ] Define the exact Glass Blur revision 6 values and performance label.
- [ ] Define effective-state vocabulary and unsupported capability reporting.

Exit: the preset recipe and every output field have an owner, reader,
precedence rule, impact level, and rollback path.

### Phase 1 — Look & Feel domain and resolver

Suggested backend package: `backend/internal/lookfeel/`.

- [ ] Add versioned preset catalog, selection, provenance, and override models.
- [ ] Implement Native and Glass Blur revision 6 recipes.
- [ ] Resolve recipes into the existing four style documents without moving
      compiler logic out of the existing engine packages.
- [ ] Add per-engine reset and full-preset reset operations.
- [ ] Add migrations for legacy sessions and unavailable preset revisions.
- [ ] Persist selection and provenance through begin, resume, regeneration,
      preview, Apply, and recovery records.
- [ ] Hash the resolved composition so identical requests stay idempotent.

Tests: recipe snapshots, override preservation, per-engine reset, migration,
unknown revision recovery, deterministic hashing, and JSON round trips.

Exit: a backend test can select Glass Blur, customize Bar only, reset Bar, and
reproduce the exact original recipe without QML involvement.

### Phase 2 — Terminal adapter compiler (implemented in Slice 3)

Suggested backend package: `backend/internal/terminaltheme/`.

- [x] Add `TerminalTranslucencySpec` normalization and validation.
- [x] Add bounded writers for Ghostty, Alacritty, Kitty, and Foot.
- [x] Make writers update only their owned opacity/cell-mode keys and remain
      idempotent when run twice.
- [x] Preserve comments, color values, and unrelated terminal settings.
- [x] Produce `omagen.terminal.json` with intent and provenance.
- [x] Add capability reporting for unsupported cell modes and installed
      versions.
- [x] Add read-only user-override detection for effective-state reporting.
- [x] Enforce user opacity precedence: when a main terminal config declares
      opacity, the generated opacity key is omitted and the report explains
      which user value remains authoritative.

Tests currently cover all four writers, Preserve/preset behavior, bounds via the
shared validator, missing sections, comments, idempotence, and failure-safe
preflight. Expanded golden, malformed-input, duplicate-key, and override-fixture
coverage remains part of the runtime validation hardening slice.

Exit: one normalized spec safely produces all four portable theme artifacts,
and running the compiler twice produces byte-identical output.

### Phase 3 — Staged transaction integration (core hook implemented in Slice 3)

Primary integration points: generation/session/preview/apply services, backend
CLI, and `bin/studio-theme-set`.

- [x] Write Look & Feel and terminal sidecars into the candidate.
- [x] Invoke the terminal materializer after native template generation and
      before candidate promotion.
- [x] Fail before promotion if materialization or validation fails.
- [x] Keep native post-retint commands asynchronous and keep Demo waiting on
      the existing terminal-reload boundary.
- [ ] Ensure preview aliases, committed themes, exported themes, and recovered
      transactions contain the same materialized terminal files.
- [ ] Verify Apply checkpoints restore the original theme and terminal outputs
      without a second opacity-specific rollback mechanism.
- [x] Ensure candidates without adapter metadata retain today's behavior.

Tests: preview, Apply, Cancel, Restore, interrupted Apply, recovery, old
candidate compatibility, materializer failure before promotion, and exact
artifact comparison between preview and committed candidates.

Exit: Glass Blur can traverse the existing Test Live and Apply pipelines with
no direct writes to user terminal configs and with the original theme fully
restorable.

### Phase 4 — Look & Feel and terminal UI

Primary integration points: `Omagen.qml`, session/backend transport,
`AdvancedStyleEditor.qml`, and focused reusable QML components.

- [x] Add the complete preset cards above the four engine sections.
- [x] Display preset identity, revision, Customized state, and per-section
      override counts.
- [x] Apply a resolved preset response from the backend instead of encoding
      recipe constants in QML.
- [x] Add reset-section and reset-all actions.
- [x] Add terminal Preserve/Preset/Custom controls under the composition
      surface.
- [x] Add advanced cell-mode controls with the portable Kitty capability
      limitation called out.
- [ ] Show the two-part real-glass status: client translucency and compositor
      blur.
- [ ] Show per-terminal effective/reload/override state after Test Live.
- [x] Keep existing engine tabs, focused Demos, fixed footer actions, keyboard
      navigation, and overlay lifecycle unchanged.

Tests: QML lint and installed-shell loading are covered in this slice. Full
card interaction, narrow-layout, and effective-state/reload coverage remains in
the runtime validation slice.

Exit: a user can select Glass Blur, customize any one of the four engines or
terminal opacity, understand what is overridden, and reset at any scope.

### Phase 5 — Runtime validation

Validate one tracer first—Glass Blur through Ghostty—then run the same evidence
matrix for Alacritty, Kitty, and Foot. Completing Ghostty does not count as
supporting the other terminals.

- [x] Rebuild the backend and run all Go/unit/golden tests.
- [x] Run the repository's full validation gate with isolated writable caches.
- [x] Reinstall the development plugin with `./dev-install.sh`.
- [x] Compare installed and workspace payload hashes.
- [x] Inspect the Quickshell log for load, binding, and runtime errors.
- [x] Test Live Glass Blur and verify Hyprland accepts the generated config.
- [x] Prove live terminal translucency plus the compositor blur option on a real
      Ghostty window; the captured frame is visual evidence for translucency,
      while backdrop blur remains compositor/config evidence when the backdrop
      is visually flat.
- [x] Verify new-window consumption for Ghostty, Alacritty, Kitty, and Foot;
      existing-window reload differences remain documented below.
- [x] Verify a later user opacity setting wins and is reported, not overwritten.
- [x] Exercise Cancel/restore of the preview session and confirm the original
      theme returns without leaving a terminal window behind.
- [x] Confirm Native/Preserve returns to native behavior without killing user
      terminal sessions; this run had no pre-existing terminal sessions, and
      only the four temporary validation windows were closed.

Evidence must be labeled separately:

1. source and unit-test evidence;
2. generated-artifact evidence;
3. installed-plugin equality;
4. native reader/reload evidence;
5. live visual desktop proof.

Exit: all four terminals have documented reader/application behavior, Native
and Glass Blur are reversible, and no validation relies solely on a QML preview.
The remaining release gate is a user-observed per-terminal existing-window
reload matrix (especially Foot and Kitty) plus a visually unambiguous blur frame
over a textured backdrop. The runtime contract now registers native Hyprland
Window and Animations adapters; they validate and report the generated
`hyprland.lua` artifact without taking ownership away from the native
theme-set/reload path.

### Phase 6 — Documentation, release, and expansion gate

- [x] Register native Hyprland Window and Animations runtime adapters so the
      complete generated contract reports ready after theme-set.
- [ ] Update architecture, styling, usage, recovery, and theme-pipeline docs.
- [ ] Document terminal precedence and terminal-specific reload limitations.
- [ ] Add user-facing troubleshooting for opaque terminals, unblurred
      translucency, user overrides, and unsupported versions.
- [ ] Add schema/revision compatibility notes and export/import guarantees.
- [ ] Record performance cost and reduced-motion behavior for Glass Blur.
- [ ] Promote only after nightly validation, install verification, and the full
      four-terminal live matrix.

Exit: the feature can be understood and recovered without reading the source,
and adding another Look & Feel preset requires a catalog recipe plus tests—not
new orchestration code.

## Required test matrix

| Scenario | Native | Glass Blur | Customized Glass |
| --- | --- | --- | --- |
| Generate candidate | No new behavior overrides | Four engines plus terminal intent | Only explicit deltas differ from preset |
| Test Live | Native behavior preserved | Blur and supported opacity staged | Customized section only changes its owner |
| Apply | Existing native transaction | Same artifacts as preview | Same resolved artifacts as preview |
| Cancel/Restore | No-op or original checkpoint | Original theme restored | Original theme restored |
| User terminal opacity override | Unchanged | User value wins and is reported | User value wins and is reported |
| Old session/candidate | Loads unchanged | Not applicable | Migrates without data loss |

Terminal-specific cases must run for Ghostty, Alacritty, Kitty, and Foot:

- existing window;
- newly opened window;
- no explicit user opacity;
- later user opacity override;
- installed terminal absent;
- unsupported cell mode;
- rapid consecutive Test Live requests;
- Cancel during pending reload.

## Risks and safeguards

**Preset drift**
: Version every recipe and materialize its engine documents in the session.

**Conflicting Hyprland rules**
: Keep the four engine compilers authoritative and compose their output through
  the existing single Hyprland writer.

**User configuration damage**
: Modify staged theme artifacts only. User main configs are read-only inputs for
  precedence reporting.

**False glass claims**
: Report client opacity and compositor blur independently and require live proof
  for the combined result.

**Reload inconsistency**
: Report existing-window/new-window boundaries per terminal. Do not kill user
  sessions or enable persistent dynamic settings to make a demo appear correct.

**Parallel preview races**
: Reuse the session mutation lock, pending terminal-reload marker, and current
  preview serialization. Do not add an adapter-specific preview path.

**Native ownership regression**
: Preserve Quattro widget placement/input, Omarchy template generation, user
  shell and terminal overrides, and the existing recovery checkpoint.

## Definition of done

Look & Feel V1 is complete only when:

- Native and Glass Blur are backend-owned, versioned, deterministic recipes;
- each recipe composes Window, Shell, Bar, Animations, and adapters without
  coupling their compilers;
- the user can customize and reset each section independently;
- Ghostty, Alacritty, Kitty, and Foot receive safe, portable, theme-bounded
  opacity outputs;
- user config keeps precedence and overrides are visible;
- Test Live, Apply, Cancel, Restore, history, and recovery use the existing
  transaction paths;
- generated output, installed payload, native reload, and live visual evidence
  are reported separately;
- real glass is proven as the combination of translucent client pixels and
  accepted Hyprland blur; and
- adding a future complete preset does not require another runtime engine or a
  parallel apply mechanism.
