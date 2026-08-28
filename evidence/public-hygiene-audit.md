# Claudux Public Hygiene Audit

Audit date: 2026-08-27  
Source baseline: `bfde817e98e4df2837873d887165fa926e812636`

## Finding

The integrated candidate contains no unresolved high-severity private-data,
private-registry, generated-cache, or accidental package-surface leak. Literal
private-pattern strings remain only inside the guard implementation and its
synthetic tests. Historical model-named remote branches and co-author trailers
remain public provenance; removing them would require destructive remote or
history operations and is not claimed by this audit.

## Exact scans

### Current tree

```bash
python3 -B scripts/claudux-public-ready-grep-gate.py
```

Result: passed.

The gate excludes only its own pattern definitions and the hermetic fixture
that proves those definitions reject private-company and machine-path inputs.

No product documentation, workflow, package metadata, evidence finding, or
runtime source contains a live private host, email address, credential,
registry, or machine path.

### Candidate commit metadata

```bash
python3 -B scripts/claudux-public-ready-grep-gate.py \
  --metadata \
  --range=origin/main..HEAD
```

Result: passed after the candidate commit identity was normalized to the
maintainer's established public email.

### Reachable Git history

```bash
python3 -B scripts/claudux-public-ready-grep-gate.py \
  --metadata \
  --range=--all
```

Result: expected nonzero for the known synthetic `test@test.com` identity,
which appears as author and committer on
`93d5e6437be5b388f2199b080583db97b3ac4b89` and as a co-author trailer in
older public test-era commits. The scan reports no private-company author,
committer, or co-author email. Rewriting published history to remove the
synthetic identity remains out of scope.

### Generated and cache artifacts

```bash
git ls-files |
  rg '(^|/)(__pycache__/|.*\.py[co]$|\.DS_Store$|.*\.log$)'
```

Result: zero tracked matches.

The previously tracked
`scripts/__pycache__/claudux-public-ready-grep-gate.cpython-312.pyc` is deleted,
and `.gitignore` now excludes `__pycache__/` plus `*.py[cod]`.

### Registries and package metadata

```bash
rg -n -i --hidden --glob '!.git/**' '(registry\s*=|npmrc|artifactory|jfrog|verdaccio)' .
npm view claudux name version deprecated dist-tags versions time --json \
  --registry=https://registry.npmjs.org/
```

Result:

- `docs/.npmrc` pins `https://registry.npmjs.org/`; no private registry is
  referenced.
- The public registry still serves legacy `claudux@1.1.1` as `latest` and does
  not report a deprecation.
- Root and docs manifests declare `"private": true`; the supported install path
  remains the GitHub installer.
- No publish or deprecation command was executed. A dry-run can still assemble
  a tarball, so this audit does not misstate package metadata as publication
  proof.

### Verification surfaces

| Surface | Result |
| --- | --- |
| `npm run verify`, overlap A | Exit `0`; all suites, secret scan, and public-ready gate passed |
| `npm run verify`, overlap B | Exit `0`; same result while A was active |
| `npm --prefix docs run docs:build` | VitePress `1.6.4` build passed |
| `npm --prefix docs audit --json` | Zero vulnerabilities |
| `python3 scripts/claudux-public-ready-grep-gate.py --metadata` | Passed in both full verification runs without creating bytecode |

## Historical public provenance

### Remote branch names

After `git fetch --prune origin`, with `origin/main` at
`bfde817e98e4df2837873d887165fa926e812636`, five model/automation-named public
branches remain:

| Remote branch | Tip | Merged by ancestry | Unique commits vs `origin/main` | Patch-equivalent commits |
| --- | --- | --- | ---: | ---: |
| `automation/gpt56-pro-review` | `d02b06921e41` | no | 1 | 0 |
| `claude/docs-are-hand-maintained-20260725` | `960c1ea90f86` | no | 1 | 0 |
| `claude/model-tiers-fable-20260815` | `e9fe3091193c` | no | 4 | 0 |
| `claude/scaffold-esm-base-20260815` | `6db48d2002d1` | no | 2 | 0 |
| `codex/claudux-2.0.7-security-release` | `93d5e6437be5` | no | 1 | 1 |

`git merge-base --is-ancestor` rejects all five tips as ancestors of
`origin/main`. `git rev-list --count` finds nine unique commits across the
branches, and `git cherry` classifies eight as non-equivalent (`+`) and only
the security-release commit as patch-equivalent (`-`).

These names violate the strict neutral-branch acceptance wording, even though
they do not expose private company data. Deleting the refs now would destroy
the only public branch pointers to eight non-equivalent commits. The exact
wake is: preserve or reconcile those eight commits, then obtain Leo's explicit
approval to delete the five named remote refs.

### Commit attribution

Reachable history contains 37 `Co-authored-by:` trailers across 30 commits,
including public tool and synthetic test identities. New work adds no
attribution trailer. Rewriting published history would invalidate existing
tags and clones, so no history rewrite was attempted.

## Disposition

| Finding | Severity | Disposition |
| --- | --- | --- |
| Current private company, credential, registry, or machine-path residue | none found outside guard fixtures | Pass |
| Guard definitions and synthetic rejection fixtures | intentional | Keep; they prove the public-ready gate detects the forbidden classes |
| Tracked Python bytecode | high | Deleted; ignore rules added |
| Docs registry inheritance | high | Public npm registry pinned |
| Docs dependency vulnerabilities | none | Zero reported |
| Candidate package intent | medium | Root and docs manifests are private; no publication claim |
| Legacy public npm package | medium | Documented accurately; deprecation is a separate public mutation |
| Model/automation remote branches | medium | Blocked: eight non-equivalent commits must be preserved or reconciled, then deletion of the five named refs requires explicit approval |
| Historical co-author trailers | medium | No new trailers; no published-history rewrite |

There are zero unresolved high-severity public-hygiene findings in the
candidate. The five remote branch names and historical trailers remain explicit
medium-severity provenance rather than being hidden or described as fixed. The
strict no-model-authorship-branch checkpoint therefore remains blocked.
