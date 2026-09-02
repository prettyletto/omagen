# Add Bar Preset

Use this recipe when introducing a new built-in full-Bar layout or preset.
The full Bar is the pretty.omagen.bar product; OmagenBarWidget.qml is the
separate overlay launcher/status integration. If the request is instead for a
shared shell material, a Shell Lab control, or a generic host capability,
classify it first and route it through the owning shell, style-editor, or
bar-host context rather than hiding it in a preset.

Run scripts/agent-context bar-preset when starting the task. Keep the
preset's identifier, serialized BarSpec values, profile behavior, and QML
implementation aligned; the router is only one of several registries.

## Read first

Read these before editing:

- docs/architecture/contracts/bar-spec.md
- docs/architecture/product-boundaries.md
- bar/AGENTS.md
- bar/BarPresetRouter.qml
- one existing preset structurally similar to the new design, including its
  wrapper, horizontal composition, and vertical composition
- BarModel.js when the design changes widget ordering, tray handling, or
  workspace entries

For a normal preset, do not begin by reading OmagenBar.qml or
NativeBarClone.qml. Inspect the host only when the design requires behavior
that the existing preset API and shared Bar primitives cannot provide. Read
docs/architecture/contracts/quattro-native-clone.md before touching the
native clone; ordinary preset work should not modify it.

## Define the layout contract

Before writing QML, record the decisions for the new preset <name>:

- the stable kebab-case preset identifier and its user-facing name
- the BarSpec topology, engine, position, surface, geometry, behavior, and
  motion defaults
- the left, center, and right semantic regions
- the workspace presentation and which region renders it
- the tray location, expansion direction, and anchoring strategy
- the behavior when a region or widget grows
- the monitor-edge anchoring for horizontal and vertical placement
- whether the preset uses existing shared primitives or needs a new shared
  primitive

The semantic regions are not interchangeable visual buckets. Preserve the
meaning of left, center, and right from bar.layoutConfig; do not move widgets
between regions merely to make one orientation fit.

## Implement both orientations

Normally create all three files:

~~~text
bar/presets/<Name>BarPreset.qml
bar/presets/<Name>HorizontalBar.qml
bar/presets/<Name>VerticalBar.qml
~~~

The wrapper owns orientation routing and passes the existing bar object to
the selected child. The horizontal file owns horizontal composition. The
vertical file owns vertical composition. Do not implement one orientation by
rotating the other unless the layout is genuinely orientation-independent.

Prefer established primitives from bar/, including:

- WidgetGroup
- VerticalWidgetGroup
- WidgetSlot
- CenterGestureGroup
- IslandSurface

Keep host, runtime, workspace, popup, and input ownership in the existing
shared components. If the design needs a capability those components do not
provide, decide whether it belongs in a reusable Bar primitive or the Bar host
before adding a preset-local workaround.

### Horizontal composition

Explicitly decide and encode:

- left region position
- center region position
- right region position
- tray position
- tray expansion direction
- spacing between regions
- behavior when regions grow
- workspace presentation
- monitor-edge anchoring

#### Frozen compact-float exception

The existing horizontal compact floating bar is frozen. Do not alter its
geometry, tray direction, sizing, or surface ownership while implementing a
different preset or the vertical counterpart. Its protected behavior is:

- the three semantic groups are measured into the centered main pill;
- the tray is excluded from that measurement and rendered as a separate
  bordered surface to the pill's right;
- the collapsed tray always has one icon slot, even when it has no current
  items;
- the chevron is the first tray item, followed by drawer items and then pinned
  items;
- expansion grows rightward from the gap beside the main pill and never
  expands left over the pill, apart from monitor-edge clamping.

Use `bar/CompactTrayWidget.qml` and `BarSurface.qml` as the source of truth
for this frozen path. The vertical compact-float implementation is separate
and must be designed in `bar/presets/FloatingVerticalBar.qml` rather than by
rotating or reusing horizontal positioning assumptions. A horizontal change
requires an explicit user request and renewed manual validation.

When the tray is separate from the right group, use the established
bar.trayEntry(...) and bar.entriesWithoutTray(...) helpers. Pin the region
that must stay at the monitor edge and make tray growth happen into the
available space. A growing tray must not unexpectedly move a region that is
supposed to remain anchored.

### Vertical composition

Design the vertical layout independently. Explicitly decide and encode:

- top region
- center region
- bottom region
- tray location
- tray expansion direction
- flexible spacing
- widget alignment
- interaction direction
- edge anchoring

Do not simply transpose horizontal assumptions. Use VerticalWidgetGroup for
vertical widget stacks, place the tray as its own slot when it has drawer
behavior, and make flexible gaps explicit so a growing tray or center group
does not silently change the intended top/bottom anchors.

## Register every contract owner

After the QML files exist, search for the existing preset identifiers and
update every registry that owns the new value. At minimum inspect:

1. bar/BarPresetRouter.qml — add a case for <name> that resolves to the new
   wrapper:

   ~~~qml
   case "<name>":
       return Qt.resolvedUrl("presets/<Name>BarPreset.qml")
   ~~~

2. backend/internal/bar/model.go — inspect BarSpec.Validate, Presets,
   Preset, topology constants, and the default/normalization behavior. Add
   the identifier and defaults here when the preset is a new built-in. If it
   uses an existing topology, do not invent a new topology solely for the
   visual name.

3. backend/internal/bar/model_test.go — add stable-name, default, and
   compilation assertions for the new preset. Keep the complete preset list
   test in sync.

4. backend/internal/barprofile/model.go and its tests — determine whether
   the persisted Behavior.Form vocabulary needs a new value. A preset ID and
   a profile form/topology are different contracts; update profile validation
   only when the serialized profile actually carries the new value.

5. backend/internal/lookfeel/model.go — inspect Catalog and each relevant
   resolver when the preset is exposed through a built-in Look & Feel
   composition. Update the composition revision and tests when the resolved
   result changes.

6. User-facing QML selectors or catalogs — search qml/, BarModel.js, and
   related style-editor controls for bounded preset lists. Update them only
   when the new preset is intended to be selectable there.

A new visual preset normally does not require a BarSpec schema bump. Consider
one only when adding a serialized field or a genuinely new topology/behavior
that cannot be represented by the existing contract. Do not casually rename
commands, fields, or existing preset identifiers.

## Ownership and boundaries

Preserve these boundaries while implementing the preset:

- shell.json widget placement remains Quattro/user-owned unless an explicit
  session transaction recorded exact ownership.
- The backend session record remains authoritative for Apply, Cancel, Quit,
  recovery, and bar-profile restoration.
- Native Quattro remains the fallback for native or inherit behavior.
- pretty.omagen and pretty.omagen.bar remain separate products and manifests.
- Palette, generation, Live Canvas, Apply/session recovery, and unrelated
  presets are out of scope for a normal new preset.
- Do not duplicate host/runtime logic or change the native clone to compensate
  for a missing preset primitive.

## Validation

Run the focused checks from the repository root and the backend module:

~~~sh
cd backend
go test ./internal/bar ./internal/barprofile
go test -race ./internal/bar ./internal/barprofile
go vet ./internal/bar ./internal/barprofile
cd ..
qmllint bar/BarPresetRouter.qml \
  bar/presets/<Name>BarPreset.qml \
  bar/presets/<Name>HorizontalBar.qml \
  bar/presets/<Name>VerticalBar.qml
GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh
git diff --check
~~~

Run qmllint when available. The full gate also checks backend provenance,
manifests, required package files, and the complete QML tree. If backend
sources changed, preserve the checked-in binary provenance by letting the full
gate run its deterministic verification; rebuild the bundled backend only
through the repository's supported build script.

Manual validation is mandatory on both:

1. a horizontal monitor
2. a vertical monitor

For each orientation, check:

- all three semantic regions
- tray expansion and its growth direction
- workspace interactions and presentation
- click targets
- hover and focus behavior
- drag/reorder behavior when supported
- popup and tooltip anchoring
- compact/expanded behavior where applicable
- monitor-edge alignment

Record any live Omarchy/Hyprland validation that was unavailable. A new
preset is not complete until both orientation forms have been manually
evaluated. If one orientation is intentionally unsupported, document that
architectural decision in the Bar contract before merging; do not omit the
file silently.

## Common traps

- Registering the identifier in bar/BarPresetRouter.qml but not in the Go
  preset/default/validation catalog.
- Treating a topology, profile form, Look & Feel composition, and visual
  preset ID as if they were the same registry.
- Rendering the tray inside a growing right group and shifting an edge-anchored
  region.
- Reusing horizontal geometry by rotating it for vertical monitors.
- Moving workspace ownership or widget placement into the preset.
- Adding host behavior to a preset because a shared primitive was not checked.
- Declaring automated checks green without evaluating both monitor
  orientations.
