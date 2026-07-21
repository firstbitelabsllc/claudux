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
assets/              Static assets (banner SVG)
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

claudux installs straight from GitHub — no registry, no publish step. A release is just a tag that `install.sh` (`CLAUDUX_REF`) and `npx github:firstbitelabsllc/claudux` can pin to.

```bash
# 1. Bump version in package.json and update CHANGELOG.md
# 2. Commit, then verify the tag matches package.json before pushing:
test "vX.Y.Z" = "v$(node -p "require('./package.json').version")" && echo OK
# 3. Tag and push:
git tag vX.Y.Z && git push origin main --tags
```

Because those install paths resolve a git ref the moment it exists, a tag is installable as soon as it's pushed — CI runs after the fact, so verify locally first. If a bad tag slips through, delete it (`git push origin :refs/tags/vX.Y.Z && git tag -d vX.Y.Z`) and cut a corrected one.

Users pin a tag via `curl … | CLAUDUX_REF=vX.Y.Z sh` or `npx github:firstbitelabsllc/claudux#vX.Y.Z`. `docs.yml` deploys the VitePress site to GitHub Pages on every push to `main`.

### Learn more

- [Commands reference](https://firstbitelabsllc.github.io/claudux/guide/commands) (live docs)
- [README](./README.md)

By contributing, you agree to the MIT license.
