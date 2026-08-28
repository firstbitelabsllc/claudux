# Claudux Takeoff Audit

Audit date: 2026-08-27
Input challenged: `2e7e6a65180113a552a142c686d8cf0d420e8bee`
Repair ref: `89b857f5bc047691dfbc5ae322f16f0495486e56`
Mode: proof-only release challenge; no pull request, merge, tag, package publish,
Pages deploy, or release action

## Verdict

`PROOF-ONLY` — the challenge found two release-gate blockers, fixed both at
their narrow enforcement boundaries, and left no surviving `~c402` blocker.

The installer, backend source boundary, and manifest transaction already had
mutation-killing gates. The public metadata gate did not reject AI attribution,
and the link gate did not scan the repository README or run against the current
repository inside the release suite. Both false greens are now regressions.

## Pre-declaration

The audit used one isolated worktree pinned to the input commit and one
local-only shake branch, `takeoff/shake-c402-20260827`. Every mutation was
committed before its gate ran, restored by a revert, and the worktree returned
to a detached clean input ref.

| Lane | Positive marker and floor | Shake | Mutation target |
| --- | --- | --- | --- |
| Install | public branch install exits `0`, reports `claudux 2.0.7`, and installed `HEAD` equals the requested branch ref; installer suite `24/24` | installer suite twice | corrupt otherwise-successful `--version` output |
| Backend isolation | generation-boundary suite `17/17` | twice | bypass source-boundary validation |
| Manifest atomicity | manifest suite `107/107` | twice | disable rollback after a later file commit fails |
| Public hygiene | public-ready suite `5/5` before repair; candidate metadata scan exits `0` | twice | add an AI co-author trailer to committed metadata |
| Reader trust | link suite `18/18` before repair; current links, Pages build, and Vale pass | twice | point the README at a missing local file |

The focused counts were stable across both repeats: `24/24`, `17/17`,
`107/107`, `5/5`, and `18/18`.

## Adversarial ledger

| Lane | Planted fault and took-proof | Gate result | Classification | Smallest remedy |
| --- | --- | --- | --- | --- |
| Install | Commit `3a6a480` added a second line to successful `claudux --version` output. A real isolated install cloned that commit through the production installer path. | Installer exited `1`: `--version` must output exactly `claudux 2.0.7`. | `no action` | None. Exact output and exit status are already enforced. |
| Backend isolation | Commit `82994a7` returned success before `validate_generation_workspace_unchanged` inspected or rolled back source edits. | Focused suite exited `1`; `3/17` passed and `14/17` failed, including source restoration, backend commit removal, dirty-file restoration, and refusal reporting. | `no action` | None. The suite kills removal of the source boundary. |
| Manifest atomicity | Commit `11dcb29` inverted the rollback condition after staged page writes. | Focused suite exited `1`; `104/107` passed and three transaction assertions failed: earlier page rollback, later page stability, and staging cleanup. | `no action` | None. The suite kills partial multi-file commit behavior. |
| Public hygiene | Commit `6e82e48` contained `Co-authored-by: ChatGPT <chatgpt@users.noreply.github.com>`. The trailer was visible in `git show`. | **False green:** the metadata gate exited `0`. | `block` — fixed | Detect AI-specific co-author trailers and generation footers in commit bodies while preserving ordinary human co-authors. |
| Reader trust | Commit `c4ab5ca` changed the README Architecture link to `./ARCHITECTURE-missing.md`. | **False green:** both `bash lib/validate-links.sh` and `npm run verify` exited `0`. | `block` — fixed | Parse README links with repository-root confinement and make the link suite validate the current repository, not fixtures alone. |

## Blocker repairs

### Public metadata

`scripts/claudux-public-ready-grep-gate.py` now rejects:

- AI-specific `Co-authored-by:` trailers;
- AI generation footers such as `Generated with Claude Code`.

It still allows a normal human co-author. The regression creates real temporary
Git commits rather than matching source strings:

```text
AI co-author trailer is rejected
AI co-author finding is named
human co-author trailer remains allowed
AI generation footer is rejected
public-ready-gate: 9 passed, 0 failed
```

No published history was rewritten. The repair protects new candidate commits.

### Reader links

`lib/validate-links.sh` now scans `README.md` alongside VitePress Markdown,
resolves README targets inside the repository root, preserves the stricter
`docs/` boundary for documentation pages, and rejects traversal from either
scope.

`tests/test-link-validation.sh` now runs the validator against the current
repository before its isolated fixtures. The repaired suite covers:

- valid README links to root files, docs routes, and assets;
- a missing README page;
- README traversal outside the repository;
- the existing docs page, asset, anchor, symlink, and VitePress route cases.

The same missing Architecture mutation that previously passed now makes
`npm run verify` exit `1` with:

```text
FAIL current repository links pass (exit code)
Some tests failed.
```

The restored focused suite passes `24/24`.

## Restored exact-ref proof

The following checks passed at repair ref `89b857f`:

| Surface | Result |
| --- | --- |
| Full source verification | `npm run verify` exited `0`; 19 suite summaries totaled `562/562`, then the secret scan and HEAD metadata gate passed |
| Shell static analysis | `npm run lint` exited `0` under ShellCheck warning severity |
| Patch hygiene | `git diff --check HEAD^ HEAD` exited `0` |
| Current local links | 53 valid, 7 external skipped, zero broken links, zero duplicate heading IDs |
| Pages build | VitePress `1.6.4` built client/server bundles and rendered every page with `DOCS_BASE=/claudux/` |
| Prose | Vale reported zero errors, warnings, or suggestions across 15 files |
| Dependency audit | zero vulnerabilities at every severity |
| Candidate metadata | `origin/main..89b857f` passed the public-ready metadata scan |
| Public install | installer cloned `hardening/public-trust`, returned `claudux 2.0.7`, and installed exact ref `89b857f` |

## Killed false positives

| Concern | Classification | Receipt |
| --- | --- | --- |
| The five historical model/automation-named remote refs must be deleted for this checkpoint. | `follow-up` | Eight commits remain non-equivalent to `origin/main`; deleting their only refs would be destructive. Preserve or reconcile them first, then obtain explicit deletion approval under the existing cleanup lane. |
| Historical AI or synthetic co-author trailers require a public-history rewrite. | `follow-up` | The candidate adds no such trailer. The new gate protects candidate ranges; rewriting published history would invalidate existing public refs and is not required for this proof-only challenge. |
| The second authenticated backend is implied by structural coverage. | `follow-up` | It is not implied. The authenticated Claude lifecycle remains the only real backend lifecycle; an authenticated Codex target run is still an explicit gap. |
| A private root package means no package-surface check is useful. | `no action` | `npm pack --dry-run --json` still completed successfully, while `package.json` remains `"private": true`; no publication claim or mutation was made. |

## Not exercised

- authenticated Codex generation in a disposable real target;
- the installer tarball fallback without Git;
- GitHub pull-request checks at the final audit commit;
- GitHub Pages channel acceptance or browser readback of a deployed site;
- npm publication, release tags, merge, or public-history rewriting;
- deletion of the protected legacy remote refs.

## Release boundary

The repaired branch is ready for the draft-pull-request checkpoint only.
Opening that pull request remains a separate human-facing action and is not
authorized by this audit.
