# Installed-theme editing change

Use this recipe for installed-theme editing, theme adoption, managed-scope
migration, or theme recipe export. Read
`docs/architecture/contracts/theme-edit.md`, `docs/architecture/frontend.md`,
`backend/internal/themeedit`, `qml/gateways/ThemeGateway.qml`, and
`qml/controllers/ThemeEditController.qml` with their direct callers.

Preserve stock-before-user precedence, regular-file and symlink rejection,
source immutability during Open/Preview/Cancel, durable `workflow:
"theme-edit"`, explicit managed scopes, and replacement recovery. A new-name
Apply publishes a user theme; replacing an existing user theme uses a
session-owned backup and removes it only after native Apply commits.

Keep recipe export sidecar-only unless a separate contract adds import. Do not
move theme ownership or recursive cleanup into QML. Preserve the existing CLI
`theme list`, `theme edit`, and `theme export-recipe` contract.

```zsh
cd backend
GOCACHE=/tmp/omagen-gocache go test ./internal/themeedit ./internal/session ./internal/cli
GOCACHE=/tmp/omagen-gocache go test -race ./internal/themeedit ./internal/session ./internal/cli
cd ..
qmllint qml/gateways/ThemeGateway.qml qml/controllers/ThemeEditController.qml
GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh
git diff --check
```

Manually validate Open, stock/user merge, Preview, Cancel, scope migration,
new-name Apply, replacement Apply, recipe export, and recovery when a live
Omarchy session is available. Record unavailable native checks in the handoff.

