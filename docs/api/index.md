# CLI API Reference

Complete reference for all claudux command-line interface options and behaviors.

## Commands

### `claudux`

**Syntax**: `claudux [command] [options]`

**Description**: Main entry point. Without arguments, shows interactive menu.

**Examples:**
```bash
claudux                 # Interactive menu
claudux update          # Generate documentation
claudux serve           # Start dev server  
claudux --help          # Show help
```

### `claudux update`

**Syntax**: `claudux update [options]`

**Description**: Generate or update documentation by analyzing the current codebase.

**Options:**
- `-m, --message, --with <directive>`: Focused directive for generation
- `--strict`: Fail on broken links (exit code 1)

**Examples:**
```bash
claudux update
claudux update -m "Focus on API documentation"  
claudux update --with "Add deployment guide"
claudux update --strict
```

**Process flow:**
1. Load project configuration and detect type
2. Build comprehensive AI prompt
3. Execute two-phase generation (analysis → creation)  
4. Validate all internal links
5. Display change summary

**Exit codes:**
- `0`: Success
- `1`: Generation failed or broken links in strict mode
- `124`: Timeout
- `130`: Interrupted

### `claudux serve`

**Syntax**: `claudux serve`

**Description**: Start VitePress development server for local documentation preview.

**Behavior:**
- Serves at `http://localhost:5173`
- Hot reload on file changes
- Automatically installs VitePress dependencies if needed
- Prompts to generate docs if none exist

**Examples:**
```bash
claudux serve
# 📖 Docs available at: http://localhost:5173
# Press Ctrl+C to stop the server
```

### `claudux recreate`

**Syntax**: `claudux recreate`

**Description**: Delete all existing documentation and start fresh.

**Behavior:**
- Removes entire `docs/` directory
- Regenerates from scratch
- Useful for major structural changes

**Examples:**
```bash
claudux recreate
# ⚠️  This will delete all existing documentation
# Are you sure? (y/N): y
```

### `claudux template`

**Syntax**: `claudux template`

**Description**: Generate `claudux.md` file with documentation preferences for the project.

**Behavior:**
- Analyzes current project structure
- Creates preferences file based on detected patterns
- Guides future documentation generation

**Examples:**
```bash
claudux template
# ✅ Generated claudux.md (docs preferences) (42 lines)
```

### `claudux check`

**Syntax**: `claudux check`

**Description**: Validate environment and display system status.

**Output example:**
```
🔎 Environment check

• Node: v18.17.0
• Claude: claude-cli/1.2.3  
• docs/: present
```

**Validates:**
- Node.js version (≥18 required)
- Claude CLI installation and authentication
- Documentation directory status

### `claudux audit`

**Syntax**: `claudux audit [--json] [--strict] [--release] [--handoff-strict]`

**Description**: Print a no-AI documentation readiness report. This command is designed for CI checks and team-agent handoffs because it summarizes the current docs state without invoking Claude or Codex.

**Options:**
- `--json`: Emit machine-readable JSON with project, manifest, link, checkpoint, and worktree fields
- `--strict`: Exit non-zero when the docs manifest or internal link validation fails
- `--release`: Exit non-zero when docs/package release-readiness checks fail
- `--handoff-strict`: Exit non-zero when checkpoint freshness or dirty docs state should block handoff

**Examples:**
```bash
claudux audit
claudux audit --json
claudux audit --strict
```

**Reports:**
- Project name, detected type, repo root, branch, HEAD SHA, and active backend
- Docs directory presence and markdown file count
- Manifest validity, page count, source-owned page count, and pinned section count
- Internal link validation status
- Checkpoint freshness and changed files since the last checkpoint
- Uncommitted documentation/config changes that agents should review before handoff

## Global Options

### `--help`, `-h`, `help`

**Syntax**: `claudux [--help|-h|help]`

**Description**: Display help information and usage examples.

### `--version`, `-V`, `version`

**Syntax**: `claudux [--version|-V|version]`

**Description**: Display the installed claudux version.

**Output**: `claudux 1.2.0`

## Environment Variables

### `FORCE_MODEL`

**Values**: `opus`, `sonnet`

**Default**: `sonnet`

**Description**: Select Claude model for generation.

```bash
FORCE_MODEL=opus claudux update    # More capable, slower
FORCE_MODEL=sonnet claudux update  # Faster, default
```

### `CLAUDUX_MESSAGE`

**Description**: Default directive message for updates.

```bash
CLAUDUX_MESSAGE="Focus on API docs" claudux update
# Equivalent to: claudux update -m "Focus on API docs"
```

### `DOCS_BASE`

**Description**: Base path for deployed documentation (CI/CD use).

```bash
export DOCS_BASE='/my-project/'  # For GitHub Pages deployment
claudux update
```

**Usage**: Set in CI environments for proper deployment paths. Local development always uses `/`.

### `CLAUDUX_BACKEND`

**Values**: `claude`, `codex`

**Default**: `claude`

**Description**: Select the model backend used by generation commands.

```bash
CLAUDUX_BACKEND=codex claudux update
```

### `CODEX_MODEL` and `CODEX_REASONING_EFFORT`

**Defaults**: `gpt-5.4` and `xhigh`

**Description**: Configure the Codex backend when `CLAUDUX_BACKEND=codex`.

```bash
export CLAUDUX_BACKEND=codex
export CODEX_MODEL=gpt-5.4
export CODEX_REASONING_EFFORT=xhigh
claudux update
```

## Exit Codes

Claudux follows standard Unix conventions:

| Code | Meaning | Common Causes |
|------|---------|---------------|
| `0` | Success | Normal operation completed |
| `1` | General error | Missing dependencies, configuration issues |
| `2` | Usage error | Invalid command-line arguments |
| `124` | Timeout | Claude API timeout, network issues |
| `130` | Interrupted | User pressed Ctrl+C |

## Interactive Menu API

### Menu States

**No existing documentation:**
```
1) Generate docs              (scan code → markdown)
2) Serve                      (vitepress dev server) 
3) Create claudux.md           (docs preferences)
4) Exit
```

**Existing documentation:**
```
1) Update docs                (regenerate from code)
2) Update (focused)           (enter directive → update)
3) Diff                       (files changed since last gen)
4) Status                     (documentation freshness)
5) Validate links             (check for broken links)
6) Audit                      (no-AI readiness report)
7) Serve                      (vitepress dev server)
8) Create claudux.md           (docs preferences)
9) Recreate                   (start fresh)
10) Exit
```

### Menu Behavior

**Navigation**: Use number keys + Enter
**Cancellation**: Ctrl+C at any time
**Error handling**: Invalid selections prompt retry

## Configuration Files API

### `claudux.json`

**Location**: Project root

**Schema:**
```json
{
  "project": {
    "name": "string",              // Project display name
    "type": "string"               // Project type override
  },
  "ai": {
    "default_model": "sonnet|opus", // Model preference
    "timeout_seconds": 90           // Generation timeout
  }
}
```

### `claudux.md`

**Location**: Project root

**Purpose**: Documentation preferences and site structure guidance

**Generation**: `claudux template`

**Format**: Markdown with structured sections for site configuration, page hierarchy, and styling preferences.

## Integration APIs

### Git Integration

**Requirements**: Must be run from git repository

**Behavior:**
- Auto-detects project root via `git rev-parse --show-toplevel`
- Shows git status before generation
- Tracks documentation changes in git history

### VitePress Integration

**Generated files:**
- `docs/.vitepress/config.ts` - VitePress configuration
- `docs/package.json` - VitePress dependencies
- `docs/vite.config.js` - Vite build configuration

**Development server**: 
- Port: `5173` (VitePress default)
- Command: `npm run docs:dev` (from docs/ directory)

This API reference provides the complete interface for automating and integrating claudux into your development workflow.
