# claudux — documentation preferences

This file carries repo-specific documentation preferences for the claudux repo
itself. When a target project ships a `claudux.md`, claudux reads it at
generation time and includes it in the prompt (see `lib/docs-generation.sh`,
the `claudux_prefs` branch). It is *not* the `CLAUDE.md` that claudux generates
for your projects — that is an AI instruction contract for a target repo.

Keep this file to preferences. Architecture, patterns, and command behavior
live in the generated docs; do not restate them here or they drift.

## Documentation preferences for this repo

- Verbosity is on by default — do NOT document a `-v`/`--verbose` flag or any
  `CLAUDUX_VERBOSE` configuration.
- Default model is Sonnet (speed). If you mention model selection, note that
  `FORCE_MODEL=opus claudux update` forces Opus when a heavier model helps.

## Positioning and voice

Applies to the Home hero, feature cards, and every section intro.

- Lead with the outcome, not the model: **generate a docs site from your
  codebase, preview it locally, keep it in sync.**
- The hero sells that plainly — point claudux at a repo, get a navigable
  VitePress site scanned from the actual source, then update it in place when
  the code changes. Generation runs locally against your own authenticated
  Claude or Codex CLI.
- Feature cards cover the source-owned manifest (the repo owns structure),
  bounded section patches (the model rewrites wording, not layout), content
  protection, and two-phase generation — not just "AI writes docs."
- Short declarative sentences, plain words, benefit before mechanism. No
  corporate speak ("seamless", "powerful", "beautiful documentation",
  "transform your codebase", "in minutes") and no rule-of-three filler.
- Never emit: "AI-Powered Documentation Generator", "Transform your codebase
  into beautiful documentation", "Documentation debt is killing your
  productivity".

## Quick usage

```bash
claudux update   # generate or update docs
claudux serve    # preview locally
claudux check    # verify environment and backend
```
