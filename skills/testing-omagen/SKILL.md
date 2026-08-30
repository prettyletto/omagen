---
name: testing-omagen
description: >-
  Run guarded, real-desktop end-to-end tests of the Omagen plugin in this
  repository on Omarchy/Hyprland, including image selection, live palette and
  Look & Feel application, screenshots, and ownership-safe restoration. Use
  only for live Omagen GUI testing in this repository; do not use for ordinary
  unit tests, static review, or unrelated desktop automation.
---

# Testing Omagen

Use this skill only when the repository root is
`/home/prettyletto/Projects/GO/omarchy-themegen` and the request requires
interacting with the installed Omagen UI on the real desktop. Run commands from
the repository root with zsh, as required by `AGENTS.md`.

The canonical helper is [`scripts/ui-test`](../../scripts/ui-test). Read the
repository's [real desktop UI testing guide](../../docs/development/ui-testing.md)
when the helper or the live environment needs more detail.

## Guardrails

- Announce that the test will affect the live desktop before opening Omagen.
- Start with `scripts/ui-test check` and
  `~/.config/omarchy/plugins/pretty.omagen/bin/omagen session status`.
  Require a reachable Wayland/Hyprland session, working shell IPC, DBus, and
  pointer injection. If an active session or an unexpected Omagen layer already
  exists, stop and report it rather than adopting or deleting it.
- Use the existing helper for keyboard, pointer, focus, workspace, summon,
  layer/client inspection, and screenshots. Do not use broad process killing,
  delete `~/.local/state/omagen`, remove themes, or mutate `/usr/share/omarchy`.
- Use the repository-owned `preview.png` as the default image fixture. Do not
  browse or modify a user's Pictures directory just to obtain test input.
- Do not click **Apply theme** unless the user explicitly asks for a permanent
  theme write. A preview E2E must remain reversible through the UI.
- Use the UI's **Restore & close** or **Cancel** path for cleanup. Backend
  mutation commands are not a substitute for testing the UI lifecycle.
- If a click, layer transition, session status, or ownership boundary is
  ambiguous, stop the flow, capture the current state, and report the blocker.

## Canonical live E2E

Use a unique prefix such as `.tmp/ui-tests/e2e-YYYYMMDD-HHMMSS` for screenshots;
the directory is ignored by git. Inspect each key screenshot visually with
`view_image`, not only by trusting a command exit code.

1. Preflight the desktop and confirm the backend session is inactive and not
   recoverable. Capture the initial desktop with
   `scripts/ui-test screenshot <prefix>-01-initial.png`.
2. Open Omagen through the real shell integration:
   `scripts/ui-test summon`. Wait for `namespace=omagen-setup`, inspect layers,
   and capture the setup surface.
3. Activate **Choose image** in the setup UI. The expected chooser is the real
   `xdg-desktop-portal-gtk` client. Enter and select
   `/home/prettyletto/Projects/GO/omarchy-themegen/preview.png` through the
   chooser, then verify that the setup card visibly shows the selected path.
   Capture both the chooser and selected-image states.
4. Select **In-depth** so the Look & Feel controls are available, then activate
   **Continue**. Wait for `namespace=omagen-live-canvas` and the backend session
   to become active/recoverable. The first canvas state should show the
   generated **SOURCE** palette and the desktop should visibly carry the
   temporary preview styling. Capture this state.
5. Open **Choose a preset**, select a visible Look & Feel recipe (use **Glass
   Blur** when the catalog is available unless the user names another preset),
   and capture the selected-but-not-yet-applied state. Activate **Test Live
   composition**, wait for the busy state to finish, and verify the selected
   recipe remains highlighted. Capture the applied state. A changed temporary
   Omagen bar/layer or other recipe-specific desktop change is useful evidence,
   but layer/session ownership is authoritative.
6. Capture a final pre-cleanup screenshot, then click the actual visible
   **Restore & close** control in the Live Canvas. Wait for the restore operation
   to finish and verify all of the following:

   - the original Omarchy theme/background appearance is back;
   - `omagen-live-canvas`, `omagen-setup`, and temporary Omagen bar layers are
     gone;
   - the session status reports `active:false` and `recoverable:false`;
   - no temporary demo or chooser client remains.

7. Treat any mismatch as a failed E2E even if the original theme was restored.
   In particular, the Live Canvas **Restore & close** button must close the
   Omagen surface, not merely return to the initial setup card. If restoration
   leaves setup visible, capture that failure, report it, and then close the
   leftover setup surface through its own UI so the user's desktop is clean.
   Never hide this failure by calling the test a pass.

## Input and observation patterns

- Prefer `scripts/ui-test key`, `type`, `move`, and `click` for real input. Use
  keyboard navigation where possible, then use pointer coordinates derived from
  the current screenshot for controls that need a mouse click.
- Treat ordinary windows and layer-shell surfaces separately. Use
  `scripts/ui-test clients` for portal/dialog clients and
  `scripts/ui-test layers` for Omagen surfaces; a missing Hyprland client does
  not mean a missing Omagen layer.
- Use bounded waits and re-inspect state after each asynchronous operation.
  Do not use unbounded sleeps or assume a fixed generation duration.
- `ydotool` is an input dependency used by the helper; verify it with
  `scripts/ui-test check` rather than starting a second daemon. Do not disable
  the user's existing `ydotool.service` as part of a test.

## Reporting

Report the exact flow, selected fixture and preset, screenshot paths, session
status, remaining layers/clients, and whether restoration and closing both
passed. Distinguish a restored desktop from a fully passed E2E: both restoration
and close are required. Do not create or update another skill as a side effect
of this skill.
