#!/usr/bin/env bash

version_at_least() {
  local actual=${1#v} required=${2#v} first
  first=$(printf '%s\n%s\n' "$required" "$actual" | sort -V | head -n 1)
  [[ $first == "$required" ]]
}

nvim_version() {
  command -v nvim >/dev/null 2>&1 || return 1
  nvim --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

install_official_neovim() {
  local version=${NVIM_RELEASE_VERSION:-v0.11.2} machine asset base temp sums archive extracted install backup
  local hash filename extra matches=0
  machine=$(uname -m)
  case "$machine" in
    x86_64|amd64) asset=nvim-linux-x86_64.tar.gz ;;
    aarch64|arm64) asset=nvim-linux-arm64.tar.gz ;;
    *) warn "No official Neovim archive mapping for $machine"; return 1 ;;
  esac
  base="https://github.com/neovim/neovim/releases/download/$version"
  if (( DRY_RUN )); then
    run curl -fL -o "/tmp/$asset" "$base/$asset"
    run curl -fL -o /tmp/nvim-shasum.txt "$base/shasum.txt"
    log "Would verify $asset against the matching upstream shasum.txt SHA256 entry"
    return 0
  fi
  temp=$(mktemp -d "${TMPDIR:-/tmp}/configscripts-nvim.XXXXXX") || return 1
  archive=$temp/$asset
  sums=$temp/shasum.txt
  curl -fL -o "$archive" "$base/$asset" || { warn "Neovim archive download failed; retained temporary directory at $temp"; return 1; }
  curl -fL -o "$sums" "$base/shasum.txt" || { warn "Neovim checksum download failed; retained temporary directory at $temp"; return 1; }
  while read -r hash filename extra; do
    if [[ $hash =~ ^[[:xdigit:]]{64}$ && $filename == "$asset" && -z ${extra:-} ]]; then
      printf '%s  %s\n' "$hash" "$filename" >"$temp/selected.sha256"
      ((matches++))
    fi
  done <"$sums"
  if (( matches != 1 )) || ! (cd "$temp" && sha256sum -c selected.sha256); then
    warn "Neovim checksum verification failed; retained download at $temp"
    return 1
  fi
  tar -xzf "$archive" -C "$temp" || { warn "Neovim extraction failed; retained temporary directory at $temp"; return 1; }
  extracted=$temp/${asset%.tar.gz}
  install=$HOME/.local/opt/neovim
  run mkdir -p "$HOME/.local/opt" "$HOME/.local/bin" || return 1
  if [[ -e $install ]]; then
    backup="${install}.backup.$(date +%Y%m%d%H%M%S)"
    run mv "$install" "$backup" || return 1
    log "Backed up managed Neovim to $backup"
  fi
  run mv "$extracted" "$install" || return 1
  if [[ -e $HOME/.local/bin/nvim || -L $HOME/.local/bin/nvim ]]; then
    local current_link=''
    [[ -L $HOME/.local/bin/nvim ]] && current_link=$(readlink "$HOME/.local/bin/nvim" 2>/dev/null || true)
    if [[ $current_link != "$install/bin/nvim" ]]; then
      run mv "$HOME/.local/bin/nvim" "$HOME/.local/bin/nvim.backup.$(date +%Y%m%d%H%M%S)" || return 1
    fi
  fi
  run ln -sfn "$install/bin/nvim" "$HOME/.local/bin/nvim" || return 1
  rm -f "$archive" "$sums" "$temp/selected.sha256" || return 1
  rmdir "$temp" || return 1
}

ensure_neovim() {
  local version
  version=$(nvim_version 2>/dev/null || true)
  if [[ -n $version ]] && version_at_least "$version" 0.11.2; then
    log "Neovim $version meets the >=0.11.2 requirement"
    return 0
  fi
  if [[ -n $version ]]; then
    warn "Native Neovim $version is older than 0.11.2"
  else
    warn "Neovim is not currently on PATH"
  fi
  if confirm "Install checksum-verified official Neovim ${NVIM_RELEASE_VERSION:-v0.11.2} under ~/.local?"; then
    install_official_neovim || { warn "Official Neovim installation failed"; ((FAILURES++)); }
  else
    warn "Keeping the native Neovim path; plugin bootstrap may require >=0.11.2"
  fi
}

offer_plugin_sync() {
  [[ -d $HOME/.config/nvim ]] || return 0
  command -v nvim >/dev/null 2>&1 || return 0
  if confirm "Run the existing Neovim config's Lazy and Mason bootstrap now?"; then
    run nvim --headless '+Lazy! sync' '+MasonUpdate' '+qa' || warn "Neovim plugin/Mason sync did not complete"
  fi
}
