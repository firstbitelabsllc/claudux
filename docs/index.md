---
layout: home

hero:
  name: claudux
  text: Docs that re-run with the code
  tagline: Local CLI that turns a codebase into maintained VitePress guides. You own structure; Claude or Codex proposes wording.
  actions:
    - theme: brand
      text: Get Started
      link: /guide/
    - theme: alt
      text: View on GitHub
      link: https://github.com/firstbitelabsllc/claudux

features:
  - icon: 🔄
    title: Re-runnable updates
    details: Re-run `claudux update` when the product changes. Prefer deterministic manifests when structure is part of the product.
  
  - icon: 🧠
    title: Backend-aware, not hosted-only
    details: Uses your authenticated Claude or Codex CLI on the machine. No built-in cloud API key path.
  
  - icon: ⚡
    title: VitePress output
    details: Ships a navigable static docs site you can preview with `claudux serve` and validate with link checks.
  
  - icon: 🔒
    title: Local orchestration
    details: The CLI runs on your machine. Skip markers and path denylists protect sensitive blocks and files.
  
  - icon: 🍰
    title: Low config default
    details: Detects common project types out of the box. Add `docs-structure.json` when you need pinned structure.
  
  - icon: 🔗
    title: Link validation
    details: Built-in validation catches broken internal links. Review still matters; the model can be wrong.
---

## Quick Start

```bash
# Install globally
npm install -g claudux

# Generate docs for your project
cd your-project
claudux update

# Preview locally  
claudux serve  # http://localhost:5173
```

## See It In Action

<p align="center">
  <img src="/assets/terminal-demo.svg" alt="claudux update terminal session" style="width: 100%; max-width: 800px;" />
</p>

## The Problem Every Developer Knows

**Documentation debt is killing your productivity.** You ship features, but docs lag behind. New team members struggle to onboard. You spend weekends writing docs instead of building.

## How It Works

Claudux uses a **two-phase flow** to produce reliable docs:

1. **🧠 Plan**: Analyze source code and produce a navigable outline + VitePress config
2. **✍️ Write**: Generate pages with correct links, breadcrumbs, and cross-references

## Commands Overview

| Command | Purpose |
|---------|---------|
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
- An authenticated AI CLI: [Claude Code](https://www.npmjs.com/package/@anthropic-ai/claude-code) (default) or [Codex CLI](https://github.com/openai/codex)

---

<div style="text-align: center; margin-top: 40px;">
  <strong>Keep your docs as fresh as your code.</strong><br>
  <a href="https://www.npmjs.com/package/claudux">📦 Install from npm</a> • 
  <a href="https://github.com/firstbitelabsllc/claudux">⭐ Star on GitHub</a>
</div>
