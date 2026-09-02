#!/usr/bin/env bash

wallpaper_directory() {
  printf '%s' "${WALLPAPER_DIR:-$HOME/Pictures/WPs}"
}

wallpapers_available() {
  local directory image
  directory=$(wallpaper_directory)
  [[ -d $directory ]] || return 1
  image=$(find "$directory" -type f -size +0c \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null)
  [[ -n $image ]]
}

wallpaper_backend_available() {
  if (( IS_OMARCHY )); then
    command -v omarchy-theme-bg-set >/dev/null 2>&1 || { warn "Omarchy wallpaper setter is unavailable"; return 1; }
    return 0
  fi
  case "$DESKTOP" in
    hyprland)
      if ! command -v hyprctl >/dev/null 2>&1 || ! command -v hyprpaper >/dev/null 2>&1; then
        warn "Hyprland rotation requires both hyprctl and hyprpaper"
        return 1
      fi ;;
    sway) command -v swaymsg >/dev/null 2>&1 || { warn "Sway rotation requires swaymsg"; return 1; } ;;
    gnome) command -v gsettings >/dev/null 2>&1 || { warn "GNOME rotation requires gsettings"; return 1; } ;;
    *) return 1 ;;
  esac
}

write_wallpaper_script() {
  local target=$1 setter=''
  run mkdir -p "$(dirname "$target")" || return 1
  (( IS_OMARCHY )) && setter=$(command -v omarchy-theme-bg-set 2>/dev/null || true)
  (( DRY_RUN )) && { log "Would generate $target for $DESKTOP"; return 0; }
  if [[ -e $target ]] && ! grep -q '^# Managed by configScripts$' "$target" 2>/dev/null; then
    warn "Preserving non-managed wallpaper helper: $target"
    return 1
  fi
  {
    cat <<'EOF'
#!/usr/bin/env bash
# Managed by configScripts
set -u
wallpaper_dir=${WALLPAPER_DIR:-$HOME/Pictures/WPs}
mapfile -d '' images < <(find "$wallpaper_dir" -type f -size +0c \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 2>/dev/null)
((${#images[@]})) || exit 1
image=${images[RANDOM % ${#images[@]}]}
EOF
    printf 'omarchy_setter=%q\n' "$setter"
    cat <<'EOF'
case "${SETUP_DESKTOP:-}" in
  omarchy) [[ -n $omarchy_setter ]] && "$omarchy_setter" "$image" ;;
  hyprland) hyprctl hyprpaper preload "$image" >/dev/null && hyprctl hyprpaper wallpaper ",contain:$image" >/dev/null ;;
  sway) swaymsg output '*' bg "$image" fill >/dev/null ;;
  gnome) gsettings set org.gnome.desktop.background picture-uri "file://$image" && gsettings set org.gnome.desktop.background picture-uri-dark "file://$image" ;;
  *) exit 1 ;;
esac
EOF
  } >"$target"
  chmod +x "$target"
}

write_hyprpaper_unit() {
  local unit_dir=$1 executable
  (( IS_OMARCHY )) && return 0
  [[ $DESKTOP == hyprland ]] || return 0
  executable=$(command -v hyprpaper 2>/dev/null) || return 1
  cat >"$unit_dir/configscripts-hyprpaper.service" <<EOF
[Unit]
Description=Hyprpaper backend for configScripts wallpaper rotation
PartOf=graphical-session.target

[Service]
ExecStart="$executable"
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
}

write_wallpaper_units() {
  local unit_dir=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
  local script=$HOME/.local/bin/configscripts-wallpaper-rotate service_desktop=$DESKTOP
  run mkdir -p "$unit_dir" || return 1
  (( IS_OMARCHY )) && service_desktop=omarchy
  write_wallpaper_script "$script" || return 1
  (( DRY_RUN )) && { log "Would generate wallpaper service and 30-minute timer in $unit_dir"; return 0; }
  cat >"$unit_dir/configscripts-wallpaper.service" <<EOF
[Unit]
Description=Rotate workstation wallpaper

[Service]
Type=oneshot
Environment=SETUP_DESKTOP=$service_desktop
ExecStart=%h/.local/bin/configscripts-wallpaper-rotate
EOF
  cat >"$unit_dir/configscripts-wallpaper.timer" <<'EOF'
[Unit]
Description=Rotate workstation wallpaper every 30 minutes

[Timer]
OnBootSec=5m
OnUnitActiveSec=30m
Persistent=true

[Install]
WantedBy=timers.target
EOF
  write_hyprpaper_unit "$unit_dir"
}

setup_wallpaper_rotation() {
  [[ $DESKTOP != none ]] || return 0
  wallpapers_available || { warn "Wallpaper rotation unavailable: no nonempty JPG, PNG, or WebP image in $(wallpaper_directory)"; return 0; }
  confirm "Generate and enable 30-minute wallpaper rotation?" || return 0
  wallpaper_backend_available || { ((FAILURES++)); return 1; }
  write_wallpaper_units || { warn "Could not generate wallpaper timer"; ((FAILURES++)); return 1; }
  if command -v systemctl >/dev/null 2>&1; then
    run systemctl --user daemon-reload || warn "Could not reload user units"
    if [[ $DESKTOP == hyprland ]] && (( ! IS_OMARCHY )); then
      run systemctl --user enable --now configscripts-hyprpaper.service || warn "Could not enable hyprpaper backend"
    fi
    run systemctl --user enable --now configscripts-wallpaper.timer || warn "Could not enable wallpaper timer"
  fi
}
