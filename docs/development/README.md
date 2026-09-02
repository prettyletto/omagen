# Development documentation

Development notes that are not part of the current architecture live here.
The current architecture is canonical under [`docs/architecture/`](../architecture/README.md).

Start with [`docs/development.md`](../development.md) for the existing
contributor and packaging workflow. Use the domain recipe in
[`docs/agents/`](../agents/README.md) to keep a change scoped.

- [`cli.md`](cli.md) — backend command families, lifecycle sequence, and safe
  inspection/mutation guidance.
- [`ui-testing.md`](ui-testing.md) — guarded live Omarchy/Hyprland testing.
- [`release-process.md`](release-process.md) — nightly → dev → main promotion,
  CI gates, marketplace preflight, and release evidence.

For the read-only repository health baseline, confirmed cleanup candidates,
architecture opportunities, lifecycle risks, and coverage priorities, see
[`architecture-health.md`](architecture-health.md).
