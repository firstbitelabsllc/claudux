# Claudux Claim Contract Audit

Audit date: 2026-08-27  
Source baseline: `bfde817e98e4df2837873d887165fa926e812636`

This is the release contract, not marketing copy. Every promoted claim below
names its mechanical owner, current behavioral proof, remaining risk, and a
falsifier that can still turn the suite red.

## Verdict

The ten release-blocking claim defects found at the baseline are repaired in
the integrated candidate. Focused regressions pass, two overlapping
`npm run verify` processes both exit `0`, the docs build passes, and the docs
dependency audit reports zero vulnerabilities.

## Claim-to-code matrix

| Public claim | Mechanical owner and current behavior | Current proof | Strongest falsifier and status |
| --- | --- | --- | --- |
| A manifest path cannot escape the repository or `docs/`. | Manifest validation, indexing, guard capture, and patch application in `lib/docs-manifest.sh` resolve paths against the real repository and `docs/` roots, reject symlink traversal, and require regular files. | `tests/test-docs-manifest.sh`: manifest symlink rejection, three outside-root refusals, and unchanged external bytes; manifest suite `107/107`. | Replace a manifest page with an external symlink. **Killed** — every consumer refuses it before mutation. |
| Multi-file section patches are all-or-nothing. | `apply_manifest_section_patches()` stages the full batch, validates target versions, commits targets, and rolls earlier targets back if a later commit fails. | Invalid mixed batch leaves both targets unchanged; injected second-file I/O failure restores the first target and removes transaction files. | Fail the second commit after the first succeeds. **Killed** — both original hashes survive. |
| Skip-marker protection fails closed. | Protected-block parsers reject nested starts, unmatched starts, and orphan end markers before replacing deterministic cache files. Guard validation hashes and compares protected block bytes. | Malformed marker controls preserve the prior index and guard cache; changed Markdown and source-language blocks are rejected. | Remove or nest one marker, or rewrite protected bytes. **Killed** — generation cannot obtain a valid guard. |
| One project has one active mutating Claudux process. | `acquire_lock()` uses an atomic per-project directory lock; `cleanup_on_exit()` stops and waits for jobs, runs generation cleanup, then releases only its owned lock. | `tests/test-cli-safety.sh` covers live contention, stale recovery, ownership, background cleanup, and cleanup-before-unlock; `32/32`. | Start two updates and add a trapped background child. **Killed** — the second updater fails and the first child acknowledges `TERM`. |
| Git path handling preserves arbitrary legal filenames. | `lib/git-utils.sh` and the generation boundary consume NUL-delimited Git records and escape tabs/newlines only for display. | Safe-path tests cover spaces, tabs, newlines, quotes, renames, and a literal ` -> ` without splitting or truncation. | Add a renamed file whose source and destination contain control characters. **Killed** — one record remains one path pair. |
| Codex JSONL progress is structurally parsed. | `format_codex_output_stream()` parses JSON objects with Node and selects only valid top-level events and structural usage fields. | `tests/test-codex-jsonl.sh` covers reordered keys, nested decoys, escapes, malformed lines, paths, errors, and counters; `17/17`. | Reorder keys and embed escaped quotes, backslashes, and newlines. **Killed** — event meaning and counters remain exact. |
| Link validation catches reader-visible local failures. | `lib/validate-links.sh` checks VitePress routes, Markdown pages, images, generated and explicit anchors, traversal, and symlink confinement while skipping external schemes. | Valid fixture passes; missing page, asset, anchor, config route, and traversal fixtures fail; `18/18`. | Keep config valid while breaking three Markdown targets. **Killed** — all three are named and returned in the output file. |
| `claudux check` is an executable readiness verdict. | The CLI enforces Node 18+, validates the configured backend name, and runs `check_claude()` or `check_codex()` without generating docs. | CLI safety and check-command suites reject Node 16, logged-out Claude, logged-out Codex, and unsupported backend names. | Stub an installed CLI whose auth probe fails. **Killed** — `check` exits nonzero with backend-specific remediation. |
| A successful installer proves the installed binary runs. | `verify()` in `install.sh` requires the installed command to exit `0` and print exactly `claudux <package version>`. | `tests/test-installer-verification.sh` covers missing, non-executable, failing, empty, malformed, noisy, prerelease, and mismatched versions; `24/24`. | Return `claudux 2.0.8` from a `2.0.7` install. **Killed** — installation fails. |
| Default generation refuses unrelated source mutations without laundering them into the result. | `lib/docs-generation.sh` snapshots unrelated dirty paths and `HEAD`, detects new worktree/index/commit mutations, removes backend commits, and restores the pre-run source state while leaving the docs diff reviewable. | `tests/test-generation-boundary-rollback.sh` covers new, pre-dirty, untracked, renamed, deleted, and committed source mutations; `17/17`; the real-target fault run also restores `src/`. | Have the backend edit and commit source while also writing docs. **Killed** — the run fails, `HEAD` and source bytes are restored, docs remain reviewable. |

## Claims narrowed to match reality

| Former overclaim | Current public contract |
| --- | --- |
| “The model is on rails” in every mode. | Manifest mode puts the backend on section rails: it is read-only and Claudux applies validated patch JSON. Without a manifest, the backend may write anywhere under `docs/`; unrelated Git paths and commits are rollback-protected, but documentation is review-bounded rather than section-bounded. |
| “`serve` and `check` never call a backend.” | `serve` is preview-only and never invokes a model. `check` never generates docs, but it does run the selected backend's authentication diagnostic. |
| “No network calls except to the AI backend CLI.” | Generation delegates model transport to the selected backend CLI. Preview setup may contact the configured public npm registry to install VitePress dependencies. |
| “Two-phase generation” is a machine-enforced plan-then-write protocol. | The docs describe prompt construction plus backend execution in default mode and a machine-enforced section-patch transaction in manifest mode. Project JSON files are prompt profiles, not a render engine. |
| “Failed generations leave no partial artifacts.” | Manifest patch batches are transactional. Default mode restores unrelated Git paths and backend commits but deliberately leaves documentation output for human review. |
| “Smart Cleanup” is an always-on scored deletion engine. | The automatic hook is a no-op. Interactive cleanup is model-assisted, conservative, and blocked from deleting manifest-owned pages unless explicitly enabled. |
| The root package is the supported npm release surface. | The supported installer clones GitHub. Root and generated docs manifests declare `"private": true`; the public registry still contains legacy `claudux@1.1.1`, and no publication or deprecation was attempted here. |

## Integrated acceptance

1. Behavioral regressions cover every blocked row.
2. The fixes live at the canonical lock, manifest, parser, validator,
   installer, preview, and rollback boundaries.
3. Focused suites are green.
4. Planted hostile fixtures still produce the required refusals.
5. Two concurrent full verification runs, a docs build, a zero-vulnerability
   audit, and the real-target lifecycle are green.

The remaining authenticated Codex lifecycle is a declared coverage gap, not a
contradiction in any promoted claim.
