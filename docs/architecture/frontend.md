# Frontend architecture

The frontend is a long-lived Quickshell plugin loaded by Omarchy. `Omagen.qml`
is the application composition root: it owns overlay routing, session-facing
coordination, and composition of state, gateways, and views. It is not the
authority for durable session or filesystem state.

The QML tree is organized by role:

- `qml/views/` contains windows and feature surfaces such as Setup, Recovery,
  Live Canvas, Demo, and settings.
- `qml/components/` contains reusable controls and styling editors.
- `qml/gateways/` contains domain-scoped backend commands. `BackendCommand.qml`
  owns bounded process/JSON mechanics; each gateway owns one command family.
- `qml/services/` contains the compatibility façade plus settings/image helpers.
- `qml/state/` contains the small UI-facing state models.
- `qml/app/` contains application-level signal bridges and pure style-document
  helpers extracted from the composition root.
- `qml/features/` contains feature-owned pure state helpers, currently the
  Live Canvas color metadata/copy rules.

Backend calls are asynchronous gateway invocations that exchange the existing
JSON protocol. A gateway may normalize QML naming and parse bounded output,
but it must not implement session rollback, Apply recovery, palette generation,
or native desktop ownership. `BackendService.qml` remains a deliberately thin
compatibility façade for the composition root while callers migrate to the
domain gateways.

The application observes native notifications, background, and Hyprland
events only to drive contained visual signals. Omarchy remains the owner of
the visible notification, background, and compositor surfaces.
