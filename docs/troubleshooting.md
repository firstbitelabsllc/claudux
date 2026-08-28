# Troubleshooting

Start with the command that matches the backend you intend to use:

```bash
# Claude is the default
claudux check

# Codex
CLAUDUX_BACKEND=codex claudux check
```

`claudux check` reports the Node.js version, selected backend, backend CLI
version, authentication probe, and whether `docs/` already exists. It does not
validate the current Git worktree or generate documentation.

## Installation

### `claudux: command not found`

The installer links the CLI at `~/.local/bin/claudux`. Re-run the installer,
then add that directory to your shell path if the installer prints a path
warning:

```bash
curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/main/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
claudux --version
```

Persist the `PATH` line in the shell file named by the installer.

### Backend CLI not found

Install the backend you plan to use:

```bash
# Claude
npm install -g @anthropic-ai/claude-code

# Codex
npm install -g @openai/codex
```

Then run the matching environment check. Setting `CLAUDUX_BACKEND=codex`
selects Codex; any other value uses Claude.

### Node.js is too old

Claudux requires Node.js 18 or newer:

```bash
node --version

# Example with nvm
nvm install 18
nvm use 18
```

### Global npm permission error

The Claudux installer itself is user-local and does not need a global npm
install. If a backend CLI global install fails with `EACCES`, use a Node version
manager such as `nvm` or `fnm`, then install the backend again. Avoid changing
ownership of system npm directories with a recursive `sudo chown`.

## Authentication

Claudux has no API key store. The selected backend CLI owns authentication.

### Claude

Check the current authentication state, sign in when needed, then re-run:

```bash
claude auth status
claude auth login
claudux check
```

Claudux checks `claude auth status` without printing account metadata; the
environment check fails when the CLI is not authenticated.

### Codex

```bash
codex login
codex login status
CLAUDUX_BACKEND=codex claudux check
```

`OPENAI_API_KEY` is also supported by the Codex CLI. Claudux does not read or
store that value itself.

## Generation

### No Git repository found

`update`, `serve`, and the interactive menu require a Git repository. Run the
command from an existing repository root, or initialize Git only when that is
actually how you want to manage the project:

```bash
git rev-parse --show-toplevel
cd /path/to/project
claudux update
```

`help`, `--version`, and `check` can run outside a repository.

### Empty or generic documentation

First verify the detected project configuration:

```bash
cat claudux.json 2>/dev/null || true
claudux check
```

Then give the backend a bounded directive and review the diff:

```bash
claudux update --with "Document the public API and its tested error behavior"
git diff -- docs/
```

`project.type` in `claudux.json` can override auto-detection. Use one of the
built-in types or a type backed by `lib/templates/<type>-project-config.json`;
unknown values fall back to detection.

### Manifest or section-patch failure

When `docs-structure.json` is present, Claudux validates it before invoking the
backend. The backend must then return one bounded section-patch payload instead
of writing docs directly.

Read the first reported manifest or patch error. Common causes are:

- a page path outside `docs/`
- duplicate page, section, navigation, or order values
- a missing required heading
- a patch targeting a pinned or out-of-scope section
- a patch body containing a same-level heading or run-specific cache data

The section-patch batch is all-or-nothing. A rejected batch does not partially
edit its target documentation files.

### Backend timeout or stalled output

The Codex adapter honors `CLAUDUX_TIMEOUT` when `timeout` or `gtimeout` is
available. Its default is 600 seconds; `0` disables the wrapper timeout. The
Claude adapter has no equivalent hard timeout.

```bash
CLAUDUX_TIMEOUT=900 CLAUDUX_BACKEND=codex claudux update
```

For a slow run, narrow the request rather than changing unrelated project
files:

```bash
claudux update --with "Update only the API documentation affected by src/api/"
```

### Backend exits nonzero

Claudux prints the tail of the backend output and retains a temporary JSONL log
when output exists. The failure message prints that retained path.

Codex stderr defaults to:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/claudux/codex-stderr.log
```

The file can contain authentication errors or backend output. Do not attach it
to a public issue without reviewing and redacting it.

## Links

### Broken internal links

`claudux update` runs the internal link validator after generation. The normal
mode warns when unresolved links remain; strict mode exits nonzero:

```bash
claudux update --strict
```

Claudux may attempt one focused missing-page repair when the validator reports
missing files. It does not guarantee that every broken anchor, navigation
target, or sidebar target can be repaired automatically.

Review the reported source and target, fix the link or manifest entry, and run
strict mode again.

## Preview

### VitePress dependencies are missing

`claudux serve` creates missing support files and runs
`npm install --no-audit --no-fund` under `docs/` when VitePress is absent.

To restore exactly the dependencies in an existing lockfile:

```bash
npm --prefix docs ci --no-audit --no-fund
claudux serve
```

Do not delete `docs/package-lock.json` as a first recovery step; it is the
reproducible dependency record.

### Port 5173 is already in use

Identify the listener before stopping it:

```bash
lsof -nP -iTCP:5173 -sTCP:LISTEN
```

Stop only a process you recognize and own. To preview on another port without
changing Claudux:

```bash
npm --prefix docs run docs:dev -- --port 5174
```

### Static build fails

Run the same build script used by the generated site:

```bash
npm --prefix docs run docs:build
```

Fix the first VitePress error, then rerun the build and
`claudux update --strict`. A successful dev-server start is not proof that the
static production build succeeds.

## Diagnostic report

Before opening an issue, collect the smallest useful, non-secret report:

```bash
claudux --version
node --version
git status --short

# Include only the selected backend
claude --version
claudux check

# Or:
codex --version
codex login status
CLAUDUX_BACKEND=codex claudux check
```

Also include the exact Claudux command, its exit code, and the first relevant
error. Review configuration, retained JSONL, and stderr files before sharing
them; they may contain repository details or authentication diagnostics.

Report bugs through [GitHub Issues](https://github.com/firstbitelabsllc/claudux/issues).
