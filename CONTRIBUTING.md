## Contributing to Claudux

Thanks for your interest in contributing! This project welcomes improvements of all sizes.

### Local setup

```bash
git clone https://github.com/firstbitelabsllc/claudux.git
cd claudux
npm link            # symlink for local dev
claudux check       # verify environment
claudux update      # generate docs
claudux serve       # preview at localhost:5173
```

### Project layout

```
bin/claudux          CLI entry point (bash)
lib/                 Library modules (colors, project detection, docs generation, etc.)
lib/codex-utils.sh   Codex backend adapter (loaded when CLAUDUX_BACKEND=codex)
lib/templates/       Per-framework prompt configs (React, Next.js, iOS, Go, etc.)
lib/vitepress/       VitePress scaffolding (config template, theme, vite config)
tests/               Pure-bash test suites (zero runtime deps)
docs/                Generated VitePress site (committed to repo)
assets/              Static assets (banner SVG, terminal demo, hero image)
.github/             CI workflows and issue/PR templates
```

### Code style

- Shell scripts should be POSIX-friendly where possible
- Keep functions small and descriptive
- Prefer clear output and stable UX over cleverness

### Pull requests

- Describe the problem, the approach, and screenshots if UI/UX changes
- Update docs if behavior changes
- Keep diffs focused; small and frequent PRs are easier to review

### Release process

claudux is distributed straight from GitHub — there is no npm registry package and no publish step. A release is just a tag: the install script (`CLAUDUX_REF`) and `npx github:firstbitelabsllc/claudux` fetch whatever ref you point them at.

1. Bump `version` in `package.json`
2. Update `CHANGELOG.md` with the new version's changes
3. Commit: `git commit -m "release: vX.Y.Z"`
4. Tag: `git tag vX.Y.Z`
5. Push: `git push origin main --tags`

What happens automatically:
- `ci.yml` runs lint, structure, syntax, version, and test jobs on every push/PR
- `docs.yml` deploys the VitePress site to GitHub Pages on push to main

Users on the tag get it via `CLAUDUX_REF=vX.Y.Z curl … | sh` or `npx github:firstbitelabsllc/claudux#vX.Y.Z`. No registry, no tokens, no secrets.

### Learn more

- [Commands reference](https://firstbitelabsllc.github.io/claudux/guide/commands) (live docs)
- [README](./README.md)

By contributing, you agree to the MIT license.
