# Claudux Eve Receiver Evidence - 2026-06-20

## Scope

- Repo: `git@github.com:firstbitelabsllc/claudux.git` (GitHub redirects from the old `leojkwan/claudux` remote)
- Base: `origin/main@3f5fcec`
- Worktree: `/Users/leokwan/Development/claudux-worktrees/eve-studio-20260620`
- Branch: `codex/eve-studio-claudux-20260620`
- Receiver setup/readiness commits include: `a7e98c1 chore: add Eve local
  cockpit`, `ed0ce79 docs: record Claudux Eve receiver PR`, `697a284 docs:
  record Claudux Eve readiness proof`
- PR: `https://github.com/firstbitelabsllc/claudux/pull/82`
- PR state after readiness proof: `OPEN`, non-draft, `MERGEABLE/CLEAN`, base
  `main`
- Primary checkout preserved: `/Users/leokwan/Development/claudux`

## Installed

- Dev dependencies: `eve@0.11.5`, `ai@7.0.0-beta.178`
- Eve scripts: `eve:info`, `eve:build`, `eve:dev:local`, `eve:capabilities`
- Agent files under `agent/`
- Capability check: `tools/eve-capability-check.mjs` (kept out of the npm
  package payload; `release:check` tarball dry-run lists only `scripts/secret-scan.sh`
  from `scripts/`)
- Generated artifacts ignored: `.eve/`, `.output/`
- Moussey verifier handoff:
  `abe9e254-9d53-4f1e-82eb-aa531d899f13`

## True-Integration Readiness Update

- Current target branch check: `origin/main@3f5fcec` is already an ancestor of
  the receiver branch, so no replay merge was required.
- The hosted `Release readiness` check failed before this update because its
  Node 18/npm 10 lockfile-normalization step removed six Linux `@rolldown`
  optional-package `libc` arrays from `package-lock.json`. The lockfile now
  matches that CI-normalized form.
- PR #82 was marked ready after the lockfile normalization; hosted checks passed.
  The exact current PR head and post-refresh check readback are recorded in the
  command-center receipt because this evidence file itself can move the head.
- `tools/eve-capability-check.mjs` now verifies package.json, package-lock, and
  installed `node_modules` versions for `eve`, `ai`, and transitive `zod`, plus
  `node_modules/.bin/eve`. It also asserts the repo package-gate scripts
  `lint` and `release:check`.

## Proof

Local proof:

```sh
npm install -D --save-exact eve@0.11.5 ai@7.0.0-beta.178 --fetch-timeout=120000 --fetch-retries=5
=> completed; npm audit found 0 vulnerabilities

npm ci --dry-run
=> exit 0

node --check tools/eve-capability-check.mjs
=> pass

npm run eve:capabilities -- --json
=> ok:true, verdict claudux_eve_installed_local_only, errors:[], warnings:[]

npm run eve:info -- --json
=> eve v0.11.5, status:ready, diagnostics 0 errors / 0 warnings

npm run eve:build
=> pass; built .output successfully

git diff --check
=> pass

npm run test
=> 104/104 passed

npm run test:all
=> all suites passed: backend router 50/50, content protection 12/12, diff calculation 18/18, docs manifest 98/98, hardening 59/59, integration 31/31, state file 26/26

npm run lint
=> pass via shellcheck

npm run secret-scan
=> pass

npm run release:check
=> pass; release audit valid, lockfile clean, package packable, npm pack dry-run listed 54 package files and did not include tools/eve-capability-check.mjs

gh pr view 82 --repo firstbitelabsllc/claudux --json number,state,isDraft,mergeable,mergeStateStatus,headRefName,baseRefName,url,headRefOid
=> initial receiver readback was OPEN/draft; final readiness readback below supersedes this state
```

Readiness reproof:

```sh
npm install --package-lock=false --fetch-timeout=120000 --fetch-retries=5
=> exit 0; 0 vulnerabilities

npm install --package-lock-only --ignore-scripts --no-audit --no-fund
=> exit 0; no additional lockfile changes after Linux libc normalization

npm ci --dry-run
=> exit 0

npm ci --no-audit --fetch-timeout=120000 --fetch-retries=5
=> exit 0

npm ls eve ai zod --depth=0
=> top-level eve@0.11.5 and ai@7.0.0-beta.178 present; zod is transitive and verified by the capability checker

node --check tools/eve-capability-check.mjs
=> pass

git diff --check
=> pass

npm run eve:capabilities -- --json
=> ok:true, installed dependency versions reported, errors:[], warnings:[]

npm run eve:info -- --json
=> eve v0.11.5, status:ready, diagnostics 0 errors / 0 warnings

npm run eve:build
=> pass; built .output successfully

npm run test
=> 104/104 passed

npm run test:all
=> all suites passed: backend router 50/50, content protection 12/12, diff calculation 18/18, docs manifest 98/98, hardening 59/59, integration 31/31, state file 26/26

npm run lint
=> pass via shellcheck

npm run secret-scan
=> pass

npm run release:check
=> pass; release audit valid, lockfile clean, package packable, npm pack dry-run listed 54 package files and did not include tools/eve-capability-check.mjs

POST /api/coding/handoffs + GET /api/coding/handoffs/abe9e254-9d53-4f1e-82eb-aa531d899f13
=> ok:true, label claudux-eve-true-integration, proposedAction codex-verifier

gh pr ready 82 --repo firstbitelabsllc/claudux
=> marked ready for review

gh pr checks 82 --repo firstbitelabsllc/claudux --watch --interval 10
=> pass: Release readiness, ShellCheck lint, Version consistency, Bash syntax check, File structure checks, Test suite, Docs build, CodeQL, Graphite / mergeability_check; Graphite / AI Reviews skipped

gh pr view 82 --repo firstbitelabsllc/claudux --json number,state,isDraft,mergeable,mergeStateStatus,headRefName,baseRefName,url,headRefOid
=> OPEN, non-draft, MERGEABLE/CLEAN, head codex/eve-studio-claudux-20260620, base main
```

## Non-Claims

- `origin/main` is not Eve-powered until this branch is merged or replayed and
  re-proved.
- The primary checkout was not mutated.
- No generated docs edit, env file, credential, deploy, npm publish, release
  action, paid/model/API call, remote-machine mutation, patch promote, or
  external human message happened.
