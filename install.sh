#!/bin/sh
# claudux installer — install without npm.
#
# Quick start:
#   curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/main/install.sh | sh
#
# Or pin a branch/tag/commit:
#   curl -fsSL https://raw.githubusercontent.com/firstbitelabsllc/claudux/main/install.sh | CLAUDUX_REF=v2.0.0 sh
#
# What it does: fetches claudux into ~/.local/share/claudux (git clone, or a
# tarball download if git is absent) and symlinks bin/claudux onto your PATH.
# Re-running it updates an existing install in place. No npm, no registry.
set -eu

REPO="firstbitelabsllc/claudux"
REF="${CLAUDUX_REF:-main}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claudux"
BIN_DIR="$HOME/.local/bin"
GIT_URL="https://github.com/$REPO.git"
# codeload's /archive/<ref> resolves branches, tags, and commit SHAs alike.
TARBALL_URL="https://github.com/$REPO/archive/$REF.tar.gz"

info() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- prerequisite: Node.js 18+ (claudux uses node for deterministic hashing) ---
check_node() {
  have node || die "Node.js 18+ is required but 'node' was not found. Install Node 18 or newer, then re-run this installer."
  node_major=$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)
  case "$node_major" in
    '' | *[!0-9]*) die "Could not parse a Node.js version from '$(node -v 2>/dev/null)'." ;;
  esac
  if [ "$node_major" -lt 18 ]; then
    die "Node.js 18+ is required. Found $(node -v). Please upgrade Node and re-run."
  fi
  info "Node.js $(node -v) detected."
}

# --- fetch (or update) the source tree ---
install_source() {
  mkdir -p "$(dirname "$DATA_DIR")"
  if have git; then
    if [ -d "$DATA_DIR/.git" ]; then
      info "Updating claudux in $DATA_DIR ..."
      git -C "$DATA_DIR" fetch --quiet --depth 1 origin "$REF"
      git -C "$DATA_DIR" reset --hard --quiet FETCH_HEAD
    else
      info "Cloning $REPO ($REF) into $DATA_DIR ..."
      rm -rf "$DATA_DIR"
      git clone --quiet --depth 1 --branch "$REF" "$GIT_URL" "$DATA_DIR" 2>/dev/null \
        || git clone --quiet "$GIT_URL" "$DATA_DIR"
    fi
  elif have curl; then
    have tar || die "Found curl but not tar; cannot extract the download. Install git or tar and re-run."
    info "Downloading $REPO ($REF) tarball (git not found) ..."
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT INT TERM
    curl -fsSL "$TARBALL_URL" -o "$tmp/claudux.tar.gz" || die "Download failed: $TARBALL_URL"
    tar -xzf "$tmp/claudux.tar.gz" -C "$tmp" || die "Failed to extract the claudux tarball."
    extracted=$(find "$tmp" -maxdepth 1 -type d -name 'claudux-*' | head -n 1)
    [ -n "$extracted" ] || die "Could not locate the extracted claudux directory."
    rm -rf "$DATA_DIR"
    mv "$extracted" "$DATA_DIR"
    rm -rf "$tmp"
    trap - EXIT INT TERM
  else
    die "Need either git or curl to fetch claudux. Install one and re-run."
  fi
  [ -f "$DATA_DIR/bin/claudux" ] || die "Install incomplete: $DATA_DIR/bin/claudux is missing."
}

# --- symlink the entry point onto PATH ---
link_bin() {
  mkdir -p "$BIN_DIR"
  chmod +x "$DATA_DIR/bin/claudux"
  ln -sf "$DATA_DIR/bin/claudux" "$BIN_DIR/claudux"
  info "Linked $BIN_DIR/claudux -> $DATA_DIR/bin/claudux"
}

# --- verify the installed binary runs ---
verify() {
  installed_version=$("$DATA_DIR/bin/claudux" --version 2>/dev/null || true)
  if [ -n "$installed_version" ]; then
    info "Installed: $installed_version"
  else
    warn "Installed, but '$DATA_DIR/bin/claudux --version' produced no output."
  fi
}

# --- tell the user how to reach it if PATH is missing the bin dir ---
path_hint() {
  case ":${PATH:-}:" in
    *":$BIN_DIR:"*) return 0 ;;
  esac
  case "$(basename "${SHELL:-/bin/sh}")" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc" ;;
    *)    rc="$HOME/.profile" ;;
  esac
  warn "$BIN_DIR is not on your PATH."
  info "Add this to $rc, then restart your shell:"
  # Intentional literal: the user pastes $HOME/$PATH verbatim into their rc file.
  # shellcheck disable=SC2016
  info '    export PATH="$HOME/.local/bin:$PATH"'
}

main() {
  info "Installing claudux (ref: $REF) — no npm required."
  check_node
  install_source
  link_bin
  verify
  path_hint
  info ""
  info "Next steps:"
  info "  cd into any repo, then run:  claudux update"
  info "  It scans your code and generates a VitePress docs site with Claude or Codex."
}

main "$@"
