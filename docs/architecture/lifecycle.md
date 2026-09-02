# Lifecycle architecture

An active session captures the original theme/background and the configuration
needed to resume. That record survives the QML overlay being hidden or
reloaded. `session.Service` and its stores are the durable lifecycle authority.

An installed-theme edit enters the same lifecycle after native adoption:

```text
List/resolve native theme -> snapshot merged source -> source-only Preview
  -> clone or same-name Apply -> commit/recover
```

Preview is temporary and session-scoped. Apply is a staged transaction with
prepared/committed state and explicit recovery. Cancel, Quit, and recovery
close Omagen-owned Demo state, recover interrupted Apply when present, restore
and verify the recorded baseline, remove preview artifacts, and only then clear
the session.

Preview and Apply are single-flight desktop intents. While a native operation
is running, the coordinator retains only the newest requested appearance. A
deduplicated request completes through the same signal as a real preview, and a
matching live preview is promoted without another native theme switch.

The visible desktop activation is also epoch-fenced. Theme promotion, shell
updates, bar-profile changes, and optional runtime/retint work must carry the
same activation identity; deferred work from an older identity must not replay
an intermediate appearance after a newer intent is current.

The Studio driver has a dedicated Live Canvas fast path: preview promotes its
wallpaper with an instant Quickshell handoff and sends the new palette/shell
payload directly over IPC; it never waits for a presentation crossfade.
Permanent Apply retains the animated transition. When a permanent operation
does use snapshots, delayed cleanup and post-commit adapters close the critical
lock before they run, so they cannot add transition-animation time to preview.

The frontend may request lifecycle operations and display busy/error states. It
must not keep a second baseline, delete session files, infer ownership from
current UI state, or treat a successful process launch as a completed
transaction.

The QML operation seam is split by ownership: `ApplyController.qml` coordinates
the staged Apply sequence, `DemoController.qml` owns frontend Demo resource
state, `PreviewController.qml` owns preview command state, and
`GenerationController.qml` owns generate/describe/discard sequencing. The
adjacent `RuntimeSetupController.qml` and
`LookFeelController.qml` own their respective request state without moving
cross-domain composition out of the root. The backend session record remains
authoritative for rollback, cleanup, and recovery; controllers only coordinate
requests and high-level outcomes.

Live Canvas intentionally has no preview history, checkpoints, cursor, or
back/forward navigation. Each Test Live request replaces the current temporary
candidate; **Back to configuration** discards the generation, while
**Restore & close** uses the durable session baseline to restore the desktop.

For detailed invariants, read [`contracts/engine.md`](contracts/engine.md).
