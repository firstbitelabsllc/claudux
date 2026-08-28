# Project Profiles

Claudux ships project-type JSON files under `lib/templates/`. Their job is
narrow: the generation prompt tells the backend to read the selected file for
framework-specific context and suggested documentation focus.

They are **project profiles**, not a deterministic template engine.

## What a profile does

A profile can influence model-authored documentation by describing:

- Project type and common technology assumptions
- Files and directories worth inspecting
- Suggested documentation focus areas
- A possible navigation shape
- Testing, packaging, and deployment concepts that may be relevant

Those values are prompt context. The backend must still inspect the actual
repository, and the generated result still needs review.

## What a profile does not do

Claudux does not:

- Parse profile fields into a validated runtime schema
- Render Markdown pages from profile JSON
- Deterministically create the profile's suggested sidebar
- Execute `conditional_sections`
- Perform variable substitution inside profile JSON
- Reject unknown profile fields
- Verify that referenced frameworks or files exist
- Use `ai.default_model` or `ai.fast_model` to select the runtime model

Model selection comes from environment and project configuration:

```text
Claude: FORCE_MODEL -> claudux.json project.model -> sonnet
Codex:  CODEX_MODEL and CODEX_REASONING_EFFORT
```

## Selection order

For a detected or configured type such as `react`, the generation prompt uses
the first file that exists:

1. `lib/templates/react/config.json`
2. `lib/templates/react-project-config.json`
3. `lib/templates/react-config.json`
4. `lib/templates/generic/config.json`

This order matters because the repository currently contains both directory
and flat naming styles for some project types.

## Project-type resolution

`lib/project.sh` first reads `project.type` from `claudux.json` or the legacy
flat type from `.claudux.json`.

Accepted built-in values are:

```text
ios
nextjs
react
nodejs
javascript
rust
python
go
java
generic
```

An additional type is accepted when
`lib/templates/<type>-project-config.json` exists. Otherwise claudux warns and
falls back to file-based detection.

Detection currently checks, in order:

- Xcode project or workspace markers
- Next.js configuration or dependency
- React dependency
- Node type dependency
- Generic `package.json`
- Cargo
- Python package markers
- Go module
- Maven or Gradle
- Generic fallback

Because order is significant, a Next.js project is classified before the more
general React check.

## Shell-level project configuration

The main CLI reads only these `claudux.json` values:

```json
{
  "project": {
    "name": "My Project",
    "type": "react",
    "model": "sonnet"
  }
}
```

Do not assume arbitrary `documentation`, `features`, or
`claude_instructions` keys in `claudux.json` are interpreted by the shell.
Use `claudux.md` for free-form documentation preferences that should enter the
generation prompt.

The separate VitePress setup script can also read `deployment.base` and
`deployment.siteUrl` when `jq` is available.

## VitePress scaffolding is separate

`lib/vitepress/setup.sh` is the deterministic scaffolding path. It is not the
JSON project-profile loader.

When invoked by `serve`, setup can:

- Create `docs/.vitepress/config.ts` only when it is missing
- Copy the bundled theme
- Copy isolated Vite and PostCSS configuration
- Detect and copy a logo
- Write `docs/package.json`
- Derive the GitHub Pages base
- Replace a small fixed set of placeholders when those placeholders already
  exist in the VitePress config

The supported config placeholders are implementation-specific:

- `{{PROJECT_NAME}}`
- `{{PROJECT_DESCRIPTION}}`
- `{{LOGO_CONFIG_LINE}}`
- `{{FAVICON_TAG}}`
- `{{SITE_URL}}`

This substitution happens in the VitePress setup script, not in project
profiles or generated Markdown.

## Adding a project profile

1. Add valid JSON at `lib/templates/<type>-project-config.json`, or use the
   directory form `lib/templates/<type>/config.json`.
2. Keep the content advisory: focus areas and plausible defaults, not claims
   that every target repository shares.
3. Set `project.type` in a disposable target while testing.
4. If auto-detection is required, add the specific detector before broader
   fallbacks in `lib/project.sh`.
5. Verify the built prompt points to the expected file.
6. Run the focused tests and a disposable real-target generation.

There is no profile-schema validator today. Use a JSON parser to catch syntax
errors before relying on a new file:

```bash
node -e 'JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"))' \
  lib/templates/mytype-project-config.json
```

## Testing expectations

A profile change is not proven by a successful JSON parse alone. Useful proof
includes:

- Correct project-type detection or explicit type selection
- Correct profile path in the generated prompt
- No runtime-model change from inert profile fields
- A target repository whose generated docs reflect real source facts
- Link validation and VitePress build success

Project profiles guide the backend. The manifest and deterministic validators
remain the enforcement layer.
