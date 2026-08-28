# Features

Claudux generates VitePress documentation through an authenticated Claude or
Codex CLI. Its safety model has two distinct levels: default generation guards
the source tree, while a committed `docs-structure.json` adds section-level
control over the documentation itself.

## Generation modes

| Mode | Backend authority | Enforced boundary |
|------|-------------------|-------------------|
| Default generation | May edit documentation paths directly | In a Git checkout, changes and commits outside the documentation allowlist are rejected and restored |
| Manifest mode | Read-only; returns section-patch JSON | Only writable manifest sections may change, and the target-file batch is applied transactionally |

The distinction matters. Default mode is useful for creating a first draft.
Manifest mode is the stronger choice once people have curated parts of the
site.

## First-draft generation

`claudux update` detects the project type, selects a project profile, reads
project configuration and existing docs, builds one prompt, and invokes the
selected backend.

```bash
claudux update
```

The backend can create or rewrite documentation files. Before that invocation,
claudux snapshots `HEAD` and all existing dirty paths outside the documentation
allowlist. If generation changes an unrelated source file, rewrites one of
those pre-existing dirty paths, renames source into `docs/`, or creates a
commit that includes source changes, the run fails and restores the source
state. The generated docs remain available for review.

This rollback boundary depends on Git. In a non-Git directory, there is no
source snapshot to restore.

## Manifest-owned updates

A committed `docs-structure.json` changes the execution contract:

- Page IDs, paths, navigation order, source ownership, required sections, and
  deletion policy come from the repository.
- Pinned sections and sections with `generated: false` are read-only.
- Changed source files narrow the incremental impact allowlist when a valid
  checkpoint exists.
- The backend receives read-only authority and returns a JSON patch batch.
- Claudux rejects unknown, duplicate, read-only, out-of-impact, path-escaping,
  heading-escaping, or provenance-leaking patches.
- Target files are staged, checked for concurrent edits, and committed as one
  patch transaction. A commit failure triggers restoration of already-moved
  targets and a hard error if restoration itself fails.
- Pinned, explicit read-only, and skip-marker blocks are hash-checked against
  the pre-generation guard snapshot.

```bash
git add docs-structure.json
claudux update
```

Manifest mode constrains what may change. It does not make generated prose
factually correct; the diff still needs review.

## Incremental scoping

Claudux records a successful documentation checkpoint. On a later run it
compares source, docs, and manifest inputs with that checkpoint:

- A usable checkpoint plus changed files enables incremental prompt scoping.
- The static index resolves changed sources to manifest-owned pages and
  sections.
- No source changes or an unusable checkpoint falls back to a full scan.

Incremental scoping narrows the work. It does not bypass manifest validation.

## Local link validation

The link checker stays local and validates:

- VitePress nav and sidebar routes
- Inline and reference-style Markdown links
- Local images and other assets
- Generated and explicit heading anchors
- Duplicate explicit IDs
- Encoded path traversal
- Symlink escapes outside `docs/`

External URLs are counted and skipped rather than fetched. If a generated site
has missing local pages, `update` can launch one focused repair pass. Remaining
failures warn by default and fail the command with `--strict`.

```bash
claudux update --strict
```

## Focused directives

`-m`, `--message`, and `--with` provide the same high-level directive:

```bash
claudux update -m "Document the new authentication flow"
```

The directive changes the prompt. It does not grant broader write authority or
override the manifest allowlist.

## Project profiles

Project-type JSON files under `lib/templates/` are prompt profiles. They give
the backend framework-specific context and suggested focus areas. They are not
a deterministic renderer, schema validator, substitution engine, or
conditional page generator.

See [Project Profiles](/technical/templates) for the exact selection order and
the separate VitePress scaffolding behavior.

## Preview and readiness

`claudux serve` previews an existing docs site. It never invokes a model, but it
may create missing VitePress support files and run `npm install` before
starting the development server.

`claudux check` validates Node 18+, selected-backend CLI presence,
selected-backend authentication, and whether `docs/` exists. It does not
generate docs. Modern Codex uses `codex login status`; the legacy compatibility
path may execute a small authentication probe.

## Cleanup

The main update path does not run automatic semantic cleanup:

- `cleanup_docs_silent` is intentionally empty.
- `cleanup_docs` is a separate legacy, interactive model-judgment helper.
- There is no deterministic confidence score or automatic obsolete-page
  deletion pipeline.

Use the manifest deletion contract, review proposed removals, and delete pages
intentionally.

## Trust boundary

Claudux can enforce paths, section targets, protected hashes, and local-link
integrity. It cannot prove that a model-authored explanation is complete or
correct. The final acceptance surface is the working-tree diff plus the
project's own tests and build.

## Next steps

- [Generation Pipeline](/features/two-phase-generation)
- [Cleanup](/features/smart-cleanup)
- [Content Protection](/features/content-protection)
- [Deterministic Generation](/technical/deterministic-generation)
