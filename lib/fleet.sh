#!/usr/bin/env bash

# Fleet parity helpers: bring a fresh host to the shared baseline.
# Root-owned writes always go through confirm_fleet_root; non-interactive
# mode performs user-level steps only and never touches system paths.

FLEET_MANAGED_MARKER='# Managed by configScripts fleet'

confirm_fleet_root() {
  local prompt=$1
  (( NON_INTERACTIVE )) && { warn "Skipping privileged fleet step in non-interactive mode: $prompt"; return 1; }
  confirm "$prompt"
}

fleet_write_file_root() {
  local target=$1 source=$2
  run sudo install -o root -g root -m 755 "$source" "$target"
}

fleet_nm_dispatcher() {
  local src=$1
  cat >"$src" <<'EOF'
#!/bin/sh
# Managed by configScripts fleet: reassert tailscale on full connectivity.
# $1 is the interface, $2 is the action. Root-owned, env is NM-provided.
if [ "${2:-}" = connectivity-change ] && [ "${CONNECTIVITY_STATE:-}" = FULL ]; then
  /usr/bin/tailscale up >/dev/null 2>&1 || true
fi
EOF
  printf '%s' "$src"
}

fleet_sleep_hook() {
  local src=$1
  cat >"$src" <<'EOF'
#!/bin/sh
# Managed by configScripts fleet: reconnect network after resume.
# $1 is pre/post, $2 is the sleep state. Only act after waking.
if [ "$1" != post ]; then
  exit 0
fi

# Let the PCI bus and radio settle before poking devices.
sleep 3

/usr/bin/nmcli networking on >/dev/null 2>&1 || true
/usr/bin/nmcli radio wifi on >/dev/null 2>&1 || true

# Reconnect any wifi/ethernet device NM left disconnected.
# Parsing is field-based (DEVICE:TYPE), never matched on free text.
/usr/bin/nmcli -t -f DEVICE,TYPE device status 2>/dev/null | while IFS= read -r line; do
  dev=${line%%:*}
  type=${line##*:}
  case "$type" in
    wifi|ethernet) ;;
    *) continue ;;
  esac
  if /usr/bin/nmcli -t -f GENERAL.STATE device show "$dev" 2>/dev/null | grep -qE ':[[:space:]]+100 \('; then
    continue
  fi
  /usr/bin/nmcli device connect "$dev" >/dev/null 2>&1 || true
done

# Reassert tailscale once the link has had a moment. Detached on purpose:
# the hook must return promptly; `up` with no flags reuses stored prefs.
( sleep 5; /usr/bin/tailscale up >/dev/null 2>&1 || true ) &
EOF
  printf '%s' "$src"
}

fleet_setup_network_hooks() {
  local tmpdir dispatcher sleep_hook
  if (( DRY_RUN )); then
    log "Would stage NetworkManager dispatcher + suspend/resume hook templates and prompt for privileged install"
    return 0
  fi
  tmpdir=$(mktemp -d) || return 1
  dispatcher=$tmpdir/50-fleet-tailscale
  sleep_hook=$tmpdir/50-fleet-net-resume
  fleet_nm_dispatcher "$dispatcher" >/dev/null
  fleet_sleep_hook "$sleep_hook" >/dev/null
  if confirm_fleet_root "Install NetworkManager dispatcher + suspend/resume hooks (needs root)?"; then
    fleet_write_file_root /etc/NetworkManager/dispatcher.d/50-fleet-tailscale "$dispatcher" || warn "Could not install the dispatcher hook"
    fleet_write_file_root /usr/lib/systemd/system-sleep/50-fleet-net-resume "$sleep_hook" || warn "Could not install the sleep hook"
  fi
  rm -rf "$tmpdir"
}

fleet_setup_boot_updates() {
  local unit_src unit_dest=/etc/systemd/system/fleet-update-boot.service
  if (( DRY_RUN )); then
    log "Would stage the fleet-update-boot unit and prompt for privileged install"
    return 0
  fi
  if ! confirm_fleet_root "Enable update-on-boot service (needs root, no auto-reboot)?"; then
    return 0
  fi
  unit_src=$(mktemp) || return 1
  cat >"$unit_src" <<'EOF'
[Unit]
Description=Fleet update on boot (updates only, never restarts the machine)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'if command -v pacman >/dev/null; then pacman -Syu --noconfirm; elif command -v apt-get >/dev/null; then apt-get update && apt-get upgrade -y; elif command -v dnf >/dev/null; then dnf upgrade -y; fi >>/var/log/fleet-update-boot.log 2>&1 || true'

[Install]
WantedBy=multi-user.target
EOF
  run sudo install -o root -g root -m 644 "$unit_src" "$unit_dest" || warn "Could not install the boot-update unit"
  run sudo systemctl enable fleet-update-boot.service || warn "Could not enable the boot-update unit"
  rm -f "$unit_src"
}

fleet_setup_session_path() {
  local envdir=${XDG_CONFIG_HOME:-$HOME/.config}/environment.d target
  target=$envdir/60-fleet-mise.conf
  if [[ -e $target ]] && ! grep -q "$FLEET_MANAGED_MARKER" "$target" 2>/dev/null; then
    warn "Preserving non-managed environment file: $target"
    return 1
  fi
  (( DRY_RUN )) && { log "Would write $target with the mise shims PATH"; return 0; }
  run mkdir -p "$envdir" || return 1
  {
    printf '%s\n' "$FLEET_MANAGED_MARKER"
    printf 'PATH=%s/.local/share/mise/shims:%s/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin\n' "$HOME" "$HOME"
  } >"$target"
  log "Wrote $target (applies at next login)"
}

fleet_setup_mise_toolchain() {
  command -v mise >/dev/null 2>&1 || { warn "mise is not installed; skipping toolchain sync"; return 1; }
  [[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml ]] || { warn "No mise config.toml; skipping toolchain sync"; return 1; }
  run mise install || warn "mise toolchain sync reported failures"
}

fleet_setup() {
  (( FLEET )) || return 0
  (( CONFIGS_ONLY )) && return 0
  fleet_setup_session_path
  fleet_setup_mise_toolchain || true
  fleet_setup_network_hooks
  fleet_setup_boot_updates
  return 0
}
