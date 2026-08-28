# Context budget defaults

Use progressive disclosure:

1. Read `AGENTS.md`, one recipe, and the named canonical contract.
2. Inspect symbols and imports in the listed source files.
3. Read direct callers/callees only when the change crosses a seam.
4. Run focused tests before expanding to the full gate.
5. Re-read the final changed files and update the route if ownership moved.

Do not start by reading every `.md`, every QML file, all palette internals, or
all historical plans. These are routing defaults, not debugging restrictions:
expand context when evidence shows a hidden dependency, a contract test, or a
recovery path is involved.
