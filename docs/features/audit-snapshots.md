# Audit Snapshots

`claudux audit` gives a repo a single, deterministic docs-readiness snapshot without invoking an AI backend. It is meant for CI, release checks, and team-agent handoffs where the next worker needs to know whether docs are valid before deciding what to touch.

## Why It Exists

`claudux status` answers whether docs are fresh relative to the last checkpoint. `claudux validate` answers whether internal links are valid. `claudux audit` combines those signals with project detection, manifest state, pinned-section counts, and worktree changes so a human or agent can start from one report.

## Human Report

```bash
claudux audit
```

The default output reports:

- Project name, detected type, repo root, branch, HEAD SHA, and backend
- Whether `docs/` exists and how many markdown files it contains
- `docs-structure.json` validity, page count, source-owned page count, and pinned-section count
- Internal link validation status
- Checkpoint freshness and changed files since checkpoint
- Uncommitted documentation/config changes

## JSON Report

Use JSON when another tool should parse the handoff:

```bash
claudux audit --json
```

The JSON report has stable top-level `project`, `docs`, and `ready` fields. The `docs.checkpoint` object includes both counts and file lists for changed files and uncommitted documentation/config changes.

## Strict Mode

```bash
claudux audit --strict
```

Strict mode exits non-zero when the manifest or internal link validation fails. It does not fail just because the checkpoint is missing or stale; those are advisory signals that tell the next agent whether to refresh docs.

## Release Mode

```bash
claudux audit --release
```

Release mode also fails missing docs, uncommitted docs/config drift, stale package-lock metadata, package dry-run failures, or repository metadata that does not point at the configured project home.

## Handoff-Strict Mode

```bash
claudux audit --handoff-strict
```

Handoff-strict mode treats missing or stale checkpoints, changed files since checkpoint, and uncommitted docs/config changes as failures.

## Team-Agent Handoff

In a plan-first repo such as vidux, run audit before assigning a documentation slice:

```bash
claudux audit --json > /tmp/claudux-audit.json
```

The handoff should include the report plus the plan files that triggered the doc work. That keeps documentation updates source-proven instead of chat-proven.
