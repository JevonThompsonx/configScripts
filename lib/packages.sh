#!/usr/bin/env bash

# group|capability|command|pacman|apt|dnf|zypper|apk|aur|flatpak
package_manifest() {
  cat <<'EOF'
core|fish|fish|fish|fish|fish|fish|fish||
core|git|git|git|git|git-core|git|git||
core|github-cli|gh|github-cli|gh|gh|gh|github-cli||
core|curl|curl|curl|curl|curl|curl|curl||
core|wget|wget|wget|wget|wget|wget|wget||
core|rsync|rsync|rsync|rsync|rsync|rsync|rsync||
core|jq|jq|jq|jq|jq|jq|jq||
core|archives|unzip|unzip,zip,p7zip,tar|unzip,zip,p7zip-full,tar|unzip,zip,p7zip,p7zip-plugins,tar|unzip,zip,p7zip,tar|unzip,zip,7zip,tar||
core|ripgrep|rg|ripgrep|ripgrep|ripgrep|ripgrep|ripgrep||
core|fd|fd|fd|fd-find|fd-find|fd|fd||
core|fzf|fzf|fzf|fzf|fzf|fzf|fzf||
core|bat|bat|bat|bat|bat|bat|bat||
core|eza|eza|eza|eza|eza|eza|eza||
core|zoxide|zoxide|zoxide|zoxide|zoxide|zoxide|zoxide||
core|btop|btop|btop|btop|btop|btop|btop||
core|htop|htop|htop|htop|htop|htop|htop||
core|tmux|tmux|tmux|tmux|tmux|tmux|tmux||
core|starship|starship|starship|starship|starship|starship|starship||
core|atuin|atuin|atuin|atuin|atuin|atuin|atuin|atuin|
core|bun|bun|bun||||bun|bun-bin|
core|mise|mise|mise|mise|mise|mise||mise-bin|
core|powershell|pwsh||powershell|powershell|powershell||powershell-bin|
core|neovim|nvim|neovim|neovim|neovim|neovim|neovim||
core|node|node|nodejs,npm|nodejs,npm|nodejs,npm|nodejs-default,npm|nodejs,npm||
core|pnpm|pnpm|pnpm|pnpm|pnpm|pnpm|pnpm||
core|python|python3|python,python-pip,python-virtualenv|python3,python3-pip,python3-venv|python3,python3-pip,python3-virtualenv|python3,python3-pip,python3-virtualenv|python3,py3-pip,py3-virtualenv||
core|go|go|go|golang-go|golang|go|go||
core|rust|cargo|rustup|rustc,cargo|rust,cargo|rust,cargo|rust,cargo||
core|ffmpeg|ffmpeg|ffmpeg|ffmpeg|ffmpeg-free|ffmpeg|ffmpeg||
core|imagemagick|magick|imagemagick|imagemagick|ImageMagick|ImageMagick|imagemagick||
core|yt-dlp|yt-dlp|yt-dlp|yt-dlp|yt-dlp|yt-dlp|yt-dlp||
core|caddy|caddy|caddy|caddy|caddy|caddy|caddy||
core|tailscale|tailscale|tailscale|tailscale|tailscale|tailscale|tailscale||
desktop-wayland|wayland-clipboard|wl-copy|wl-clipboard|wl-clipboard|wl-clipboard|wl-clipboard|wl-clipboard||
desktop-x11|x11-clipboard|xclip|xclip,xsel|xclip,xsel|xclip,xsel|xclip,xsel|xclip,xsel||
desktop-hyprland|hyprland|Hyprland|hyprland|hyprland|hyprland|hyprland|hyprland||
desktop-hyprland|hyprpaper|hyprpaper|hyprpaper|hyprpaper|hyprpaper|hyprpaper|hyprpaper||
desktop-hyprland|waybar|waybar|waybar|waybar|waybar|waybar|waybar||
desktop-hyprland|wofi|wofi|wofi|wofi|wofi|wofi|wofi||
desktop-sway|sway|sway|sway|sway|sway|sway|sway||
desktop-sway|waybar|waybar|waybar|waybar|waybar|waybar|waybar||
desktop-sway|wofi|wofi|wofi|wofi|wofi|wofi|wofi||
desktop-gnome|gnome-shell|gnome-shell|gnome-shell|gnome-shell|gnome-shell|gnome-shell|gnome||
workstation|brave-browser|brave-browser||||||brave-bin|com.brave.Browser
workstation|chromium|chromium|chromium|chromium|chromium|chromium|chromium||org.chromium.Chromium
workstation|bitwarden|bitwarden||||||bitwarden|com.bitwarden.desktop
workstation|discord|discord|discord|||discord||discord|com.discordapp.Discord
workstation|falkon|falkon|falkon|falkon|falkon|falkon|falkon||org.kde.falkon
workstation|obsidian|obsidian||||||obsidian|md.obsidian.Obsidian
workstation|joplin|joplin-desktop||||||joplin-appimage|net.cozic.joplin_desktop
workstation|seafile|seafile-applet|seafile-client|seafile-gui|seafile-client|seafile-client|seafile-client||com.seafile.Client
workstation|syncthing|syncthing|syncthing|syncthing|syncthing|syncthing|syncthing||
workstation|stremio|stremio||||||stremio|com.stremio.Stremio
workstation|bottles|bottles||||||bottles|com.usebottles.bottles
workstation|steam|steam|steam|steam-installer|steam|steam|steam||com.valvesoftware.Steam
workstation|lutris|lutris|lutris|lutris|lutris|lutris|lutris||net.lutris.Lutris
workstation|moonlight|moonlight|moonlight-qt|moonlight-qt|moonlight-qt|moonlight-qt|moonlight-qt||com.moonlight_stream.Moonlight
workstation|rustdesk|rustdesk||||||rustdesk-bin|com.rustdesk.RustDesk
workstation|localsend|localsend||||||localsend-bin|org.localsend.localsend_app
workstation|obs|obs|obs-studio|obs-studio|obs-studio|obs-studio|obs-studio||com.obsproject.Studio
workstation|audacity|audacity|audacity|audacity|audacity|audacity|audacity||org.audacityteam.Audacity
workstation|blender|blender|blender|blender|blender|blender|blender||org.blender.Blender
workstation|darktable|darktable|darktable|darktable|darktable|darktable|darktable||org.darktable.Darktable
workstation|gimp|gimp|gimp|gimp|gimp|gimp|gimp||org.gimp.GIMP
workstation|inkscape|inkscape|inkscape|inkscape|inkscape|inkscape|inkscape||org.inkscape.Inkscape
workstation|kdenlive|kdenlive|kdenlive|kdenlive|kdenlive|kdenlive|kdenlive||org.kde.kdenlive
workstation|libreoffice|libreoffice|libreoffice-fresh|libreoffice|libreoffice|libreoffice|libreoffice||org.libreoffice.LibreOffice
workstation|vlc|vlc|vlc|vlc|vlc|vlc|vlc||org.videolan.VLC
workstation|mpv|mpv|mpv|mpv|mpv|mpv|mpv||io.mpv.Mpv
workstation|qbittorrent|qbittorrent|qbittorrent|qbittorrent|qbittorrent|qbittorrent|qbittorrent||org.qbittorrent.qBittorrent
workstation|telegram|telegram-desktop|telegram-desktop|telegram-desktop|telegram-desktop|telegram-desktop|telegram-desktop||org.telegram.desktop
full|dolphin-emulator|dolphin-emu|dolphin-emu|dolphin-emu|dolphin-emu|dolphin-emu|dolphin-emu||org.DolphinEmu.dolphin-emu
full|retroarch|retroarch|retroarch|retroarch|retroarch|retroarch|retroarch||org.libretro.RetroArch
full|ryujinx|ryujinx||||||ryujinx-bin|io.github.ryubing.Ryujinx
full|docker|docker|docker,docker-compose|docker.io,docker-compose-v2|docker,docker-compose-plugin|docker,docker-compose|docker,docker-cli-compose||
full|virtualization|virsh|qemu-full,libvirt,virt-manager|qemu-system,libvirt-daemon-system,virt-manager|qemu-kvm,libvirt,virt-manager|qemu,libvirt,virt-manager|qemu-system-x86_64,libvirt,virt-manager||
EOF
}

group_selected() {
  case "$1" in
    core) return 0 ;;
    workstation) [[ $PROFILE == workstation || $PROFILE == full ]] ;;
    full) [[ $PROFILE == full ]] ;;
    desktop-wayland) [[ $PROFILE != core && ( $DESKTOP == hyprland || $DESKTOP == sway || ( $DESKTOP == gnome && ${XDG_SESSION_TYPE:-} == wayland ) ) ]] ;;
    desktop-x11) [[ $PROFILE != core && $DESKTOP == gnome && ${XDG_SESSION_TYPE:-} != wayland ]] ;;
    desktop-*) [[ $PROFILE != core && $1 == desktop-$DESKTOP ]] ;;
    *) return 1 ;;
  esac
}

package_field() {
  case "$DISTRO_FAMILY" in
    pacman) printf '%s' "$1" ;; apt) printf '%s' "$2" ;; dnf) printf '%s' "$3" ;;
    zypper) printf '%s' "$4" ;; apk) printf '%s' "$5" ;;
  esac
}

native_is_installed() {
  case "$DISTRO_FAMILY" in
    pacman) pacman -Q "$1" >/dev/null 2>&1 ;; apt) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed' ;;
    dnf) rpm -q "$1" >/dev/null 2>&1 ;; zypper) rpm -q "$1" >/dev/null 2>&1 ;; apk) apk info -e "$1" >/dev/null 2>&1 ;;
  esac
}

native_is_available() {
  case "$DISTRO_FAMILY" in
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;; apt) apt-cache show "$1" >/dev/null 2>&1 ;;
    dnf) dnf --quiet list --available "$1" >/dev/null 2>&1 || dnf --quiet list --installed "$1" >/dev/null 2>&1 ;;
    zypper) zypper --non-interactive search --match-exact "$1" 2>/dev/null | grep -q "$1" ;;
    apk) apk search -e "$1" >/dev/null 2>&1 ;;
  esac
}

native_spec_ready() {
  local spec=$1 primary
  IFS=',' read -r -a packages <<<"$spec"
  primary=${packages[0]:-}
  [[ -n $primary ]] && { native_is_installed "$primary" || native_is_available "$primary"; }
}

install_native_spec() {
  local spec=$1 pkg index=0 primary_ok=0 install_status
  IFS=',' read -r -a packages <<<"$spec"
  for pkg in "${packages[@]}"; do
    if native_is_installed "$pkg"; then
      (( index == 0 )) && primary_ok=1
    elif native_is_available "$pkg"; then
      install_status=0
      case "$DISTRO_FAMILY" in
        pacman) run sudo pacman -S --needed --noconfirm "$pkg" || install_status=$? ;;
        apt) run sudo apt-get install -y "$pkg" || install_status=$? ;;
        dnf) run sudo dnf install -y "$pkg" || install_status=$? ;;
        zypper) run sudo zypper --non-interactive install "$pkg" || install_status=$? ;;
        apk) run sudo apk add "$pkg" || install_status=$? ;;
      esac
      if (( install_status == 0 )); then
        (( index == 0 )) && primary_ok=1
      else
        warn "Native package failed: $pkg"
      fi
    else
      warn "Native package unavailable: $pkg"
    fi
    ((index++))
  done
  (( primary_ok ))
}

ensure_debian_command_alias() {
  local capability=$1 target='' link=''
  [[ $DISTRO_FAMILY == apt ]] || return 0
  case "$capability" in
    fd) target=$(command -v fdfind 2>/dev/null || true); link=$HOME/.local/bin/fd ;;
    bat) target=$(command -v batcat 2>/dev/null || true); link=$HOME/.local/bin/bat ;;
    *) return 0 ;;
  esac
  if [[ -z $target ]] && (( DRY_RUN )); then
    [[ $capability == fd ]] && target=/usr/bin/fdfind || target=/usr/bin/batcat
  fi
  [[ -n $target ]] || return 1
  if [[ -e $link || -L $link ]]; then
    [[ -L $link && $(readlink "$link" 2>/dev/null) == "$target" ]]
    return
  fi
  run mkdir -p "$HOME/.local/bin" && run ln -s "$target" "$link"
}

ensure_flatpak_ready() {
  command -v flatpak >/dev/null 2>&1 || {
    native_is_available flatpak && install_native_spec flatpak || return 1
  }
  run flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_capability() {
  local capability=$1 command_name=$2 native=$3 aur=$4 flatpak_id=$5
  if [[ -n $command_name ]] && command -v "$command_name" >/dev/null 2>&1; then
    log "$capability already available"
    return 0
  fi
  if [[ -n $native ]] && native_spec_ready "$native"; then
    log "$capability: native ($native)"
    if install_native_spec "$native"; then
      ensure_debian_command_alias "$capability" || warn "Could not create the Debian $capability command alias"
      return 0
    fi
    warn "$capability native install failed; trying fallback"
  fi
  if [[ $DISTRO_FAMILY == pacman && -n $aur ]]; then
    local helper=
    command -v paru >/dev/null 2>&1 && helper=paru
    [[ -z $helper ]] && command -v yay >/dev/null 2>&1 && helper=yay
    if [[ -n $helper ]] && "$helper" -Si "$aur" >/dev/null 2>&1; then
      log "$capability: AUR ($aur via $helper)"
      run "$helper" -S --needed --noconfirm "$aur" && return 0
      warn "$capability AUR install failed; trying Flatpak"
    fi
  fi
  if [[ -n $flatpak_id ]]; then
    ensure_flatpak_ready || { warn "$capability unavailable: Flatpak could not be prepared"; return 1; }
    if command -v flatpak >/dev/null 2>&1 && flatpak info --user "$flatpak_id" >/dev/null 2>&1; then
      log "$capability Flatpak already installed"
      return 0
    fi
    log "$capability: Flatpak ($flatpak_id)"
    run flatpak install --user -y flathub "$flatpak_id" && return 0
  fi
  warn "$capability is unavailable for $DISTRO_ID"
  return 1
}

install_profile_packages() {
  local group capability command_name pac apt dnf zypper apk aur flatpak_id native
  while IFS='|' read -r group capability command_name pac apt dnf zypper apk aur flatpak_id; do
    group_selected "$group" || continue
    native=$(package_field "$pac" "$apt" "$dnf" "$zypper" "$apk")
    install_capability "$capability" "$command_name" "$native" "$aur" "$flatpak_id" || ((FAILURES++))
  done < <(package_manifest)
}

initialize_arch_rust() {
  [[ $DISTRO_FAMILY == pacman ]] || return 0
  command -v cargo >/dev/null 2>&1 && return 0
  command -v rustup >/dev/null 2>&1 || return 0
  if confirm "Initialize the Rust stable toolchain with rustup?"; then
    run rustup default stable || warn "Rust stable toolchain initialization failed"
  else
    warn "rustup is installed but no Cargo toolchain is initialized"
  fi
}

install_ai_tools() {
  (( AI_TOOLS )) || return 0
  command -v npm >/dev/null 2>&1 || { warn "npm is unavailable; skipping optional AI CLIs"; return 1; }
  local command_name npm_package
  while IFS='|' read -r command_name npm_package; do
    if command -v "$command_name" >/dev/null 2>&1; then
      log "$command_name already available"
      continue
    fi
    log "Installing $npm_package to $HOME/.local"
    run npm install --global --prefix "$HOME/.local" "$npm_package" || {
      warn "Failed to install $npm_package; continuing"
      ((FAILURES++))
    }
  done <<'EOF'
opencode|opencode-ai
claude|@anthropic-ai/claude-code
codex|@openai/codex
copilot|@github/copilot
pi|@earendil-works/pi-coding-agent
EOF
}
