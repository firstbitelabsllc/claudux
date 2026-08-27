# CLI Reference

This page documents the public command-line surface and the execution boundary
behind each command.

## Synopsis

```bash
claudux
claudux update [--with|-m <directive>] [--strict]
claudux serve
claudux check
claudux help
claudux --version
```

Run `claudux` without arguments to open the interactive menu.

## `claudux update`

Generate or update documentation from the current project.

```bash
claudux update
claudux update -m "Document the new authentication flow"
claudux update --with "Focus on deployment"
claudux update --strict
```

### Options

| Option | Meaning |
|--------|---------|
| `-m <directive>` | Add a focused instruction to the generation prompt |
| `--message <directive>` | Same as `-m` |
| `--with <directive>` | Same as `-m` |
| `--strict` | Fail if local-link problems remain after the optional repair pass |

An option without its required directive, an unknown option, or an unexpected
positional argument exits with code `2`.

### Execution flow

1. Load project configuration and detect the project type.
2. Validate `docs-structure.json` when present.
3. Build the static analysis index and manifest guard snapshot.
4. Resolve incremental source changes and impact scope.
5. Build one backend prompt.
6. Check the selected backend and invoke it.
7. Enforce default source rollback or apply the manifest patch batch.
8. Run manifest, protected-content, source-boundary, and local-link checks.
9. Optionally launch one focused missing-page repair update.
10. Refresh deterministic caches and save the successful checkpoint.
11. Print the working-tree change summary.

The prompt asks the model to analyze before writing, but that is one backend
invocation rather than a separate plan artifact and write artifact.

### Default generation

Without manifest section-patch mode, the backend may write documentation paths
directly. In a Git checkout, claudux snapshots unrelated dirty work and
starting `HEAD`, then rejects and restores any change or commit outside the
documentation allowlist. Generated docs remain in the working tree for review.

### Manifest generation

With a qualifying committed `docs-structure.json`, the backend is read-only
and must return section-patch JSON. Claudux validates the complete batch,
stages target files, checks for concurrent edits, and commits or restores the
target batch transactionally.

The patch transaction does not include later guard, link, cache, or checkpoint
stages.

### Link behavior

The validator checks VitePress routes, Markdown links, local assets, anchors,
duplicate explicit IDs, traversal, and symlink escape. External URLs are
skipped.

- Default: unresolved failures warn after the optional repair pass.
- `--strict`: unresolved failures exit nonzero.

## `claudux serve`

Preview existing documentation with the VitePress development server.

```bash
claudux serve
```

Aliases: `claudux server`, `claudux dev`.

Behavior:

- Requires `docs/index.md`; otherwise prints `claudux update` guidance and
  returns nonzero.
- Never invokes Claude or Codex.
- Runs VitePress setup when support files are missing.
- May copy the bundled theme and build-isolation files.
- May create a minimal VitePress config.
- Rewrites `docs/package.json` during setup.
- Runs `npm install --no-audit --no-fund` when VitePress is absent.
- Verifies the `docs:dev` script.
- Starts `npm run docs:dev` from `docs/`.

The reported preview URL is `http://localhost:5173`.

## `claudux check`

Validate the local runtime and selected backend.

```bash
claudux check
```

Alias: `claudux --check`.

Checks:

- Node.js exists and is version 18 or newer.
- The selected backend is `claude` or `codex`.
- The selected backend CLI exists.
- The selected backend authentication check succeeds.
- Reports whether `docs/` exists.

`check` does not generate documentation. For current Codex CLIs it uses
`codex login status`. The compatibility path for older CLIs may run a small
`codex exec` probe and can therefore consume provider tokens.

The command exits `1` when one or more required checks fail.

## Help and version

```bash
claudux --help
claudux -h
claudux help

claudux --version
claudux -V
claudux version
```

Version output is read from the installed `package.json`.

## Interactive menu

Without existing docs:

```text
1) Generate docs
2) Serve
3) Exit
```

With existing docs:

```text
1) Update docs
2) Update (focused)
3) Serve
4) Exit
```

The generation choices call `update`. The serve choice uses the model-free
preview path.

## Environment variables

### Backend selection

| Variable | Default | Meaning |
|----------|---------|---------|
| `CLAUDUX_BACKEND` | `claude` | Select `claude` or `codex` |
| `FORCE_MODEL` | Project model or `sonnet` | Select the Claude model |
| `CODEX_MODEL` | `gpt-5.4` | Select the Codex model |
| `CODEX_REASONING_EFFORT` | `xhigh` | Set Codex reasoning effort |
| `CLAUDUX_TIMEOUT` | `600` | Codex timeout in seconds when `timeout` or `gtimeout` is available; `0` disables it |

### Prompt and docs behavior

| Variable | Meaning |
|----------|---------|
| `CLAUDUX_MESSAGE` | Default focused directive when no `-m`/`--with` value is supplied |
| `DOCS_BASE` | VitePress base path normalized into generated config |
| `CLAUDUX_DOCS_STRUCTURE` | Override the manifest path |
| `DOCS_STRUCTURE_FILE` | Alternate manifest-path override recognized by the manifest helper |
| `CLAUDUX_UNLOCK_PINNED_SECTIONS=1` | Permit an explicitly flagged manifest patch to target pinned content |

Unlocking pinned sections also requires the returned patch to set
`unlock_pinned: true`.

### Runtime paths and Codex sandbox

| Variable | Meaning |
|----------|---------|
| `XDG_STATE_HOME` | Base for project locks and Codex stderr state |
| `TMPDIR` | Base for process-private temporary files |
| `CODEX_STDERR_LOG` | Override the Codex stderr log path |
| `CODEX_SANDBOX_MODE` | Override the default Codex sandbox mode |

Codex defaults to `workspace-write` for normal generation and `read-only` for
section-patch mode. Overriding the sandbox can weaken that pre-execution
boundary; manifest patch validation still controls accepted documentation
output.

## Configuration files

### `claudux.json`

The main CLI reads:

```json
{
  "project": {
    "name": "My Project",
    "type": "react",
    "model": "sonnet"
  }
}
```

- `project.name`: display name
- `project.type`: accepted built-in or profile-backed project type
- `project.model`: Claude model used when `FORCE_MODEL` is unset

The VitePress setup path can additionally read:

```json
{
  "deployment": {
    "base": "/my-project/",
    "siteUrl": "https://example.com/my-project/"
  }
}
```

Those deployment values currently require `jq` in the setup script.

### `.claudux.json`

Legacy flat configuration. The CLI reads `name` and `type`.

### `claudux.md`

Optional free-form documentation preferences. The generation prompt tells the
backend to read it when present.

### `docs-structure.json`

Deterministic page and section contract. It can define:

- Page ID, path, title, group, and order
- Source ownership patterns
- Required sections
- Pinned or explicit read-only sections
- Deletion policy
- Stable page and section IDs used as patch addresses

See [Deterministic Generation](/technical/deterministic-generation).

## Generated and state paths

| Path | Purpose |
|------|---------|
| `docs/` | Generated or maintained VitePress site |
| `.claudux-state.json` | Successful freshness checkpoint |
| `.claudux/index/` | Static analysis, impact, guard, and cache artifacts |
| XDG state `claudux/locks/` | Per-project process locks |
| XDG state `claudux/codex-stderr.log` | Owner-scoped Codex stderr by default |

Failed runs do not advance the successful checkpoint.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Command completed successfully |
| `1` | Runtime, backend, generation, validation, or readiness failure |
| `2` | Invalid command or command-line usage |
| `124` | Backend timeout |
| `130` | Interrupted with Ctrl+C |

The exact nonzero code of an underlying npm or backend process can also
propagate through the shell pipeline.

## Automation guidance

`claudux update` is model-backed and may change documentation. For CI gates,
prefer deterministic checks against an already-generated tree:

```bash
bash lib/validate-links.sh
npm --prefix docs run docs:build
```

If CI intentionally runs generation, pin the Claudux revision, backend
configuration, manifest, and strict-link policy, then inspect the resulting
diff rather than treating exit `0` as proof of prose correctness.
