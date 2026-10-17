#!/bin/bash
# reverse-debianSetup.sh — Undo the changes made by debianSetup.sh in a Debian 13 Qubes template
# Usage: bash reverse-debianSetup.sh
#
# WARNING: This is a best-effort reverse. Review before running. It removes packages/repos/config
# added by debianSetup.sh. It will NOT delete your personal data/projects, but it may remove
# tools you now want. Run in a disposable/clone first if unsure.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
header() { echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"; }

if [ "$EUID" -eq 0 ]; then
    err "Do NOT run as root. Use a regular user with sudo."
    exit 1
fi
sudo -v

# ── 1. Remove NVIDIA drivers (common cause of broken Qubes GUI in templates) ──
header "Removing NVIDIA drivers"
sudo apt remove --purge -y nvidia-driver nvidia-settings firmware-misc-nonfree \
    nvidia-driver-libs nvidia-egl-common nvidia-kernel-common 2>/dev/null || true
sudo apt autoremove -y || true

# ── 2. Remove Flatpak apps and Flathub remote ────────────────────────────────
header "Removing Flatpak apps"
if command -v flatpak &>/dev/null; then
    flatpak list --app --columns=application 2>/dev/null | tail -n +1 | while read -r app; do
        [ -z "$app" ] && continue
        sudo flatpak uninstall -y "$app" 2>/dev/null || true
    done
    sudo flatpak remote-delete flathub 2>/dev/null || true
fi
sudo apt remove --purge -y flatpak gnome-software-plugin-flatpak 2>/dev/null || true

# ── 3. Remove added apt sources ──────────────────────────────────────────────
header "Removing added apt sources"
sudo rm -f /etc/apt/sources.list.d/github-cli.list
sudo rm -f /etc/apt/sources.list.d/tailscale.list
sudo rm -f /etc/apt/sources.list.d/nodesource.list
sudo rm -f /usr/share/keyrings/githubcli-archive-keyring.gpg
sudo rm -f /usr/share/keyrings/tailscale-archive-keyring.gpg
# NodeSource cleanup (list file name varies)
sudo rm -f /etc/apt/sources.list.d/nodesource*.list 2>/dev/null || true
sudo apt update || true

# ── 4. Remove packages installed by debianSetup.sh ───────────────────────────
header "Removing installed packages"
PACKAGES=(
    # base tools
    eza ripgrep jq build-essential pkg-config libssl-dev unzip
    # fish
    fish zoxide fastfetch
    # github cli
    gh
    # node
    nodejs
    # neovim
    neovim python3-pynvim
    # go
    golang-go
    # tailscale
    tailscale
    # vulkan
    libvulkan1 vulkan-loader mesa-vulkan-drivers
    # containers
    docker.io podman distrobox
    # fonts
    fonts-firacode fonts-noto-color-emoji
    # misc
    appimagelauncher
)
sudo apt remove --purge -y "${PACKAGES[@]}" 2>/dev/null || true
sudo apt autoremove -y || true

# ── 5. Remove cargo-installed tools ──────────────────────────────────────────
header "Removing cargo-installed tools"
rm -f "$HOME/.cargo/bin/atuin" 2>/dev/null || true
# Remove rustup/cargo entirely (optional; comment out if you want to keep Rust)
if [ -d "$HOME/.cargo" ]; then
    warn "Removing Rust/Cargo toolchain"
    rm -rf "$HOME/.cargo" "$HOME/.rustup"
fi

# ── 6. Remove Bun ────────────────────────────────────────────────────────────
header "Removing Bun"
rm -rf "$HOME/.bun" 2>/dev/null || true

# ── 7. Revert default shell to bash ─────────────────────────────────────────
header "Reverting default shell to bash"
if [ "$SHELL" != "/bin/bash" ]; then
    sudo chsh -s /bin/bash "$(whoami)" 2>/dev/null || true
    warn "Default shell changed to bash. Log out/in for it to take effect."
fi

# ── 8. Remove cloned fish config changes (optional) ─────────────────────────
header "Cleaning fish config"
# Only remove the PATH lines added by the script, keep the rest
if [ -f "$HOME/.config/fish/config.fish" ]; then
    sed -i '/# Added by configScripts (cargo\/bin + bun\/bin)/,/set -gx PATH \$HOME\/.cargo\/bin/d' \
        "$HOME/.config/fish/config.fish" 2>/dev/null || true
fi

# ── 9. Remove Nextcloud AppImage ─────────────────────────────────────────────
header "Removing Nextcloud AppImage"
rm -f "$HOME/Applications/Nextcloud-latest-x86_64.AppImage" 2>/dev/null || true

# ── 10. Remove AppImageLauncher deb (best-effort) ───────────────────────────
header "Removing AppImageLauncher"
sudo apt remove --purge -y appimagelauncher 2>/dev/null || true

# ── 11. Revert contrib/non-free repo change (optional) ───────────────────────
header "Reverting apt sources (contrib/non-free)"
# This only removes the added words; review /etc/apt/sources.list afterwards
if [ -f /etc/apt/sources.list ]; then
    sudo sed -i 's/ main contrib non-free non-free-firmware/ main/g' /etc/apt/sources.list 2>/dev/null || true
fi
sudo apt update || true

log "Cleanup complete. Review changes, then reboot the template if needed."
echo ""
warn "Some user-level config (git, fish plugins, projects) was left intact."
warn "Remove manually if desired: ~/.config/fish, ~/.config/nvim, ~/Projects, etc."
