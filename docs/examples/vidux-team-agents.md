# Vidux Team Agents

Vidux is the clearest dogfood case for claudux because it stores team-agent coordination in repo files instead of only in chat history. A vidux-managed repo usually has a root `PLAN.md`, project plans under `projects/*/PLAN.md`, command scripts, verification gates, and append-only `Progress` or `Drift Log` sections. Claudux can use those files as source-owned context when refreshing the docs.

## Detection

Claudux now detects a repo as `vidux` when either condition is true:

- `vidux.config.json` exists at the repo root.
- A root `PLAN.md` exists and at least one `projects/*/PLAN.md` file is present.

That detection selects `lib/templates/vidux-project-config.json`, which asks the backend to keep plan state, team-agent handoffs, command references, drift logs, telemetry, and verification gates as distinct documentation surfaces.

## Recommended Flow

Run claudux from the vidux-managed repo root:

```bash
claudux update -m "Refresh team-agent docs from PLAN.md, projects/*/PLAN.md, command scripts, and verification gates"
```

For Codex-backed generation:

```bash
CLAUDUX_BACKEND=codex claudux update -m "Refresh vidux team-agent docs from current plan state"
```

When the repo also has `docs-structure.json`, use the manifest to keep the documentation tree stable. The manifest should own page IDs, navigation order, and deletion policy; the model should only update bounded generated sections.

## What To Document

Good vidux docs separate operating state from product claims:

- Plan files: what `PLAN.md`, subplans, `Progress`, and `Drift Log` mean.
- Agent lanes: which team agents own which surfaces and how they hand off work.
- Commands: how `bin/` and `scripts/` helpers are invoked and verified.
- Verification: the exact gates that prove a plan slice is done.
- Telemetry: local signpost, cache, or state files only when the repo checks them in or explicitly documents them as local-only.

## Prompt Shape

A focused directive keeps claudux away from broad rewrites:

```text
Refresh only source-proven team-agent docs. Treat PLAN.md and projects/*/PLAN.md as operating state, preserve manifest-owned navigation, and document drift/telemetry helpers from checked-in scripts and tests.
```

This is the same division of labor as the tools themselves: vidux keeps the plan honest; claudux keeps the docs honest.
