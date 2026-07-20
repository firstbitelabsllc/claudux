# The Drift Gate

`claudux drift` fails your build when a source file changed but the doc section that documents it did not.

No model runs on the pass/fail path. The gate parses, hashes, compares, and exits. It needs no API key and makes no network call, so it runs identically on your laptop and on a bare CI runner.

## Why this exists

Anyone can generate docs now. The problem is proving they still match the code a week later.

Stale docs are the ones nobody notices until something acts on a lie. That is getting more expensive, not less, because the primary reader of your docs is shifting from a human to an agent. A human skims a wrong doc and shrugs. An agent reads it, believes it, and calls your API the wrong way.

## How it works

### 1. Declare what each doc section documents

`docs-structure.json` already carries a `source_patterns[]` array per page and per section. That array is the join: it names the code a given doc unit is responsible for describing.

### 2. Baseline

```bash
claudux drift --accept
```

This writes `docs-drift-lock.json` at the repo root and you commit it. It is the `package-lock.json` of this analogy: a record of each covered source file's hash and each doc section's hash, with no timestamps in it, so the diff stays reviewable.

The lock is committed on purpose. `.claudux-state.json` and `.claudux/index/` are gitignored, so a gate that read the local checkpoint would find nothing on a fresh CI runner and pass green forever.

### 3. Compare

```bash
claudux drift
```

The gate re-hashes both sides and looks for exactly one condition:

> a source file this section claims to document changed since the lock, **and** the section's body did not.

Change the code and the doc together, and the gate stays quiet. Change only the code, and it fails and names the pair.

### 4. Exit

| Code | Meaning |
|------|---------|
| `0` | Clean, or no baseline yet (a missing lock is never a false failure) |
| `1` | Drift found |
| `2` | Environment error, such as an unreadable lock |

It never exits `0` to hide a problem it could not evaluate.

## Sensitivity

Raw per-file hashing trips on reindents and comment edits. People then disable the gate, and the product is dead. So the default is `significant`.

Set `drift_sensitivity` at the root of `docs-structure.json`:

| Mode | Behavior |
|------|----------|
| `significant` *(default)* | Normalize CRLF, drop blank lines, drop full-line comments, collapse inline whitespace, then hash. Fires on renamed flags, changed defaults, changed literal paths, and added or removed logic. Ignores reformatting. |
| `raw` | Raw file hash. The strict escape hatch. |
| `surface` | Hash only exported symbol signatures and CLI commands. Shell repos only — it is empty for TypeScript, Swift, and Python, so it would silently pass everything. claudux dogfoods itself in this mode. |

### Residual false positives

Being honest about the ones `significant` does not kill: trailing and inline comment edits, block-comment reflow, and coverage granularity. A broad pattern like `lib/**` flags its whole page when any matched file changes. The fix is authorial — narrower `source_patterns` give sharper signal.

## Re-baselining

When you have read the diff and decided the docs are actually fine, freeze the new baseline:

```bash
claudux drift --accept
```

That is the deterministic escape hatch, and it involves no AI. `claudux update` also clears drift, because it rebuilds the index and re-checkpoints as part of regenerating.

Every failure message prints the fix inline, so nobody has to go looking for this page:

```
docs/guide/commands.md documents lib/ui.sh, which changed.
    Update the doc, or run 'claudux drift --accept' to re-baseline.
```

## Add it to CI

No secrets, no API key, no network.

```yaml
name: Docs drift
on: [push, pull_request]

jobs:
  drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 18
      - run: npm i -g firstbitelabsllc/claudux
      - run: claudux drift
```

claudux runs this exact workflow on its own pull requests.

### Locally, as a warning instead

Save this as `.git/hooks/pre-commit` and make it executable:

```bash
#!/bin/sh
claudux drift --warn-only
```

`--warn-only` always exits `0`. You see the report on the commit that caused the drift, and the commit still lands. CI stays the hard gate.

## Machine-readable output

```bash
claudux drift --json
```

```json
{
  "command": "drift",
  "sensitivity": "significant",
  "ready": true,
  "drifted": [
    {
      "doc_file": "docs/reference/configuration.md",
      "page_id": "configuration",
      "section_id": null,
      "changed_sources": [".env.example"],
      "doc_hash_unchanged": true
    }
  ],
  "new_sources": [],
  "skipped": []
}
```

`drifted[]` and `new_sources[]` are sorted, and identical inputs produce byte-identical output. That is a hard requirement, not a nicety — a gate that reorders its own report cannot be diffed.

## Edge cases

- **No lock**: exit `0` with `skipped: [{ reason: "no-baseline" }]` and a hint to run `--accept`. A first run never fails a build.
- **Deleted source**: counts as changed, so it drifts its owning section. A doc describing code you removed is exactly the lie this catches.
- **Renamed source**: read as a delete plus an add. The old path fires; the new path appears in `new_sources[]` as a note only, since it has no baseline to compare against.
