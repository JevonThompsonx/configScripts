#!/bin/bash
#
# Server/Headless Setup Script for Arch, Debian, Fedora, and Alpine-based Systems
#

# --- Pre-flight Checks ---

if [ "$EUID" -eq 0 ]; then
    echo "❌ This script must not be run as root. Use sudo internally when prompted."
    exit 1
fi

# Function to print a formatted section header
print_header() {
    echo ""
    echo "===================================================================="
    echo "➡️  $1"
    echo "===================================================================="
}

check_dependencies() {
    print_header "Checking for essential dependencies"
    local missing_deps=()
    local deps=("curl" "git" "unzip")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "❌ Missing essential dependencies: ${missing_deps[*]}. Please install them and re-run."
        exit 1
    fi
    echo "✅ Essential dependencies found."
}

# --- Distribution-Specific Setup Functions ---

setup_arch() {
    print_header "Running Arch Linux Setup"
    sudo pacman -Syu --noconfirm
    local packages=(
        tree git curl wget gnupg unzip ffmpeg github-cli neovim
        npm zoxide fastfetch fish eza tailscale
        python python-pip go ripgrep lazygit luarocks ruby php jdk-openjdk
        xsel xclip clamav
    )
    sudo pacman -S --noconfirm --needed "${packages[@]}"
}

setup_debian() {
    print_header "Running Debian/Ubuntu Setup"
    sudo apt update
    sudo apt install -y curl wget gpg git lsb-release software-properties-common

    # Add eza repo
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list

    local codename=$(lsb_release -cs)
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.noarmor.gpg" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.tailscale-keyring.list" | sudo tee /etc/apt/sources.list.d/tailscale.list

    sudo apt update
    sudo apt install -y \
        gh neovim nodejs npm zoxide fastfetch fish \
        ffmpeg eza tailscale python3 python3-pip \
        golang-go ripgrep lazygit luarocks \
        ruby-full php openjdk-17-jdk xsel xclip clamav
}

setup_fedora() {
    print_header "Running Fedora Setup"
    sudo dnf upgrade --refresh -y
    sudo dnf install -y \
      "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

    sudo dnf install -y \
        git curl wget unzip fish fzf zoxide ripgrep eza fastfetch lazygit \
        neovim nodejs npm golang go gh tailscale \
        ffmpeg python3-pip luarocks ruby php java-17-openjdk-devel xsel xclip clamav
}

setup_alpine() {
    print_header "Running Alpine Linux Setup"
    sudo apk update && sudo apk upgrade
    sudo sed -i 's/^#//g' /etc/apk/repositories
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" | sudo tee -a /etc/apk/repositories
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" | sudo tee -a /etc/apk/repositories
    sudo apk update

    local packages=(
        tree git curl wget gnupg unzip ffmpeg neovim
        nodejs npm zoxide fish tailscale
        python3 py3-pip go ripgrep luarocks ruby php83 openjdk17
        xsel xclip clamav clamav-daemon freshclam
        github-cli bash shadow build-base util-linux gcompat libc6-compat gzip
    )
    sudo apk add "${packages[@]}"
    sudo apk add fastfetch --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing

    # Shell configuration
    if command -v fish &> /dev/null; then
        local FISH_PATH=$(which fish)
        if ! grep -q "$FISH_PATH" /etc/shells; then echo "$FISH_PATH" | sudo tee -a /etc/shells; fi
    fi

    # OpenRC Services
    sudo rc-update add clamd default 2>/dev/null
    sudo freshclam 2>/dev/null
    sudo rc-service clamd start 2>/dev/null
}

# --- Neovim & LazyVim Logic ---

check_nvim_compatibility() {
    print_header "Verifying Neovim version for LazyVim"
    local REQUIRED="0.11.2"
    local CURRENT=$(nvim --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")

    # If version is less than 0.11.2
    if [ "$(printf '%s\n%s' "$REQUIRED" "$CURRENT" | sort -V | head -n1)" != "$REQUIRED" ]; then
        echo "⚠️  Neovim ($CURRENT) is below $REQUIRED."
        
        # Try to install latest via AppImage (non-Alpine)
        if [ ! -f /etc/alpine-release ] && [ "$(uname -m)" == "x86_64" ]; then
            echo "Attempting to install latest Neovim AppImage..."
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
            chmod +x nvim-linux-x86_64.appimage
            sudo mv nvim-linux-x86_64.appimage /usr/local/bin/nvim
            return 0
        else
            echo "Package manager version is too old and AppImage not suitable. Falling back to LazyVim v14."
            return 1
        fi
    fi
    return 0
}

setup_lazyvim() {
    print_header "Setting up LazyVim"
    local nvim_config="$HOME/.config/nvim"
    
    # Clone starter if not exists
    if [ ! -d "$nvim_config" ]; then
        git clone https://github.com/LazyVim/starter "$nvim_config"
        rm -rf "$nvim_config/.git"
    fi

    if ! check_nvim_compatibility; then
        echo "🔧 Applying LazyVim v14.x pin for Neovim compatibility..."
        mkdir -p "$nvim_config/lua/plugins"
        cat <<EOF > "$nvim_config/lua/plugins/core.lua"
return {
  { "LazyVim/LazyVim", version = "14.15.0" },
}
EOF
        # Clean up old state
        rm -rf "$HOME/.local/share/nvim/lazy/LazyVim"
        rm -f "$nvim_config/lazy-lock.json"
    fi
}

# --- Personal Configs ---

clone_user_configs() {
    print_header "Cloning Fish Configurations"
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            mkdir -p "$HOME/.config"
            if [ -d "$HOME/.config/fish" ]; then mv "$HOME/.config/fish" "$HOME/.config/fish.bak.$(date +%s)"; fi
            gh repo clone JevonThompsonx/fish "$HOME/.config/fish"
        else
            echo "⚠️  GitHub CLI not authenticated. Run 'gh auth login' manually."
        fi
    fi
}

# --- Common Setup ---

install_rust() {
    print_header "Installing Rust"
    if ! command -v cargo &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
    fi
}

install_bun() {
    print_header "Installing Bun"
    if ! command -v bun &> /dev/null; then
        curl -fsSL https://bun.sh/install | bash
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

    install_rust
    install_bun
    clone_user_configs
    setup_lazyvim

    print_header "Finalizing Services"

    # Tailscale
    if command -v tailscale &> /dev/null; then
        if command -v systemctl &> /dev/null; then
            sudo systemctl enable --now tailscaled
        elif command -v rc-service &> /dev/null; then
            sudo rc-update add tailscale default && sudo rc-service tailscale start
        fi
        echo "Connect Tailscale with: sudo tailscale up"
    fi

    # Shell Change
    if command -v fish &> /dev/null; then
        sudo chsh -s "$(which fish)" "$USER"
    fi

    echo "✅ Setup Finished! Please reboot and run Neovim to initialize plugins."
}

main
