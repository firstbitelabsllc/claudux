# Content Protection

Claudux protects manually curated content from model modification. This page
says exactly what is mechanically enforced, what is prompt guidance, and how to
tell the difference — so you can decide what to trust it with.

## The two modes

### With a committed `docs-structure.json` (enforced)

The manifest flips generation into its guarded mode:

- The model runs **read-only** (`--allowedTools "Read"`); it proposes
  section-scoped patches and cannot write files itself.
- Code applies patches **all-or-nothing** against the manifest: single-section
  span, impact allowlist, path boundary.
- Skip-marker blocks and pinned sections are **sha256-hashed** in a guard
  snapshot before generation; if a guarded block changed, generation aborts
  with `Protected documentation structure changed during generation`.

This is the mode to use when protection matters. Commit the manifest.

### Without a manifest (guidance)

The first generation pass runs with write access (`Read,Write,Edit,Delete`).
Path rules here are **prompt guidance, not an enforced barrier**: generation
prompts steer the model away from `notes/`, `private/`, secrets, and build
output, and in practice it follows them — but no code checks which files it
writes.

Two things are still mechanically enforced in both modes:

- `Bash` is disallowed, so the backend cannot run shell commands or
  `git commit`.
- Generated docs land via the normal working tree, so `git diff` shows you
  everything before you commit.

## Skip markers

Protect specific blocks within files:

```markdown
<!-- skip -->
This block is hash-guarded in manifest mode.
<!-- /skip -->
```

| Language | Start marker | End marker |
|----------|--------------|------------|
| Markdown / HTML / XML | `<!-- skip -->` | `<!-- /skip -->` |
| JS / TS / Swift / Go / Rust / Java / C++ | `// skip` | `// /skip` |
| Python / shell / Ruby | `# skip` | `# /skip` |
| CSS / SCSS | `/* skip */` | `/* /skip */` |
| SQL | `-- skip` | `-- /skip` |

Markers must sit on their own line. In manifest mode, every skip block's hash
is captured in the guard snapshot, so a silent edit to a protected block fails
the run. Without a manifest, markers are guidance the model is prompted to
respect.

## Best practices

**Commit the manifest.** `docs-structure.json` is what turns protection from
guidance into enforcement. Everything else on this page is secondary.

**Protect only what needs protection.** Wrap the sensitive block, not the whole
file, so the rest of the page keeps getting maintained:

```markdown
## Public API Documentation

This section documents our public API endpoints.

<!-- skip -->
### Internal Debugging Endpoints
These are for development use only...
<!-- /skip -->
```

**Commit your markers** so protection is consistent for everyone who runs
claudux on the repo.

**Review the diff.** Protection narrows what the model can change; it does not
replace reading `git diff docs/` before you commit.

## Removing protection

Delete the marker pair and run `claudux update` — the section becomes
maintainable again. In manifest mode, update the manifest entry if the section
was pinned there.
