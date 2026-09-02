#!/usr/bin/env bash

PROFILE=workstation
DESKTOP=auto
PROFILE_EXPLICIT=0
DESKTOP_EXPLICIT=0
NON_INTERACTIVE=0
DRY_RUN=0
CONFIGS_ONLY=0
SKIP_CONFIGS=0
PRIVATE_CONFIGS=0
AI_TOOLS=0
AI_TOOLS_EXPLICIT=0
OS_RELEASE_PATH=${OS_RELEASE_PATH:-/etc/os-release}
DISTRO_FAMILY=
DISTRO_ID=
IS_OMARCHY=0
# Aggregated by the entrypoint after independently attempted capabilities.
# shellcheck disable=SC2034
FAILURES=0

log() { printf '[setup] %s\n' "$*"; }
warn() { printf '[warning] %s\n' "$*" >&2; }
die() { printf '[error] %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: unifiedSetup.sh [options]

Options:
  --help                         Show this help
  --dry-run                      Print actions without changing the system
  --non-interactive              Never prompt; use safe defaults
  --profile core|workstation|full
  --desktop auto|hyprland|sway|gnome|none
  --configs-only                 Only manage selected configuration repos
  --skip-configs                 Do not manage configuration repos
  --private-configs              Opt into private repos (requires existing auth
                                 in non-interactive mode)
  --ai-tools                     Install selected AI CLIs with user-local npm

OS_RELEASE_PATH may point to a test os-release file.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --help) usage; return 2 ;;
      --dry-run) DRY_RUN=1 ;;
      --non-interactive) NON_INTERACTIVE=1 ;;
      --profile)
        [[ $# -ge 2 ]] || { die "--profile requires a value"; return 1; }
        PROFILE=$2; PROFILE_EXPLICIT=1; shift ;;
      --desktop)
        [[ $# -ge 2 ]] || { die "--desktop requires a value"; return 1; }
        DESKTOP=$2; DESKTOP_EXPLICIT=1; shift ;;
      --configs-only) CONFIGS_ONLY=1 ;;
      --skip-configs) SKIP_CONFIGS=1 ;;
      --private-configs) PRIVATE_CONFIGS=1 ;;
      --ai-tools) AI_TOOLS=1; AI_TOOLS_EXPLICIT=1 ;;
      *) die "Unknown option: $1"; usage >&2; return 1 ;;
    esac
    shift
  done

  case "$PROFILE" in core|workstation|full) ;; *) die "Invalid profile: $PROFILE"; return 1 ;; esac
  case "$DESKTOP" in auto|hyprland|sway|gnome|none) ;; *) die "Invalid desktop: $DESKTOP"; return 1 ;; esac
  if (( CONFIGS_ONLY && SKIP_CONFIGS )); then
    die "--configs-only and --skip-configs cannot be combined"
    return 1
  fi
}

detect_platform() {
  if [[ ! -r $OS_RELEASE_PATH ]]; then
    die "Cannot read os-release file: $OS_RELEASE_PATH"
    return 1
  fi

  local ID='' ID_LIKE=''
  # os-release is a shell-compatible assignment file.
  # shellcheck disable=SC1090
  source "$OS_RELEASE_PATH"
  DISTRO_ID=${ID,,}
  local ancestry=" ${DISTRO_ID} ${ID_LIKE,,} "

  case "$ancestry" in
    *" omarchy "*) DISTRO_FAMILY=pacman; IS_OMARCHY=1 ;;
    *" arch "*) DISTRO_FAMILY=pacman ;;
    *" debian "*|*" ubuntu "*) DISTRO_FAMILY=apt ;;
    *" fedora "*|*" rhel "*|*" centos "*) DISTRO_FAMILY=dnf ;;
    *" opensuse "*|*" suse "*) DISTRO_FAMILY=zypper ;;
    *" alpine "*) DISTRO_FAMILY=apk ;;
    *)
      die "Unsupported distribution: ${ID:-unknown} (ID_LIKE: ${ID_LIKE:-unset})"
      return 1 ;;
  esac

  if [[ -n ${OMARCHY_PATH:-} || -d ${XDG_CONFIG_HOME:-$HOME/.config}/omarchy ]] || command -v omarchy-theme-bg-set >/dev/null 2>&1; then
    IS_OMARCHY=1
  fi
  log "Detected ${DISTRO_ID:-unknown} using $DISTRO_FAMILY"
}

resolve_desktop() {
  [[ $DESKTOP != auto ]] && return
  if (( IS_OMARCHY )); then
    DESKTOP=hyprland
  elif [[ ${XDG_CURRENT_DESKTOP:-} == *[Hh][Yy][Pp][Rr][Ll][Aa][Nn][Dd]* ]] || [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    DESKTOP=hyprland
  elif [[ ${XDG_CURRENT_DESKTOP:-} == *[Ss][Ww][Aa][Yy]* ]] || [[ -n ${SWAYSOCK:-} ]]; then
    DESKTOP=sway
  elif [[ ${XDG_CURRENT_DESKTOP:-} == *[Gg][Nn][Oo][Mm][Ee]* ]]; then
    DESKTOP=gnome
  else
    DESKTOP=none
  fi
}

choose_value() {
  local prompt=$1 default=$2 allowed=$3 answer
  read -r -p "$prompt [$default] " answer || return 1
  answer=${answer:-$default}
  case " $allowed " in
    *" $answer "*) printf '%s' "$answer" ;;
    *) die "Invalid choice: $answer"; return 1 ;;
  esac
}

choose_interactive_options() {
  (( NON_INTERACTIVE )) && return 0
  if (( ! PROFILE_EXPLICIT )); then
    PROFILE=$(choose_value "Profile (core/workstation/full)" workstation "core workstation full") || return 1
  fi
  if (( ! DESKTOP_EXPLICIT )); then
    DESKTOP=$(choose_value "Desktop (hyprland/sway/gnome/none)" "$DESKTOP" "hyprland sway gnome none") || return 1
  fi
  if (( ! CONFIGS_ONLY && ! AI_TOOLS_EXPLICIT )) && confirm "Install optional OpenCode, Claude, Codex, Copilot, and Pi CLIs?"; then
    AI_TOOLS=1
  fi
}

confirm() {
  local prompt=$1
  if (( NON_INTERACTIVE )); then
    return 1
  fi
  local answer
  read -r -p "$prompt [y/N] " answer || return 1
  [[ $answer == y || $answer == Y || $answer == yes || $answer == YES ]]
}

run() {
  if (( DRY_RUN )); then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

print_plan() {
  log "Plan: profile=$PROFILE desktop=$DESKTOP packages=$((! CONFIGS_ONLY)) configs=$((! SKIP_CONFIGS)) private=$PRIVATE_CONFIGS ai-tools=$AI_TOOLS"
  (( IS_OMARCHY )) && log "Omarchy detected: existing desktop/theme defaults are protected"
}

confirm_plan() {
  (( NON_INTERACTIVE || DRY_RUN )) && return 0
  confirm "Apply this package/configuration plan?"
}

unit_exists() {
  local scope=$1 unit=$2 state
  if [[ $scope == user ]]; then
    state=$(systemctl --user show --property=LoadState --value "$unit" 2>/dev/null) || return 1
  else
    state=$(systemctl show --property=LoadState --value "$unit" 2>/dev/null) || return 1
  fi
  [[ -n $state && $state != not-found ]]
}

offer_selected_services() {
  [[ $PROFILE == full ]] || {
    if [[ $PROFILE != core ]] && command -v syncthing >/dev/null 2>&1 && unit_exists user syncthing.service && confirm "Enable and start the Syncthing user service?"; then
      run systemctl --user enable --now syncthing.service || warn "Could not enable the Syncthing user service"
    fi
    return
  }
  if command -v docker >/dev/null 2>&1 && unit_exists system docker.service && confirm "Enable and start the Docker system service?"; then
    run sudo systemctl enable --now docker.service || warn "Could not enable Docker"
  fi
  if command -v virsh >/dev/null 2>&1 && unit_exists system libvirtd.service && confirm "Enable and start the libvirt system service?"; then
    run sudo systemctl enable --now libvirtd.service || warn "Could not enable libvirt"
  fi
  if command -v syncthing >/dev/null 2>&1 && unit_exists user syncthing.service && confirm "Enable and start the Syncthing user service?"; then
    run systemctl --user enable --now syncthing.service || warn "Could not enable the Syncthing user service"
  fi
}

offer_risky_actions() {
  if command -v fish >/dev/null 2>&1 && [[ ${SHELL:-} != */fish ]] && confirm "Change the login shell to fish?"; then
    run chsh -s "$(command -v fish)" || warn "Could not change login shell"
  fi
  if command -v tailscale >/dev/null 2>&1 && confirm "Run 'sudo tailscale up' now?"; then
    run sudo tailscale up || warn "Tailscale login did not complete"
  fi
  command -v systemctl >/dev/null 2>&1 && offer_selected_services
}
