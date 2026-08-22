# Omagen engine contract

This document freezes the backend boundary that Studio builds on. The durable
session is the rollback authority; Studio may request operations through the
services below, but it must not implement a second baseline, transaction, or
cleanup system.

## Lifecycle contract

The supported session lifecycle is:

```text
Begin
  -> Generate directions
  -> Test Live / Preview
  -> Back to configuration / Discard generation
  -> Resume or Generate again
  -> Demo open / close
  -> Apply and commit
  -> Cancel, Quit, or Recovery
```

The durable baseline is captured by `session.Service.Begin` and remains in the
session record until a non-committed session is successfully restored. The
record stores the original theme and background, source/configuration state,
current generation, preview direction, and Apply transaction metadata.

The lifecycle invariants are:

- `generation.Service.Discard` clears only `generation_id` and
  `preview_variant`; it preserves the active session, baseline, source image,
  and configuration. This is the backend operation for configuration Back.
- Preview is temporary. `preview.Service.Apply` owns preview aliases and
  records the preview direction in the active session.
- Cancel and bar Quit use the same backend restoration contract: close owned
  Demo state, recover an interrupted Apply if necessary, restore and verify the
  original theme/background, remove preview resources, and clear the session.
- Apply owns the permanent transaction:

  ```text
  PREPARED -> publish owned destination -> apply theme -> COMMITTED
           -> remove ownership marker -> clear active session
  ```

- Recovery never silently discards an active session when ownership or
  restoration cannot be verified.
- Cleanup may remove only provably Omagen-owned resources from inactive
  sessions. Active sessions and ordinary user themes are outside its authority.

## Stable service boundaries

These public service methods and result models are the engine contract for the
first Studio slices:

| Service | Stable responsibility | Studio may request |
| --- | --- | --- |
| `session.Service` | Baseline, active-session state, restore, and recovery | `Begin`, `Status`, `Cancel`, `RecoverActive` |
| `generation.Service` | Generated directions and generation ownership | `Generate`, `Describe`, `Discard` |
| `preview.Service` | Temporary theme aliases and live-preview bookkeeping | `Apply`, `CleanupSession` |
| `demo.Service` | Owned workspace/windows and their cleanup | `Open`, `Close`, `CapturePreview` |
| `apply.Service` | Permanent publish, commit, and pending-Apply recovery | `Apply`, `RecoverPending` |
| `cleanup.Service` | Inactive owned-resource cleanup | `Run` |

The services receive their external boundary through small interfaces. The
Omarchy adapter owns native theme/background operations; service code owns
session safety and never reaches around the adapter to create a second restore
path.

## Studio attachment rules

New Studio capabilities attach to an active session by carrying its
`session_id`, and, where relevant, its `generation_id` and selected variant.
Before mutating state, the capability must use the owning service and respect
the active session's Apply phase.

Studio code must:

- use `session.Service` as the only source of the original baseline;
- use `generation.Service` for staged candidate identity and generation
  discard;
- use `preview.Service` for temporary live candidates;
- use `demo.Service` for owned windows/workspaces;
- use `apply.Service` for permanent commit;
- use `cleanup.Service` only for inactive owned artifacts; and
- preserve the shared mutation lock and recovery behavior of those services.

Studio code must not:

- write or clear `active-session.json` directly;
- restore the original theme/background directly;
- delete preview aliases or Demo state directly;
- mark an in-memory setting as live without calling the owning service; or
- treat hiding/closing a QML surface as cancellation.

The first Studio-specific driver is therefore an adapter behind Preview/Apply;
it is not a replacement for the session, Apply, or recovery services.

## Evidence boundary

The contract tests in `backend/internal/contract` exercise the service APIs
through temporary XDG roots and faked native Omarchy operations. They prove
state ownership, restoration, preview cleanup, permanent commit, pending-Apply
guards, and inactive cleanup. QML routing remains a separate presentation
boundary: `PreviewConfigWindow` routes Back to `quitSession`, while the
generated workspace routes Back to `generation.Service.Discard` through
`returnToConfiguration`.

Focused tests are not live-desktop proof. Live theme readers, shell IPC,
Hyprland behavior, and visual interaction remain explicitly separate evidence
layers for later N1/N3 work.
