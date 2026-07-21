# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 2.0.x   | Yes       |
| < 2.0   | No        |

Only the latest `main` (and any tag at or above 2.0) receives security fixes.

## Reporting a Vulnerability

**Do not open a public issue.** Instead, use GitHub private vulnerability reporting for this repository (Security → Report a vulnerability), with:

- A description of the vulnerability
- Steps to reproduce
- Affected version(s)
- Impact assessment (what an attacker could do)

You should receive an acknowledgment within 72 hours. Fixes for confirmed vulnerabilities will be released as patch versions and credited in the changelog unless you prefer to remain anonymous.

## Scope

Claudux runs locally on your machine. It shells out to the Claude CLI and Node.js to generate documentation. Security-relevant areas include:

- **Shell injection** -- claudux passes user-provided arguments (project paths, messages) to shell commands. Improper quoting or escaping could allow command injection.
- **File system access** -- the tool reads source files and writes to the `docs/` directory. Path traversal bugs could read or overwrite unintended files.
- **Dependency chain** -- claudux itself has zero npm runtime dependencies, but it invokes `npx vitepress` which pulls packages at runtime. Supply-chain attacks on VitePress or its transitive dependencies are in scope.
- **Secrets in generated docs** -- if source files contain credentials, those could be reproduced in the generated documentation. Claudux does not currently scrub secrets from output.

## Out of Scope

- Vulnerabilities in the Claude CLI itself (report to [Anthropic](https://www.anthropic.com/responsible-disclosure))
- Vulnerabilities in VitePress (report to [VitePress](https://github.com/vuejs/vitepress/security))
- Issues that require physical access to the machine running claudux
- Social engineering attacks

## Security Design Decisions

- **No direct model API calls.** Claudux runs locally and delegates model transport to the authenticated Claude or Codex CLI you selected. Those backend CLIs may make their own network requests according to their configuration and provider terms.
- **No runtime npm dependencies.** The attack surface from `node_modules` is zero at install time.
- **No eval or dynamic code execution.** Shell scripts use `set -u` and `set -o pipefail` for safer defaults.
- **Lock file for concurrency.** Prevents multiple claudux instances from corrupting the same docs directory simultaneously.
