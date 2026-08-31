# Backend CLI reference

The bundled `bin/omagen` is the backend used by the installed plugin. QML
gateways consume the same interface, so command names, argument order, JSON
fields, stderr behavior, and exit codes are compatibility surfaces.

Successful responses are JSON on stdout. Exit `1` means an operational
failure; exit `2` means invalid usage, malformed input, or an unsupported
value. Warnings may be written to stderr even when the JSON response succeeds.

## Safe inspection

```zsh
bin/omagen ping
bin/omagen help
bin/omagen session status
bin/omagen session resume
bin/omagen demo capabilities
bin/omagen look-feel list
bin/omagen look-feel resolve <preset>
bin/omagen theme list
bin/omagen theme export-recipe <theme-id>
bin/omagen runtime status
bin/omagen bar inspect
bin/omagen generation describe <session_id> <generation_id>
```

`session resume` can recover a pending Apply as part of normal lifecycle
behavior, and `bar inspect` captures a current snapshot. Treat both as
inspection with possible state work, not as pure text-only queries.

## Session lifecycle

The normal sequence is:

```text
session begin -> generate -> preview apply (optional, repeatable)
           -> demo open/open-window (optional)
           -> apply OR session cancel
```

`session begin` captures baseline state and creates durable session authority.
`generate` creates the six variants. `preview apply` changes only owned
temporary resources. `apply` promotes a selected variant. `session cancel`
restores the session-owned baseline.

```zsh
bin/omagen session begin
bin/omagen generate <session_id> <image-path> [generation options]
bin/omagen generation describe <session_id> <generation_id>
bin/omagen preview apply <session_id> <generation_id> <variant>
bin/omagen preview cleanup <session_id>
bin/omagen apply <session_id> <generation_id> <variant> <theme_name>
bin/omagen session cancel <session_id>
bin/omagen session recover
```

The QML gateways are the best source for constructing verbose generation and
session style arguments. Preview and Apply accept `--run` (alias `--apps`),
`--skip`, `--scope`, `--wait`, and explicit trusted-hook opt-in; hooks are
disabled by default.

## Demo and other command families

```zsh
bin/omagen demo open <session_id>
bin/omagen demo open-window <session_id>
bin/omagen demo reflow <session_id>
bin/omagen demo capture <session_id>
bin/omagen demo close <session_id>

bin/omagen look-feel save <name> '<composition-json>'
bin/omagen look-feel import <manifest.json>
bin/omagen look-feel export <preset>
bin/omagen theme edit <theme-id>
bin/omagen bar apply-profile <profile.json>
bin/omagen bar restore <session_id>
bin/omagen runtime install
bin/omagen runtime dismiss
bin/omagen runtime theme-set <theme>
bin/omagen terminal materialize <staged-theme-directory>
bin/omagen cleanup
```

All commands after help/inspection that write a theme, profile, recipe,
runtime, Demo resource, or cleanup state are mutating. Do not remove Demo
directories, workspaces, previews, themes, or backgrounds with broad shell
commands. Use `demo close`, `preview cleanup`, `session cancel`, or
`session recover` so ownership checks remain in force.

For a failed operation, capture stdout, stderr, exit status, `session status`,
and remaining Omagen layers before attempting recovery. The backend session
record is the authority; QML state is only a view of it.

