# QML UI change

Read:

- `AGENTS.md`
- `docs/architecture/frontend.md`
- `docs/architecture/contracts/qml-backend.md`
- the target view/component and its direct caller

Usually edit `qml/views/`, `qml/components/`, `qml/state/`, or the smallest
composition-root seam in `Omagen.qml`. Use `qml/gateways/` for backend command
access and `qml/services/` for the façade plus settings/image helpers.

Normally do not touch Go domain logic, palette internals, session stores, or
the full `bar/` implementation for a presentation-only change. Preserve
asynchronous signal ordering, busy/error handling, and native ownership.

Run `qmllint` when available and `GOCACHE=/tmp/omagen-gocache
./scripts/v1-check.sh`. Manually exercise the affected route in Quickshell
when possible. Common trap: a visible QML state change is not proof that the
durable backend operation completed.
