# Getting Started

Claudux does two things. It gates your build on doc/code drift, and it generates VitePress docs.

[The drift gate](/features/drift-gate) is the part that runs in CI. It is deterministic — parse, hash, compare, exit — and it needs no API key and no network. Generation is the AI-assisted half, and it runs on your machine against your own authenticated CLI.

## Installation

```bash
npm install -g claudux
```

Or run it without installing: `npx claudux drift`.

**Requirements:**
- Node.js ≥ 18.0.0
- Generation needs an authenticated Claude CLI (`claude config get`) or Codex CLI when `CLAUDUX_BACKEND=codex`. The drift gate needs neither.

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

4. **Baseline the gate, then run it**:
   ```bash
   claudux drift --accept   # commit docs-drift-lock.json
   claudux drift            # exits 1 when a doc falls behind its code
   ```

   Then run `claudux drift` in CI on every push. It needs no secrets.

## First Run Experience

When you run `claudux update` for the first time:

1. **Project Detection**: Automatically detects your project type (React, Next.js, Python, etc.)
2. **Code Analysis**: Scans source files to understand structure and patterns
3. **Documentation Generation**: Creates docs with proper navigation
4. **Link Validation**: Ensures all internal links work correctly

## Interactive Menu

Run `claudux` without arguments to access the interactive menu:

```bash
$ claudux

📚 claudux - Your Project Documentation  
Powered by Claude AI - Local CLI orchestration

Select:

1) Generate docs              (scan code → markdown)
2) Serve                      (vitepress dev server)
3) Create claudux.md           (docs preferences)  
4) Exit
```

## Basic Workflow

```bash
# One-time setup
npm install -g claudux
cd your-project

# Regular usage
claudux update    # Regenerate docs when code changes
claudux serve     # Preview changes locally
```

The generated documentation will be created in a `docs/` directory with:
- VitePress configuration
- Responsive navigation
- Full-text search
- Mobile-friendly design
- Automatic breadcrumbs

## Next Steps

- [Commands Reference →](/guide/commands)
- [Configuration Options →](/guide/configuration)  
- [Features Overview →](/features/)
