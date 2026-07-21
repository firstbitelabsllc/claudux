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

claudux is distributed straight from GitHub — there is no npm registry package and no publish step. A release is just a tag: the install script (`CLAUDUX_REF`) and `npx github:firstbitelabsllc/claudux` fetch whatever ref you point them at. Because those paths resolve a git ref the moment it exists, **a tag is installable as soon as it's pushed** — CI runs *after* the ref is already public and cannot gate it. So verify the version locally before you push, and delete any tag that turns out to be wrong.

1. Bump `version` in `package.json`
2. Update `CHANGELOG.md` with the new version's changes
3. Commit: `git commit -m "release: vX.Y.Z"`
4. Verify locally that the tag matches `package.json` before pushing:
   ```bash
   test "vX.Y.Z" = "v$(node -p "require('./package.json').version")" && echo OK
   ```
5. Tag: `git tag vX.Y.Z`
6. Push: `git push origin main --tags`

If you push a mismatched or otherwise bad tag, it is already installable — **delete it immediately** and cut a corrected one:

```bash
git push origin :refs/tags/vX.Y.Z   # remove the remote tag
git tag -d vX.Y.Z                    # remove it locally
```

What happens automatically:
- `ci.yml` runs lint, structure, syntax, version, and test jobs on every push/PR, and also on `v*` tag pushes — where it additionally flags a tag that doesn't match the `package.json` version. This runs *after* the ref already exists, so treat it as a post-push alarm (delete the bad tag), not a gate that prevents a bad ref from resolving.
- `docs.yml` deploys the VitePress site to GitHub Pages on push to main

Users on the tag get it via `curl … | CLAUDUX_REF=vX.Y.Z sh` or `npx github:firstbitelabsllc/claudux#vX.Y.Z`. No registry, no tokens, no secrets. (The assignment goes on the `sh` side of the pipe so the installer actually receives it; on the `curl` side it would apply only to `curl` and the installer would fall back to `main`.)

### Learn more

- [Commands reference](https://firstbitelabsllc.github.io/claudux/guide/commands) (live docs)
- [README](./README.md)

By contributing, you agree to the MIT license.
