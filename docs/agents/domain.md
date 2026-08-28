# Domain documentation layout

This is a domain-routed repository rather than a single giant `CONTEXT.md`.
Current architecture is split under `docs/architecture/`; task routing and
consumer rules are under `docs/agents/`; decisions are under `docs/adr/`; and
plans are under `docs/plans/`. `docs/agents/context-map.yaml` is the index for
which documents, source, tests, dependencies, and exclusions belong to each
context.
