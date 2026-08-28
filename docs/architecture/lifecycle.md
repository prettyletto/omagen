# Lifecycle architecture

An active session captures the original theme/background and the configuration
needed to resume. That record survives the QML overlay being hidden or
reloaded. `session.Service` and its stores are the durable lifecycle authority.

Preview is temporary and session-scoped. Apply is a staged transaction with
prepared/committed state and explicit recovery. Cancel, Quit, and recovery
close Omagen-owned Demo state, recover interrupted Apply when present, restore
and verify the recorded baseline, remove preview artifacts, and only then clear
the session.

The frontend may request lifecycle operations and display busy/error states. It
must not keep a second baseline, delete session files, infer ownership from
current UI state, or treat a successful process launch as a completed
transaction.

For detailed invariants, read
[`contracts/engine.md`](contracts/engine.md) and
[`contracts/studio-protocol.md`](contracts/studio-protocol.md).
