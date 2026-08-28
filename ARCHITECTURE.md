# Architecture

Claudux is a Bash CLI that orchestrates an authenticated Claude or Codex CLI,
uses Node.js helpers for deterministic validation and patch application, and
previews the resulting Markdown through VitePress.

It is not dependency-free:

- Node.js 18+ is required by validation and manifest helpers.
- One authenticated model CLI is required for `update`.
- Git enables incremental state and default-mode source rollback.
- `serve` uses npm and VitePress, installing docs dependencies when missing.

## Project layout

```text
bin/
  claudux               Command parsing, project locks, readiness checks, dispatch
lib/
  project.sh            Project metadata and type detection
  claude-utils.sh       Claude CLI readiness, model settings, output parsing
  codex-utils.sh        Codex CLI readiness, execution, JSONL parsing
  docs-generation.sh    Prompt assembly, backend invocation, rollback boundary, links
  docs-manifest.sh      Manifest validation, static index, guards, section transactions
  git-utils.sh          Status and change summaries
  cleanup.sh            Legacy interactive cleanup helper; update path is a no-op
  server.sh             Preview-only VitePress server orchestration
  validate-links.sh     Local route, Markdown, asset, anchor, and escape validation
  templates/            Project profiles used as backend prompt inputs
  vitepress/            Deterministic preview scaffolding and theme files
docs/                   This repository's VitePress site
tests/                  Bash integration and regression suites
```

## Command boundaries

| Command | Model call | Other side effects |
|---------|------------|--------------------|
| `claudux update` | Yes | Writes docs or applies section patches, validates, refreshes state |
| `claudux serve` | No | May scaffold VitePress support files, run `npm install`, and start the dev server |
| `claudux check` | No generation | Checks Node, selected CLI, selected-backend authentication, and docs state |
| `claudux help` / `--version` | No | Read-only output |

Current Codex authentication uses `codex login status`. Older Codex versions
fall back to a small exec probe when that command is unavailable, so `check`
can consume provider tokens on that compatibility path.

## Update flow

```text
project config + project profile + source + existing docs
                         |
                         v
              manifest and static-index checks
                         |
                         v
                 one backend invocation
                    /             \
                   /               \
          default generation      manifest mode
          direct docs writes      read-only patch JSON
                   \               /
                    \             /
              deterministic boundary checks
                         |
                         v
              local links + cache + checkpoint
```

The generation prompt contains “analysis” and “generation” phases, but they
run inside one backend invocation. Claudux does not require a separate plan
artifact before writes. One later missing-page auto-fix may start a second,
focused update.

## Default generation boundary

Without manifest section-patch mode, Claude receives
`Read,Write,Edit,Delete` and Codex defaults to a workspace-write sandbox.
Claudux captures a Git snapshot before the backend starts:

- starting `HEAD`
- starting index tree
- every dirty path outside the documentation allowlist
- content, mode, directory tree, or symlink target for those paths

After generation, changes and commits outside `docs/`, `.claudux/`, and the
known documentation configuration paths fail the run. Claudux restores those
unrelated paths and soft-resets an unexpected commit. Generated docs remain in
the working tree for review.

This boundary depends on Git, and mutating commands refuse to run outside a Git
repository. Informational commands such as `check`, `help`, and `--version`
remain available without one.

## Manifest section-patch boundary

When a qualifying committed `docs-structure.json` is present:

1. The manifest is validated and a static source-to-section index is built.
2. Pinned, explicit read-only, and skip-marker blocks are hash-snapshotted.
3. The backend receives read-only authority and must return a delimited JSON
   patch batch.
4. Each patch is checked for known IDs, duplicate targets, impact scope,
   read-only state, safe path, required body, heading boundaries, and
   transient provenance.
5. Final page bytes are built in memory and staged beside each target.
6. Original target bytes are rechecked for concurrent edits.
7. Target files are committed by rename; a later failure restores already
   moved targets or reports rollback failure explicitly.

That transaction covers section-patch application. Later manifest guards,
source-boundary checks, link validation, cache refresh, and checkpoint writes
are separate stages.

## Backend router

`CLAUDUX_BACKEND` selects the adapter:

```bash
CLAUDUX_BACKEND=claude  # default
CLAUDUX_BACKEND=codex
```

Both adapters provide readiness, model-setting, execution, and output-format
functions to `docs-generation.sh`. Generation commands require the selected
adapter and authentication. Diagnostic commands soft-load the Codex adapter so
help and version output still work when it is absent.

Authentication remains owned by the backend CLI. Claudux does not accept a
hosted API key.

## Project profiles and VitePress scaffolding

JSON files under `lib/templates/` are project profiles. The shell selects one
path and instructs the backend to read it. Claudux does not interpret those
files as a rendering schema, apply conditional page rules, or use their
`ai.default_model` values for runtime model selection.

VitePress setup is a separate deterministic path in
`lib/vitepress/setup.sh`. It can create a minimal config, copy the theme and
build-isolation files, write `docs/package.json`, detect a logo, and replace a
small fixed set of placeholders when they already exist in the config.

See [Project Profiles](./docs/technical/templates.md) for the exact boundary.

## Link validation

`lib/validate-links.sh` parses VitePress configuration and Markdown locally. It
checks:

- Nav and sidebar routes
- Inline and reference-style Markdown links
- Local assets
- Generated and explicit anchors
- Duplicate explicit IDs
- Percent-decoding errors and traversal
- Symlinks that escape `docs/`

External URLs are skipped. The update flow can launch one focused repair pass
for missing pages. Remaining failures warn by default and are fatal with
`--strict`.

## State and concurrency

Project-scoped PID locks live under the user's XDG state directory, preventing
two Claudux commands from running concurrently in one project. Stale locks are
removed after their process disappears.

Generation temp files are process-private and honor `TMPDIR`. Codex stderr is
stored under the user's XDG state directory, refuses symlink or foreign-owned
targets, and is tightened to mode `0600`.

The successful state checkpoint records freshness inputs and backend identity.
Failed generation, strict link failure, or cache refresh failure does not
advance it.

## Network and data boundary

- `update` sends prompt context through the authenticated backend CLI.
- `serve` may contact the configured npm registry when docs dependencies are
  absent.
- The installer downloads Claudux from GitHub.
- External links in documentation are not fetched by the link validator.
- Backend stderr and retained failure logs can contain diagnostic text; state
  paths are owner-scoped, but users should still inspect logs before sharing.

## Testing

The repository uses Bash test drivers plus Node and Git fixtures. Focused
suites cover backend routing, manifest validation and transactions, source
rollback, links, installer behavior, server isolation, state, and CLI safety.

```bash
bash tests/run-tests.sh
bash tests/run-all.sh
npm run verify
npm --prefix docs run docs:build
```

A green source suite proves the current checkout, not a release, install, or
published docs site.
