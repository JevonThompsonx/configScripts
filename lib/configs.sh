#!/usr/bin/env bash

path_is_under_home() {
  local candidate=$1 existing resolved home_resolved
  [[ $candidate == "$HOME"/* && $candidate != *'/../'* && $candidate != */.. ]] || return 1
  home_resolved=$(cd -P "$HOME" 2>/dev/null && pwd) || return 1
  existing=$candidate
  while [[ ! -e $existing && ! -L $existing ]]; do
    existing=$(dirname "$existing")
  done
  if command -v readlink >/dev/null 2>&1; then
    resolved=$(readlink -f "$existing" 2>/dev/null) || return 1
  elif [[ -d $existing ]]; then
    resolved=$(cd -P "$existing" 2>/dev/null && pwd) || return 1
  else
    resolved=$(cd -P "$(dirname "$existing")" 2>/dev/null && pwd) || return 1
  fi
  [[ $resolved == "$home_resolved" || $resolved == "$home_resolved"/* ]]
}

normalize_git_url() {
  local value=$1
  value=${value%.git}
  value=${value#git@github.com:}
  value=${value#https://github.com/}
  printf '%s' "$value"
}

repo_is_safe_to_update() {
  local repo=$1 expected=$2 origin upstream upstream_remote upstream_url counts behind ahead
  origin=$(git -C "$repo" remote get-url origin 2>/dev/null) || return 1
  [[ $(normalize_git_url "$origin") == "$(normalize_git_url "$expected")" ]] || return 1
  [[ -z $(git -C "$repo" status --porcelain 2>/dev/null) ]] || return 1
  upstream=$(git -C "$repo" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || return 1
  [[ $upstream == origin/* ]] || return 1
  upstream_remote=${upstream%%/*}
  upstream_url=$(git -C "$repo" remote get-url "$upstream_remote" 2>/dev/null) || return 1
  [[ $(normalize_git_url "$upstream_url") == "$(normalize_git_url "$expected")" ]] || return 1
  counts=$(git -C "$repo" rev-list --left-right --count "HEAD...$upstream" 2>/dev/null) || return 1
  read -r ahead behind <<<"$counts"
  [[ ${ahead:-1} == 0 && ${behind:-1} =~ ^[0-9]+$ ]]
}

clone_to_empty_destination() {
  local repo=$1 destination=$2 privacy=$3 temporary
  temporary="${destination}.clone.$$"
  run mkdir -p "$(dirname "$destination")" || return 1
  if (( DRY_RUN )); then
    if [[ $privacy == private ]]; then
      run gh repo clone "$repo" "$temporary"
    else
      run git clone "https://github.com/${repo}.git" "$temporary"
    fi
    run mv "$temporary" "$destination"
    return
  fi
  [[ ! -e $temporary ]] || { warn "Temporary clone path exists; skipping: $temporary"; return 1; }
  if [[ $privacy == private ]]; then
    gh repo clone "$repo" "$temporary" || return 1
  else
    git clone "https://github.com/${repo}.git" "$temporary" || return 1
  fi
  mv "$temporary" "$destination" || { warn "Clone succeeded but final move failed; clone retained at $temporary"; return 1; }
}

manage_repo() {
  local repo=$1 destination=$2 privacy=$3 conflict=${4:-0}
  if ! path_is_under_home "$destination"; then
    warn "Refusing destination outside HOME: $destination"
    return 1
  fi
  if (( conflict )); then
    if ! confirm "Omarchy manages $destination. Replace it with $repo?"; then
      warn "Preserving Omarchy config at $destination"
      return 0
    fi
  fi
  if [[ -d $destination/.git ]]; then
    if repo_is_safe_to_update "$destination" "$repo"; then
      run git -C "$destination" pull --ff-only || { warn "Pull failed for $destination"; return 1; }
    else
      warn "Repository is dirty, unpushed, diverged, lacks an origin upstream, or has a different origin; skipping $destination"
      return 0
    fi
    return 0
  fi
  if [[ -e $destination ]]; then
    if ! confirm "Existing non-git path $destination. Back it up and install $repo?"; then
      warn "Preserving existing path: $destination"
      return 0
    fi
    local timestamp backup temporary="${destination}.clone.$$"
    timestamp=$(date +%Y%m%d%H%M%S)
    backup="${destination}.backup.${timestamp}"
    if (( DRY_RUN )); then
      temporary="${destination}.clone.$$"
      run mkdir -p "$(dirname "$destination")"
      if [[ $privacy == private ]]; then
        run gh repo clone "$repo" "$temporary"
      else
        run git clone "https://github.com/${repo}.git" "$temporary"
      fi
      run mv "$destination" "$backup"
      run mv "$temporary" "$destination"
      return 0
    fi
    [[ ! -e $temporary ]] || { warn "Temporary clone path exists; skipping"; return 1; }
    if [[ $privacy == private ]]; then
      gh repo clone "$repo" "$temporary" || return 1
    else
      git clone "https://github.com/${repo}.git" "$temporary" || return 1
    fi
    mv "$destination" "$backup" || { warn "Could not back up $destination"; return 1; }
    if ! mv "$temporary" "$destination"; then
      warn "Could not place clone; restoring original"
      mv "$backup" "$destination" || warn "Restore failed; original remains at $backup"
      return 1
    fi
    log "Backed up existing path to $backup"
    return 0
  fi
  clone_to_empty_destination "$repo" "$destination" "$privacy"
}

private_auth_ready() {
  command -v gh >/dev/null 2>&1 || { warn "gh is unavailable; skipping private configs"; return 1; }
  gh auth status >/dev/null 2>&1 && return 0
  if (( NON_INTERACTIVE )); then
    warn "Private configs requested but gh is not authenticated; skipping"
    return 1
  fi
  confirm "Private configs require GitHub login. Run 'gh auth login'?" || return 1
  run gh auth login || return 1
  gh auth status >/dev/null 2>&1
}

setup_selected_configs() {
  local omarchy_conflict=$IS_OMARCHY
  manage_repo JevonThompsonx/nvim "$HOME/.config/nvim" public "$omarchy_conflict" || ((FAILURES++))
  manage_repo JevonThompsonx/alacritty "$HOME/.config/alacritty" public 0 || ((FAILURES++))
  if [[ $PROFILE != core ]]; then
    manage_repo JevonThompsonx/falkon "$HOME/.config/falkon" public 0 || ((FAILURES++))
  fi
  if [[ $DESKTOP == hyprland || $DESKTOP == sway ]]; then
    manage_repo JevonThompsonx/waybar "$HOME/.config/waybar" public "$omarchy_conflict" || ((FAILURES++))
    manage_repo JevonThompsonx/wofi "$HOME/.config/wofi" public "$omarchy_conflict" || ((FAILURES++))
  fi

  if (( ! PRIVATE_CONFIGS )); then
    if (( ! NON_INTERACTIVE )) && confirm "Install private fish, OpenCode, and wallpaper configs?"; then
      PRIVATE_CONFIGS=1
    fi
  fi
  (( PRIVATE_CONFIGS )) || return 0
  private_auth_ready || return 0
  manage_repo JevonThompsonx/fish "$HOME/.config/fish" private 0 || ((FAILURES++))
  manage_repo JevonThompsonx/opencode "$HOME/.config/opencode" private 0 || ((FAILURES++))
  if [[ $PROFILE == full ]] || confirm "Install the private wallpaper repository?"; then
    manage_repo JevonThompsonx/WPs "$HOME/Pictures/WPs" private 0 || ((FAILURES++))
  fi
}
