#!/usr/bin/env python3
"""Claudux public-ready content gate (vidux-parity subset).

Default-on scan of tracked files for employer/private identity leaks that must
not ship in a public OSS repo. Self + hermetic test fixtures are denylisted.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXCLUDED_RELATIVE_PATHS = {
    Path("scripts/claudux-public-ready-grep-gate.py"),
    Path("tests/test-public-ready-gate.sh"),
}

PRIVACY_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("employer email or domain", re.compile(r"\bsnapchat\.com\b", re.IGNORECASE)),
    ("employer internal hostname", re.compile(r"\bsc-corp\.net\b", re.IGNORECASE)),
    ("employer internal .snap TLD", re.compile(r"\.snap\b", re.IGNORECASE)),
    ("employer source path", re.compile(r"\b(?:lkwan|Snapchat/Dev)\b")),
    (
        "gmail address other than the maintainer's public commit identity",
        re.compile(r"\b(?!leojkwan@gmail\.com\b)[\w.+-]+@gmail\.com\b", re.IGNORECASE),
    ),
    ("private Leo Flow lane", re.compile(r"\bLeo[ -]Flow\b", re.IGNORECASE)),
    ("private vidux overlay name", re.compile(r"/vidux-leo\b")),
    ("private skills repo path", re.compile(r"\bDevelopment/ai(?:-leo)?/(?:hooks|skills)\b")),
]

ALLOWLIST_AUTHOR_EMAILS = {
    "leojkwan@gmail.com",
    "noreply@github.com",
    "codesmith-bot@users.noreply.github.com",
    "cursoragent@cursor.com",
    "41898282+github-actions[bot]@users.noreply.github.com",
}


def tracked_files() -> list[Path]:
    out = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-files", "-z"],
        text=True,
    )
    files: list[Path] = []
    for raw in out.split("\0"):
        if not raw:
            continue
        rel = Path(raw)
        if rel in EXCLUDED_RELATIVE_PATHS:
            continue
        if any(part in {".git", "node_modules", "__pycache__"} for part in rel.parts):
            continue
        files.append(rel)
    return files


def scan_file(rel: Path) -> list[str]:
    path = ROOT / rel
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return [f"{rel}: unreadable ({exc})"]
    hits: list[str] = []
    for lineno, line in enumerate(text.splitlines(), 1):
        for label, pattern in PRIVACY_PATTERNS:
            if pattern.search(line):
                hits.append(f"{rel}:{lineno}: {label}: {line.strip()[:160]}")
    return hits


def scan_commit_metadata(range_spec: str | None) -> list[str]:
    """Scan author/committer emails (+ Co-authored-by) for the given range or HEAD."""
    if range_spec:
        args = ["git", "-C", str(ROOT), "log", "--format=%ae%n%ce%n%b", range_spec]
    else:
        args = ["git", "-C", str(ROOT), "log", "-1", "--format=%ae%n%ce%n%b"]
    try:
        blob = subprocess.check_output(args, text=True, errors="replace")
    except subprocess.CalledProcessError as exc:
        return [f"git log failed: {exc}"]
    hits: list[str] = []
    coauthor = re.compile(
        r"^Co-authored-by:\s*.*<([^>]+)>",
        re.IGNORECASE | re.MULTILINE,
    )
    emails: set[str] = set()
    lines = blob.splitlines()
    # First two lines of each commit block are %ae / %ce when format is per-commit;
    # for simplicity collect every bare email-looking token + coauthor trailers.
    for line in lines:
        stripped = line.strip()
        if re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", stripped):
            emails.add(stripped.lower())
    for match in coauthor.finditer(blob):
        emails.add(match.group(1).lower())
    allow = {e.lower() for e in ALLOWLIST_AUTHOR_EMAILS}
    for email in sorted(emails):
        if email in allow:
            continue
        if re.search(r"snapchat\.com|sc-corp\.net|(?:^|@)[^@]*\.snap$", email, re.I):
            hits.append(f"commit metadata: employer email {email}")
        elif email == "test@test.com" or email.endswith("@test.com"):
            hits.append(f"commit metadata: non-production test email {email}")
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--metadata",
        action="store_true",
        help="Also scan commit author/committer emails (HEAD or --range)",
    )
    parser.add_argument(
        "--range",
        default=None,
        help="git log range for --metadata (default: HEAD only)",
    )
    args = parser.parse_args()

    hits: list[str] = []
    for rel in tracked_files():
        hits.extend(scan_file(rel))
    if args.metadata:
        hits.extend(scan_commit_metadata(args.range))

    if hits:
        print("Claudux public-ready gate FAILED:", file=sys.stderr)
        for hit in hits:
            print(f"  {hit}", file=sys.stderr)
        return 1
    print("Claudux public-ready gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
