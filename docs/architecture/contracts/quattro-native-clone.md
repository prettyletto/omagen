# Native Quattro clone contract

`NativeBarClone.qml` is checked-in vendor compatibility code. It is a
maintained copy/fork of Omarchy Quattro's native Bar implementation used when
the Omagen full-Bar host must reproduce the native workspace presentation.

The file is intentionally kept at the repository root because Quickshell
module loading and the installed Bar preset currently depend on that path.
It is not part of the normal Omagen Bar host refactor surface.

## Maintenance record

- Upstream source: the installed Omarchy Quattro native `Bar.qml` and its
  workspace presentation dependency.
- Upstream commit: not recorded in the current dev checkout; record the
  exact Omarchy/Quattro revision before the next synchronization.
- Import date: legacy code retained for current full-Bar compatibility.
- Local modifications: URL-loaded workspace presentation and the minimum
  compatibility adjustments required by Omagen's full-Bar entry point.

## Update procedure

1. Compare the installed Quattro source with `NativeBarClone.qml` and
   `WorkspacePresentation.qml`.
2. Record the upstream revision and every local modification in this document.
3. Validate the `native` Bar preset on horizontal and vertical monitors.
4. Run the Bar-focused tests and the full QML/package gate.

Agents should not edit or decompose the clone unless the task explicitly
concerns upstream Quattro compatibility. Normal Bar preset and host work
belongs in `bar/` and `OmagenBar.qml`.
