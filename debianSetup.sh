#!/bin/bash
# debianSetup.sh — Run on Debian 13 to replicate Bazzite environment
# Usage: bash debianSetup.sh
#
# Requires: sudo access (will prompt for password at start)
set -euo pipefail

# ── Color helpers ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
header() { echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"; }

# ── Pre-flight ─────────────────────────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    err "Do NOT run this script as root. Use a regular user with sudo."
    exit 1
fi

sudo -v  # Cache sudo credentials, prompt once

# ── 1. Enable contrib, non-free, non-free-firmware repos ──────────────────────
header "Enabling contrib/non-free repos"
if [ -f /etc/apt/sources.list ]; then
    # Only add if contrib missing (idempotent)
    if ! grep -q contrib /etc/apt/sources.list 2>/dev/null; then
        sudo sed -i '/^deb.* main/s/ main/ main contrib non-free non-free-firmware/' /etc/apt/sources.list
    fi
fi
sudo apt update

# ── 2. Install basic tools ────────────────────────────────────────────────────
header "Installing base CLI tools"
FOUNDATION=(
    curl wget git ca-certificates gnupg
    build-essential pkg-config libssl-dev unzip
    python3 python3-pip python3-venv pipx
    eza ripgrep jq
)
sudo apt install -y "${FOUNDATION[@]}"

# ── 3. Fish shell + config ────────────────────────────────────────────────────
header "Installing Fish shell"
sudo apt install -y fish

# Set fish as default shell for user (effective after next login)
if [ "$SHELL" != "/usr/bin/fish" ]; then
    warn "Changing default shell to fish. Log out/in for it to take effect."
    sudo chsh -s /usr/bin/fish "$(whoami)"
fi

# Create fish config directory
mkdir -p ~/.config/fish/{functions,conf.d,completions,themes}

# ── 4. Install zoxide ─────────────────────────────────────────────────────────
header "Installing zoxide"
sudo apt install -y zoxide

# ── 5. Install atuin (via cargo, not in Debian repos) ─────────────────────────
header "Installing atuin via cargo"
if ! command -v cargo &>/dev/null; then
    log "Installing Rust/Cargo first..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi
cargo install atuin

# ── 6. Install fastfetch ──────────────────────────────────────────────────────
header "Installing fastfetch"
sudo apt install -y fastfetch

# ── 7. Install GitHub CLI ─────────────────────────────────────────────────────
header "Installing GitHub CLI"
curl -fsSL "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
    | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh

log "After script completes, run: gh auth login"

# ── 8. Install Node.js (latest LTS via NodeSource) ────────────────────────────
header "Installing Node.js"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt install -y nodejs
sudo npm install -g npm@latest

# ── 9. Install Neovim ─────────────────────────────────────────────────────────
header "Installing Neovim"
sudo apt install -y neovim python3-pynvim
sudo npm install -g neovim tree-sitter-cli 2>/dev/null || warn "npm neovim/tree-sitter install skipped"

# ── 10. Install Bun ───────────────────────────────────────────────────────────
header "Installing Bun"
curl -fsSL https://bun.sh/install | bash

# ── 11. Install Go ────────────────────────────────────────────────────────────
header "Installing Go"
sudo apt install -y golang-go

# ── 12. Install Flatpak + Flathub ─────────────────────────────────────────────
header "Installing Flatpak"
sudo apt install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo apt install -y gnome-software-plugin-flatpak 2>/dev/null || warn "gnome-software-plugin-flatpak not available"

# ── 13. Install Flatpak apps (compatible subset from Bazzite) ─────────────────
header "Installing Flatpak applications"
BROWSERS=(
    com.brave.Browser
    io.gitlab.librewolf-community
    io.github.ungoogled_software.ungoogled_chromium
)
MEDIA=(
    com.obsproject.Studio
    com.spotify.Client
    org.videolan.VLC
    org.gimp.GIMP
    org.audacityteam.Audacity
    org.kde.kdenlive
    com.github.unrud.VideoDownloader
)
DEV=(
    md.obsidian.Obsidian
    com.github.tchx84.Flatseal
    io.github.flattool.Warehouse
    io.github.flattool.Ignition
    io.missioncenter.MissionCenter
    com.mattjakeman.ExtensionManager
)
UTILITY=(
    io.github.peazip.PeaZip
    org.qbittorrent.qBittorrent
    org.telegram.desktop
    com.rustdesk.RustDesk
    org.angryip.ipscan
    com.ranfdev.DistroShelf
    org.fedoraproject.MediaWriter
    org.libreoffice.LibreOffice
)
GAMING=(
    org.libretro.RetroArch
    com.github.Matoking.protontricks
    org.DolphinEmu.dolphin-emu
    net.rpcs3.RPCS3
    io.mgba.mGBA
)
FLATPAKS=("${BROWSERS[@]}" "${MEDIA[@]}" "${DEV[@]}" "${UTILITY[@]}" "${GAMING[@]}")
for app in "${FLATPAKS[@]}"; do
    log "Installing $app..."
    sudo flatpak install -y flathub "$app" || warn "Failed to install $app"
done

# ── 14. Install Tailscale ─────────────────────────────────────────────────────
header "Installing Tailscale"
curl -fsSL "https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg" \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL "https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list" \
    | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
sudo apt update
sudo apt install -y tailscale
sudo systemctl enable --now tailscaled
log "After script: sudo tailscale up"

# ── 15. Install GPU drivers (auto-detect) ─────────────────────────────────────
header "Installing GPU drivers"
if lspci | grep -qi 'vga.*nvidia' || lspci | grep -qi '3d.*nvidia'; then
    log "NVIDIA GPU detected — installing proprietary drivers"
    sudo apt install -y nvidia-driver firmware-misc-nonfree nvidia-settings || warn "NVIDIA driver install failed"
    log "Reboot required for NVIDIA driver"
elif lspci | grep -qi 'vga.*intel'; then
    log "Intel GPU detected — installing Intel drivers"
    sudo apt install -y intel-media-va-driver libva-drm2 libva2 i965-va-driver || true
elif lspci | grep -qi 'vga.*amd\|vga.*ati'; then
    log "AMD GPU detected — using Mesa drivers (already installed)"
else
    warn "Unknown GPU — Mesa drivers installed as fallback"
fi

# ── 16. Vulkan support ────────────────────────────────────────────────────────
header "Installing Vulkan support"
sudo apt install -y libvulkan1 vulkan-loader mesa-vulkan-drivers mesa-vulkan-drivers:i386 2>/dev/null || true

# ── 17. Install Docker + Podman ────────────────────────────────────────────────
header "Installing container tools"
sudo apt install -y docker.io podman distrobox 2>/dev/null || true
sudo systemctl enable --now docker 2>/dev/null || true

# ── 18. Install Fonts ─────────────────────────────────────────────────────────
header "Installing fonts"
sudo apt install -y fonts-firacode fonts-noto-color-emoji

# ── 19. AppImageLauncher ──────────────────────────────────────────────────────
header "Installing AppImageLauncher"
wget -q "https://github.com/TheAssassin/AppImageLauncher/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb" -O /tmp/appimagelauncher.deb
sudo apt install -y /tmp/appimagelauncher.deb && rm -f /tmp/appimagelauncher.deb
mkdir -p ~/Applications

# ── 20. Set up fish config (clone latest from GitHub) ─────────────────────────
header "Cloning fish configuration"
if [ ! -d ~/.config/fish/.git ]; then
    git clone https://github.com/JevonThompsonx/fish.git /tmp/fish-config
    mkdir -p ~/.config/fish
    cp -R /tmp/fish-config/* ~/.config/fish/
    rm -rf /tmp/fish-config
    log "Fish config cloned"
else
    log "Fish config already cloned, updating..."
    git -C ~/.config/fish pull --ff-only || warn "Fish config pull failed — check manually"
fi

# ── 21. Install Fisher plugins ────────────────────────────────────────────────
header "Installing Fisher plugins"
fish -c "curl -sL https://git.io/fisher | source && fisher update" || warn "Fisher install/update skipped — run 'fisher update' in fish shell"

# ── 22. Nextcloud AppImage ────────────────────────────────────────────────────
header "Installing Nextcloud"
if [ ! -f ~/Applications/Nextcloud-latest-x86_64.AppImage ]; then
    wget -q "https://github.com/nextcloud-releases/desktop/releases/latest/download/Nextcloud-latest-x86_64.AppImage" -O /tmp/nextcloud.AppImage
    mv /tmp/nextcloud.AppImage ~/Applications/Nextcloud-latest-x86_64.AppImage
    chmod +x ~/Applications/Nextcloud-latest-x86_64.AppImage
else
    log "Nextcloud AppImage already exists"
fi

# ── 23. Git configuration ────────────────────────────────────────────────────
header "Setting up Git"
git config --global user.name "Jevon Thompson"
git config --global user.email "JThompsonx00@gmail.com"
git config --global credential.helper ""
git config --global credential.helper "!/usr/bin/gh auth git-credential"

# ── 24. Create Projects directory ─────────────────────────────────────────────
header "Creating project directories"
mkdir -p ~/Projects ~/Documents ~/Downloads ~/Pictures

# ── Summary ───────────────────────────────────────────────────────────────────
header "SETUP COMPLETE"
echo ""
echo "  Next steps (you must run these):"
echo ""
echo "  1. Reboot (NVIDIA driver, fish shell)"
echo "     sudo reboot"
echo ""
echo "  2. After reboot, authenticate:"
echo "     gh auth login"
echo "     sudo tailscale up"
echo "     atuin login -u Jevonx"
echo "     atuin sync"
echo ""
echo "  3. In fish shell, update plugins:"
echo "     fisher update"
echo ""
echo "  4. Install remaining flatpaks (if desired):"
echo "     flatpak install flathub com.github.zocker_160.SyncThingy"
echo "     flatpak install flathub com.rcloneui.RcloneUI"
echo "     flatpak install flathub com.vysp3r.ProtonPlus"
echo "     flatpak install flathub org.azahar_emu.Azahar"
echo "     flatpak install flathub info.cemu.Cemu"
echo "     flatpak install flathub net.kuribo64.melonDS"
echo "     flatpak install flathub com.pokemmo.PokeMMO"
echo "     flatpak install flathub com.github.mtkennerly.ludusavi"
echo "     flatpak install flathub com.moonlight_stream.Moonlight"
echo "     flatpak install flathub io.itsterminal.WebPConverter"
echo "     flatpak install flathub org.virt_manager.virt-manager"
echo "     flatpak install flathub page.codeberg.dnkl.foot"
echo ""
echo "  5. Clone config repos:"
echo "     gh repo clone JevonThompsonx/nvim ~/.config/nvim"
echo ""
