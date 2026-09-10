# Pocket Greeting: authenticated agent demo

This is a small, committed public fixture for a real Claude Code or Codex
documentation run. Its **Quick start** paragraph is human-written and pinned;
only **API** is generated from `src/greet.js`.

From the Claudux checkout, run the complete Codex demo:

```bash
examples/agent-demo/run.sh
```

It creates and retains a committed scratch project, runs Claudux from that
exact directory, and prints the documentation diff. The demo leaves
`CODEX_MODEL` unset so the authenticated Codex CLI selects its configured
available default; it explicitly uses low reasoning effort. The manifest puts
Codex in read-only section-patch mode, then Claudux validates and applies the
returned patch to the allowed API section.

The helper refuses to run if the original fixture has changed and checks it
again after the model run. It also proves the pinned Quick start bytes and
source file stayed unchanged:

```bash
CLAUDUX_BACKEND=claude examples/agent-demo/run.sh
```

Set `CLAUDUX_BACKEND=claude` only to use Claude Code instead. The CLI reference
remains available through `claudux --help`; the helper above is the normal
agent-first path.
