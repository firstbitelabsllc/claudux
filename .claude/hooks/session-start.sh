#!/bin/bash
# Claude Code cloud sessions only: install shellcheck so `npm run lint` works.
# The package has no npm dependencies, so there is nothing else to install.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

if command -v shellcheck >/dev/null 2>&1; then
  exit 0
fi

SUDO=""
if [ "$(id -u)" != "0" ]; then
  SUDO="sudo"
fi

$SUDO apt-get update -qq
$SUDO apt-get install -y -qq shellcheck
