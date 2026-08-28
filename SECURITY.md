# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| Current 2.0.x release | Yes |
| Older releases | No |

Security fixes target the current 2.0.x release line and `main`.

## Reporting a Vulnerability

**Do not open a public issue.** Instead, use GitHub private vulnerability reporting for this repository (Security → Report a vulnerability), with:

- A description of the vulnerability
- Steps to reproduce
- Affected version(s)
- Impact assessment (what an attacker could do)

Include a safe contact method if the report needs follow-up. Maintainers will
coordinate disclosure and remediation through the private report.

## Scope

Claudux runs locally on your machine. It uses Node.js for deterministic
validation and delegates model execution to the selected Claude or Codex CLI.
Security-relevant areas include:

- **Shell injection** -- claudux passes user-provided arguments (project paths, messages) to shell commands. Improper quoting or escaping could allow command injection.
- **File system access** -- the tool reads source files and writes to the `docs/` directory. Path traversal bugs could read or overwrite unintended files.
- **Dependency chain** -- the claudux package has no npm runtime dependencies. `serve` can scaffold a `docs/package.json` and run `npm install` for VitePress and its development dependencies. Supply-chain attacks through that install path are in scope.
- **Secrets in generated docs** -- if source files contain credentials, those could be reproduced in the generated documentation. Claudux does not currently scrub secrets from output.
- **Runtime isolation** -- project locks and the default Codex stderr log live in per-user XDG state. Ephemeral files honor `TMPDIR`; unsafe ownership, symlink handling, permissions, or cross-process collisions in either location are in scope.

## Out of Scope

- Vulnerabilities in the selected Claude or Codex CLI itself (report them to
  that CLI's vendor)
- Vulnerabilities in VitePress (report to [VitePress](https://github.com/vuejs/vitepress/security))
- Issues that require physical access to the machine running claudux
- Social engineering attacks

## Security Design Decisions

- **No direct model API calls.** Claudux runs locally and delegates model transport to the authenticated Claude or Codex CLI you selected. Those backend CLIs may make their own network requests according to their configuration and provider terms.
- **No core runtime npm dependencies.** Installing claudux does not install a dependency tree for the CLI itself; previewing a generated site can install the dependencies declared under `docs/`.
- **No eval or dynamic code execution.** Shell scripts use `set -u` and `set -o pipefail` for safer defaults.
- **XDG-scoped runtime state.** Project locks live under `${XDG_STATE_HOME:-~/.local/state}/claudux/locks/` (not a shared temp dir). Codex backend stderr appends to `.../claudux/codex-stderr.log` in the same tree.
- **TMPDIR-aware mktemps.** `claudux_mktemp` creates temps under `${TMPDIR:-/tmp}` so a caller-isolated `TMPDIR` stays isolated; it does not hardcode `/tmp/claudux-*`.
- **Lock file for concurrency.** Prevents multiple claudux instances from corrupting the same docs directory simultaneously.
