---
name: claudux
description: "Use for Claudux receiver work: Bash CLI docs generator, deterministic docs manifest, shell tests, and source-owned documentation guardrails."
---

# Claudux Receiver Skill

Claudux is a Bash-first CLI. Keep `bin/claudux` as a command router and put
behavior in focused `lib/*.sh` modules. Generated docs live under `docs/**`; do
not hand-edit generated docs for receiver work.

Before work:

- Read `claude.md`, `claudux.md`, `docs-structure.json`, `package.json`, and
  `git status --short --branch`.
- Preserve `/Users/leokwan/Development/claudux`; use the clean Eve worktree.
- Do not create env files, credentials, npm publish artifacts, deploys, or Pages
  changes.

Allowed receiver proof:

- `npm ci --dry-run`
- `npm run eve:capabilities -- --json`
- `npm run eve:info -- --json`
- `npm run eve:build`
- `npm run test`
- `npm run test:all`
- `npm run secret-scan`
- `git diff --check`

Do not claim `origin/main` is Eve-powered until the receiver PR is merged or
replayed and re-proved from the merged branch.
