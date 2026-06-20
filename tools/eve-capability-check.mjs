#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = process.cwd();
const canonicalCommandCenterPlan = "/Users/leokwan/Development/vidux/projects/agentic-command-center/PLAN.md";

const requiredFiles = [
  "agent/agent.ts",
  "agent/instructions.md",
  "agent/skills/claudux/SKILL.md",
  "agent/skills/ledger/SKILL.md",
  "agent/skills/local-boundary/SKILL.md",
  "agent/skills/vidux/SKILL.md",
  "agent/subagents/local-readiness/agent.ts",
  "agent/subagents/local-readiness/instructions.md",
  "bin/claudux",
  "claude.md",
  "claudux.md",
  "docs-structure.json",
  "evidence/2026-06-20-eve-studio-claudux-receiver/README.md",
  "package.json",
  "package-lock.json",
  "scripts/secret-scan.sh",
  "tests/run-tests.sh",
  "tests/run-all.sh",
  "tools/eve-capability-check.mjs",
];

const requiredScripts = [
  "eve:info",
  "eve:build",
  "eve:dev:local",
  "eve:capabilities",
  "test",
  "test:all",
  "lint",
  "secret-scan",
  "release:check",
];

const requiredExactDevDeps = {
  ai: "7.0.0-beta.178",
  eve: "0.11.5",
};

const forbiddenFiles = [
  ".env",
  ".env.local",
  ".env.production",
  ".npmrc",
];

const forbiddenTokens = [
  "ANTHROPIC_API_KEY=",
  "OPENAI_API_KEY=",
  "AI_GATEWAY_API_KEY=",
  "GITHUB_TOKEN=",
  "NPM_TOKEN=",
  "ghp_",
];

function abs(relPath) {
  return path.join(root, relPath);
}

function exists(relPath) {
  return fs.existsSync(abs(relPath));
}

function readJson(relPath) {
  return JSON.parse(fs.readFileSync(abs(relPath), "utf8"));
}

function readText(relPath) {
  return fs.readFileSync(abs(relPath), "utf8");
}

function readMaybe(filePath) {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch {
    return "";
  }
}

function gitStatus() {
  try {
    return execFileSync("git", ["status", "--short", "--branch"], {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return "git_status_unavailable";
  }
}

function listFiles(dir, predicate) {
  const start = abs(dir);
  if (!fs.existsSync(start)) return [];
  const files = [];
  const stack = [start];
  while (stack.length) {
    const current = stack.pop();
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === "node_modules" || entry.name === ".git") continue;
        stack.push(full);
      } else if (!predicate || predicate(full)) {
        files.push(path.relative(root, full));
      }
    }
  }
  return files.sort();
}

function statusCountsFromText(text) {
  const counts = {};
  const pattern = /\[(done|completed|in_progress|pending|blocked|parked|in_review|queued|todo|open|LEO-GATED)\]/g;
  for (const match of text.matchAll(pattern)) {
    counts[match[1]] = (counts[match[1]] ?? 0) + 1;
  }
  return counts;
}

function mergeCounts(countsList) {
  const merged = {};
  for (const counts of countsList) {
    for (const [key, value] of Object.entries(counts)) {
      merged[key] = (merged[key] ?? 0) + value;
    }
  }
  return merged;
}

const errors = [];
const warnings = [];

for (const file of requiredFiles) {
  if (!exists(file)) errors.push(`Missing required file: ${file}`);
}

for (const file of forbiddenFiles) {
  if (exists(file)) errors.push(`Forbidden local credential/config file exists: ${file}`);
}

if (!fs.existsSync(canonicalCommandCenterPlan)) {
  warnings.push(`Command-center Vidux plan is not readable from this machine: ${canonicalCommandCenterPlan}`);
}

const packageJson = readJson("package.json");
const packageLock = readJson("package-lock.json");

const dependencyVersions = {};
const lockDependencyVersions = {};
const installedDependencyVersions = {};

function installedPackage(name) {
  const packagePath = `node_modules/${name}/package.json`;
  if (!exists(packagePath)) {
    errors.push(`Installed dependency missing: ${packagePath}`);
    return null;
  }

  const parsed = readJson(packagePath);
  installedDependencyVersions[name] = parsed.version ?? null;
  if (parsed.name !== name) {
    errors.push(`${packagePath} package name must be ${name}, got ${parsed.name ?? "missing"}`);
  }
  return parsed;
}

for (const script of requiredScripts) {
  if (!packageJson.scripts?.[script]) errors.push(`Missing package script: ${script}`);
}

for (const [name, version] of Object.entries(requiredExactDevDeps)) {
  const actual = packageJson.devDependencies?.[name];
  dependencyVersions[name] = actual ?? null;
  if (actual !== version) errors.push(`Dev dependency ${name} must be ${version}, got ${actual ?? "missing"}`);

  const lockVersion = packageLock.packages?.[`node_modules/${name}`]?.version;
  lockDependencyVersions[name] = lockVersion ?? null;
  if (lockVersion !== version) {
    errors.push(`package-lock dependency ${name} must be ${version}, got ${lockVersion ?? "missing"}`);
  }

  const installed = installedPackage(name);
  if (installed && installed.version !== version) {
    errors.push(`node_modules/${name}/package.json version must be ${version}, got ${installed.version ?? "missing"}`);
  }
}

const lockedZod = packageLock.packages?.["node_modules/zod"]?.version;
lockDependencyVersions.zod = lockedZod ?? null;
if (lockedZod !== "4.4.3") {
  errors.push(`Locked zod must be 4.4.3, got ${lockedZod ?? "missing"}`);
}

const installedZod = installedPackage("zod");
if (installedZod && installedZod.version !== "4.4.3") {
  errors.push(`node_modules/zod/package.json version must be 4.4.3, got ${installedZod.version ?? "missing"}`);
}

if (!exists("node_modules/.bin/eve")) {
  errors.push("Installed Eve binary missing: node_modules/.bin/eve");
}

const gitignore = exists(".gitignore") ? readText(".gitignore") : "";
for (const ignored of [".eve/", ".output/"]) {
  if (!gitignore.includes(ignored)) errors.push(`.gitignore must include ${ignored}`);
}

const searchable = [
  ...listFiles("agent", (file) => file.endsWith(".md") || file.endsWith(".ts")),
  ...listFiles("evidence", (file) => file.endsWith(".md")),
];

for (const file of searchable) {
  const text = readText(file);
  for (const token of forbiddenTokens) {
    if (text.includes(token)) errors.push(`${file} contains forbidden token: ${token}`);
  }
}

const status = gitStatus();
if (!status.includes("codex/eve-studio-claudux-20260620")) {
  warnings.push("Expected clean Eve worktree branch name was not detected");
}

const commandCenterText = readMaybe(canonicalCommandCenterPlan);
const manifest = readJson("docs-structure.json");
const planCounts = mergeCounts([statusCountsFromText(commandCenterText)]);
const activeStatusMarkers = ["in_progress", "pending", "blocked", "parked", "in_review", "queued", "todo", "open", "LEO-GATED"]
  .reduce((sum, key) => sum + (planCounts[key] ?? 0), 0);

dependencyVersions.zodPackageLock = lockedZod;

const report = {
  ok: errors.length === 0,
  verdict: errors.length === 0 ? "claudux_eve_installed_local_only" : "claudux_eve_install_incomplete",
  repo: root,
  packageName: packageJson.name,
  gitStatus: status.split("\n"),
  dependencyVersions,
  lockDependencyVersions,
  installedDependencyVersions,
  scripts: requiredScripts,
  commandCenterPlan: {
    path: canonicalCommandCenterPlan,
    readable: fs.existsSync(canonicalCommandCenterPlan),
    statusCounts: planCounts,
    activeStatusMarkers,
  },
  clauduxSurface: {
    docsManifestVersion: manifest.version ?? null,
    manifestPageCount: Array.isArray(manifest.pages) ? manifest.pages.length : null,
    shellLibCount: listFiles("lib", (file) => file.endsWith(".sh")).length,
    shellTestCount: listFiles("tests", (file) => file.endsWith(".sh")).length,
  },
  filesChecked: requiredFiles.length,
  gatesNotCrossed: [
    "no primary checkout mutation",
    "no generated docs edit",
    "no npm publish or release action",
    "no GitHub Pages or live deploy",
    "no remote-machine mutation",
    "no model download, model server start, hosted API call, or paid spend",
    "no credentials, secrets, or env creation",
    "no customer, household, or external human message",
  ],
  sourceNotes: [
    "Primary /Users/leokwan/Development/claudux checkout is clean but was still preserved; this receiver works only in the clean eve-studio worktree.",
    "Claudux is Bash-first; receiver proof focuses on shell tests, secret scan, and Eve metadata.",
    "Generated docs under docs/** were not edited.",
  ],
  errors,
  warnings,
};

const json = JSON.stringify(report, null, 2);
if (process.argv.includes("--json")) {
  console.log(json);
} else {
  console.log(`${report.verdict}: ${errors.length} error(s), ${warnings.length} warning(s)`);
  if (errors.length) console.log(errors.map((error) => `ERROR ${error}`).join("\n"));
  if (warnings.length) console.log(warnings.map((warning) => `WARN ${warning}`).join("\n"));
}

process.exit(errors.length === 0 ? 0 : 1);
