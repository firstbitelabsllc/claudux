---
layout: home

hero:
  name: claudux
  text: Generate VitePress docs from your codebase
  tagline: Draft a docs site from your code with Claude or Codex, keep unrelated source paths outside the write boundary, and opt into manifest-owned section updates when you need tighter control.
  actions:
    - theme: brand
      text: Get Started
      link: /guide/
    - theme: alt
      text: View on GitHub
      link: https://github.com/firstbitelabsllc/claudux

features:
  - icon: 🧠
    title: Generation from your code
    details: "`claudux update` drafts a full VitePress docs site straight from your source, so you start from a real draft instead of an empty folder."

  - icon: 🔑
    title: Local backend, no API key
    details: Uses your authenticated Claude or Codex CLI on the machine. There is no built-in cloud API key path.

  - icon: 📐
    title: The repo owns structure
    details: In manifest mode, a committed `docs-structure.json` holds page IDs, navigation order, source ownership, and writable sections.

  - icon: ✂️
    title: Bounded section patches
    details: In manifest mode, the backend returns patch JSON and claudux transactionally applies only validated, manifest-approved section bodies.

  - icon: 🔒
    title: Content protection
    details: "Manifest-mode guard snapshots hash pinned sections, explicit read-only sections, and skip-marker blocks so protected text cannot change silently."

  - icon: ⚡
    title: VitePress output
    details: Ships a navigable static docs site you can preview with `claudux serve`. Internal links are validated on every update.
---

## Quick Start

```bash
# latest main
curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/main/install.sh | sh

# pin the current release
curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/v2.0.7/install.sh | CLAUDUX_REF=v2.0.7 sh
```

```bash
cd your-project

claudux update           # generate or update the VitePress docs
claudux serve            # preview at http://localhost:5173
```

Run `claudux` with no arguments for an interactive menu.

## Why this exists

Anyone can ask a model to write docs now. The hard part is making the write boundary explicit: which paths the backend may edit, which sections code will accept, and which failures stop the checkpoint.

claudux separates two trust levels. Default generation lets the backend write documentation paths but rejects and restores unrelated source mutations. A committed manifest goes further: the backend becomes read-only and code applies only validated section patches.

## How generation works

One command drives the pipeline, but the write boundary depends on whether the repository has a manifest.

1. **Prepare**: claudux detects the project type, selects a project profile, validates the manifest when present, builds a static index, and constructs one backend prompt.
2. **Generate**: default mode permits direct documentation edits and guards the rest of the Git tree; manifest mode accepts only section-patch JSON and applies the batch transactionally.
3. **Validate**: manifest guards, source boundaries, local routes, Markdown links, assets, and anchors are checked before the successful checkpoint is saved. `--strict` makes unresolved link failures fatal.

## Commands Overview

| Command | Purpose |
|---------|---------|
| `claudux` | Interactive menu (adapts to project state) |
| `claudux update` | Generate or update docs, enforce write boundaries, and validate local links |
| `claudux update -m "..."` | Update with a focused directive |
| `claudux serve` | Start dev server at localhost:5173 |
| `claudux check` | Environment diagnostics |
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
  <strong>Generate docs from your codebase. Preview locally. Ship them.</strong><br>
  <a href="https://github.com/firstbitelabsllc/claudux#install">📦 Install</a> • 
  <a href="https://github.com/firstbitelabsllc/claudux">⭐ Star on GitHub</a>
</div>
