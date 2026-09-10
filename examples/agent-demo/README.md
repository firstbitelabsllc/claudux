# Pocket Greeting: authenticated agent demo

This is a small, committed public fixture for a real Claude Code or Codex
documentation run. Its **Quick start** paragraph is human-written and pinned;
only **API** is generated from `src/greet.js`.

From the Claudux checkout, make an isolated Git project and run Claude Code:

```bash
demo_dir="$(examples/agent-demo/prepare-scratch.sh)"
cd "$demo_dir"
CLAUDUX_BACKEND=claude /absolute/path/to/claudux/bin/claudux update \
  -m "Document the exported greet function in the API section. Keep Quick start byte-for-byte unchanged."
```

The manifest puts Claude Code in section-patch mode with `Read` as its only
tool. Claudux validates and applies its returned patch to the allowed API
section, then you can inspect the diff:

```bash
git diff -- docs/index.md
./verify-result.sh
```

To use Codex instead, replace `CLAUDUX_BACKEND=claude` with
`CLAUDUX_BACKEND=codex`. The CLI reference remains available through
`claudux --help`; the command above is the normal agent-first path.
