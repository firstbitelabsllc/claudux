---
layout: home

hero:
  name: claudux
  text: Generate VitePress docs from your codebase
  tagline: Scan your code, draft a full docs site with Claude or Codex, preview it locally, and ship it. The repo owns the structure, so the model rewrites wording without reorganizing your docs.
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
    details: A committed manifest holds page IDs, navigation order, and which source each section describes, so the model rewrites wording and never reorganizes your docs.

  - icon: ✂️
    title: Bounded section patches
    details: A regen applies validated section patches, touching the sections that changed instead of rewriting whole pages.

  - icon: 🔒
    title: Content protection
    details: "Pinned sections, read-only sections, and skip-marker blocks are hashed before and after generation, so protected text cannot change silently."

  - icon: ⚡
    title: VitePress output
    details: Ships a navigable static docs site you can preview with `claudux serve`. Internal links are validated on every update.
---

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/main/install.sh | sh
```

```bash
cd your-project

claudux update           # generate or update the VitePress docs
claudux serve            # preview at http://localhost:5173
```

Run `claudux` with no arguments for an interactive menu.

## Why this exists

Anyone can ask a model to write docs now. The hard part is keeping the model on rails: not reorganizing your navigation, not rewriting sections that didn't change, not touching content you marked as yours.

claudux puts those rails in the repo. A committed manifest owns page structure, skip markers protect blocks, and link validation catches 404s before your readers do. You get a full draft on the first run, and bounded, reviewable updates after that.

## How generation works

Parse the code, plan the structure, write within it.

1. **Analyze**: claudux scans your source for structure and patterns, and reads any existing docs and the manifest for context.
2. **Generate**: it applies bounded section patches so a regen touches only the sections that changed, guarded by skip markers and path denylists.
3. **Validate**: internal links are checked on every update; `--strict` makes broken links a hard failure.

## Commands Overview

| Command | Purpose |
|---------|---------|
| `claudux` | Interactive menu (adapts to project state) |
| `claudux update` | Generate/update docs (includes cleanup and link validation) |
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
