---
layout: home

hero:
  name: claudux
  text: Docs that fail CI when they stop matching the code
  tagline: A deterministic doc/code drift gate. Parse, hash, compare, exit. No API key, no network, no model on the pass/fail path. It also generates VitePress docs.
  actions:
    - theme: brand
      text: Get Started
      link: /guide/
    - theme: alt
      text: View on GitHub
      link: https://github.com/firstbitelabsllc/claudux

features:
  - icon: 🚨
    title: The drift gate
    details: "`claudux drift` fails the build when a documented source file changed but its doc section didn't. It names the doc, the source, and the fix."
  
  - icon: 🔑
    title: Keyless and offline
    details: The gate reads a committed lockfile and the working tree. No API key, no network call, no model. It runs the same on your laptop and on a bare CI runner.
  
  - icon: 🎚️
    title: A sensitivity knob
    details: "`significant` is the default. It ignores whitespace, blank lines, and comment churn, so the gate fires on real changes instead of reformatting."
  
  - icon: 🔄
    title: Re-baseline on purpose
    details: "Read the diff, decide the docs are fine, run `claudux drift --accept`. It updates the lockfile the way `npm install` updates `package-lock.json`."
  
  - icon: 🧠
    title: Generation stays local
    details: Uses your authenticated Claude or Codex CLI on the machine. No built-in cloud API key path. AI only ever suggests a fix after a deterministic flag.
  
  - icon: ⚡
    title: VitePress output
    details: Ships a navigable static docs site you can preview with `claudux serve` and validate with link checks.
---

## Quick Start

The drift gate ships in source (1.2.0). npm still serves 1.1.1, which has no `claudux drift`, so install from source until the 1.2.0 publish lands:

```bash
npm i -g firstbitelabsllc/claudux
```

```bash
cd your-project

claudux drift --accept   # commit the baseline once
claudux drift            # exits 1 when a doc falls behind its code

claudux update           # generate or update the VitePress docs
claudux serve            # preview at http://localhost:5173
```

Then run `claudux drift` in CI on every push. It needs no secrets.

## See It In Action

<p align="center">
  <img src="/assets/terminal-demo.svg" alt="claudux update terminal session" style="width: 100%; max-width: 800px;" />
</p>

## Why this exists

Anyone can generate docs now. The problem is proving they still match the code a week later.

Stale docs are the ones nobody notices until something acts on a lie. That is getting more expensive, not less, because the primary reader of your docs is shifting from a human to an agent. A human skims a wrong doc and shrugs. An agent reads it, believes it, and calls your API the wrong way.

So claudux checkpoints which source files each doc section describes, and fails the build when the source moved and the doc didn't.

## How the gate works

Parse, hash, compare, exit. No model is involved in the pass/fail decision.

1. **Baseline**: `claudux drift --accept` writes `docs-drift-lock.json`, a committed, timestamp-free record of each source file's hash and each doc section's hash.
2. **Compare**: `claudux drift` re-hashes both sides and looks for one condition — a source file a section claims to document changed, and that section's body did not.
3. **Exit**: `0` when clean, `1` on drift with the doc, the source, and the fix printed, `2` on an environment error. It never exits 0 to hide a problem.

## Commands Overview

| Command | Purpose |
|---------|---------|
| `claudux drift` | Fail the build when a documented source changed but its doc didn't |
| `claudux drift --accept` | Re-baseline `docs-drift-lock.json` after reviewing the diff |
| `claudux drift --json` | Machine-readable drift report for CI |
| `claudux drift --warn-only` | Report drift and always exit 0 (local pre-commit) |
| `claudux` | Interactive menu (adapts to project state) |
| `claudux update` | Generate/update docs (includes cleanup and validation) |
| `claudux update -m "..."` | Update with a focused directive |
| `claudux serve` | Start dev server at localhost:5173 |
| `claudux diff` | Files changed since last doc generation |
| `claudux status` | Documentation freshness and last run details |
| `claudux validate` | Check all internal links without regenerating |
| `claudux recreate` | Start fresh (delete all docs) |
| `claudux check` | Environment diagnostics |
| `claudux template` | Generate claudux.md (docs preferences) |
| `claudux --version` | Show installed version |
| `claudux --help` | Show help and usage |

## Multi-Backend Support

claudux supports multiple AI backends. Claude is the default; Codex is available as an alternative via the `CLAUDUX_BACKEND` environment variable.

```bash
# Default -- uses Claude
claudux update

# Use Codex instead
CLAUDUX_BACKEND=codex claudux update
```

## Requirements

- Node.js >= 18
- An authenticated AI CLI: [Claude CLI](https://docs.anthropic.com/claude/docs/claude-cli) (default) or [Codex CLI](https://github.com/openai/codex)

---

<div style="text-align: center; margin-top: 40px;">
  <strong>Keep your docs true to your code.</strong><br>
  <a href="https://github.com/firstbitelabsllc/claudux#install">📦 Install</a> • 
  <a href="https://github.com/firstbitelabsllc/claudux">⭐ Star on GitHub</a>
</div>
