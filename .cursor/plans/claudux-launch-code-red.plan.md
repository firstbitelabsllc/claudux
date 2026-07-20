# claudux — CODE RED: launch the drift-gate re-center

**Status:** ACTIVE · **Authority:** this file is the sole mission authority · **Repo:** `firstbitelabsllc/claudux` (canonical public) · **Trunk:** `origin/main`

## Mission (one line)

Drive claudux from "re-centered + drift gate landed on `origin/main` (#85, `2d1f872`)" to "the drift gate is dogfooded in claudux's OWN CI, proven on a second real repo, and 1.2.0 is published" — ranking real launch-credibility risk first, landing by the repo's normal branch/PR rule, never spinning on a human gate.

## What is already TRUE on origin/main (grounded 2026-07-19, ref `origin/main` = `2d1f872`)

- `lib/drift.sh` — deterministic comparator, wired: `REQUIRED_LIBS` includes `drift.sh`; `"drift")` case in `bin/claudux:375` calls `claudux_drift`.
- `docs-drift-lock.json` — committed baseline (`baseline=269cafb`), un-ignored.
- `tests/test-drift.sh` — drift test suite (auto-discovered by `tests/run-all.sh`).
- `.github/workflows/docs-drift.yml` — copy-paste CI job.
- README re-centered: hook "Your build fails the moment a doc starts lying." + drift-verdict banner + terminal-demo SVG + comparison table with staleness row + honest install (source 1.2.0 vs npm 1.1.1).
- GitHub repo "About" description + topics re-centered to the drift positioning (fixed 2026-07-19).
- **Proven live this session** (detached worktree off `origin/main`): `claudux drift` clean → exit 0; surface change to a documented `lib/*.sh` with doc untouched → exit 1, names 6 doc pages + the changed source + the exact fix; restore → exit 0; `--json` emits `{command,sensitivity,baseline,head_sha,ready,drifted[],new_sources[]}`.

## Setup Contract (readiness before deep work)

- **No credentials needed for the core mission** — the gate is keyless, offline, deterministic. This is the entire pitch; never add a network/API dependency to the pass/fail path.
- `npm publish` needs `npm login` (Leo's token) — LEO-GATED, see below.
- Second-repo dogfood needs a target repo already on this machine (e.g. `resplit-ios/.claudux-tool`, `resplit-web`, `strongyes-web`) — no new access required.
- Browser proof uses headless Playwright CLI (`PLAYWRIGHT_BROWSERS_PATH=~/Library/Caches/ms-playwright`) — already available; claude-in-chrome extension is NOT connected, so do not wait on it.

## P0-first inference (rank by launch-credibility blast radius, not easy-close)

The largest reachable risk to this launch is **"is it actually a real lint or just an AI wrapper?"** Everything that hardens that answer ranks above polish.

### Rows (agent-completable)

| # | Row | Priority | validation |
|---|-----|----------|------------|
| R1 | **Dogfood the gate in claudux's own CI.** `docs-drift.yml` currently ships as an *example*; make the repo actually run `claudux drift` on its own PRs (or confirm it already gates and record the run URL). The credibility money-shot: claudux's own red X on a drifting PR. | P0 | CI run URL showing `claudux drift` executing on a PR; a deliberate drift PR going red, then green after `--accept`/doc-fix. |
| R2 | **Re-baseline the lock to include `lib/drift.sh`.** Current baseline `269cafb` predates `drift.sh`, so every clean run prints a "new source (no baseline)" note for it. Run `claudux drift --accept`, commit the updated `docs-drift-lock.json`, confirm the note clears. | P0 | `claudux drift` exits 0 with an EMPTY `new_sources[]`; committed lock diff is timestamp-free and reviewable. |
| R3 | **Prove the gate on a second REAL repo** (not a fixture). Pick one owned repo on-disk, run `claudux drift --accept` to seed a lock, make a real code+no-doc change, confirm exit 1 names the right doc, restore. Record the transcript. | P0 | exit-code transcript from a non-claudux repo naming the correct doc/source pair. |
| R4 | **Full green gate on `origin/main` HEAD**: `shellcheck`, `tests/run-all.sh`, `tests/test-drift.sh`, `claudux audit --release` (if present), `npm pack --dry-run`. Fix any red. | P0 | pasted pass output of each; any fix lands via branch/PR. |
| R5 | **Wire `--warn-only` pre-commit example + README "Add to CI" polish** only after R1–R4 are green. Verify every doc snippet (CI YAML, pre-commit one-liner) actually runs as written. | P2 | copy-run each snippet; no drift between doc and behavior. |
| R6 | **Browser-render proof**: headless-capture the live GitHub README body and confirm the drift-verdict banner, terminal-demo SVG, and comparison table render (light+dark). | P2 | screenshots read back; note any SVG that fails to render on GitHub's `<img>` sanitizer. |

**P0 inference line (emit every cycle before editing):**
`P0 inference: candidates=[...] selected=<row> because=<largest reachable credibility break> deferred=<why the rest wait>`

Ladder discipline: a green row stopped at `branch_pushed`/`pr_open`/`merged` moves UP the ladder before any new P2 work.

## LEO-GATED handoffs (NOT agent-completable — park as handoffs, never a whole-goal stop)

- **`npm publish` 1.2.0** — needs `npm login` (Leo's token). npm README freezes per version; the re-centered README is already on `main`, so publish is unblocked the moment Leo runs login. Agent prepares `npm pack --dry-run` + a one-command publish recipe; Leo runs it.
- **External posting** (blog / LinkedIn / X) about the re-center — Leo's voice, Leo's call.
- **Restoring the retracted leojkwan.com post / reopening claudux #82** — stay as-is unless Leo says otherwise.

When a cycle finds only LEO-GATED work reachable, it parks with a resume predicate and re-runs P0 inference with those gates excluded — it does NOT mark the mission blocked or complete.

## Progress

- 2026-07-19 — Mission opened. Grounded origin/main (`2d1f872`); proved gate end-to-end (clean→0, drift→1, restore→0, `--json` clean); fixed stale repo description + added drift topics. Collision preflight: 3 legacy claudux automations all stale/complete on old `leojkwan/claudux` remote — no live executor, no collision. PLAN landed via branch/PR (#86).
- 2026-07-19 — **Cycle 1: R2 ✅ + R4 ✅** (PR #87, merged → `49d4812`). Green gate on origin/main HEAD: shellcheck 0, `tests/run-all.sh` **314/314** (fixed 2 stale header tests — `head -2`→`head -4` after the #85 re-center made the header 3 lines), `npm pack --dry-run` = `claudux-1.2.0.tgz` (54 files). R2: `docs-drift-lock.json` re-baselined to include `lib/drift.sh`; `drift --json` now `ready=true, drifted=0, new_sources=0`. **Bonus fix (gate correctness):** `bin/claudux` routed the `📍 Changing to project root` notice to **stderr** — it was corrupting `--json` stdout, breaking every CI JSON consumer. Worktree landed + torn down; both branches pruned. Next P0: R1 (dogfood in own CI) or R3 (second real repo).
- 2026-07-19 — **Cycle 2: R3 ✅ + real bug fixed** (PR #89, merged → `88fc2a2`). Proved the gate on **resplit-web** (a real `significant`-mode repo, throwaway worktree, real repo left unpolluted — no lock committed): no-baseline→exit 0; `--accept` seed→exit 0; real `.env.example` token change with doc untouched→**exit 1** naming `docs/reference/configuration.md ← .env.example`; RED report prints the exact `--accept` fix hint. **This surfaced a real correctness bug the self-dogfood (surface mode) could never hit:** the `dir/**` glob matcher stripped `/**` (3 chars, incl. the slash), so `docs/**` matched the root file `docs-drift-lock.json` → the gate never converged on `--accept`. Fixed `slice(0,-3)`→`slice(0,-2)` in **both** matcher copies (`drift.sh`, `docs-manifest.sh`) per the determinism contract; added `test-drift.sh` Test 11 (verified it fails on old code, passes on fix). Full gate: shellcheck 0, **318/318**, npm pack OK. Worktrees torn down, branch pruned.
  - **R1 PARKED** (not blocked): the `docs-drift.yml` workflow already gates the repo (`bash bin/claudux drift` on every PR + push to main — confirmed in the tree), so the *plumbing* half of R1 is TRUE. The remaining half (capture a CI run URL + push a deliberate-drift PR red→green) is blocked on a **GitHub Actions API outage** (`gh run list` → HTTP 503, persistent across backoff). Wake condition: `gh run list --workflow=docs-drift.yml` returns non-503. Resume: capture the run URL from a recent PR (#87/#89 both triggered it) + push a deliberate-drift PR to watch it go red then green. Next reachable P0 while parked: R5/R6 (P2) or hold.
    - **⚠️ Correction (cycle 3): the cycle-2 diagnosis above was WRONG.** The 503 was scoped to ONE endpoint (`gh run list --workflow`); `gh pr checks`, `gh api .../check-runs`, and `gh api .../actions/runs` all worked the whole time. The real root cause: every `docs-drift.yml` run was stuck `queued` forever because the workflow targeted `blacksmith-2vcpu-ubuntu-2404` — a third-party runner **not servicing this repo**. So the gate had *never actually executed* in claudux's own CI. Not an outage; a runner misconfig. (Tool-reach discipline: a "blocked" claim must name the tool tried + why it failed — the endpoint 503 was mistaken for a platform outage.)
- 2026-07-20 — **Cycle 3: R1 ✅ COMPLETE** (own-CI dogfood proven end-to-end). Root-caused the parked R1 (see correction above) and fixed it: switched ONLY `docs-drift.yml` to `runs-on: ubuntu-latest` (the vanilla GitHub-hosted runner the copy-paste example promises — zero special infra is the whole credibility claim), PR **#91 merged → `840d318`**. Proof, all on the real surface (claudux's own Actions):
  - Gate now **executes** on ubuntu-latest — [run 29710603396](https://github.com/firstbitelabsllc/claudux/actions/runs/29710603396/job/88253813478), ✅ green, 12s (previously: never ran, stuck `queued` on Blacksmith).
  - **Red:** deliberate-drift demo PR #92 added `is_protected_secret` to `lib/content-protection.sh`, touched no doc → gate **FAILED**, [run 29710720980](https://github.com/firstbitelabsllc/claudux/actions/runs/29710720980/job/88254066087), 18s (named `lib/content-protection.sh` across 10 doc units, printed the exact `--accept` fix).
  - **Green:** `claudux drift --accept` re-baselined the lock → same gate **PASSED**, [run 29710745539](https://github.com/firstbitelabsllc/claudux/actions/runs/29710745539/job/88254128111). Red→green closed on one PR. #92 closed without merge (demo, not a feature); worktree + branch torn down.
  - **Mission terminal-condition status:** own-CI dogfood (R1) ✅ **AND** second real repo (R3, resplit-web) ✅ **AND** full green gate (R4, 318/318) ✅ — the credibility spine is closed. The launch question ("real deterministic lint or AI wrapper?") is answered on the real surface: keyless, offline, ~15s, LLM never on the pass/fail path, and claudux's own red X is on the record. Remaining rows are P2 polish (R5 pre-commit/README "Add to CI", R6 headless-render proof) + LEO-gated publish 1.2.0.

## Fleet coordination

Single owner per cycle. Fresh-read this PLAN + live claims + `origin/main` before write ownership; claim one unowned row; park conflicts as `waiting_on_owner` and rerank. Checkpoint only on material claim-state change. This is the ONLY executor for this mission; the `cost-100x` provider-control goal is a SEPARATE mission with its own PLAN — do not merge or collide.
