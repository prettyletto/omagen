# ADR-0004: Launcher widget and full Bar boundary

- Status: Accepted
- Date: 2026-08-28

## Decision

`pretty.omagen` owns the overlay and launcher/status widget. `pretty.omagen.bar`
owns the full Bar entry point and its `bar/` implementation. The widget may
open the overlay but does not own lifecycle/business state.

## Rationale

Omarchy's plugin registry treats a bar plugin and a bar widget as different
roles. Keeping separate manifests and install payloads prevents duplicate
layout ownership and keeps Bar-only work local.
