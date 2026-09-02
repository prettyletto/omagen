# Omagen documentation

Omagen is the complete renewed Omarchy Quattro product: image-derived palette
directions, reversible Live Canvas Preview and Test Live flows, Demo, Apply,
recovery, and optional Window, Shell, Bar, and Animation composition. The
overlay/widget package and the full-bar package remain separate. Start with
the user workflow, then use the focused guides for styling, Demo, recovery, or
development. Contributors should start with [the root agent guide](../AGENTS.md)
and the bounded-context routes in [docs/agents](agents/README.md).

Product-facing README, screenshots, demos, examples, and release material are
authored in the [canonical product documentation source](product/README.md).
Use the [product README authoring guide](product/README.authoring.md) while
writing it.
The root README remains developer-facing on `nightly` and `dev`; the controlled
release workflow projects the product README to the root of `main`.

- [Examples](examples.md) — wallpaper and generated-theme pairs.
- [Usage](usage.md) — choose an image, generate six palette directions, use
  Live Canvas Preview and Test Live, run Demo, and apply a theme.
- [Styling and palette settings](styling.md) — harmony, contrast, Window,
  Shell, and Bar choices.
- [Current architecture](architecture/README.md) — product boundaries,
  frontend/backend ownership, lifecycle, and contracts.
- [Demo workspace](demo.md) — temporary workspaces, application capabilities,
  fallbacks, and preview capture.
- [Recovery and safety](recovery.md) — temporary sessions, Cancel, Apply,
  Quit, and interrupted operations.
- [Development](development.md) — local plugin development and validation.
- [Nightly → dev handoff](development/nightly-to-dev-handoff.md) — promotion
  scope, security evidence, compatibility notes, and release gates.
- [v2.0.0 release notes](releases/v2.0.0.md) — release scope, trust boundary,
  upgrade/recovery guidance, and the exact-commit verification record.
- [Backend CLI reference](development/cli.md) — command families, JSON output,
  lifecycle actions, mutation commands, and recovery-safe usage.
- [Repository health and architecture notes](development/architecture-health.md)
  — behavior-preserving cleanup history, architecture opportunities, test gaps,
  and developer follow-up priorities.
- [Agent navigation](agents/README.md) — context map, invariants, recipes, and
  handoffs for bounded work.
- [Plans](plans/README.md) — optional working plans; never canonical
  architecture. There are currently no active plans in this branch.
