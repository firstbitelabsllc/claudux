# Claudux Symlink Boundary Hardening

Proof date: 2026-08-27
Source baseline: `52263313981e4f11ef94db6bc6c1d916f6bf1562`
Candidate: local `hardening/public-trust` working tree

## Verdict

Default-mode generation now refuses writable documentation, state, and
manifest paths that are absolute, traverse a parent directory, or cross a
symlink. The first check runs before Claudux writes its static index or cache;
the snapshot check repeats the same boundary before the model starts.

Both post-model workspace checks also treat a newly introduced documentation
symlink as unsafe, reject the run, and remove that repository path during
rollback. Generated dependency links inside `docs/node_modules/` and generated
VitePress cache, distribution, and temporary trees remain accepted.

## Reproduced defect

On the clean source baseline, replacing the tracked `docs/` directory with a
tracked symlink to an external directory produced this result:

```text
capture_rc=0
retained_guard_rc=0
final_guard_rc=0
git_status=
outside_changed=true
docs_kind=symlink
```

The Git-only boundary saw a clean repository because the write changed the
symlink target rather than the tracked symlink entry.

## Canonical repair

| Boundary | Repair |
| --- | --- |
| Path classification | `claudux_path_is_unsafe_generation_target` rejects absolute paths, parent traversal, and any existing symlink in the path ancestry. |
| Existing writable roots | `claudux_existing_generation_boundary_violations` scans `docs/`, `.claudux/`, standard documentation state/config files, and the configured manifest path. |
| Early update phase | `validate_generation_write_boundary` runs before static-index, cache, prompt, or model work. |
| Snapshot phase | `capture_generation_workspace_snapshot` repeats the boundary immediately before capturing the source rollback state. |
| Post-model phase | `claudux_path_is_generation_allowed` requires both lexical allowlisting and safe physical ancestry, so retained and final guards reject a new symlink. |
| Generated toolchain paths | The existing-root scan prunes `docs/node_modules/` and VitePress cache, distribution, and temporary trees to avoid rejecting normal generated dependency links. |

The deduplication path explicitly short-circuits an empty array expansion. The
first full verification run exposed that `/bin/bash` 3.2 treats an empty
declared array as unbound under `set -u`; the repaired implementation passes
the repository's Bash 3.2 runner.

## Regression proof

`/bin/bash tests/test-generation-boundary-rollback.sh` passes `46/46`.

The suite covers:

- tracked root `docs/` and `.claudux/` symlinks;
- a tracked standard config-file symlink;
- absolute and parent-traversing configured manifest paths;
- generated dependency and VitePress cache symlinks that must remain allowed;
- retained and final rollback checks after a new nested `docs/` symlink;
- byte-identical external targets for every preflight escape fixture; and
- the real `bin/claudux update` entrypoint with an authenticated Claude stub.

The real CLI fixture produced:

```text
cli_rc=1
backend_invoked=false
external_state_entries=1
external_state_changed=false
```

## Mutation controls

| Removed protection | Focused-suite result | Required failures |
| --- | --- | --- |
| Physical path classifier | `31 passed, 15 failed` | Config symlink, unsafe manifests, and both post-model symlink guards turned red. |
| Existing-root scanner | `27 passed, 19 failed` | Root `docs/`, root `.claudux/`, backend isolation, and external-state confinement turned red. |
| Early `update` preflight | `45 passed, 1 failed` | The real CLI wrote through the `.claudux/` state symlink before the later snapshot check. |

These controls show that the green assertions depend on each production guard,
not on fixture setup or an assertion that can pass independently.

## Restored green stack

| Surface | Result |
| --- | --- |
| Generation boundary suite | `46/46` passed under `/bin/bash` 3.2 |
| Diff calculation suite | `31/31` passed |
| Manifest suite | `107/107` passed |
| ShellCheck | Passed at warning severity |
| Diff whitespace check | `git diff --check` passed |
| Full verification | `npm run verify` exited `0`; all `591` checks, secret scan, and public-ready metadata gate passed |

## Scope

This guard prevents Claudux from treating redirected repository write paths as
safe. It does not claim to restore an arbitrary external file if a separately
privileged backend independently obtains that path and writes to it outside
Claudux's allowed-path workflow.
