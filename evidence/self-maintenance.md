# Claudux Self-Maintenance Proof

Proof date: 2026-08-27
Input revision: `41393288a7e00aab66b50d627532ab2407f40d52`
Backend: Claude CLI `2.1.246`, forced Sonnet tier, resolved model
`claude-sonnet-5`

## Verdict

Claudux ran against a clean detached clone of its own candidate revision in
manifest mode. The backend received read-only access, returned an empty section
patch batch, and Claudux reported that the documentation was already current.
No tracked file changed, the guard snapshot stayed byte-identical, and the
saved checkpoint points to the exact input revision.

This is a truthful no-change result rather than a generated success claim:
the persisted patch payload is `{"patches":[]}`, accepted changes are zero,
rejected changes are zero, and both the working-tree and index diffs are empty.

## Fixture and request

The fixture contained:

- `repo/` — a clean local clone detached at the input revision
- `proof/baseline-guard.json` — the guard snapshot captured before generation
- `proof/final-guard.json` — the refreshed snapshot after the update
- `proof/update.log` — local command output retained outside the candidate

The update used:

```bash
FORCE_MODEL=sonnet CLAUDUX_BACKEND=claude CLAUDUX_TIMEOUT=600 \
  ./bin/claudux update -m \
  "Audit the committed docs against the current source and tests. Propose only manifest-approved source-owned section patches that correct a concrete mismatch. Preserve pinned and skip-marked prose. If the docs are already accurate, return an empty patch batch."
```

The environment check passed with Node `v22.13.1`, the authenticated Claude
CLI, the Sonnet override, and the existing `docs/` tree.

## Deterministic boundary

Before backend invocation, Claudux validated 14 manifest pages, all 14 with
source ownership, and three pinned sections. It built the static index from 102
source files and 14 Markdown documentation files, then captured one pinned page
and three files containing protected skip blocks.

The model phase used read-only tools. Claudux then:

1. extracted zero section patches;
2. applied zero section patches;
3. revalidated the 14-page manifest;
4. passed the guard check;
5. validated 47 internal links while skipping 6 external links;
6. rebuilt the deterministic index and guard snapshot; and
7. saved `.claudux-state.json` at the exact input revision.

## Protected hashes

The normalized aggregate of `pinned_pages` and `protected_files` had the same
SHA-256 before and after the run:

```text
858b0a586c165011afb105b8f7a21c0f551375126b741b2448a60d91879e26fe
```

The complete baseline and final guard snapshots were also byte-identical.

| Protected content | SHA-256 |
| --- | --- |
| `technical.deterministic-generation#why-large-repos-need-a-manifest` | `26d26669c084d39dc12a53afac19712aaa36edc71a7edbea767e94b913087f08` |
| `technical.deterministic-generation#pipeline` | `e37fddf86490b44f0c3b9ee9bc5581ab24169a68468a7977b8a39c264ec3117b` |
| `technical.deterministic-generation#pinned-harness-example` | `64c0ad27b44e386025962caf1a7607a1ff575b8e123ef3eeabc10dd301610fd4` |
| `README.md` skip block | `9d1bb120ffebb391d84a6e5648bd61f3acc677bf3dce8261e3e7a851654a1255` |
| `docs/features/content-protection.md` first skip block | `b181aff3e5cd1bcdc32320475a6e5a76867019470446d66f3ad5ce59666a6f0b` |
| `docs/features/content-protection.md` second skip block | `982c878b11d4aa33ac437c1d2a9305548119c318f5d04b2d50b70edaf84b2329` |
| `docs/guide/configuration.md` skip block | `8d46d25cd171f608c188cd11d8c246daa9f31349c54eea2e797a930f8957fd15` |

## Proposal disposition

| Stage | Result |
| --- | --- |
| Backend proposal | Empty manifest patch batch |
| Accepted documentation changes | 0 |
| Rejected documentation changes | 0 |
| Claudux-owned local state | Checkpoint and deterministic index refreshed |
| Tracked working-tree changes | 0 |
| Staged changes | 0 |
| Commits created in fixture | 0 |

Every possible documentation target remains named by `docs-structure.json` and
its `source_patterns`. Because the backend proposed no patch, there was no
candidate text to import into the source repository and no false claim that a
no-op changed documentation.

## Final diff

`git diff --exit-code`, `git diff --cached --exit-code`, and the tracked
status count all passed with zero changes. The only new fixture files were
ignored Claudux checkpoint and index data.

No fixture change was copied into the candidate, no commit was created from
model output, and no publication or remote mutation occurred.
