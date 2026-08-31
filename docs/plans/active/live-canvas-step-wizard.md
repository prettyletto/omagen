# Live Canvas step-wizard redesign

Status: Proposed for three-agent implementation. This plan replaces the current
multi-editor Live Canvas panel with a modern, paginated wizard while preserving
the existing backend session, preview, Apply, recovery, and Demo contracts.

## Product decision

The current panel mixes palette choice, Look & Feel, advanced editors, Test
Live, Demo modes, permanent Apply, and Restore in one long scroll surface.
It has a stage indicator, but it does not behave like a wizard. The new flow
must have one current page, one clear decision, and explicit **Back** / **Next**
navigation.

~~~text
Choose variant ──Next──> Choose Look & Feel / Skip ──Next──> Advanced / Skip
      │                          │                              │
      └─ preview on click        └─ preview on click              └─ preview on Next
                                                                   │
                                                                   v
                                                    Demo / Skip ──Next──> Save or Restore
~~~

### Required user journey

1. **Palette** — choose one generated color direction. Selecting a card starts
   a reversible live preview immediately; **Next** becomes available after a
   selection exists. It does not need a separate Test Live click.
2. **Look & Feel** — choose a complete recipe or select **Keep native / Skip**.
   Selecting any recipe resolves it and starts the matching reversible live
   preview immediately. Rapid clicks must converge to the latest recipe,
   rather than disabling cards until a previous preview completes.
3. **Advanced** — present an explicit choice: **Keep the selected recipe** or
   **Customize further**. Skip advances directly. Customize reveals Window,
   Shell, Bar, Motion, and supporting terminal controls without mixing them
   into the Palette or Look & Feel page. Advancing from edited controls starts
   one preview of the complete staged composition; there is no standalone
   Test Live control in the wizard.
4. **Demo** — offer one obvious primary demo: the session-owned four-window
   desktop Demo. The user can start it, inspect the real applications, stop it,
   or skip it. Section demonstrations remain optional contextual tools inside
   their advanced section, not competing footer actions.
5. **Finish** — show a compact summary of palette, recipe, customization, and
   Demo status. The only terminal decisions are **Save & Apply** and
   **Restore & close**. Restore must both restore the original desktop and
   close Omagen.

The Back button changes only the wizard page. It must not discard the selected
variant, recipe, advanced values, current preview, or Demo state. It may be
disabled while a backend operation is in progress.

## Visual and interaction direction

- Use a compact numbered progress strip with the current step and completed
  steps; do not expose the current implementation's dense stage narration.
- Render exactly one step body at a time in a scrollable content region. Keep
  a fixed, small navigation bar with Back on the left and the contextual Next
  action on the right.
- Give Palette and Look & Feel cards generous preview space, concise labels,
  and a visible live-preview state. Make **Skip** a first-class card/action,
  not a hidden toggle.
- Make the panel feel like a modern desktop sheet: clear title, generous
  spacing, consistent card selection, brief state feedback, responsive width,
  and no repeated action rows. The live desktop remains the visual proof.
- Keep **Hide** available as a low-emphasis header action. Keep destructive
  restoration out of ordinary navigation and only on the Finish step.
- Do not redesign palette generation, recipe algorithms, the native shell
  layout, or the backend JSON/CLI protocol as part of this work.

## Behavior and architecture

### Wizard state

Create a feature-owned QML controller, tentatively
`qml/controllers/LiveCanvasWizardController.qml`, for ephemeral navigation
only. It owns the ordered step, Back/Next eligibility, the Advanced opt-in
choice, and navigation intents. `Omagen.qml` remains the owner of the durable
session, route, style documents, and composition wiring.

The controller must expose a small view contract:

| View input / event | Meaning |
| --- | --- |
| `step` / `stepCount` | Current wizard page and progress rendering |
| `canGoBack` / `canGoNext` | Navigation availability after busy/session checks |
| `nextLabel` | Contextual label such as `Next: Look & Feel`, `Preview & continue`, or `Review` |
| `advancedChoice` | `undecided`, `skip`, or `customize` |
| `goBackRequested()` / `goNextRequested()` | Pure navigation intent from the view |
| `advancedChoiceRequested(choice)` | Explicit Advanced decision |
| `restoreAndCloseRequested()` | Final-session intent, distinct from returning to setup |

The wizard controller must never become a second session authority or call the
backend directly. Existing controllers retain ownership:

- `PreviewController` owns preview requests, latest-intent queuing, and stale
  response correlation.
- `LookFeelController` owns catalog and recipe resolution.
- `DemoController` owns backend Full/Window Demo resources and the separate
  QML-only Shell/Bar demonstrations.
- `ApplyController` owns final preview, optional Demo capture/close, and the
  permanent transaction.

### Immediate preset preview

Look & Feel selection changes from staged-only to staged-and-previewed:

1. A preset-card click records the latest requested preset.
2. `LookFeelController` resolves the recipe. Cached recipes may resolve
   synchronously; uncached resolution remains single-flight.
3. When the latest requested recipe resolves, `Omagen.qml` applies the recipe
   to the existing style documents and immediately asks `PreviewController` to
   preview the selected variant with the complete resolved style snapshot.
4. While a native preview is running, later recipe clicks are accepted. The
   resolver and preview coordinator retain only the newest complete intent.
5. The page shows `Previewing…` until the current preview completes and marks
   the selected recipe as live. Failures leave the prior live preview intact,
   show the error, and keep the page actionable.

Do not bypass `PreviewController`, synthesize a backend command in a view, or
partially construct style JSON. Preview styles must be complete and equivalent
to the styles passed to generation and Apply.

### Demo behavior

The Demo page uses Full Demo as the primary public action:

- **Start demo** opens the tracked four-slot workspace using the existing
  `DemoController.startDemo()` flow, applies the current preview in the
  established sequence, and reports the selected monitor/workspace and slot
  readiness.
- **Stop demo** closes only the session-owned Demo and returns to the same
  wizard page. It must not end the preview session or reset the wizard.
- The page displays a clear busy/ready/error state and disables page navigation
  during open/close/reflow.
- Window, Shell, and Bar demonstrations remain precisely scoped to the
  Advanced subpage that owns them. Rename ambiguous view-level signals such as
  `closeCanvasRequested` where needed so the code describes Demo stop/reflow,
  not generic canvas closure.
- Apply still follows the existing ordering: final preview, optional Demo
  capture, Demo close, backend Apply. Restore/Cancel still lets the backend
  close owned Demo resources before restoring the baseline.

### Restore-close correction

The live E2E found that the Live Canvas control named **Restore & close**
restored the durable backend session but returned QML to the empty setup screen.
The final wizard action must carry an explicit close intent through cancellation
so a successful restore clears the session *and* sets `opened: false`. Do not
change backend cancellation or delete state directly.

## Three-agent execution plan

The work has a deliberate handoff: Agent 1 establishes the behavior contract;
Agent 2 consumes it to build the visual flow; Agent 3 independently tests and
reviews the integrated flow on the real desktop. This avoids two agents editing
the same large panel and keeps acceptance evidence independent of the
implementation work.

### Agent 1 — wizard orchestration, live preview, and Demo contract

**Owns**: state transitions and asynchronous behavior.

Primary files:

- `qml/controllers/LiveCanvasWizardController.qml` (new)
- `qml/controllers/LookFeelController.qml`
- `qml/controllers/DemoController.qml`
- `Omagen.qml`
- focused controller tests or QML test coverage where the repository has a
  suitable harness

Tasks:

1. Define and implement the wizard controller contract above; document any
   changed signal names at the `Omagen.qml` composition seam.
2. Wire Back/Next and Advanced opt-in intents through `Omagen.qml` without
   moving durable session or transaction logic into the controller.
3. Change Look & Feel resolution to accept a latest preset intent while preview
   is busy. Resolve and preview the latest composition automatically; preserve
   stale-response rejection and complete style documents.
4. Add an explicit `restoreAndClose` cancel intent. Route only the final wizard
   action through it so cancellation finishes with Omagen closed; preserve any
   intentionally non-terminal return-to-setup flow.
5. Simplify/clarify Demo actions at the controller/root seam. Preserve Full,
   Window, Shell, and Bar ownership distinctions and Apply's current ordering.
6. Hand Agent 2 a concise interface note with exact properties, signals,
   availability rules, and busy/error behavior. Keep the old view temporarily
   functional until Agent 2 lands the page rewrite.

Acceptance:

- Clicking a palette or Look & Feel preset immediately starts a reversible
  preview and rapid changes end on the latest click.
- No direct backend process is created from a QML view.
- Start/stop/reflow Demo stays session-owned and all busy states block unsafe
  navigation.
- Final Restore & close removes the overlay after baseline restoration.
- Existing Apply and recovery semantics remain intact.

### Agent 2 — modern paginated wizard UI and Demo page

**Owns**: visual hierarchy, pagination, and the page-level user experience.

Primary files:

- `qml/views/LiveCanvasPanel.qml`
- new focused components under `qml/views/live-canvas/` or
  `qml/components/live-canvas/`, for example `WizardChrome.qml`,
  `PaletteStep.qml`, `LookFeelStep.qml`, `AdvancedStep.qml`, `DemoStep.qml`,
  and `FinishStep.qml`
- `qml/views/live-canvas/LookFeelStep.qml` for the Look & Feel page
- `qml/components/AdvancedStyleEditor.qml` only for focused page embedding;
  do not rewrite its protected engine semantics

Tasks:

1. Replace the all-in-one scrolling editor with the five pages in the required
   user journey. Use Agent 1's wizard API rather than local boolean editor
   flags as page routing state.
2. Build a shared modern wizard chrome: header, compact progress strip,
   bounded scroll content, operation state, and one Back/Next bar. Remove the
   duplicated Test Live, Demo, Apply, and Restore footer rows.
3. Implement Palette and Look & Feel cards with clear selected/live/previewing
   feedback. Expose a visible **Keep native / Skip** path.
4. Implement the Advanced opt-in page and reuse the existing advanced editors
   inside a focused paginated subflow. Preserve staged values when navigating
   Back and do not show advanced controls after Skip.
5. Implement the dedicated Full Demo page with one Start/Stop control, state
   feedback, and a deliberate skip path. Keep section demos contextual to the
   relevant Advanced section.
6. Implement the Finish page with a concise summary, permanent Apply entry,
   and a clearly separated Restore & close action.
7. Maintain keyboard focus order, Esc-to-hide behavior, monitor-bound layer
   behavior, narrow-screen scrolling, and accessibility contrast.

Acceptance:

- One current page is visible at any time and normal progression needs only
  Back/Next plus the decision cards on that page.
- The panel no longer contains the current competing free-form editor toggles
  and permanently repeated action footer.
- Demo's Full workflow is discoverable and its state is understandable without
  reading implementation-specific labels.
- The rendered panel is visually inspected on the live desktop at a normal
  laptop monitor size and after panel scrolling.

### Agent 3 — independent live E2E test and flow review

**Owns**: acceptance evidence and review findings. This agent does not repair
the feature in the same pass; it reports reproducible failures back to Agent 1
or Agent 2 according to ownership.

Primary inputs:

- `skills/testing-omagen/SKILL.md`
- `scripts/ui-test`
- the integrated Agent 1 + Agent 2 branch/install
- `docs/agents/handoff-template.md`

Tasks:

1. Read and follow the repo-local `testing-omagen` skill before touching the
   live desktop. Confirm a clean, inactive backend session and no pre-existing
   Omagen layer; do not adopt an unknown session.
2. Run a real image-to-restore E2E using the repository-owned `preview.png`.
   Capture and visually inspect screenshots for each wizard page and every
   desktop mutation.
3. Verify palette behavior: selecting a variant immediately previews it, the
   page does not require a Test Live action, Back/Next preserve the selection,
   and rapid variant changes finish on the latest intent.
4. Verify Look & Feel behavior: select at least three recipes quickly, confirm
   each click visibly enters previewing state, and confirm the final desktop
   and selected card match the final click. Verify **Keep native / Skip** does
   not add extra shell/bar/animation ownership.
5. Verify the Advanced routes separately: Skip reaches Demo without exposing
   advanced controls; Customize preserves values through Back/Next and previews
   the complete composition when leaving the step.
6. Verify Full Demo: Start opens only the session-owned four-window workspace,
   the page exposes clear busy/ready state, Stop restores the previous
   workspace while keeping the preview session and wizard alive, and section
   demos remain confined to their advanced context.
7. Review the visual flow on the focused laptop monitor: one page at a time,
   readable progress, sensible scroll boundaries, keyboard focus order,
   Esc-to-hide/reopen behavior, no action-footer duplication, and adequate
   contrast at normal desktop scale.
8. Open the permanent Apply dialog only to verify entry and summary; cancel it
   unless the user explicitly authorizes a permanent theme write. Finish by
   clicking the real **Restore & close** control.
9. Assert the final cleanup state: original theme/background and native bar
   restored, no `omagen-*` or temporary Omagen bar layers, no Demo/chooser
   client, and backend session status `active:false`, `recoverable:false`.

Hard failures:

- A palette or Look & Feel selection still needs a separate Test Live click.
- A fast click sequence applies a stale variant or preset rather than the last
  selection.
- Back loses a selected palette, preset, or advanced edits.
- Demo leaves an untracked window/workspace or stops the preview session.
- **Restore & close** restores the theme but leaves Omagen visible; this is a
  close-contract failure even if the backend session becomes inactive.

Deliverable:

- A focused handoff using `docs/agents/handoff-template.md` with the exact
  fixture/preset sequence, screenshot paths, session and layer evidence,
  visual review findings, and a pass/fail result for every step. Route
  behavior/controller failures to Agent 1 and page/layout failures to Agent 2.
- Do not modify production UI code during the review. A failing result opens a
  targeted follow-up for the owning implementation agent, followed by another
  independent Agent 3 run.

## Integration and validation

1. Agent 1 commits or hands off the controller/view contract first. Agent 2
   builds against that exact contract and does not change controller semantics
   without returning the change to Agent 1. Agent 3 runs only after the two
   implementation changes are integrated and installed for live testing.
2. Re-run the focused backend tests for Studio, Preview, and CLI from
   `backend/`:

   ```sh
   go test ./internal/studio ./internal/preview ./internal/cli
   ```

3. Run the packaging/QML gate from the repository root:

   ```sh
   GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh
   ```

4. Use the repo-local `testing-omagen` skill and `scripts/ui-test` for a real
   desktop E2E. Capture: palette click preview, preset click preview, Advanced
   skip and customize routes, Full Demo start/stop, Back preservation, Apply
   dialog entry, and Restore & close. A pass requires no `omagen-*` layer and
   an inactive/unrecoverable backend session after Restore & close.
5. Agent 3 must pass the independent E2E before updating `docs/usage.md` and
   `docs/demo.md` as confirmed user behavior. Update the Look & Feel roadmap's
   staged-only wording because immediate preset preview supersedes it.

## Non-goals

- No palette, colorspace, contrast, or six-variant algorithm rewrite.
- No new permanent-theme behavior or Apply transaction redesign.
- No replacement of native Omarchy shell/widget layout ownership.
- No direct manipulation of user themes, backgrounds, shell JSON, or Hyprland
  state outside the existing owned preview/restore transaction.
