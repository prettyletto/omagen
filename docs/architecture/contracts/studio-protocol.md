# Studio live protocol

Status: protocol foundation implemented on 2026-08-22

The Studio protocol is the seam between an operation that wants to change the
desktop and the native adapters that actually change it. It is deliberately
more than a log: it is a durable operation tree, an append-only event journal,
a checkpoint cursor, and a Unix-domain socket stream.

## Ownership

```text
Session engine
    owns baseline, rollback, Apply, Cancel, Quit, and recovery

Studio protocol
    owns operation history, progress events, checkpoints, cursor navigation,
    persistence, and streaming transport

Driver/adapters
    own native theme promotion, shell IPC, Hyprland reloads, and app retint
```

The protocol never clears a session, decides that a rollback is safe, or
pretends that moving a cursor changed the desktop. It records the requested
operation and returns an opaque checkpoint state to the owning executor. This
keeps rollback ownership in the N0 engine contract while giving the UI a live,
observable control surface.

## Durable paths

For an Omagen state root and session ID:

```text
<state-root>/protocol/<session-id>/events.jsonl
<state-root>/protocol/<session-id>/events.jsonl.lock
<state-root>/protocol/<session-id>/events.sock
```

The protocol journal is outside the disposable session directory so an Apply
cleanup does not erase the operation evidence. Each event is one JSON object
terminated by a newline. Every append takes the journal lock, writes the full
event, flushes it, and only then broadcasts it to subscribers.

## Event model

The current event types are:

```text
operation.started
operation.progress
operation.completed
checkpoint.created
cursor.moved
```

Operations form a tree through `parent_operation_id`. A preview or Apply is a
root operation; future driver milestones can become child operations such as:

```text
preview
├── stage candidate
├── promote theme
├── apply shell payload
├── transition background
├── reload Hyprland
└── retint applications
```

Each event carries sequence, timestamp, operation/checkpoint identity, status,
message, evidence, and an optional opaque JSON payload. The payload is where a
future scope-aware executor can carry a candidate, scope, wait policy, or
native adapter request without coupling the protocol package to Omarchy.

## Checkpoints and navigation

A checkpoint records an opaque candidate state and points to its parent. Making
a new checkpoint after moving backward creates a branch:

```text
baseline
   └── candidate-a
         ├── candidate-b
         └── candidate-c
```

The protocol supports:

```text
Back                 move to the parent checkpoint
Forward              move when there is one child
Forward <checkpoint> choose a child when the tree branches
```

Navigation appends a `cursor.moved` event and returns the target checkpoint and
opaque state. It does not itself run a theme driver. The next N2 slice will add
the scope-aware executor that consumes that target and performs a reversible
native change through the session engine.

## Unix socket protocol

`omagen protocol serve <session-id>` serves the journal over the session socket.
Messages are newline-delimited JSON.

Requests:

```json
{"command":"ping"}
{"command":"snapshot"}
{"command":"subscribe","buffer":64}
{"command":"back"}
{"command":"forward","checkpoint_id":"checkpoint-000002"}
```

The subscribe response begins with a complete snapshot, followed by live event
messages. The server polls the durable journal so events appended by a separate
preview or Apply process are streamed to the subscriber. A slow subscriber is
closed with an explicit overflow error; it can reconnect using the last
sequence from its snapshot.

CLI inspection and navigation are also available without opening a socket:

```sh
bin/omagen protocol inspect <session-id>
bin/omagen protocol events <session-id> [after-sequence]
bin/omagen protocol back <session-id>
bin/omagen protocol forward <session-id> [checkpoint-id]
bin/omagen protocol serve <session-id>
```

## Current integration

Preview and Apply now create protocol operations before the native mutation,
record staging and critical-live milestones, create a checkpoint for the
candidate, and return the journal/socket/checkpoint identifiers in their JSON
results. Failed operations are recorded as terminal failed operations while the
existing session recovery path remains authoritative. The current workspace
also has a small reusable `‹ / ›` history control backed by protocol inspect and
navigation commands.

The protocol package has public-interface tests for:

- durable reload and operation-tree reconstruction;
- invalid operation/checkpoint transitions;
- linear back/forward navigation;
- branching and ambiguous forward navigation;
- event replay and live subscriptions;
- refresh from a second writer;
- concurrent writers and monotonic sequences;
- Unix socket snapshots, live events, and navigation commands;
- CLI inspection/navigation;
- preview and Apply protocol integration.

The N2 executor now consumes a cursor target, reapplies the existing preview
candidate before committing cursor movement, records child driver operations,
and leaves the cursor unchanged when native reapply fails. Driver requests also
carry explicit scope, wait, and trusted-hook policy, with bounded persisted
logs and native reader evidence. The workspace control therefore moves through
actual preview checkpoints rather than only changing selection state. The QML
control uses request/response CLI calls for this first slice; the Unix socket
subscription remains available for the later live event consumer.
