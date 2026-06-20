# Claudux Eve Receiver Evidence - 2026-06-20

## Scope

- Repo: `git@github.com:leojkwan/claudux.git`
- Base: `origin/main@3f5fcec`
- Worktree: `/Users/leokwan/Development/claudux-worktrees/eve-studio-20260620`
- Branch: `codex/eve-studio-claudux-20260620`
- Primary checkout preserved: `/Users/leokwan/Development/claudux`

## Installed

- Dev dependencies: `eve@0.11.5`, `ai@7.0.0-beta.178`
- Eve scripts: `eve:info`, `eve:build`, `eve:dev:local`, `eve:capabilities`
- Agent files under `agent/`
- Capability check: `tools/eve-capability-check.mjs` (kept out of the npm
  package payload; `release:check` tarball dry-run lists only `scripts/secret-scan.sh`
  from `scripts/`)
- Generated artifacts ignored: `.eve/`, `.output/`

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
```

## Non-Claims

- `origin/main` is not Eve-powered until this branch is merged or replayed and
  re-proved.
- The primary checkout was not mutated.
- No generated docs edit, env file, credential, deploy, npm publish, release
  action, paid/model/API call, remote-machine mutation, patch promote, or
  external human message happened.
