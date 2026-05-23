#!/bin/bash
# No-AI documentation readiness audit for humans, CI, and agent handoffs.

claudux_count_lines() {
    local value="${1:-}"
    if [[ -z "$value" ]]; then
        echo "0"
    else
        printf '%s\n' "$value" | sed '/^$/d' | wc -l | tr -d ' '
    fi
}

claudux_manifest_summary() {
    local manifest="$1"

    if [[ ! -f "$manifest" ]] || ! command -v node >/dev/null 2>&1; then
        echo "0	0	0"
        return 0
    fi

    node - "$manifest" <<'NODE'
const fs = require('fs');
const manifestPath = process.argv[2];

let pages = 0;
let sourceOwnedPages = 0;
let pinnedSections = 0;

try {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const allPages = Array.isArray(manifest.pages) ? manifest.pages : [];
  pages = allPages.length;
  sourceOwnedPages = allPages.filter(page =>
    Array.isArray(page.source_patterns) && page.source_patterns.length > 0
  ).length;
  pinnedSections = allPages.reduce((count, page) => {
    const sections = Array.isArray(page.sections) ? page.sections : [];
    return count + sections.filter(section => section.pinned === true).length;
  }, 0);
} catch {
  // Leave counts at zero; manifest validation reports the real error.
}

console.log(`${pages}\t${sourceOwnedPages}\t${pinnedSections}`);
NODE
}

claudux_json_array_from_lines() {
    local value="${1:-}"

    CLAUDUX_JSON_LINES="$value" node <<'NODE'
const lines = (process.env.CLAUDUX_JSON_LINES || '')
  .split(/\r?\n/)
  .map(line => line.trim())
  .filter(Boolean);
process.stdout.write(JSON.stringify(lines));
NODE
}

claudux_audit() {
    local output_json=false
    local strict=false
    local release=false
    local handoff_strict=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                output_json=true
                shift
                ;;
            --strict)
                strict=true
                shift
                ;;
            --release)
                release=true
                strict=true
                shift
                ;;
            --handoff-strict)
                handoff_strict=true
                strict=true
                shift
                ;;
            -h|--help)
                echo "Usage: claudux audit [--json] [--strict] [--release] [--handoff-strict]"
                echo ""
                echo "Print a no-AI documentation readiness report."
                echo "  --json            Emit machine-readable JSON."
                echo "  --strict          Exit non-zero when manifest or link validation fails."
                echo "  --release         Also fail missing docs, docs/config drift, or release metadata drift."
                echo "  --handoff-strict  Also fail missing/stale checkpoints, changed files, or docs/config drift."
                return 0
                ;;
            *)
                error_exit "Unknown option for 'audit': $1. Usage: claudux audit [--json] [--strict] [--release] [--handoff-strict]" 2
                ;;
        esac
    done

    load_project_config

    local repo_root branch head_sha backend docs_present docs_file_count
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    [[ -n "$branch" ]] || branch="detached"
    head_sha=$(git rev-parse --short=12 HEAD 2>/dev/null || echo "unknown")
    backend="${CLAUDUX_BACKEND:-claude}"

    docs_present=false
    docs_file_count=0
    if [[ -d "docs" ]]; then
        docs_present=true
        docs_file_count=$(find docs \
            -path "*/node_modules/*" -prune -o \
            -path "*/.vitepress/dist/*" -prune -o \
            -type f -name "*.md" -print 2>/dev/null | wc -l | tr -d ' ')
    fi

    local manifest manifest_present manifest_status manifest_output
    manifest="$(docs_structure_path)"
    manifest_present=false
    manifest_status="missing"
    manifest_output=""
    if [[ -f "$manifest" ]]; then
        manifest_present=true
        manifest_output=$(validate_docs_structure_manifest --post-generation 2>&1)
        if [[ $? -eq 0 ]]; then
            manifest_status="valid"
        else
            manifest_status="invalid"
        fi
    fi

    local manifest_summary manifest_pages manifest_source_owned_pages manifest_pinned_sections
    manifest_summary=$(claudux_manifest_summary "$manifest")
    IFS=$'\t' read -r manifest_pages manifest_source_owned_pages manifest_pinned_sections <<< "$manifest_summary"

    local link_status link_output
    link_status="skipped"
    link_output=""
    if [[ -d "docs" ]] && [[ -f "$LIB_DIR/validate-links.sh" ]]; then
        link_output=$("$LIB_DIR/validate-links.sh" 2>&1)
        if [[ $? -eq 0 ]]; then
            link_status="valid"
        else
            link_status="invalid"
        fi
    fi

    local checkpoint_status checkpoint_output changed_files changed_count
    checkpoint_status="missing"
    checkpoint_output=""
    changed_files=""
    if [[ -f "$STATE_FILE" ]]; then
        checkpoint_output=$(claudux_status 2>&1)
        if [[ $? -eq 0 ]]; then
            checkpoint_status="fresh"
        else
            checkpoint_status="stale"
        fi
    fi
    if ! changed_files=$(claudux_diff_since_last 2>/dev/null); then
        changed_files=""
    fi
    changed_count=$(claudux_count_lines "$changed_files")

    local uncommitted_docs uncommitted_docs_count
    uncommitted_docs=$(claudux_docs_worktree_changes 2>/dev/null || true)
    uncommitted_docs_count=$(claudux_count_lines "$uncommitted_docs")

    local strict_failed=false release_failed=false handoff_failed=false lockfile_status package_status metadata_status
    lockfile_status="skipped"
    package_status="skipped"
    metadata_status="skipped"

    if [[ "$manifest_status" == "invalid" ]] || [[ "$link_status" == "invalid" ]]; then
        strict_failed=true
    fi

    if [[ -f "package.json" ]] && [[ -f "package-lock.json" ]] && command -v node >/dev/null 2>&1; then
        if node <<'NODE'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const lock = JSON.parse(fs.readFileSync('package-lock.json', 'utf8'));
const root = (lock.packages && lock.packages['']) || {};
const fields = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'];
for (const field of fields) {
  const expected = JSON.stringify(pkg[field] || {});
  const actual = JSON.stringify(root[field] || {});
  if (expected !== actual) process.exit(1);
}
process.exit(0);
NODE
        then
            lockfile_status="clean"
        else
            lockfile_status="drift"
        fi
    fi

    if [[ -f "package.json" ]] && command -v npm >/dev/null 2>&1; then
        if npm pack --dry-run >/dev/null 2>&1; then
            package_status="packable"
        else
            package_status="failed"
        fi
    fi

    if [[ -f "package.json" ]] && command -v node >/dev/null 2>&1; then
        if node <<'NODE'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
if (pkg.name !== 'claudux') process.exit(0);
const checks = [
  pkg.repository && String(pkg.repository.url || '').includes('github.com/firstbitelabsllc/claudux'),
  String(pkg.homepage || '').includes('github.com/firstbitelabsllc/claudux'),
  pkg.bugs && String(pkg.bugs.url || '').includes('github.com/firstbitelabsllc/claudux/issues'),
];
process.exit(checks.every(Boolean) ? 0 : 1);
NODE
        then
            metadata_status="valid"
        else
            metadata_status="invalid"
        fi
    fi

    if [[ "$manifest_status" != "valid" ]] ||
        [[ "$link_status" != "valid" ]] ||
        [[ "$docs_present" != "true" ]] ||
        [[ "$docs_file_count" -eq 0 ]] ||
        [[ "$uncommitted_docs_count" -gt 0 ]] ||
        [[ "$lockfile_status" == "drift" ]] ||
        [[ "$package_status" == "failed" ]] ||
        [[ "$metadata_status" == "invalid" ]]; then
        release_failed=true
    fi

    if [[ "$manifest_status" != "valid" ]] ||
        [[ "$link_status" != "valid" ]] ||
        [[ "$checkpoint_status" != "fresh" ]] ||
        [[ "$changed_count" -gt 0 ]] ||
        [[ "$uncommitted_docs_count" -gt 0 ]]; then
        handoff_failed=true
    fi

    if $release && $release_failed; then
        strict_failed=true
    fi
    if $handoff_strict && $handoff_failed; then
        strict_failed=true
    fi

    if $output_json; then
        local changed_json uncommitted_json
        changed_json=$(claudux_json_array_from_lines "$changed_files")
        uncommitted_json=$(claudux_json_array_from_lines "$uncommitted_docs")

        node - \
            "$PROJECT_NAME" "$PROJECT_TYPE" "$repo_root" "$branch" "$head_sha" "$backend" \
            "$docs_present" "$docs_file_count" "$manifest" "$manifest_present" "$manifest_status" \
            "$manifest_pages" "$manifest_source_owned_pages" "$manifest_pinned_sections" \
            "$link_status" "$checkpoint_status" "$changed_count" "$uncommitted_docs_count" \
            "$strict_failed" "$release_failed" "$handoff_failed" "$release" "$handoff_strict" \
            "$lockfile_status" "$package_status" "$metadata_status" "$changed_json" "$uncommitted_json" <<'NODE'
const [
  projectName, projectType, repoRoot, branch, headSha, backend,
  docsPresent, docsFileCount, manifestPath, manifestPresent, manifestStatus,
  manifestPages, manifestSourceOwnedPages, manifestPinnedSections,
  linkStatus, checkpointStatus, changedCount, uncommittedDocsCount,
  strictFailed, releaseFailed, handoffFailed, releaseMode, handoffStrictMode,
  lockfileStatus, packageStatus, metadataStatus, changedJson, uncommittedJson,
] = process.argv.slice(2);

const report = {
  command: 'claudux audit',
  mode: releaseMode === 'true' ? 'release' : handoffStrictMode === 'true' ? 'handoff-strict' : 'standard',
  project: {
    name: projectName,
    type: projectType,
    root: repoRoot,
    branch,
    head_sha: headSha,
    backend,
  },
  docs: {
    present: docsPresent === 'true',
    markdown_files: Number(docsFileCount),
    manifest: {
      path: manifestPath,
      present: manifestPresent === 'true',
      status: manifestStatus,
      pages: Number(manifestPages),
      source_owned_pages: Number(manifestSourceOwnedPages),
      pinned_sections: Number(manifestPinnedSections),
    },
    links: {
      status: linkStatus,
    },
    checkpoint: {
      status: checkpointStatus,
      changed_since_checkpoint_count: Number(changedCount),
      changed_since_checkpoint: JSON.parse(changedJson),
      uncommitted_docs_count: Number(uncommittedDocsCount),
      uncommitted_docs: JSON.parse(uncommittedJson),
    },
  },
  release: {
    ready: releaseFailed !== 'true',
    lockfile: lockfileStatus,
    package: packageStatus,
    metadata: metadataStatus,
  },
  handoff: {
    ready: handoffFailed !== 'true',
  },
  ready: strictFailed !== 'true',
};

console.log(JSON.stringify(report, null, 2));
NODE
    else
        echo "Documentation audit"
        echo "-------------------"
        echo "Project:    $PROJECT_NAME ($PROJECT_TYPE)"
        echo "Repo:       $repo_root"
        echo "Branch:     $branch @ $head_sha"
        echo "Backend:    $backend"
        echo ""
        echo "Docs:       $docs_present ($docs_file_count markdown files)"
        echo "Manifest:   $manifest_status ($manifest_pages pages, $manifest_pinned_sections pinned sections)"
        echo "Links:      $link_status"
        echo "Checkpoint: $checkpoint_status"
        echo "Changed:    $changed_count since checkpoint"
        echo "Worktree:   $uncommitted_docs_count uncommitted docs/config changes"
        echo "Release:    lockfile=$lockfile_status package=$package_status metadata=$metadata_status"

        if [[ "$manifest_status" == "invalid" && -n "$manifest_output" ]]; then
            echo ""
            echo "Manifest errors:"
            printf '%s\n' "$manifest_output"
        fi

        if [[ "$link_status" == "invalid" && -n "$link_output" ]]; then
            echo ""
            echo "Link validation errors:"
            printf '%s\n' "$link_output"
        fi
    fi

    if $strict && $strict_failed; then
        if $release; then
            echo "ERROR: release audit failed" >&2
        elif $handoff_strict; then
            echo "ERROR: handoff audit failed" >&2
        fi
        return 1
    fi
    return 0
}
