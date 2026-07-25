## claudux repository guardrails (evergreen)

- This file is not user-facing documentation. Keep it short and evergreen.
- `docs/**` is HAND-MAINTAINED and hand-committed. It is not regenerated on a
  schedule and `claudux update` is not part of the contributor loop. Fix a docs
  page by editing it. Do not duplicate procedural docs into this file.
- Single source of truth for docs generation lives under `lib/**`:
  - `lib/docs-generation.sh` — prompt building and two-phase generation flow
  - `lib/templates/**` — project-type templates and content scaffolds
  - `lib/vitepress/**` — VitePress config/templates used during build
  - `lib/ui.sh` — CLI help/menu text surfaced to users
- `claudux update` on THIS repo will rewrite hand-written pages. Run it only when
  you intend to regenerate, and review the diff before committing.
- Core conventions: Bash-first, snake_case, strict mode (`set -u` and `set -o pipefail`), check command availability, keep `bin/claudux` as a router only.
- Safety: cleanup only removes stale generated docs; never touch source code. Respect protected paths configured in `lib/content-protection.sh`.
- Deployment base: local/dev uses `process.env.DOCS_BASE || '/'`; CI sets `DOCS_BASE=/claudux/` for Pages.

If content becomes procedural, versioned, or command-specific, move it into generators/templates under `lib/**` so the docs stay consistent and up to date.