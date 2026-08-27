# Technical Architecture

Claudux is a local Bash orchestrator with Node.js validation helpers, two
authenticated model-CLI adapters, a deterministic manifest patcher, and a
VitePress preview layer.

## System shape

```text
bin/claudux
   |
   +-- project/config detection -------- lib/project.sh
   +-- selected backend ---------------- lib/claude-utils.sh or lib/codex-utils.sh
   +-- generation orchestration -------- lib/docs-generation.sh
   |      |
   |      +-- default source rollback
   |      +-- manifest section patches - lib/docs-manifest.sh
   |      +-- local link validation ---- lib/validate-links.sh
   |
   +-- preview-only server ------------- lib/server.sh + lib/vitepress/
```

## Runtime requirements

| Capability | Requirement |
|------------|-------------|
| CLI and tests | Bash |
| Manifest, static index, patching, links | Node.js 18+ |
| Documentation generation | Authenticated Claude CLI or Codex CLI |
| Default rollback and incremental state | Git |
| Preview and docs build | npm and VitePress dependencies |

The root package has no npm runtime dependencies, but that does not make the
product dependency-free. Node is part of the CLI contract, and `serve` manages
a separate VitePress dependency set under `docs/`.

## Entry point

`bin/claudux` owns:

- Command parsing and usage failures
- One lock per project path
- Lazy library loading
- Node-version validation
- Selected-backend readiness and authentication
- Dispatch to `update`, `serve`, diagnostics, help, and version output

Only generation options in the interactive menu call `update`.

## Project and configuration resolution

`lib/project.sh` reads these shell-level values:

- `claudux.json`: `project.name`, `project.type`, `project.model`
- Legacy `.claudux.json`: flat `name` and `type`
- File heuristics when the type is missing or generic

Unknown configured types warn and fall back to auto-detection unless a matching
`lib/templates/<type>-project-config.json` exists.

The JSON file chosen from `lib/templates/` is a project profile that the
backend is told to read. The shell does not render it, validate a schema, or
execute conditional sections. See [Project Profiles](/technical/templates).

## Generation orchestration

`lib/docs-generation.sh`:

1. Parses the focused directive and `--strict`.
2. Loads project context.
3. Validates the manifest when present.
4. Builds the static analysis index.
5. Captures the documentation guard snapshot.
6. Resolves incremental changes and manifest impact scope.
7. Builds one backend prompt.
8. Captures the pre-generation Git source snapshot.
9. Invokes the selected backend.
10. Enforces the source boundary or applies the manifest patch batch.
11. Runs post-generation manifest, guard, source, and link checks.
12. Refreshes deterministic caches and saves the successful checkpoint.

The prompt's “phase 1” and “phase 2” headings are model instructions inside one
invocation. They are not a separate planning transaction.

## Default generation mode

The backend can edit documentation paths directly:

- Claude receives `Read,Write,Edit,Delete`, with `Bash` denied when supported.
- Codex defaults to `sandbox_mode="workspace-write"` and
  `approval_policy="never"`.

In a Git checkout, claudux snapshots unrelated dirty paths and starting `HEAD`.
After generation it detects new source changes, modifications to existing
unrelated dirty work, rename escapes, and commits containing source paths. A
violation fails the update and restores that source state while leaving docs
for review.

This is a repository boundary, not section-level protection within `docs/`.

## Manifest section-patch mode

`lib/docs-manifest.sh` owns the stricter documentation contract:

- Manifest schema and canonical path validation
- Source-to-section static index
- Incremental impact allowlist
- Pinned/read-only and skip-marker guard hashes
- Read-only backend patch contract
- Patch JSON extraction and validation
- Transactional multi-file target commit

A patch batch is fully validated before target writes. Final bytes are staged,
original bytes are checked again for concurrent edits, and target files are
renamed into place. If a later target commit fails, earlier target commits are
restored when possible and rollback failure is explicit.

The transaction ends at patch application. Later guard, link, cache, and
checkpoint failures are separate and may leave a reviewable docs diff.

## Static analysis index

The index derives deterministic relationships used by prompt scoping and
manifest enforcement:

- Source ownership and manifest section targets
- Shell `source` and required-library edges
- Package-script file references
- CLI command inventory
- Documentation links and protected-block inventory
- Changed-source impact resolution

It is not a type checker, prose verifier, backend compatibility test, or
VitePress renderer.

## Link checker

`lib/validate-links.sh` parses configuration and Markdown without fetching the
network. It validates:

- VitePress nav and sidebar targets
- Markdown destination paths
- Local assets
- Generated and explicit heading anchors
- Duplicate explicit IDs
- Encoded traversal attempts
- Symlinks escaping the docs root

External URLs are counted and skipped. `update` can run one focused repair for
missing pages. `--strict` converts remaining failures from warnings to a hard
error.

## Serve path

`lib/server.sh` never invokes a model. It requires an existing
`docs/index.md`, then:

1. Runs `lib/vitepress/setup.sh` when support files are missing.
2. Enters `docs/`.
3. Runs `npm install --no-audit --no-fund` if VitePress is absent.
4. Verifies the `docs:dev` script.
5. Starts `npm run docs:dev`.

The setup script may create or replace preview support files, so `serve` is
model-free but not universally read-only.

## Readiness path

`claudux check` verifies:

- Node exists and is version 18 or newer
- Selected backend CLI exists
- Selected backend authentication succeeds
- Documentation directory presence

It does not generate docs. Modern Codex checks `codex login status`; older
versions may require a small exec authentication probe.

## Cleanup boundary

`cleanup_docs_silent` is the function called by `update`, and it is a no-op.
The separate `cleanup_docs` helper is a legacy interactive Claude path that
asks the model to judge obsolete files. It is not deterministic scoring and is
not part of the public update pipeline.

## State, locks, and temporary files

- Project locks are keyed by canonical project path and stored under XDG state.
- Stale locks are removed after the owning PID is gone.
- Generation temps use process-private `mktemp` paths under `TMPDIR`.
- Codex stderr uses an owner-scoped path, rejects symlinks and foreign-owned
  files, and tightens permissions to `0600`.
- The checkpoint advances only after generation, validation, cache refresh,
  and change analysis succeed.

## Security boundary

Prompt context is sent through the selected authenticated backend CLI. Claudux
does not offer a hosted API-key path or fetch external documentation links.

Default mode protects source paths after the backend runs. Manifest mode
reduces backend authority before it runs and constrains documentation changes
to declared section patches. Neither mode proves generated prose is correct.

## Verification

```bash
bash tests/run-tests.sh
bash tests/run-all.sh
npm run verify
npm --prefix docs run docs:build
```

The focused regressions cover backend routing, manifest validation and
transactions, rollback, links, installer behavior, server isolation, state,
and CLI safety. Runtime proof still requires a disposable target repository.
