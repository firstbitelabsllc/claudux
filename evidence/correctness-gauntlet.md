# Claudux Correctness Gauntlet

Proof date: 2026-08-27  
Source baseline: `bfde817e98e4df2837873d887165fa926e812636`  
Real-target runtime candidate: `cd046201a47d1d57e4973c7148eaf250da67c5d6`

## Verdict

The integrated candidate clears the `~c201` Groundtruth gate. The current
working tree passed two overlapping full verification runs, each completed the
entire source suite, secret scan, and public-ready metadata scan, and neither
run emitted a failure or broken-pipe marker.

The negative controls below plant hostile states rather than echoing expected
values. A passing assertion means Claudux produced the required refusal or
rollback.

## Baseline defects found

| Boundary | Pre-fix consequence | Canonical repair |
| --- | --- | --- |
| Manifest page confinement | A manifest page symlink could redirect reads or writes outside `docs/`. | Resolve every page against the real repository and real `docs/` roots, reject symlink traversal, and require a regular file. |
| Multi-file patch transaction | A later write failure could leave an earlier page changed. | Stage the full batch, verify concurrent state, and restore earlier targets if any commit step fails. |
| Protected marker grammar | Unmatched, nested, or orphan end markers could disappear from the guard snapshot. | Parse marker structure before writing the static index or guard snapshot and fail closed on malformed pairs. |
| Project lock and EXIT cleanup | A second updater could overwrite a live lock; installing lock cleanup could discard existing background-job cleanup. | Use atomic directory locks, preserve ownership, recover only stale locks, then compose job cleanup, runtime cleanup, and lock release. |
| Git porcelain | Quoted, newline, tab, and literal ` -> ` paths could split into fake records. | Consume NUL-delimited porcelain and escape only at presentation boundaries. |
| Codex JSONL | Key order, nested `type` fields, and escaped strings could change event meaning or truncate output. | Parse each event structurally with Node instead of regular expressions. |
| Reader-visible links | Missing Markdown pages, assets, and anchors could pass while VitePress config routes were valid. | Validate config routes plus Markdown destinations, assets, anchors, traversal, and symlink confinement. |
| Environment readiness | Node 16 and an installed-but-logged-out backend could return a green `check`. | Enforce Node 18+ and run the selected backend's non-generating authentication probe. |
| Installer verification | A broken or version-mismatched installed binary could still yield installer success. | Require an exact successful `claudux <version>` response. |
| Default generation boundary | A backend source edit or commit was detected after mutation but left behind. | Snapshot unrelated Git paths and `HEAD`, reject the run, remove backend commits, and restore the exact pre-run source state. |
| Shell harness isolation | Parallel suites could overwrite fixed `/tmp/claudux-*` files, and a fixture child could receive `TERM` before installing its trap. | Give every suite a private `mktemp -d` root and make the cleanup fixture acknowledge readiness after its `TERM` trap is installed. |

## Required adversarial controls

| Planted fault | Executable falsifier | Current result |
| --- | --- | --- |
| Manifest-boundary escape | `tests/test-docs-manifest.sh` replaces a manifest page with a symlink outside `docs/`, then asks the index, guard, and patcher to use it. | All three paths reject the page; the external target remains byte-identical. |
| Protected-block mutation | `tests/test-docs-manifest.sh` captures a guard snapshot, rewrites a protected Markdown/source block, and validates the snapshot. | Validation reports the changed protected block and refuses the mutation. |
| Invalid backend response | `tests/test-docs-manifest.sh` supplies conflicting raw section-patch payload blocks. | Extraction fails with “expected exactly one unique section patch payload”; no patch is applied. |
| Broken internal link | `tests/test-link-validation.sh` plants a missing page, missing asset, and missing cross-page anchor. | Validation exits `1`, reports all three broken targets, and writes the same three targets to its machine-readable report. |

Additional mutation-killing controls cover a second patch commit failure,
malformed protection markers, live-lock contention, logged-out Claude and Codex
backends, broken installer binaries, weird Git filenames, source commits made
by a backend, and path traversal through Markdown links.

## Restored GREEN stack

| Surface | Command | Result |
| --- | --- | --- |
| Focused lock and readiness suite | `bash tests/test-cli-safety.sh` | `32/32` passed after the fixture readiness handshake |
| Manifest and transaction suite | `bash tests/test-docs-manifest.sh` | `107/107` passed |
| Protected-content suite | `bash tests/test-content-protection.sh` | `12/12` passed |
| Codex structural JSONL suite | `bash tests/test-codex-jsonl.sh` | `17/17` passed |
| Link validator suite | `bash tests/test-link-validation.sh` | `18/18` passed |
| Installer verification suite | `bash tests/test-installer-verification.sh` | `24/24` passed |
| Generation rollback suite | `bash tests/test-generation-boundary-rollback.sh` | `17/17` passed |
| Preview-only and favicon suite | `bash tests/test-server-preview-only.sh` | `14/14` passed |
| Full verification, overlap A | `npm run verify` | Exit `0`; 16 suite summaries totaling 439 checks, then secret scan and public-ready gate passed |
| Full verification, overlap B | `npm run verify` | Exit `0`; same 439 checks and gates passed concurrently |
| Overlap noise scan | Search both full logs for `FAIL`, `Broken pipe`, and `write error` | Zero matches |
| Documentation build | `npm --prefix docs run docs:build` | VitePress `1.6.4` built client/server bundles and rendered all pages |
| Documentation dependency audit | `npm --prefix docs audit --json` | Zero vulnerabilities at every severity |
| Disposable real-target lifecycle | Real installer, authenticated Claude generation, manifest update, rollback fault, build, links, audit, and browser | Passed; exact runtime receipt is in `evidence/real-target-lifecycle.md` |

## Remaining coverage gaps

- The disposable lifecycle exercised the authenticated Claude path, not an
  authenticated Codex target run.
- The integrated source patch is still uncommitted and unpushed; local source
  proof is not merge, release, install, or publication proof.
- No public package, release tag, Pages deployment, or reviewer message was
  created by this gauntlet.

## Groundtruth checkpoint

`GROUNDTRUTH_COMPLETE` is earned for `~c201`: the current candidate has
hostile negative controls, restored focused greens, two concurrent full green
runs, a fresh docs build, a zero-vulnerability audit, and one real target-repo
lifecycle. The untested authenticated Codex lifecycle remains explicit rather
than being laundered into this claim.
