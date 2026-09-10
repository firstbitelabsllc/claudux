# Reproduce the demo capture

The recording opens a loopback ttyd terminal, asks Claude Code to run
`examples/agent-demo/run.sh`, and lets Claudux invoke the authenticated,
configured Codex CLI. The helper changes only the fixture API section and
verifies the source, pinned Quick start, and original fixture remain unchanged.

Install Python 3, Node 18+, Bash, ttyd, FFmpeg, and Playwright with Chromium.
From the repository root, run:

```bash
node docs/capture.mjs
```

If Playwright is already installed elsewhere, set `PLAYWRIGHT_MODULE` to its
`index.js` path. The script records the terminal, waits for the demo's success
line, and writes PNG, WebM, MP4, and capture metadata to `docs/public/`.
It stops its ttyd process and browser when finished. Port 8832 must be free.

The paper icon was generated for this project. The bundled Space Grotesk font
is distributed under its [Open Font License](public/OFL.txt).
