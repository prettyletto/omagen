# Agent navigation

This directory is the compact operational index for repository work. Start at
the root `AGENTS.md`, classify the task, then read one recipe and the
canonical architecture document it names.

- `context-map.yaml` maps each bounded context to docs, source, tests,
  dependencies, and default exclusions.
- `invariants.md` collects cross-context safety rules.
- `context-budget.md` describes progressive disclosure defaults.
- `handoff-template.md` keeps a task handoff bounded and reproducible.
- `recipes/` contains task-specific read/test/manual-validation routes.

`docs/architecture/` is current architecture. `docs/plans/` is not
authoritative source context and is read only for planning or historical work.
The GitHub issue tracker and triage vocabulary files are present because the
repository engineering skills use them; edit them directly when conventions
change.
