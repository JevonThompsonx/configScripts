#!/usr/bin/env bash

# Apple Touch Bar Macs (e.g. MacBookPro14,3): wire the Touch Bar
# keyboard-backlight keys (XF86KbdBrightnessUp/Down) to UPower.
# Detection is vendor Apple + any Touch Bar indicator (kbd_backlight LED,
# apple-touchbar/apple-ibridge module, or iBridge USB 05ac:8600). GNOME/KDE
# handle these keys out of the box; COSMIC does not yet
# (pop-os/cosmic-epoch#2925), so COSMIC gets user custom shortcuts.
# All paths are overridable for tests via MACBOOK_* env vars.

MACBOOK_TOUCHBAR_MARKER='# Managed by configScripts macbook-touchbar'
MACBOOK_DMI_BASE=${MACBOOK_DMI_BASE:-/sys/class/dmi/id}
MACBOOK_LEDS_BASE=${MACBOOK_LEDS_BASE:-/sys/class/leds}
MACBOOK_MODULE_BASE=${MACBOOK_MODULE_BASE:-/sys/module}
MACBOOK_UDEV_RULE_PATH=${MACBOOK_UDEV_RULE_PATH:-/etc/udev/rules.d/90-apple-kbd-backlight.rules}

is_apple_vendor() {
  local vendor_file=${1:-$MACBOOK_DMI_BASE/sys_vendor}
  [[ -r $vendor_file ]] || return 1
  grep -qi 'apple' "$vendor_file" 2>/dev/null
}

macbook_kbd_backlight_device() {
  local leds=${1:-$MACBOOK_LEDS_BASE}
  [[ -e $leds/spi::kbd_backlight ]] && { printf 'spi::kbd_backlight'; return 0; }
  [[ -e $leds/smc::kbd_backlight ]] && { printf 'smc::kbd_backlight'; return 0; }
  return 1
}

has_apple_touchbar_module() {
  local base=${1:-$MACBOOK_MODULE_BASE}
  [[ -d $base/apple_touchbar || -d $base/apple-ibridge || -d $base/apple_ibridge ]]
}

has_ibridge_usb() {
  if [[ -n ${MACBOOK_USB_IDS_FILE:-} ]]; then
    [[ -r $MACBOOK_USB_IDS_FILE ]] || return 1
    grep -qi '05ac.*8600\|05ac:8600' "$MACBOOK_USB_IDS_FILE" 2>/dev/null
    return
  fi
  local dev vendor product
  for dev in /sys/bus/usb/devices/*/idVendor; do
    [[ -r $dev ]] || continue
    vendor=$(<"$dev" 2>/dev/null) || continue
    product=${dev%idVendor}idProduct
    [[ -r $product ]] || continue
    if [[ $vendor == 05ac ]] && [[ $(<"$product" 2>/dev/null) == 8600 ]]; then
      return 0
    fi
  done
  if command -v lsusb >/dev/null 2>&1; then
    lsusb 2>/dev/null | grep -qi '05ac:8600'
    return
  fi
  return 1
}

is_apple_touchbar_mac() {
  is_apple_vendor || return 1
  macbook_kbd_backlight_device >/dev/null 2>&1 && return 0
  has_apple_touchbar_module && return 0
  has_ibridge_usb && return 0
  return 1
}

ensure_macbook_touchbar_packages() {
  is_apple_touchbar_mac || return 0
  command -v brightnessctl >/dev/null 2>&1 && { log "brightnessctl already available"; return 0; }
  local native
  native=$(package_field "brightnessctl" "brightnessctl" "brightnessctl" "brightnessctl" "brightnessctl")
  [[ -n $native ]] || { warn "No brightnessctl package mapping for $DISTRO_FAMILY"; return 1; }
  install_capability "keyboard-backlight" "brightnessctl" "$native" "" ""
}

macbook_touchbar_udev_rule_content() {
  printf '%s\n' "$MACBOOK_TOUCHBAR_MARKER"
  printf 'SUBSYSTEM=="leds", KERNEL=="spi::kbd_backlight", GROUP="video", MODE="0664"\n'
  printf 'SUBSYSTEM=="leds", KERNEL=="smc::kbd_backlight", GROUP="video", MODE="0664"\n'
}

setup_macbook_touchbar_udev() {
  is_apple_touchbar_mac || return 0
  local target=${1:-$MACBOOK_UDEV_RULE_PATH}
  if [[ -e $target ]] && grep -qF "$MACBOOK_TOUCHBAR_MARKER" "$target" 2>/dev/null; then
    log "Apple keyboard-backlight udev rule already managed: $target"
    return 0
  fi
  if [[ -e $target ]]; then
    warn "Preserving non-managed udev rule: $target"
    return 1
  fi
  if (( DRY_RUN )); then
    log "Would write $target (Apple kbd_backlight group write)"
    return 0
  fi
  if (( NON_INTERACTIVE )); then
    warn "Skipping privileged udev step in non-interactive mode: $target"
    return 1
  fi
  confirm "Install Apple keyboard-backlight udev rule (needs root)?" || return 0
  local tmp
  tmp=$(mktemp) || return 1
  macbook_touchbar_udev_rule_content >"$tmp"
  run sudo install -o root -g root -m 644 "$tmp" "$target" || { warn "Could not install $target"; rm -f "$tmp"; return 1; }
  rm -f "$tmp"
  run sudo udevadm control --reload-rules || warn "Could not reload udev rules"
  run sudo udevadm trigger --subsystem-match=leds || warn "Could not trigger leds udev rules"
}

kbd_backlight_helper_content() {
  local direction=$1
  cat <<EOF
#!/bin/bash
$MACBOOK_TOUCHBAR_MARKER
# Increase/Decrease keyboard backlight via UPower (no root needed).
# Works for spi::kbd_backlight (T1) and smc::kbd_backlight via the
# org.freedesktop.UPower.KbdBacklight abstraction.
set -euo pipefail
CUR=\$(busctl --system call org.freedesktop.UPower /org/freedesktop/UPower/KbdBacklight org.freedesktop.UPower.KbdBacklight GetBrightness | awk '{print \$2}')
MAX=\$(busctl --system call org.freedesktop.UPower /org/freedesktop/UPower/KbdBacklight org.freedesktop.UPower.KbdBacklight GetMaxBrightness | awk '{print \$2}')
STEP=\$((MAX / 10))
[ "\$STEP" -lt 1 ] && STEP=1
EOF
  if [[ $direction == up ]]; then
    cat <<'EOF'
NEW=$((CUR + STEP))
[ "$NEW" -gt "$MAX" ] && NEW=$MAX
busctl --system call org.freedesktop.UPower /org/freedesktop/UPower/KbdBacklight org.freedesktop.UPower.KbdBacklight SetBrightness i "$NEW" >/dev/null
EOF
  else
    cat <<'EOF'
NEW=$((CUR - STEP))
[ "$NEW" -lt 0 ] && NEW=0
busctl --system call org.freedesktop.UPower /org/freedesktop/UPower/KbdBacklight org.freedesktop.UPower.KbdBacklight SetBrightness i "$NEW" >/dev/null
EOF
  fi
}

write_kbd_backlight_helpers() {
  is_apple_touchbar_mac || return 0
  local bindir=$HOME/.local/bin up=$HOME/.local/bin/kbd-backlight-up down=$HOME/.local/bin/kbd-backlight-down
  if (( DRY_RUN )); then
    log "Would write $up and $down (UPower keyboard-backlight helpers)"
    return 0
  fi
  run mkdir -p "$bindir" || return 1
  local target content
  for target in "$up:up" "$down:down"; do
    local file=${target%%:*} direction=${target##*:}
    if [[ -e $file ]] && ! grep -qF "$MACBOOK_TOUCHBAR_MARKER" "$file" 2>/dev/null; then
      if grep -q 'org.freedesktop.UPower.KbdBacklight' "$file" 2>/dev/null; then
        log "Adopting existing UPower helper: $file"
      else
        warn "Preserving non-managed helper: $file"
        return 1
      fi
    fi
    content=$(kbd_backlight_helper_content "$direction")
    printf '%s\n' "$content" >"$file" || return 1
    chmod +x "$file" || return 1
  done
  log "Wrote $up and $down"
}

cosmic_custom_shortcuts_path() {
  printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
}

ensure_cosmic_kbd_backlight_shortcuts() {
  local desktop=${1:-${DESKTOP:-auto}}
  if [[ $desktop != cosmic ]]; then
    command -v cosmic-comp >/dev/null 2>&1 || return 0
  fi
  is_apple_touchbar_mac || return 0
  local target
  target=$(cosmic_custom_shortcuts_path)
  if (( DRY_RUN )); then
    log "Would ensure XF86KbdBrightnessUp/Down in $target"
    return 0
  fi
  run mkdir -p "$(dirname "$target")" || return 1
  if [[ -e $target ]] && grep -q 'XF86KbdBrightnessUp' "$target" 2>/dev/null && grep -q 'kbd-backlight-up' "$target" 2>/dev/null; then
    log "COSMIC keyboard-backlight shortcuts already configured"
    return 0
  fi
  if [[ ! -e $target ]]; then
    cat >"$target" <<EOF
$MACBOOK_TOUCHBAR_MARKER
{
    (
        modifiers: [],
        key: "XF86KbdBrightnessUp",
    ): Spawn("/home/PLACEHOLDER/.local/bin/kbd-backlight-up"),
    (
        modifiers: [],
        key: "XF86KbdBrightnessDown",
    ): Spawn("/home/PLACEHOLDER/.local/bin/kbd-backlight-down"),
}
EOF
    # Replace placeholder with the real HOME without breaking RON quoting.
    local content
    content=$(<"$target")
    content=${content//\/home\/PLACEHOLDER/$HOME}
    printf '%s\n' "$content" >"$target"
    log "Wrote COSMIC keyboard-backlight shortcuts: $target"
    return 0
  fi
  # Merge into an existing custom file: insert missing entries before final }.
  if ! grep -qF "$MACBOOK_TOUCHBAR_MARKER" "$target" 2>/dev/null; then
    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    if (( NON_INTERACTIVE )); then
      warn "Existing COSMIC custom shortcuts lack keyboard-backlight keys; refusing to merge non-interactively (see $target)"
      return 1
    fi
    confirm "Merge Apple keyboard-backlight keys into existing COSMIC custom shortcuts (backup to $backup)?" || { warn "Skipping COSMIC shortcut merge"; return 0; }
    cp -p "$target" "$backup" || return 1
    log "Backed up COSMIC custom shortcuts to $backup"
  fi
  local body up_entry down_entry
  body=$(<"$target")
  # Strip marker lines and the outer braces for reassembly.
  body=$(printf '%s\n' "$body" | grep -vF "$MACBOOK_TOUCHBAR_MARKER" | sed -e '1{/^[[:space:]]*{[[:space:]]*$/d;}' -e '${/^[[:space:]]*}[[:space:]]*$/d;}')
  up_entry="    (
        modifiers: [],
        key: \"XF86KbdBrightnessUp\",
    ): Spawn(\"$HOME/.local/bin/kbd-backlight-up\"),"
  down_entry="    (
        modifiers: [],
        key: \"XF86KbdBrightnessDown\",
    ): Spawn(\"$HOME/.local/bin/kbd-backlight-down\"),"
  local new_entries=''
  grep -q 'XF86KbdBrightnessUp' "$target" 2>/dev/null || new_entries+="$up_entry"$'\n'
  grep -q 'XF86KbdBrightnessDown' "$target" 2>/dev/null || new_entries+="$down_entry"$'\n'
  {
    printf '%s\n' "$MACBOOK_TOUCHBAR_MARKER"
    printf '{\n'
    [[ -n $body ]] && printf '%s\n' "$body" | sed -e '$s/,[[:space:]]*$/,/'
    printf '%s' "$new_entries"
    printf '}\n'
  } >"$target"
  log "Merged keyboard-backlight keys into $target"
}

setup_macbook_touchbar() {
  is_apple_touchbar_mac || { log "No Apple Touch Bar Mac detected; skipping keyboard-backlight setup"; return 0; }
  log "Apple Touch Bar Mac detected; configuring keyboard-backlight keys"
  write_kbd_backlight_helpers || ((FAILURES++))
  setup_macbook_touchbar_udev || ((FAILURES++))
  ensure_cosmic_kbd_backlight_shortcuts || ((FAILURES++))
  return 0
}
