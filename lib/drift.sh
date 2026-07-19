#!/bin/bash
# claudux drift — deterministic doc/code drift gate.
#
# Pure parse -> hash -> compare -> exit. No AI, no network, runs offline in CI.
# The gate reads a committed lockfile (docs-drift-lock.json) and the working tree,
# and fails (exit 1) when a source file a doc section documents changed but the
# doc side did not. It never writes .claudux/index/ — it is non-mutating.
#
# AI stays out of the pass/fail path. It only ever suggests a fix AFTER a
# deterministic flag, never on the critical path.

# Committed, timestamp-free baseline. Un-ignored in .gitignore (see repo root).
# .claudux-state.json and .claudux/index/ stay local; the gate must not depend on
# them or a fresh CI runner would find nothing and pass green forever.
DRIFT_LOCK_FILE="${DRIFT_LOCK_FILE:-docs-drift-lock.json}"

# Resolve effective sensitivity: env override > manifest root key > default.
# Only used when WRITING a new lock; a check always reuses the lock's own value.
drift_sensitivity() {
    local override="${CLAUDUX_DRIFT_SENSITIVITY:-}"
    if [[ -n "$override" ]]; then
        printf '%s' "$override"
        return 0
    fi

    local manifest
    manifest="$(docs_structure_path)"
    if [[ -f "$manifest" ]] && command -v node >/dev/null 2>&1; then
        local val
        val=$(node -e '
          try {
            const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
            const s = m.drift_sensitivity;
            const ok = ["raw", "significant", "surface"];
            process.stdout.write(ok.includes(s) ? s : "significant");
          } catch { process.stdout.write("significant"); }
        ' "$manifest" 2>/dev/null)
        printf '%s' "${val:-significant}"
        return 0
    fi

    printf 'significant'
}

# Single Node entry point shared by write and check so the normalization routine
# (and therefore every hash) is byte-identical on both sides.
#   $1 = mode:   write | check
#   $2 = format: json | human   (check only)
_drift_run_node() {
    local mode="$1" format="${2:-json}"
    local manifest lock_file sensitivity
    manifest="$(docs_structure_path)"
    lock_file="${CLAUDUX_DRIFT_LOCK_FILE:-$DRIFT_LOCK_FILE}"
    sensitivity="$(drift_sensitivity)"

    # LC_ALL=C keeps any downstream ordering byte-stable; our JS sorts are
    # codepoint comparisons so this is belt-and-suspenders.
    LC_ALL=C node - "$mode" "$manifest" "$lock_file" "$sensitivity" "$format" <<'NODE'
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const childProcess = require('child_process');

const mode = process.argv[2];                 // 'write' | 'check'
const manifestPath = process.argv[3];
const lockFile = process.argv[4];
const sensitivityArg = process.argv[5] || 'significant';
const format = process.argv[6] || 'json';     // check only

const LOCK_VERSION = 1;

// ---------------------------------------------------------------------------
// Reused verbatim from lib/docs-manifest.sh and lib/docs-generation.sh.
// Divergence here would break determinism, so these are copied character-for-
// character from their source of truth — do not "improve" them independently.
// ---------------------------------------------------------------------------
function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}
// lib/docs-manifest.sh:376-378
function sha256File(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}
function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
// lib/docs-manifest.sh:1636-1650
function patternToRegExp(pattern) {
  const escaped = pattern
    .replace(/[.+^${}()|[\]\\]/g, '\\$&')
    .replace(/\*\*/g, ' ')
    .replace(/\*/g, '[^/]*')
    .replace(/ /g, '.*');
  return new RegExp(`^${escaped}$`);
}
function matches(pattern, file) {
  if (pattern.endsWith('/**')) {
    return file.startsWith(pattern.slice(0, -3));
  }
  return patternToRegExp(pattern).test(file);
}
// lib/docs-manifest.sh:568-586 — extension -> comment-leader map
function protectionMarkersFor(filePath) {
  const ext = path.extname(filePath).toLowerCase().replace(/^\./, '');
  if (['md', 'markdown', 'html', 'xml', 'vue'].includes(ext)) {
    return { start: '<!-- skip -->', end: '<!-- /skip -->' };
  }
  if (['swift', 'js', 'ts', 'jsx', 'tsx', 'java', 'c', 'cpp', 'h', 'hpp', 'rs', 'go'].includes(ext)) {
    return { start: '// skip', end: '// /skip' };
  }
  if (['py', 'sh', 'bash', 'zsh', 'rb', 'pl'].includes(ext)) {
    return { start: '# skip', end: '# /skip' };
  }
  if (['css', 'scss', 'sass', 'less'].includes(ext)) {
    return { start: '/* skip */', end: '/* /skip */' };
  }
  if (ext === 'sql') {
    return { start: '-- skip', end: '-- /skip' };
  }
  return { start: '# skip', end: '# /skip' };
}
// lib/docs-generation.sh:45-67 — the CHECKPOINT section-hash algorithm.
// Keeps the heading line and does NOT trim, unlike the guard's sectionBodyDigest.
function sectionHash(pagePath, section) {
  if (!section || !section.heading || !section.level || !fs.existsSync(pagePath)) {
    return null;
  }

  const lines = fs.readFileSync(pagePath, 'utf8').split(/\r?\n/);
  const headingPattern = new RegExp(
    `^#{${section.level}}\\s+${escapeRegExp(section.heading)}(?:\\s+\\{#[^}]+\\})?\\s*$`
  );
  const start = lines.findIndex(line => headingPattern.test(line));
  if (start === -1) return null;

  let end = lines.length;
  for (let i = start + 1; i < lines.length; i += 1) {
    const match = lines[i].match(/^(#{1,6})\s+/);
    if (match && match[1].length <= section.level) {
      end = i;
      break;
    }
  }

  return sha256(lines.slice(start, end).join('\n'));
}
// lib/docs-manifest.sh:444-453 / 513-537 — for `surface` sensitivity only.
function isShellLikeFile(filePath) {
  if (filePath === 'bin/claudux' || filePath.endsWith('.sh') || filePath.endsWith('.bash') || filePath.endsWith('.zsh')) {
    return true;
  }
  try {
    return /^#!.*\b(?:bash|sh|zsh)\b/.test(fs.readFileSync(filePath, 'utf8').split(/\r?\n/, 1)[0] || '');
  } catch {
    return false;
  }
}
function shellFunctionExports(filePath) {
  if (!isShellLikeFile(filePath)) return [];
  const content = fs.readFileSync(filePath, 'utf8');
  return content
    .split(/\r?\n/)
    .map(line => line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{/))
    .filter(Boolean)
    .map(match => ({ file: filePath, name: match[1], kind: 'shell-function' }));
}
function cliCommandsFromBin(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const content = fs.readFileSync(filePath, 'utf8');
  const commands = new Set();
  for (const line of content.split(/\r?\n/)) {
    const match = line.match(/^\s*((?:"[^"]+"|'[^']+'|[A-Za-z0-9_-]+)(?:\|(?:"[^"]+"|'[^']+'|[A-Za-z0-9_-]+))*)\)/);
    if (!match) continue;
    for (const raw of match[1].split('|')) {
      const command = raw.replace(/^['"]|['"]$/g, '');
      if (command && command !== '*' && command !== '""') commands.add(command);
    }
  }
  return [...commands].sort();
}

// ---------------------------------------------------------------------------
// Tracked source-file discovery — mirrors build_static_analysis_index's filter
// (git ls-files, excluding docs/, .claudux/, node_modules). Reasoning about
// committed content means git ls-files, not a worktree scan; on a fresh CI
// checkout the working tree equals the committed blob.
// ---------------------------------------------------------------------------
function trackedFiles() {
  try {
    const output = childProcess.execFileSync('git', ['ls-files', '-z'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    return output.split('\0').filter(Boolean).sort();
  } catch {
    return [];
  }
}
function isSourceFile(file) {
  if (file.startsWith('docs/')) return false;
  if (file.startsWith('.claudux/')) return false;
  if (file.includes('/node_modules/')) return false;
  try {
    return fs.existsSync(file) && fs.statSync(file).isFile();
  } catch {
    return false;
  }
}
function gitHeadSha() {
  try {
    return childProcess
      .execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
      .trim();
  } catch {
    return 'unknown';
  }
}

// Codepoint-stable comparator (locale-independent, unlike localeCompare).
function byKey(keyFn) {
  return (a, b) => {
    const ka = keyFn(a);
    const kb = keyFn(b);
    if (ka < kb) return -1;
    if (ka > kb) return 1;
    return 0;
  };
}

// ---------------------------------------------------------------------------
// Shared normalization — the signal-quality knob. Runs on BOTH sides so a
// significant-mode hash is byte-identical whether it lands in the lock or is
// recomputed by the gate.
// ---------------------------------------------------------------------------
function lineCommentLeader(filePath) {
  // Derive the line-comment prefix from the skip-marker map: '# skip' -> '#',
  // '// skip' -> '//', '-- skip' -> '--', '/* skip */' -> '/*'.
  return protectionMarkersFor(filePath).start.split(/\s+/)[0];
}
function normalizedSourceHash(filePath, sensitivity) {
  if (sensitivity === 'surface') {
    // Owned-symbol signatures only. Shell repos: function names (+ CLI commands
    // for bin/claudux). Empty/constant for non-shell files — opt-in by design.
    const symbols = shellFunctionExports(filePath).map(s => s.name).sort();
    const extras = filePath === 'bin/claudux' ? cliCommandsFromBin(filePath) : [];
    return sha256(JSON.stringify({ symbols, cli_commands: extras }));
  }

  let raw;
  try {
    raw = fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
  const text = raw.replace(/\r\n/g, '\n'); // CRLF-normalize before every hash

  if (sensitivity === 'raw') {
    return sha256(text);
  }

  // significant (default): drop blank lines + full-line comments, collapse
  // inline whitespace. Kills the dominant false-positive class (comment/blank/
  // reindent churn) while still firing on renamed flags, changed defaults,
  // changed literal strings, and added/removed logic.
  const leader = lineCommentLeader(filePath);
  const kept = [];
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (trimmed === '') continue;
    if (leader && trimmed.startsWith(leader)) continue;
    kept.push(trimmed.replace(/\s+/g, ' '));
  }
  return sha256(kept.join('\n'));
}
function pageBodyHash(filePath) {
  // Whole-page baseline: covers the 16 section-less pages that declare
  // source_patterns at page level and have no checkpoint section hash.
  if (!fs.existsSync(filePath)) return null;
  const raw = fs.readFileSync(filePath, 'utf8').replace(/\r\n/g, '\n');
  return sha256(raw);
}

// ---------------------------------------------------------------------------
// Build the current snapshot (coverage edges + doc hashes + source fingerprints)
// from the manifest and working tree. Used by write (to persist) and check (to
// compare against the lock).
// ---------------------------------------------------------------------------
function buildSnapshot(sensitivity) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const pages = Array.isArray(manifest.pages) ? manifest.pages : [];

  const coverage = [];    // {source_pattern, page_id, section_id, path}
  const docSections = [];  // {path, page_id, section_id, heading, level, sha256}
  const docPages = [];     // {path, page_id, sha256}

  for (const page of pages) {
    const pageId = page.id;
    const pagePath = page.path;

    for (const pattern of page.source_patterns || []) {
      coverage.push({ source_pattern: pattern, page_id: pageId, section_id: null, path: pagePath });
    }

    const ph = pageBodyHash(pagePath);
    if (ph) docPages.push({ path: pagePath, page_id: pageId, sha256: ph });

    for (const section of page.sections || []) {
      for (const pattern of section.source_patterns || []) {
        coverage.push({ source_pattern: pattern, page_id: pageId, section_id: section.id, path: pagePath });
      }
      const digest = sectionHash(pagePath, { heading: section.heading, level: section.level });
      if (digest) {
        docSections.push({
          path: pagePath,
          page_id: pageId,
          section_id: section.id,
          heading: section.heading,
          level: section.level,
          sha256: digest,
        });
      }
    }
  }

  const tracked = trackedFiles().filter(isSourceFile);
  const matchedSet = new Set();
  for (const edge of coverage) {
    for (const f of tracked) {
      if (matches(edge.source_pattern, f)) matchedSet.add(f);
    }
  }
  const sourceFingerprints = [...matchedSet]
    .sort()
    .map(p => ({ path: p, sha256: normalizedSourceHash(p, sensitivity) }))
    .filter(fp => fp.sha256 !== null);

  coverage.sort(byKey(e => `${e.source_pattern} ${e.page_id} ${e.section_id || ''} ${e.path}`));
  docSections.sort(byKey(s => `${s.path} ${s.section_id}`));
  docPages.sort(byKey(p => `${p.path} ${p.page_id}`));

  return { manifest, coverage, docSections, docPages, sourceFingerprints, tracked };
}

function emit(report, code) {
  if (format === 'human') {
    printHuman(report);
  } else {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  }
  process.exit(code);
}

function printHuman(report) {
  const shortBaseline = report.baseline ? String(report.baseline).slice(0, 12) : 'none';
  console.log(`claudux drift — sensitivity=${report.sensitivity}, baseline=${shortBaseline}`);

  const noBaseline = report.skipped.some(s => s.reason === 'no-baseline');
  if (noBaseline) {
    console.log('No baseline lock found (docs-drift-lock.json).');
    console.log("Run 'claudux drift --accept' to create one.");
    return;
  }

  if (report.ready) {
    console.log('✅ Docs match code. No drift detected.');
  } else {
    const n = report.drifted.length;
    console.log(`❌ Drift detected: ${n} doc ${n === 1 ? 'unit' : 'units'} out of date. The code moved; the doc didn't.`);
    console.log('');
    for (const d of report.drifted) {
      const where = d.section_id ? `${d.doc_file} § ${d.heading || d.section_id}` : d.doc_file;
      const sources = d.changed_sources.join(', ');
      console.log(`  ${where} (page: ${d.page_id})`);
      console.log(`    documents ${sources}, which changed.`);
      console.log(`    Update the doc, or run 'claudux drift --accept' to re-baseline.`);
    }
  }

  if (report.new_sources.length) {
    console.log('');
    console.log(`New source(s) matched a documented pattern (no baseline to diff — review, not a failure):`);
    for (const n of report.new_sources) {
      console.log(`  ${n.source}  [${n.patterns.join(', ')}]`);
    }
  }

  if (report.skipped.length) {
    console.log('');
    for (const s of report.skipped) {
      console.log(`  skipped: ${s.reason}${s.detail ? ` — ${s.detail}` : ''}`);
    }
  }
}

// ===========================================================================
// WRITE — persist the baseline lock. Deterministic; no timestamps, no backend.
// ===========================================================================
if (mode === 'write') {
  const snap = buildSnapshot(sensitivityArg);
  const lock = {
    version: LOCK_VERSION,
    head_sha: gitHeadSha(),
    manifest_hash: sha256File(manifestPath),
    drift_sensitivity: sensitivityArg,
    source_fingerprints: snap.sourceFingerprints,
    doc_section_hashes: snap.docSections,
    doc_page_hashes: snap.docPages,
    source_to_section_coverage: snap.coverage,
  };
  fs.writeFileSync(lockFile, `${JSON.stringify(lock, null, 2)}\n`);
  console.log(
    `[claudux:drift] wrote ${lockFile} (${lock.source_fingerprints.length} source fingerprints, ` +
    `${lock.doc_section_hashes.length} sections, ${lock.doc_page_hashes.length} pages, sensitivity=${sensitivityArg})`
  );
  process.exit(0);
}

// ===========================================================================
// CHECK — the gate. Read the lock + working tree, compare, exit.
// ===========================================================================
function report(partial) {
  return {
    command: 'claudux drift',
    sensitivity: partial.sensitivity !== undefined ? partial.sensitivity : null,
    baseline: partial.baseline !== undefined ? partial.baseline : null,
    head_sha: gitHeadSha(),
    ready: partial.ready,
    drifted: partial.drifted || [],
    new_sources: partial.new_sources || [],
    skipped: partial.skipped || [],
  };
}

// First run: no lock -> never a false fail.
if (!fs.existsSync(lockFile)) {
  emit(
    report({
      ready: true,
      skipped: [{ reason: 'no-baseline', detail: "run 'claudux drift --accept' to create docs-drift-lock.json" }],
    }),
    0
  );
}

let lock;
try {
  lock = JSON.parse(fs.readFileSync(lockFile, 'utf8'));
} catch (error) {
  // Corrupt lock: env error, never a false pass.
  emit(report({ ready: false, skipped: [{ reason: 'corrupt-lock', detail: String((error && error.message) || error) }] }), 2);
}

const lockSensitivity = lock.drift_sensitivity || sensitivityArg;

let snap;
try {
  snap = buildSnapshot(lockSensitivity);
} catch (error) {
  emit(
    report({
      sensitivity: lockSensitivity,
      baseline: lock.head_sha || null,
      ready: false,
      skipped: [{ reason: 'manifest-error', detail: String((error && error.message) || error) }],
    }),
    2
  );
}

const lockFpByPath = new Map((lock.source_fingerprints || []).map(fp => [fp.path, fp.sha256]));
const curFpByPath = new Map(snap.sourceFingerprints.map(fp => [fp.path, fp.sha256]));
const curTrackedSet = new Set(snap.tracked);
const lockSectionByKey = new Map((lock.doc_section_hashes || []).map(s => [`${s.page_id} ${s.section_id}`, s]));
const lockPageByKey = new Map((lock.doc_page_hashes || []).map(p => [p.page_id, p]));
const curSectionByKey = new Map(snap.docSections.map(s => [`${s.page_id} ${s.section_id}`, s]));
const curPageByKey = new Map(snap.docPages.map(p => [p.page_id, p]));

const driftedMap = new Map(); // `${path} ${section_id||''}` -> entry
const newSources = new Map(); // path -> Set(patterns)
const skipped = [];

for (const edge of lock.source_to_section_coverage || []) {
  const pattern = edge.source_pattern;
  const changed = new Set();

  // Currently-tracked files matching the pattern.
  for (const f of snap.tracked) {
    if (!matches(pattern, f)) continue;
    const lockFp = lockFpByPath.get(f);
    if (lockFp === undefined) {
      if (!newSources.has(f)) newSources.set(f, new Set());
      newSources.get(f).add(pattern);
      continue;
    }
    if (curFpByPath.get(f) !== lockFp) changed.add(f);
  }

  // Deletions: baseline fingerprints for this pattern that are gone now.
  for (const [p] of lockFpByPath) {
    if (!matches(pattern, p)) continue;
    if (!curTrackedSet.has(p)) changed.add(p);
  }

  if (changed.size === 0) continue;

  // Doc side.
  let lockDocHash;
  let curDocHash;
  let heading = null;
  if (edge.section_id) {
    const lockS = lockSectionByKey.get(`${edge.page_id} ${edge.section_id}`);
    if (!lockS) {
      skipped.push({ reason: 'section-missing-in-lock', detail: `${edge.page_id}#${edge.section_id}` });
      continue;
    }
    heading = lockS.heading;
    lockDocHash = lockS.sha256;
    const curS = curSectionByKey.get(`${edge.page_id} ${edge.section_id}`);
    curDocHash = curS ? curS.sha256 : null; // null => heading changed/removed => doc changed
  } else {
    const lockP = lockPageByKey.get(edge.page_id);
    if (!lockP) {
      skipped.push({ reason: 'page-missing-in-lock', detail: edge.page_id });
      continue;
    }
    lockDocHash = lockP.sha256;
    const curP = curPageByKey.get(edge.page_id);
    curDocHash = curP ? curP.sha256 : null;
  }

  const docUnchanged = curDocHash !== null && curDocHash === lockDocHash;
  if (!docUnchanged) continue; // author touched the doc -> not drift

  const dkey = `${edge.path} ${edge.section_id || ''}`;
  if (!driftedMap.has(dkey)) {
    driftedMap.set(dkey, {
      doc_file: edge.path,
      page_id: edge.page_id,
      section_id: edge.section_id || null,
      heading,
      changed_sources: new Set(),
      doc_hash_unchanged: true,
    });
  }
  const entry = driftedMap.get(dkey);
  for (const c of changed) entry.changed_sources.add(c);
}

const drifted = [...driftedMap.values()]
  .map(d => ({
    doc_file: d.doc_file,
    page_id: d.page_id,
    section_id: d.section_id,
    heading: d.heading,
    changed_sources: [...d.changed_sources].sort(),
    doc_hash_unchanged: d.doc_hash_unchanged,
  }))
  .sort(byKey(d => `${d.doc_file} ${d.section_id || ''}`));

const newSourcesOut = [...newSources.entries()]
  .map(([source, patterns]) => ({ source, patterns: [...patterns].sort() }))
  .sort(byKey(n => n.source));

const skippedOut = skipped
  .filter((s, i, all) => all.findIndex(x => x.reason === s.reason && x.detail === s.detail) === i)
  .sort(byKey(s => `${s.reason} ${s.detail || ''}`));

emit(
  report({
    sensitivity: lockSensitivity,
    baseline: lock.head_sha || null,
    ready: drifted.length === 0,
    drifted,
    new_sources: newSourcesOut,
    skipped: skippedOut,
  }),
  drifted.length === 0 ? 0 : 1
);
NODE
}

# Re-baseline: rewrite docs-drift-lock.json from the current tree. No AI.
save_drift_lock() {
    if ! command -v node >/dev/null 2>&1; then
        warn "Cannot write drift lock: Node is unavailable."
        return 1
    fi
    local manifest
    manifest="$(docs_structure_path)"
    if [[ ! -f "$manifest" ]]; then
        warn "Cannot write drift lock: manifest ($manifest) is missing."
        return 1
    fi
    _drift_run_node write
}

# Keep an ALREADY-ADOPTED drift lock in lockstep with regenerated docs. Called
# from the 'claudux update' flow so the committed baseline never goes stale
# behind a doc regeneration: without this, an 'update' that changes both a
# covered source and its doc leaves the lock on the OLD doc hash, and every later
# source-only edit to that unit slips past the gate (its doc hash stays != the
# stale lock). This makes the README promise that 'claudux update' refreshes the
# lock actually true. Adoption itself stays explicit via 'claudux drift --accept';
# this only refreshes a lock that already exists, and is always best-effort so a
# lock-write hiccup never fails generation.
refresh_drift_lock_if_adopted() {
    local lock_file="${CLAUDUX_DRIFT_LOCK_FILE:-$DRIFT_LOCK_FILE}"
    [[ -f "$lock_file" ]] || return 0
    if ! save_drift_lock >/dev/null 2>&1; then
        warn "Could not refresh ${lock_file}; run 'claudux drift --accept' to re-baseline."
    fi
    return 0
}

# The gate. Prints a report ($1 = json|human) and returns:
#   0 = no drift / no baseline / degraded (Node absent)
#   1 = drift detected
#   2 = corrupt lock / manifest error (env error, never a false pass)
verify_doc_code_drift() {
    local format="${1:-human}"

    if ! command -v node >/dev/null 2>&1; then
        if [[ "$format" == "json" ]]; then
            printf '%s\n' '{"command":"claudux drift","sensitivity":null,"baseline":null,"head_sha":null,"ready":true,"drifted":[],"new_sources":[],"skipped":[{"reason":"node-unavailable"}]}'
        else
            info "drift check skipped: Node unavailable (the deterministic gate needs Node)."
        fi
        return 0
    fi

    local out rc
    out=$(_drift_run_node check "$format")
    rc=$?
    printf '%s\n' "$out"
    return $rc
}

# Command entry: claudux drift [--json] [--warn-only] [--accept]
claudux_drift() {
    local output_json=false warn_only=false accept=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                output_json=true
                shift
                ;;
            --warn-only)
                warn_only=true
                shift
                ;;
            --accept)
                accept=true
                shift
                ;;
            -h|--help)
                cat <<'EOF'
Usage: claudux drift [--json] [--warn-only] [--accept]

Deterministic doc/code drift gate. No AI, no network — parse, hash, compare, exit.
Fails (exit 1) when a source file a doc section documents changed but the doc did not.

  --json        Emit machine-readable JSON (CI-parseable).
  --warn-only   Always exit 0 (local pre-commit advisory).
  --accept      Re-baseline: rewrite docs-drift-lock.json from the current tree (no AI).
EOF
                return 0
                ;;
            *)
                error_exit "Unknown option for 'drift': $1. Usage: claudux drift [--json] [--warn-only] [--accept]" 2
                ;;
        esac
    done

    load_project_config

    if $accept; then
        # Deterministic re-baseline, mirroring what `claudux update` refreshes.
        if declare -F build_static_analysis_index >/dev/null 2>&1; then
            build_static_analysis_index >/dev/null 2>&1 || true
        fi
        if declare -F capture_docs_structure_guard_snapshot >/dev/null 2>&1; then
            capture_docs_structure_guard_snapshot >/dev/null 2>&1 || true
        fi
        save_drift_lock >/dev/null || error_exit "Failed to write ${DRIFT_LOCK_FILE}"
        success "Re-baselined drift lock → ${DRIFT_LOCK_FILE}"
        return 0
    fi

    local format="human"
    $output_json && format="json"

    local rc
    verify_doc_code_drift "$format"
    rc=$?

    if $warn_only; then
        return 0
    fi
    return $rc
}
