#!/usr/bin/env bash

# Interactive, idempotent Linux workstation setup.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"
# shellcheck source=lib/configs.sh
source "$SCRIPT_DIR/lib/configs.sh"
# shellcheck source=lib/desktop.sh
source "$SCRIPT_DIR/lib/desktop.sh"
# shellcheck source=lib/neovim.sh
source "$SCRIPT_DIR/lib/neovim.sh"

main() {
  local parse_status=0
  parse_args "$@" || parse_status=$?
  (( parse_status == 2 )) && return 0
  (( parse_status == 0 )) || return "$parse_status"

  if (( EUID == 0 )) && [[ ${SETUP_ALLOW_ROOT_FOR_TESTS:-0} != 1 ]] && (( ! DRY_RUN )); then
    die "Run as a regular user. This script invokes sudo only for native packages."
    return 1
  fi

  detect_platform || return 1
  resolve_desktop
  choose_interactive_options || return 1
  print_plan
  if ! confirm_plan; then
    log "Setup cancelled before making changes."
    return 0
  fi

  if (( ! CONFIGS_ONLY )); then
    install_profile_packages
    initialize_arch_rust
    install_ai_tools
    ensure_neovim
    offer_risky_actions
  fi

  if (( ! SKIP_CONFIGS )); then
    setup_selected_configs
    offer_plugin_sync
    setup_wallpaper_rotation
  fi

  log "Setup completed with $FAILURES optional failure(s)."
  (( FAILURES == 0 ))
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
