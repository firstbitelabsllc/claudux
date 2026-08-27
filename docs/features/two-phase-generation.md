# Generation Pipeline

`claudux update` prepares context, invokes one selected backend, enforces the
applicable write boundary, validates the result, and saves a checkpoint only
on the successful path.

The generation prompt asks the model to analyze first and write second. Those
“phase 1” and “phase 2” labels are instructions inside one backend invocation,
not an enforced two-artifact protocol. Claudux does not require a separate plan
file or validate a model plan before writing. A later missing-page repair can
launch one additional focused update.

## 1. Resolve project context

Claudux loads:

- `claudux.json` or the legacy `.claudux.json`
- Auto-detected project type when no accepted type is configured
- The matching JSON project profile under `lib/templates/`
- `.ai-docs-style.md` when present
- `claudux.md` when present
- `docs-structure.json`, preferred over the legacy `docs-map.md`
- Existing documentation and the repository files available to the backend

Project profiles are prompt inputs. They are not rendered or schema-validated
by the shell CLI.

## 2. Validate deterministic inputs

Before model invocation, the update path:

1. Validates `docs-structure.json` when the manifest helper is loaded.
2. Builds the static analysis index.
3. Enables section-patch mode when the committed manifest qualifies.
4. Captures the manifest guard snapshot for pinned, explicit read-only, and
   skip-marker content.
5. Resolves incremental changes and the source-to-section impact allowlist when
   a valid checkpoint exists.
6. Builds the final backend prompt.

A malformed manifest, failed static index, or failed guard snapshot stops the
run before generation.

## 3. Capture the source boundary

In a Git checkout, claudux snapshots:

- Starting `HEAD`
- The starting index tree
- Every dirty path outside the documentation allowlist
- File type, mode, content, directory tree, or symlink target for those paths

Allowed generation paths include `docs/`, `.claudux/`, the active manifest,
legacy docs-map and style files, the docs site plan, and the claudux state file.

The snapshot lets claudux distinguish a backend mutation from unrelated work
that was already dirty before the command started.

## 4. Invoke the selected backend

### Default generation

Without manifest section-patch mode:

- Claude receives `Read,Write,Edit,Delete`, with `Bash` explicitly disallowed
  when the installed CLI supports that flag.
- Codex defaults to a workspace-write sandbox with
  `approval_policy="never"`.
- The backend writes documentation paths directly.

After the invocation, claudux scans both the working tree and commits created
since the starting `HEAD`. Any unrelated path mutation fails the run. Claudux
restores that source path or pre-existing dirty value and soft-resets an
unexpected commit, while leaving generated documentation available for review.

This boundary requires Git. A non-Git directory does not have a restorable
source snapshot.

### Manifest section-patch mode

With a qualifying committed manifest:

- Claude receives `Read` only.
- Codex defaults to a read-only sandbox unless explicitly overridden.
- The backend must return one delimited JSON payload containing section
  patches.
- Direct documentation writes are not the accepted output.

Claudux validates every patch before committing a target:

- Known page and section IDs
- No duplicate targets
- Incremental impact allowlist
- Pinned and explicit read-only status
- Safe page path inside the documentation root
- Existing target page unless creation is explicitly allowed
- Required Markdown body
- No transient cache-provenance prose
- No same-level or higher-level heading that escapes the declared section

It then builds each final page in memory, writes staged copies beside the
targets, verifies the originals did not change concurrently, and commits the
target files by rename. If a later target commit fails, already-committed
targets are restored. A restoration failure is reported explicitly.

The transaction covers the manifest section-patch batch. It does **not** mean
the entire `claudux update` command is rolled back if a later guard, link,
cache, or checkpoint step fails.

## 5. Run post-generation checks

After backend success and patch application:

1. The source boundary is checked again.
2. `DOCS_BASE` handling in `docs/.vitepress/config.ts` is normalized.
3. The manifest receives post-generation validation.
4. The pre-generation guard snapshot is verified.
5. The source boundary is checked after claudux's own documentation edits.
6. Local links, routes, assets, anchors, duplicate IDs, traversal, and symlink
   escapes are validated.
7. One missing-page repair update may run.
8. Deterministic caches are refreshed.
9. The successful checkpoint is saved.
10. The working-tree change summary is printed.

External URLs are skipped. Without `--strict`, unresolved link failures warn
and the update can continue. With `--strict`, they fail the command.

## Failure behavior

| Failure | Result |
|---------|--------|
| Invalid manifest or static index | Stops before backend invocation |
| Backend unavailable or unauthenticated | Stops before generation |
| Backend timeout or malformed output | No successful checkpoint |
| Default-mode source escape | Unrelated source paths are restored in Git; docs remain reviewable |
| Invalid manifest patch batch | Target docs are unchanged |
| Transaction commit failure | Already-committed targets are restored when possible; rollback failure is explicit |
| Protected-block mismatch | Update fails after guard validation |
| Broken links without `--strict` | Warning after the optional repair pass |
| Broken links with `--strict` | Update fails |
| Cache refresh failure | Update fails and does not advance the checkpoint |

## Focused and incremental updates

A focused directive changes the prompt:

```bash
claudux update -m "Document the new authentication flow"
```

Incremental mode changes the context and, in manifest mode, the allowed target
set. Neither mechanism bypasses the write boundary.

## Review surface

Claudux is designed to leave a reviewable working-tree result, not to publish
or commit documentation automatically. Before accepting generated prose:

```bash
git status --short
git diff -- docs/ docs-structure.json
npm --prefix docs run docs:build
```

Use `claudux update --strict` when local-link failures must block acceptance.
