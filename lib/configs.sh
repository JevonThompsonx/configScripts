#!/usr/bin/env bash

# The user's own repositories are mirrored: Forgejo is the primary remote and
# GitHub is the mirror. Config clones prefer Forgejo and fall back to GitHub.
FORGEJO_SSH_HOST=${FORGEJO_SSH_HOST:-forgejo}
FORGEJO_OWNER=${FORGEJO_OWNER:-zLeafNinja}
GITHUB_OWNER=${GITHUB_OWNER:-JevonThompsonx}

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
  value=${value#http://github.com/}
  value=${value#git@forgejo:}
  value=${value#https://forgejo/}
  value=${value#ssh://git@forgejo/}
  printf '%s' "$value"
}

# Resolve a repository spec to a clone URL. `owner/name` maps to GitHub, an
# explicit URL or path is used as-is.
repo_source_url() {
  local repo=$1
  case "$repo" in
    *://*|/*|./*|~/*) printf '%s' "$repo" ;;
    *) printf 'https://github.com/%s.git' "$repo" ;;
  esac
}

# Primary (Forgejo) URL for one of the user's own repositories.
forgejo_repo_url() {
  printf 'git@%s:%s/%s.git' "$FORGEJO_SSH_HOST" "$FORGEJO_OWNER" "$1"
}

# GitHub mirror URL for one of the user's own repositories.
github_repo_url() {
  printf 'https://github.com/%s/%s.git' "$GITHUB_OWNER" "$1"
}

# True when the given URL matches any of the accepted URLs.
url_matches_any() {
  local candidate=$1
  shift
  local expected normalized
  normalized=$(normalize_git_url "$candidate")
  for expected in "$@"; do
    [[ -n $expected ]] || continue
    if [[ $normalized == "$(normalize_git_url "$expected")" ]]; then
      return 0
    fi
  done
  return 1
}

# A repository is safe to update when its origin (and the upstream it tracks)
# point at one of the accepted URLs, the worktree is clean and the branch is
# not ahead of or diverged from its upstream.
repo_is_safe_to_update() {
  local repo=$1 expected=$2 origin upstream upstream_remote upstream_url counts behind ahead
  local -a accepted=()
  read -r -a accepted <<<"$expected"
  (( ${#accepted[@]} )) || return 1
  origin=$(git -C "$repo" remote get-url origin 2>/dev/null) || return 1
  url_matches_any "$origin" "${accepted[@]}" || return 1
  [[ -z $(git -C "$repo" status --porcelain 2>/dev/null) ]] || return 1
  upstream=$(git -C "$repo" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || return 1
  [[ $upstream == origin/* ]] || return 1
  upstream_remote=${upstream%%/*}
  upstream_url=$(git -C "$repo" remote get-url "$upstream_remote" 2>/dev/null) || return 1
  url_matches_any "$upstream_url" "${accepted[@]}" || return 1
  counts=$(git -C "$repo" rev-list --left-right --count "HEAD...$upstream" 2>/dev/null) || return 1
  read -r ahead behind <<<"$counts"
  [[ ${ahead:-1} == 0 && ${behind:-1} =~ ^[0-9]+$ ]]
}

# Clone from the first source that works, preferring the primary remote.
clone_from_sources() {
  local destination=$1
  shift
  local source
  for source in "$@"; do
    [[ -n $source ]] || continue
    if git clone "$source" "$destination" >/dev/null 2>&1; then
      log "Cloned from $source"
      return 0
    fi
    warn "Clone from $source failed; trying the next source"
    if [[ -e $destination ]] && path_is_under_home "$destination"; then
      rm -rf -- "$destination"
    fi
  done
  return 1
}

# Pull the current branch, preferring the primary remote when the clone has one.
pull_repo() {
  local destination=$1 primary=$2 branch remote url
  if [[ -n $primary ]]; then
    branch=$(git -C "$destination" branch --show-current 2>/dev/null) || branch=""
    if [[ -n $branch ]]; then
      for remote in $(git -C "$destination" remote 2>/dev/null); do
        url=$(git -C "$destination" remote get-url "$remote" 2>/dev/null) || continue
        if url_matches_any "$url" "$primary"; then
          log "Updating $destination from the primary remote ($remote)"
          run git -C "$destination" pull --ff-only "$remote" "$branch" || return 1
          return 0
        fi
      done
    fi
  fi
  run git -C "$destination" pull --ff-only || return 1
}

# Keep the mirror remote in the clone so both remotes stay usable.
attach_mirror_remote() {
  local destination=$1 mirror=$2 name=$3
  [[ -n $mirror ]] || return 0
  git -C "$destination" remote get-url "$name" >/dev/null 2>&1 && return 0
  git -C "$destination" remote add "$name" "$mirror" >/dev/null 2>&1 || return 0
}

clone_to_empty_destination() {
  local repo=$1 destination=$2 privacy=$3 temporary
  shift 3
  temporary="${destination}.clone.$$"
  run mkdir -p "$(dirname "$destination")" || return 1
  if (( DRY_RUN )); then
    if [[ $privacy == private ]]; then
      run gh repo clone "$repo" "$temporary"
    else
      local source
      for source in "$@"; do
        [[ -n $source ]] || continue
        run git clone "$source" "$temporary"
        break
      done
    fi
    run mv "$temporary" "$destination"
    return
  fi
  [[ ! -e $temporary ]] || { warn "Temporary clone path exists; skipping: $temporary"; return 1; }
  if [[ $privacy == private ]]; then
    gh repo clone "$repo" "$temporary" || return 1
  else
    clone_from_sources "$temporary" "$@" || return 1
  fi
  mv "$temporary" "$destination" || { warn "Clone succeeded but final move failed; clone retained at $temporary"; return 1; }
}

# manage_repo <owner/name> <destination> <public|private> [omarchy_conflict] [primary_url]
#
# `primary_url` is the authoritative remote for the repository (Forgejo). When
# given, the clone prefers it, keeps the GitHub URL as a `github` remote, and
# updates are pulled from the primary remote when the clone has one.
manage_repo() {
  local repo=$1 destination=$2 privacy=$3 conflict=${4:-0} primary=${5:-}
  local source mirror branch
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
  source=$(repo_source_url "$repo")
  mirror=""
  if [[ -n $primary ]]; then
    mirror="$source"
  fi
  if [[ -d $destination/.git ]]; then
    if repo_is_safe_to_update "$destination" "$source $primary"; then
      pull_repo "$destination" "$primary" || { warn "Pull failed for $destination"; return 1; }
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
        local candidate
        for candidate in "$primary" "$source"; do
          [[ -n $candidate ]] || continue
          run git clone "$candidate" "$temporary"
          break
        done
      fi
      run mv "$destination" "$backup"
      run mv "$temporary" "$destination"
      return 0
    fi
    [[ ! -e $temporary ]] || { warn "Temporary clone path exists; skipping"; return 1; }
    if [[ $privacy == private ]]; then
      gh repo clone "$repo" "$temporary" || return 1
    else
      clone_from_sources "$temporary" "$primary" "$source" || return 1
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
  clone_to_empty_destination "$repo" "$destination" "$privacy" "$primary" "$source" || return 1
  if [[ -n $mirror ]]; then
    branch=$(git -C "$destination" branch --show-current 2>/dev/null) || branch=""
    attach_mirror_remote "$destination" "$mirror" "github"
    if [[ -n $branch ]]; then
      git -C "$destination" branch --set-upstream-to="origin/$branch" >/dev/null 2>&1 || true
    fi
  fi
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
  manage_repo "$GITHUB_OWNER/nvim" "$HOME/.config/nvim" public "$omarchy_conflict" "$(forgejo_repo_url nvim)" || ((FAILURES++))
  manage_repo "$GITHUB_OWNER/alacritty" "$HOME/.config/alacritty" public 0 "$(forgejo_repo_url alacritty)" || ((FAILURES++))
  if [[ $PROFILE != core ]]; then
    manage_repo "$GITHUB_OWNER/falkon" "$HOME/.config/falkon" public 0 "$(forgejo_repo_url falkon)" || ((FAILURES++))
  fi
  if [[ $DESKTOP == hyprland || $DESKTOP == sway ]]; then
    manage_repo "$GITHUB_OWNER/waybar" "$HOME/.config/waybar" public "$omarchy_conflict" "$(forgejo_repo_url waybar)" || ((FAILURES++))
    manage_repo "$GITHUB_OWNER/wofi" "$HOME/.config/wofi" public "$omarchy_conflict" "$(forgejo_repo_url wofi)" || ((FAILURES++))
  fi

  if [[ ! PRIVATE_CONFIGS ]]; then
    if [[ ! NON_INTERACTIVE ]] && confirm "Install private fish, OpenCode, and wallpaper configs?"; then
      PRIVATE_CONFIGS=1
    fi
  fi
  (( PRIVATE_CONFIGS )) || return 0
  private_auth_ready || return 0
  manage_repo "$GITHUB_OWNER/fish" "$HOME/.config/fish" private 0 || ((FAILURES++))
  manage_repo "$GITHUB_OWNER/opencode" "$HOME/.config/opencode" private 0 || ((FAILURES++))
  if [[ $PROFILE == full ]] || confirm "Install the private wallpaper repository?"; then
    manage_repo "$GITHUB_OWNER/WPs" "$HOME/Pictures/WPs" private 0 || ((FAILURES++))
  fi
}
