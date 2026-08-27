# Claudux Real-Target Lifecycle

Proof date: 2026-08-27  
Candidate commit: `cd046201a47d1d57e4973c7148eaf250da67c5d6`  
Target repository HEAD: `57085288bb3d17c769f58565ed4f8f02cd5dc8ba`  
Backend exercised: authenticated Claude CLI, Sonnet tier  
Backend not exercised: Codex CLI

## Verdict

The candidate installs through the real installer, generates a working
VitePress site in a fresh JavaScript repository, constrains a source-scoped
incremental update to the manifest-owned API section, rolls back an unrelated
source mutation, and serves the final site with zero browser console errors.

## Fixture boundary

The lifecycle used one disposable root with four isolated children:

- `candidate/` — clean local clone containing the integrated candidate commit
- `target/` — fresh Git repository for a small exact-cent arithmetic package
- `home/` — isolated Claudux install and backend state
- `browser-proof/` — terminal Playwright logs and page capture

The installer was not modified. A test-only `git` shim replaced only the
public GitHub clone URL with the local `candidate/` clone so the unpushed
candidate commit could travel through the production install path.

```sh
HOME="$FIXTURE/home" \
PATH="$FIXTURE/bin:$PATH" \
NPM_CONFIG_USERCONFIG=/dev/null \
CLAUDUX_REF=hardening/public-trust \
sh "$FIXTURE/candidate/install.sh"
```

Result:

```text
candidate = cd046201a47d1d57e4973c7148eaf250da67c5d6
installed = cd046201a47d1d57e4973c7148eaf250da67c5d6
version   = claudux 2.0.7
```

## Ordered lifecycle

| Step | Command or action | Receipt |
| --- | --- | --- |
| 1 | Initialize a private ESM package with `addCents` and `formatUsd`. | Target commit `0c54fab`; the two original tests passed. |
| 2 | Run `claudux check` with the isolated authenticated backend. | Exit `0`; Node, Claude CLI, authentication, docs state, backend `claude`, and model `sonnet` passed. |
| 3 | Run `claudux update` before a manifest exists. | Claude generated `docs/index.md`, `docs/guide/index.md`, `docs/api/index.md`, and `docs/.vitepress/config.ts`; link validation reported five valid links and zero broken links. |
| 4 | Commit the generated site plus a deterministic `docs-structure.json`. | Target commit `72a767b`; manifest validation reported three pages, one source-owned page, and one pinned section. |
| 5 | Add a failing `allocateCents` test before its source exists. | `npm test` was red: two tests passed and the allocation test failed because `src/allocate.js` did not exist. |
| 6 | Implement and commit `allocateCents`. | Target commit `44a55a6`; all five target tests passed. |
| 7 | Run `claudux update -m "Document the new allocateCents API from its source and tests."`. | The backend was read-only during generation; Claudux applied one validated section patch to `docs/api/index.md`. |
| 8 | Commit the bounded documentation update. | Target commit `5708528`; only `docs/api/index.md` changed. |
| 9 | Replace the backend with a deterministic fixture that appends to `src/ledger.js`, then run `claudux update`. | Exit `1`; Claudux reported a source-boundary violation, restored the source tree, and kept the docs reviewable. |
| 10 | Reinstall candidate `cd04620`, remove only generated preview support files, then run `claudux serve`. | Setup regenerated the theme/config support, wrote a valid fallback favicon, installed 131 public npm packages, and started VitePress `1.6.4`. |
| 11 | Run target tests, docs build, link validation, dependency audit, and browser proof. | All checks below passed. |

## Manifest-bounded incremental proof

The target manifest pins `docs/guide/index.md#quick-start` and makes the API
page source-owned. Before the focused update:

```text
docs/api/index.md   8a3747210fb94ff19aa3af10527a84cede5a8ca4941dab54bfcc65cc104e7915
docs/guide/index.md 392930f4325fec28c7b3469a424271648b2984f77e95319f2efaba474fb557d5
```

After the update:

```text
docs/api/index.md   df786a60bff64e9dc9c02a4e5541b2edbe6c4ed63a328ab080b298c11b33dde2
docs/guide/index.md 392930f4325fec28c7b3469a424271648b2984f77e95319f2efaba474fb557d5
```

The API hash changed and the pinned guide hash stayed byte-identical. The
accepted diff added only the `allocateCents(total, parts)` API contract,
examples, errors, and negative-remainder behavior.

## Unrelated-mutation refusal

The fault backend performed one deterministic mutation:

```text
append "// deterministic unrelated mutation" to src/ledger.js
return an empty manifest patch payload
```

Claudux then:

1. detected a change outside `docs/` and manifest paths;
2. exited nonzero;
3. reported that unrelated source changes were rolled back;
4. restored `src/` exactly to target HEAD;
5. left the accepted documentation commits unchanged.

`git diff --exit-code HEAD -- src` passed after the refusal.

## Final scaffold and browser proof

| Surface | Result |
| --- | --- |
| Target application tests | `5/5` passed |
| VitePress build | Passed; client/server bundle and four pages rendered |
| Internal links | Five valid, zero broken |
| Generated docs package | `"private": true` |
| Resolved Vite | `6.4.3` |
| Dependency audit | Zero vulnerabilities |
| Fallback favicon | Valid 621-byte ICO; header `000001000100` |
| Served page | Title `ledger-math`; expected hero, guide link, API link, and three feature cards rendered |
| Favicon request | `200`, `image/x-icon`, 621 bytes |
| Browser console | Zero errors, zero warnings |

The viewport capture is retained as
`browser-proof/home-final.png` inside the disposable fixture. It is
`1280x720` and shows the generated home page rather than a VitePress error or
blank shell.

## Explicit gap

This lifecycle proves the Claude path only. Codex has structural unit and
integration coverage in the source suite, but a second authenticated real
target lifecycle remains untested and must not be implied by this receipt.
