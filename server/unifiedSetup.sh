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
    local deps=("curl" "git") 
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
    
    echo "Updating package index..."
    sudo apk update
    sudo apk upgrade
    
    echo "Enabling community and testing repositories..."
    # Robust repo enabling
    sudo sed -i 's/^#//g' /etc/apk/repositories 
    
    # Specifically ensure edge community and testing are available for fastfetch/gh
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" | sudo tee -a /etc/apk/repositories
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" | sudo tee -a /etc/apk/repositories
    
    sudo apk update
    
    echo "Installing packages with apk..."
    local packages=(
        tree git curl wget gnupg unzip ffmpeg neovim
        nodejs npm zoxide fish tailscale
        python3 py3-pip go ripgrep luarocks ruby php83 openjdk17
        xsel xclip clamav clamav-daemon freshclam
        github-cli bash shadow build-base util-linux
    )
    
    # Fastfetch is often in testing on Alpine
    sudo apk add "${packages[@]}"
    sudo apk add fastfetch --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing
    
    echo "Configuring shell environment for Alpine..."
    # Alpine's fish path needs to be in /etc/shells for chsh to work
    if command -v fish &> /dev/null; then
        local FISH_PATH=$(which fish)
        if ! grep -q "$FISH_PATH" /etc/shells; then
            echo "$FISH_PATH" | sudo tee -a /etc/shells
        fi
    fi

    echo "Setting up ClamAV services (OpenRC)..."
    sudo rc-update add clamd default 2>/dev/null
    sudo freshclam 2>/dev/null || echo "⚠️ ClamAV update failed, continuing..."
    sudo rc-service clamd start 2>/dev/null
}

# --- Common Logic Functions ---

install_rust() {
    print_header "Installing Rust"
    if ! command -v cargo &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
}

install_bun() {
    print_header "Installing Bun"
    # Note: On Alpine, Bun requires 'gcompat' or 'libc6-compat'
    if [ -f /etc/alpine-release ]; then
        sudo apk add gcompat
    fi
    if ! command -v bun &> /dev/null; then
        curl -fsSL https://bun.sh/install | bash
    fi
}

# ... [Include your setup_lazyvim and clone_user_configs functions here] ...

main() {
    check_dependencies

    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo "❌ Cannot detect distribution."
        exit 1
    fi
    
    DISTRO_ID="${ID_LIKE:-$ID}"

    case "$DISTRO_ID" in
        *arch*) setup_arch ;;
        *debian*|*ubuntu*) setup_debian ;;
        *fedora*) setup_fedora ;;
        *alpine*) setup_alpine ;;
        *) echo "❌ Unsupported distribution: $ID"; exit 1 ;;
    esac
    
    install_rust
    install_bun
    # install_common_dev_tools
    # clone_user_configs
    # setup_lazyvim

    print_header "Finalizing Services"

    # Tailscale Setup (Systemd vs OpenRC)
    if command -v tailscale &> /dev/null; then
        if command -v systemctl &> /dev/null; then
            sudo systemctl enable --now tailscaled
        elif command -v rc-service &> /dev/null; then
            sudo rc-update add tailscale default
            sudo rc-service tailscale start
        fi
        echo "Attempting Tailscale login..."
        sudo tailscale up --authkey=YOUR_KEY_HERE || echo "⚠️ Manual 'tailscale up' required."
    fi

    # Set Default Shell
    if command -v fish &> /dev/null; then
        local FISH_PATH=$(which fish)
        echo "Setting default shell to $FISH_PATH"
        sudo chsh -s "$FISH_PATH" "$USER"
    fi

    echo "✅ Setup Complete. Please reboot."
}

main
