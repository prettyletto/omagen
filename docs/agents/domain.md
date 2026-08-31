# Domain documentation layout

This is a domain-routed repository rather than a single giant `CONTEXT.md`.
Current architecture is split under `docs/architecture/`; task routing and
consumer rules are under `docs/agents/`; decisions are under `docs/adr/`; and
plans are under `docs/plans/`. `docs/agents/context-map.yaml` is the index for
which documents, source, tests, dependencies, and exclusions belong to each
context.

Choose the smallest context that owns the requested behavior. Use a secondary
context only when a caller, dependency, or contract test crosses the seam.
`docs/architecture/` describes the system; this directory describes how to
enter it safely. `docs/development/cli.md` is the command reference, and
`skills/testing-omagen/SKILL.md` is the only route for live desktop UI testing.
