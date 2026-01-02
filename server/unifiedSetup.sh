#!/bin/bash
#
# Definitive Server/Headless Setup Script (Arch, Debian, Fedora, Alpine)
# Optimized for Neovim 0.11.2+ and LazyVim
#

# --- Pre-flight Checks ---
if [ "$EUID" -eq 0 ]; then
    echo "❌ This script must not be run as root. Use sudo internally when prompted."
    exit 1
fi

print_header() {
    echo -e "\n===================================================================="
    echo "➡️  $1"
    echo "===================================================================="
}

check_dependencies() {
    print_header "Checking for essential dependencies"
    local deps=("curl" "git" "unzip" "sed")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "❌ Missing $dep. Please install it manually first."
            exit 1
        fi
    done
    echo "✅ Essential dependencies found."
}

# --- Distribution-Specific Setup Functions ---

setup_arch() {
    print_header "Running Arch Linux Setup"
    sudo pacman -Syu --noconfirm
    local packages=(tree git curl wget gnupg unzip ffmpeg github-cli neovim npm zoxide fastfetch fish eza tailscale python python-pip go ripgrep lazygit luarocks ruby php jdk-openjdk xsel xclip clamav)
    sudo pacman -S --noconfirm --needed "${packages[@]}"
}

setup_debian() {
    print_header "Running Debian/Ubuntu Setup"
    sudo apt update && sudo apt install -y curl wget gpg git lsb-release software-properties-common
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    local codename=$(lsb_release -cs)
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.noarmor.gpg" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.tailscale-keyring.list" | sudo tee /etc/apt/sources.list.d/tailscale.list
    sudo apt update && sudo apt install -y gh neovim nodejs npm zoxide fastfetch fish ffmpeg eza tailscale python3 python3-pip golang-go ripgrep lazygit luarocks ruby-full php openjdk-17-jdk xsel xclip clamav
}

setup_fedora() {
    print_header "Running Fedora Setup"
    sudo dnf upgrade --refresh -y
    sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y git curl wget unzip fish fzf zoxide ripgrep eza fastfetch lazygit neovim nodejs npm golang go gh tailscale ffmpeg python3-pip luarocks ruby php java-17-openjdk-devel xsel xclip clamav
}

setup_alpine() {
    print_header "Running Alpine Linux Setup (v3.21+ Migration)"
    
    # 1. Force upgrade to v3.21 if on older version
    if grep -q "v3.17" /etc/apk/repositories; then
        echo "Updating repositories from v3.17 to v3.21..."
        sudo sed -i 's/v3.17/v3.21/g' /etc/apk/repositories
        sudo sed -i '/@edge/d' /etc/apk/world # Clean old world tags
        sudo sed -i 's/community\///g; s/main\///g' /etc/apk/world
    fi

    # 2. Add Edge Repos for Neovim 0.11 compatibility
    if ! grep -q "edge/community" /etc/apk/repositories; then
        echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" | sudo tee -a /etc/apk/repositories
        echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" | sudo tee -a /etc/apk/repositories
        echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" | sudo tee -a /etc/apk/repositories
    fi

    sudo apk update
    sudo apk upgrade --available --update-cache

    local packages=(tree git curl wget gnupg unzip ffmpeg nodejs npm zoxide fish tailscale python3 py3-pip go ripgrep luarocks ruby php83 openjdk17 xsel xclip clamav clamav-daemon freshclam github-cli bash shadow build-base util-linux gcompat libc6-compat gzip tree-sitter-cli)
    sudo apk add "${packages[@]}"

    # 3. Force the Neovim 0.11.x and Libuv/Libluv bridge
    sudo apk add --upgrade --repository http://dl-cdn.alpinelinux.org/alpine/edge/main --repository http://dl-cdn.alpinelinux.org/alpine/edge/community libuv libluv neovim
    
    # 4. OpenRC Services
    sudo rc-update add clamd default 2>/dev/null
    sudo rc-service clamd start 2>/dev/null
}

# --- Neovim & LazyVim Logic ---

setup_lazyvim() {
    print_header "Resetting Neovim Environment"
    local nvim_config="$HOME/.config/nvim"
    
    # Wipe old caches that cause "module not found" errors in 0.11
    rm -rf "$HOME/.local/state/nvim/luac"
    rm -rf "$HOME/.cache/nvim"
    
    # Fresh Starter Clone
    if [ ! -d "$nvim_config" ]; then
        git clone https://github.com/LazyVim/starter "$nvim_config"
        rm -rf "$nvim_config/.git"
    fi
    
    # If neovim is still somehow old, apply the v14 pin
    local VER=$(nvim --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
    if [ "$(printf '%s\n%s' "0.11.2" "$VER" | sort -V | head -n1)" != "0.11.2" ]; then
        echo "🔧 Pinning LazyVim v14 for compatibility with Neovim $VER"
        mkdir -p "$nvim_config/lua/plugins"
        echo 'return { { "LazyVim/LazyVim", version = "14.15.0" }, }' > "$nvim_config/lua/plugins/core.lua"
        rm -rf "$HOME/.local/share/nvim/lazy"
    fi
}

# --- Personal Configs & Fixes ---

fix_fish_cargo() {
    print_header "Fixing Fish/Cargo Environment"
    mkdir -p "$HOME/.cargo"
    echo 'set -gx PATH "$HOME/.cargo/bin" $PATH' > "$HOME/.cargo/env.fish"
    
    mkdir -p "$HOME/.config/fish"
    if ! grep -q "env.fish" "$HOME/.config/fish/config.fish" 2>/dev/null; then
        echo 'source "$HOME/.cargo/env.fish"' >> "$HOME/.config/fish/config.fish"
    fi
}

# --- Execution ---

main() {
    check_dependencies
    if [ -f /etc/os-release ]; then . /etc/os-release; else exit 1; fi
    DISTRO_ID="${ID_LIKE:-$ID}"

    case "$DISTRO_ID" in
        *arch*) setup_arch ;;
        *debian*|*ubuntu*) setup_debian ;;
        *fedora*) setup_fedora ;;
        *alpine*) setup_alpine ;;
        *) echo "❌ Unsupported distro"; exit 1 ;;
    esac

    # Generic installs
    [ ! -d "$HOME/.cargo" ] && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    [ ! -f "$HOME/.bun/bin/bun" ] && curl -fsSL https://bun.sh/install | bash
    
    fix_fish_cargo
    setup_lazyvim

    # Finalize Shell
    sudo chsh -s "$(which fish)" "$USER"

    echo -e "\n✅ Setup Finished! Please REBOOT to apply system library changes."
}

main
