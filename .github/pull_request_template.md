## Summary

<!-- What changed and why? -->

## Bounded context

- [ ] Palette/generation
- [ ] Lifecycle/recovery
- [ ] Demo
- [ ] QML/UI
- [ ] Runtime
- [ ] Bar
- [ ] Packaging/release
- [ ] Documentation/governance

## Safety and compatibility

- [ ] Backend session authority and ownership boundaries are preserved.
- [ ] Existing QML↔Go command names, fields, and exit behavior are preserved.
- [ ] User-owned themes, shell configuration, backgrounds, and hooks are protected.
- [ ] Both plugin manifests remain separate and valid.
- [ ] No secrets or private user data are included.

## Validation

- [ ] Focused tests passed.
- [ ] `GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh` passed.
- [ ] `python3 scripts/marketplace-preflight.py` passed or review-required capabilities are documented.
- [ ] QML behavior tests were run, or the environment limitation is recorded.
- [ ] Real Omarchy/Hyprland validation was run, or the limitation is recorded.
- [ ] Documentation was updated.
