# Features Overview

Claudux generates VitePress docs from your codebase with Claude or Codex, and keeps the model on rails so it rewrites wording without reorganizing your docs or touching content you protect.

## Generation Features

### 🔄 Automatic Updates

**Problem**: Documentation becomes stale the moment you ship new code.

**Solution**: Claudux analyzes your actual source code on every run, detecting:
- New functions and APIs
- Changed behavior and patterns  
- Deprecated or removed features
- Updated configuration options

```bash
claudux update  # Always generates current documentation
```

### 🧠 Code Understanding

**Problem**: Generic documentation templates don't capture your project's uniqueness.

**Solution**: Claude AI understands your codebase structure and patterns:
- Analyzes import/export relationships
- Detects architectural patterns (MVC, microservices, etc.)
- Understands framework conventions (React hooks, Express middleware)
- Preserves domain-specific terminology

### ⚡ One-Command Generation

**Problem**: Documentation toolchains are complex and time-consuming.

**Solution**: Single command generates complete sites:

```bash
claudux update  # Generates VitePress site with navigation, search, mobile support
```

**Includes:**
- Responsive navigation structure
- Full-text search
- Mobile-friendly design  
- Auto-generated breadcrumbs
- Dark/light theme toggle

### 🔒 Local Orchestration

**Problem**: Docs tools should be explicit about where orchestration runs and which model backend is used.

**Solution**: Claudux runs as a local CLI and delegates model work to your selected authenticated backend:
- Reads files from your local checkout
- Uses locally installed Claude or Codex CLI
- Processes generated docs in your environment
- Sends prompt context through the selected backend CLI

### 🍰 Low-friction defaults (not zero config)

**Problem**: Documentation tools require extensive setup and maintenance.

**Solution**: Project-type detection plus templates reduce setup — you still
need an authenticated Claude or Codex CLI and a writable docs tree:

```bash
cd any-project
claudux update
```

**Typically detects:**
- Project type hints (React, Python, Go, etc.)
- Common entry points / package manifests
- Existing `docs/` layout when present

Not a promise of zero configuration for every monorepo or unusual layout.

## Advanced Features

### 🔗 Link Validation

Prevents broken documentation with built-in validation:

```bash
claudux update  # Includes automatic link checking
```

**Validates:**
- Internal page references
- Anchor links within pages
- Asset and image references

External URLs are skipped, not fetched — link checking stays offline and deterministic.

**Auto-fix capability:**
```bash
claudux update -m "Fix broken links and create missing pages"
```

### 🛡️ Content Protection

Preserves sensitive or manually curated content:

```markdown
<!-- skip -->
This section won't be modified by claudux
<!-- /skip -->
```

**Automatically protects:**
- `notes/` and `private/` directories
- Environment files (`*.env`, `*.key`)
- Configuration secrets

### 🎯 Focused Updates

Target specific documentation areas:

```bash
claudux update -m "Update API documentation only"
claudux update --with "Add examples for the new authentication flow"
```

### 📱 Project-Specific Optimization

Adapts documentation structure to your project type:

**CLI tools**: Command reference, installation, examples  
**Libraries**: API docs, integration guides, usage patterns  
**Web apps**: Features, deployment, configuration  
**Mobile apps**: Setup, architecture, app store guidelines

## Quality Assurance

### Accuracy — what is (and isn’t) guaranteed

**True today:**
- Write boundaries: structure manifests + section hash / source-boundary checks
- Internal link checks that stay offline (external URLs skipped)
- Protected paths / skip markers for curated content

**Not a product guarantee:**
- Perfect extraction of every signature or example
- Zero placeholders forever
- Automated “accuracy score” of prose

Model output can still be wrong; Claudux refuses silent protected edits and
keeps structure contracts honest.

### Consistency Features

- **Unified navigation**: Sidebar appears on all pages when templates apply
- **Cross-references**: Linking between related concepts when generated
- **Terminology**: Best-effort consistency via prompts + review
- **Styling**: Follows VitePress / project theme defaults

## Next Steps

Explore specific features in detail:

- [Two-Phase Generation →](/features/two-phase-generation)
- [Smart Cleanup →](/features/smart-cleanup)  
- [Content Protection →](/features/content-protection)
