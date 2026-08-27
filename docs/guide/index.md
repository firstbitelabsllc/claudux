# Getting Started

Claudux scans your code and drafts a VitePress docs site with Claude or Codex, then lets you preview it locally and update it in place. Generation runs on your machine against your own authenticated CLI.

When a committed `docs-structure.json` is present, the repository owns the page tree, required sections, pinned content, and source-to-doc mapping. Claudux switches the backend to read-only section-patch mode and applies the validated patches itself. Without that manifest, the backend can write within the documentation boundary, so review the generated diff.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/main/install.sh | sh
```

Or run it once without installing: `npx github:firstbitelabsllc/claudux update`.

**Requirements:**
- Node.js ≥ 18.0.0
- An authenticated Claude CLI, or an authenticated Codex CLI when `CLAUDUX_BACKEND=codex`
- A Git repository for `update` and `serve`

Run `claudux check` to verify Node and the selected backend before generation.

## Quick Start

1. **Navigate to your project**:
   ```bash
   cd your-project
   ```

2. **Generate documentation**:
   ```bash
   claudux update
   ```

3. **Preview locally**:
   ```bash
   claudux serve  # Opens http://localhost:5173
   ```

## First Run Experience

When you run `claudux update` for the first time:

1. **Project Detection**: Automatically detects your project type (React, Next.js, Python, etc.)
2. **Code Analysis**: Scans source files to understand structure and patterns
3. **Documentation Generation**: Drafts docs directly, or returns bounded section patches when a manifest is present
4. **Link Validation**: Reports broken internal links; `claudux update --strict` fails if they remain

## Interactive Menu

Run `claudux` without arguments to access the interactive menu:

```bash
$ claudux

📚 claudux - Your Project Documentation
Generate docs from your codebase · powered by Claude AI

Select:

1) Generate docs              (scan code → markdown)
2) Serve                      (vitepress dev server)
3) Exit
```

## Basic Workflow

```bash
# One-time setup
curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/main/install.sh | sh
cd your-project

# Regular usage
claudux update    # Regenerate docs when code changes
claudux serve     # Preview changes locally
```

The generated documentation is created in `docs/`. Claudux's VitePress
scaffolder supplies a responsive theme, local search, and breadcrumbs when it
needs to create the site support files. The backend may generate or update the
project-specific navigation and VitePress configuration, so validate the built
site before publishing it.

## Next Steps

- [Commands Reference →](/guide/commands)
- [Configuration Options →](/guide/configuration)  
- [Features Overview →](/features/)
