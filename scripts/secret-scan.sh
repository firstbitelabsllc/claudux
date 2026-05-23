#!/bin/bash
# Lightweight tracked-file secret scan for CI and release checks.
set -uo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: secret scan must run inside a git worktree" >&2
    exit 1
fi

patterns=(
    'sk-(proj|ant|live|test)-[A-Za-z0-9_-]{20,}'
    'gh[pousr]_[A-Za-z0-9_]{30,}'
    'github_pat_[A-Za-z0-9_]{40,}'
    'AKIA[0-9A-Z]{16}'
    'xox[baprs]-[A-Za-z0-9-]{20,}'
    'npm_[A-Za-z0-9]{30,}'
    '-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----'
)

status=0
for pattern in "${patterns[@]}"; do
    if matches=$(git grep -n -I -E "$pattern" -- \
        ':!package-lock.json' \
        ':!docs/package-lock.json' \
        ':!*.svg' \
        ':!assets/*.svg' 2>/dev/null); then
        if [[ -n "$matches" ]]; then
            echo "Potential secret pattern matched: $pattern" >&2
            printf '%s\n' "$matches" >&2
            status=1
        fi
    fi
done

if [[ $status -eq 0 ]]; then
    echo "Secret scan passed."
fi

exit "$status"
