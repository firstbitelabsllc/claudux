## claudux repository guardrails (evergreen)

- This file is not user-facing documentation. Keep it short and evergreen.
- All docs are generated. Do not duplicate or maintain procedural docs here.
- Single source of truth for docs generation lives under `lib/**`:
  - `lib/docs-generation.sh`: prompt building and two-phase generation flow
  - `lib/templates/**`: project-type templates and content scaffolds
  - `lib/vitepress/**`: VitePress config/templates used during build
  - `lib/ui.sh`: CLI help/menu text surfaced to users
- Do not edit `docs/**` or `docs/.vitepress/**` directly; they are generated artifacts.
- Core conventions: Bash-first, snake_case, strict mode (`set -u` and `set -o pipefail`), check command availability, keep `bin/claudux` as a router only.
- Safety: cleanup only removes stale generated docs; never touch source code. Content protection is enforced by the `docs-structure.json` manifest guards in `lib/docs-manifest.sh` (`lib/content-protection.sh` holds unused utility helpers and is not an enforcement layer).
- Deployment base: local/dev uses `process.env.DOCS_BASE || '/'`; CI sets `DOCS_BASE=/claudux/` for Pages.

If content becomes procedural, versioned, or command-specific, move it into generators/templates under `lib/**` so the docs stay consistent and up to date.

## Code comments

Use names, types and tests to explain code. Do not add narration, section
banners, commented-out code or workaround history. Fix an owned workaround
at its cause; keep behavior changes separate from comment deletion.

Keep license headers, public API contracts, necessary tool or compiler
directives, and non-obvious constraints imposed by a current external
platform, dependency or protocol. Link the relevant issue or specification
when it explains the constraint. Correctness or safety suppressions require
a code fix and focused proof; deleting the directive alone is not a fix.
Change generated or vendored comments through their source owner.
