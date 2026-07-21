# Changelog

All notable changes to claudux are documented in this file.

## [2.0.0] - 2026-07-21

Minimal, open-source-ready surface. claudux is now focused on one job: generate a VitePress docs site from your codebase, preview it locally, and update it in place.

### Removed

- **Standalone reporting and lifecycle commands.** `audit`, `drift`, `diff`, `status`, `validate`, `recreate`, and `template` are gone from the CLI. Their machinery that actually matters survives internally: link validation and the manifest deletion guard run inside `update`, and the `.claudux-state.json` checkpoint still scopes each incremental run.
- The `--release` audit gate and the terminal-demo assets tied to the removed surface.
- **npm as a distribution channel.** The `publish.yml` workflow and the root `package-lock.json` are gone; claudux is a zero-dependency bash CLI that installs straight from GitHub via the install script or `npx github:firstbitelabsllc/claudux`. No registry package to publish, no `NPM_TOKEN`. A release is just a git tag. (Node 18+ is still required at runtime, and the VitePress docs site still uses npm.)

### Changed

- The command surface is now `claudux` (menu), `update` (with `-m`/`--with`/`--strict`), `serve`, `check`, `help`, and `--version`.
- `package.json` description and keywords reworded around generation; `release:check` drops the audit step.
- Docs, README, and the VitePress site rewritten to describe only the shipped commands.

## [1.2.0] - 2026-07-18

### Added

- **Deterministic docs mode.** A checked-in `docs-structure.json` makes the docs tree source-owned state: claudux builds a static-analysis index before calling the model, applies output through bounded section patches instead of broad rewrites, and blocks cleanup and `recreate` from deleting manifest-owned pages.
- **`claudux audit`.** No-AI readiness report covering project detection, manifest validity, link status, checkpoint freshness, and uncommitted docs/config drift. `--json` for machines, `--strict` and `--release` for CI gates, `--handoff-strict` for agent handoffs.
- **Multi-backend support.** Switch AI backends via `CLAUDUX_BACKEND=codex` env var. Codex adapter uses GPT-5.4 with xhigh reasoning effort in non-interactive exec mode. Claude remains the default.
- **Change tracking.** `claudux diff` shows files changed since the last documentation run. `claudux status` shows checkpoint state (last run time, SHA, backend, stale file count). Checkpoint stored in `.claudux-state.json` (gitignored).
- **Incremental updates.** `claudux update` scopes the LLM prompt to only changed files when a checkpoint exists, reducing token usage on large repos.
- **New CLI commands.** `diff`, `status`, and `validate` are now wired into the CLI. `check` shows active backend and CLI availability.
- **Test suite.** Pure-bash suites cover backend routing, state files, diff calculation, hardening, integration, CLI behavior, and manifest guards.
- **CI pipeline.** GitHub Actions with 5 parallel jobs: ShellCheck lint, file structure, bash syntax, version consistency, and full test suite. Runs on every push/PR to main.
- **npm publish workflow.** Automated publish on `v*` tag push. Verifies tag matches `package.json` version, runs full CI, publishes with provenance.
- **ARCHITECTURE.md.** Module map, two-phase pipeline, backend router interface, content protection, concurrency model, and security design.
- **SECURITY.md.** Responsible disclosure policy and threat model (shell injection, path traversal, dependency chain, secrets-in-docs).
- **GitHub templates.** Bug report and feature request issue templates. PR template with checklist.
- **Terminal demo SVG.** Visual demo of `claudux update` session in README and docs site.
- **Hero banner SVG.** Styled banner for README with tagline.

### Changed

- `claudux help` now lists all 11 commands (was 7). Help text includes `CLAUDUX_BACKEND` env var documentation.
- `claudux check` now shows active backend and validates the correct CLI (Claude or Codex) based on `CLAUDUX_BACKEND`.
- README expanded with multi-backend section, comparison table, architecture cross-link, and demo SVG.
- CONTRIBUTING.md updated with CI-based release process and `NPM_TOKEN` setup instructions.
- package.json description and keywords updated for multi-backend discoverability.

### Fixed

- `claudux diff` and `claudux status` previously returned "Unknown command" despite being documented in help text.
- `save_claudux_state` produced invalid JSON when `docs/` had no tracked files.
- JSON escaping bug: filenames with double-quotes or backslashes corrupted `.claudux-state.json`.
- Codex JSONL formatter matched hypothetical event types instead of actual Codex CLI v0.119 events.
- `check_generation_backend()` called Claude validation even when Codex backend was active.

## [1.1.1] - 2025-08-29

First release documented in this changelog. Versions 1.0.0 through 1.1.0 shipped to npm on 2025-08-26 through 2025-08-29 and predate it.

- Claude-only backend with two-phase documentation generation
- VitePress site scaffolding and serving
- Link validation with auto-fix
- Content protection for manual edits
- Project type auto-detection
