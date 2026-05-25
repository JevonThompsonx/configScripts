#!/bin/bash
# cloneConfigs.sh — Clone personal dotfiles from GitHub
# Usage: bash cloneConfigs.sh

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }

# ── Check gh installed ─────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
    err "GitHub CLI not installed. Install it first."
    exit 1
fi

# ── Check gh auth ──────────────────────────────────────────────────────────────
if ! gh auth status &>/dev/null; then
    err "GitHub CLI not authenticated. Run: gh auth login"
    exit 1
fi

# ── Clone repos ────────────────────────────────────────────────────────────────
clone_repo() {
    local repo="$1" dest="$2"

    # Safety: refuse to delete paths not under $HOME
    case "$dest" in
        "$HOME"/*) ;;
        *) err "Refusing to delete $dest (not under \$HOME)"; exit 1 ;;
    esac

    if [ -d "$dest/.git" ]; then
        log "$repo already cloned at $dest, pulling..."
        git -C "$dest" pull --ff-only || warn "Pull failed for $dest — check manually"
    else
        mkdir -p "$(dirname "$dest")"
        [ -d "$dest" ] && rm -rf "$dest"
        gh repo clone "$repo" "$dest"
        log "$repo cloned to $dest"
    fi
}

log "Cloning configuration repositories..."

clone_repo "JevonThompsonx/fish" "$HOME/.config/fish"
clone_repo "JevonThompsonx/nvim" "$HOME/.config/nvim"

log "Config clone complete!"
