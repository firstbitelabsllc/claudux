# Installation

## Prerequisites

**Node.js ≥ 18.0.0**  
Download from [nodejs.org](https://nodejs.org/) or use a version manager:

```bash
# Using nvm
nvm install 18
nvm use 18

# Using fnm
fnm install 18
fnm use 18
```

**AI Backend CLI**

claudux supports Claude (default) and Codex as backends. Install at least one:

```bash
# Claude (default backend)
npm install -g @anthropic-ai/claude-code
claude  # complete the CLI's sign-in flow

# Codex (alternative backend)
npm install -g @openai/codex
codex login
```

Verify your setup:
```bash
claudux check  # shows active backend and CLI status
```

## Install Claudux

The supported Claudux release is distributed straight from GitHub. A legacy
package may still exist on the public npm registry, but it is not the current
2.x release. Pick one of the GitHub-backed installation paths below.

### Install script (Recommended)

The script clones the repo into `~/.local/share/claudux` and symlinks `bin/claudux` onto your PATH:

```bash
# latest main
curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/main/install.sh | sh

# pin the current release
curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/v2.0.7/install.sh | CLAUDUX_REF=v2.0.7 sh
```

- Tracks `main` by default — pin a branch, tag, or commit with `CLAUDUX_REF`.
- Release notes: [v2.0.7](https://github.com/firstbitelabsllc/claudux/releases/tag/v2.0.7).
- Re-run any time to update in place (idempotent).
- Falls back to a tarball download if `git` is not present; still needs Node 18+.

Verify installation:
```bash
claudux --version
```

### Run once without installing

```bash
npx github:firstbitelabsllc/claudux update
```

`npx` fetches claudux from GitHub — no npm account, no global install.

### Global install from GitHub

```bash
npm i -g github:firstbitelabsllc/claudux
```

### From Source

```bash
git clone https://github.com/firstbitelabsllc/claudux.git
cd claudux
mkdir -p ~/.local/bin                             # ensure the target dir exists
ln -sf "$PWD/bin/claudux" ~/.local/bin/claudux    # put it on your PATH
```

## Environment Check

Verify your environment is properly configured:

```bash
claudux check
```

This command validates:
- Node.js version and availability
- Active backend (Claude or Codex)
- Backend CLI installation and authentication
- Documentation directory status

Example output:
```
🔎 Environment check

• Node: v18.17.0
• Backend: claude
• Claude CLI: installed
• Model: sonnet
• docs/: not present (will be created on first run)
```

## Troubleshooting

**Backend CLI not found**
```bash
# For Claude (default)
npm install -g @anthropic-ai/claude-code
claude

# For Codex
npm install -g @openai/codex
codex login
```

If a global backend install fails with `EACCES`, use a Node version manager
such as `nvm` or `fnm` instead of recursively changing system-directory
ownership.

**Node version issues**
```bash
# Check version
node --version

# Update if needed
nvm install --lts
```

See the [troubleshooting guide](/troubleshooting) for authentication, manifest,
link, preview, and diagnostic failures.

## Next Steps

Once installed, head to the [commands guide](/guide/commands) to start generating documentation.
