#!/bin/bash
#
# Server/Headless Setup Script for Arch, Debian, and Fedora-based Systems
# This script auto-detects the distribution and installs a common
# set of essential command-line development tools and server configurations.
#

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Pre-flight Checks ---

# Prevent script from being run as root.
if [ "$EUID" -eq 0 ]; then
    echo "❌ This script must not be run as root. Use sudo internally when prompted."
    exit 1
fi

# Function to check for essential dependencies.
check_dependencies() {
    print_header "Checking for essential dependencies"
    local missing_deps=()
    local deps=("curl" "git") # Essential for the script to even start
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

# --- Helper Functions ---

# Function to print a formatted section header
print_header() {
    echo ""
    echo "===================================================================="
    echo "➡️  $1"
    echo "===================================================================="
}

# --- REMOVED: install_appimages function (GUI-related) ---

# Function to install Rust and Cargo
install_rust() {
    print_header "Installing Rust and Cargo"
    if ! command -v cargo &> /dev/null; then
        # The '-y' flag automates the installation
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        # Add cargo to the shell profile for persistence.
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.profile"
        # Source it for the current session as well.
        source "$HOME/.cargo/env"
        echo "Rust installed successfully."
    else
        echo "Rust is already installed. Skipping."
    fi
}

# Function to install Bun
install_bun() {
    print_header "Installing Bun JavaScript runtime"
    if ! command -v bun &> /dev/null; then
        curl -fsSL https://bun.sh/install | bash
        echo "Bun installed successfully."
        echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.profile"
    else
        echo "Bun is already installed. Skipping."
    fi
    # Source the profile to make bun available immediately.
    if [ -x "$HOME/.bun/bin/bun" ]; then
        "$HOME/.bun/bin/bun" --version
    fi
}

# Function to install common development tools via Cargo and NPM
install_common_dev_tools() {
    print_header "Installing common development tools (NPM packages, Cargo crates)"

    # Source cargo env to ensure it's available in this shell
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi

    echo "Installing global NPM packages..."
    
    # Configure NPM to use a local directory to avoid permission errors
    echo "➡️  Configuring NPM to use a user-local directory..."
    local NPM_GLOBAL_DIR="$HOME/.npm-global"
    mkdir -p "$NPM_GLOBAL_DIR"
    npm config set prefix "$NPM_GLOBAL_DIR"
    
    # Add the new path to the current session's PATH so the command works now
    export PATH="$NPM_GLOBAL_DIR/bin:$PATH"
    
    # Ensure the path is added to the shell profile for future sessions
    if ! grep -q 'export PATH="$HOME/.npm-global/bin:$PATH"' "$HOME/.profile" &>/dev/null; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.profile"
        echo "✅ Added NPM global path to $HOME/.profile for future sessions."
    fi
    # This command will now succeed by installing into the user's home directory
    # Removed: @tailwindcss/language-server (often used with GUI editors)
    npm install -g neovim tree-sitter-cli

    echo "Installing Rust-based tools with Cargo..."
    if command -v cargo &> /dev/null; then
        cargo install selene atuin
    else
        echo "⚠️  Cargo not found in PATH. Skipping installation of Rust tools."
    fi
}

# Function to clone personal configuration files
clone_user_configs() {
    print_header "Cloning user configuration files from GitHub"
    
    # Check for gh CLI before trying to use it.
    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI ('gh') not found. It should have been installed by the distro-specific function."
        exit 1
    fi

    echo "Authenticating with GitHub CLI. Please follow the prompts."
    # Use `gh auth status` to check if already logged in.
    if ! gh auth status &> /dev/null; then
        if ! gh auth login; then
            echo "❌ GitHub authentication failed. Cannot clone configs."
            exit 1
        fi
    else
        echo "✅ Already authenticated with GitHub."
    fi

    echo "Authentication successful. Cloning repositories..."

    # Helper function to clone a repo to a specific destination
    clone_repo() {
        local repo_name="$1"
        local destination_dir="$2"
        
        echo "Setting up repository: $repo_name"
        # Use `mv` for a backup instead of destructive `rm -rf`.
        if [ -d "$destination_dir" ]; then
            echo "Backing up existing directory: $destination_dir -> ${destination_dir}.bak"
            mv "$destination_dir" "${destination_dir}.bak.$(date +%s)"
        fi
        
        echo "Cloning $repo_name into $destination_dir..."
        gh repo clone "$repo_name" "$destination_dir" || { echo "❌ Failed to clone $repo_name."; exit 1; }
    }

    # --- REMOVED: Alacritty themes/configs and Wallpapers as they are GUI related. ---
    
    # Clone personal terminal/shell dotfiles
    clone_repo JevonThompsonx/fish "$HOME/.config/fish"
    
    echo "✅ System config cloning complete!"
}

# --- Distribution-Specific Setup Functions ---

setup_arch() {
    print_header "Running Arch Linux Setup"
    sudo pacman -Syu --noconfirm

    echo "Installing packages with pacman..."

    local packages=(
        tree git curl wget gnupg unzip ffmpeg github-cli neovim
        npm zoxide fastfetch fish eza tailscale
        python python-pip go ripgrep lazygit luarocks ruby php jdk-openjdk
        xsel xclip # xsel/xclip for server clipboard over SSH/tmux
    )
    
    # Pruned packages for headless:
    # Removed: calibre (GUI e-reader), foot (terminal emulator), ttf-fira-code (fonts), appimagelauncher (GUI)
    
    # Check for an existing Node.js installation before adding it to the list.
    if ! command -v node &> /dev/null; then
        echo "Node.js not found. Adding 'nodejs' to the installation list."
        packages+=("nodejs")
    else
        echo "✅ Node.js is already installed ($(node -v)). Skipping installation to avoid conflicts."
    fi

    sudo pacman -S --noconfirm --needed --ask 20 "${packages[@]}"

    # --- REMOVED: Omarchy Specific Setup (Desktop Environment logic) ---
}

setup_debian() {
    print_header "Running Debian/Ubuntu Setup"
    sudo apt update
    # Ensure tools for adding repositories are present
    sudo apt install -y curl wget gpg git lsb-release software-properties-common
    
    # Add external repositories
    echo "Adding external repositories..."

    # --- REMOVED: AppImageLauncher PPA (GUI-related) ---

    # eza
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    
    # Dynamically get the distro codename.
    local codename
    codename=$(lsb_release -cs)
    echo "Detected Debian/Ubuntu codename: $codename"
    
    # Tailscale
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.noarmor.gpg" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.tailscale-keyring.list" | sudo tee /etc/apt/sources.list.d/tailscale.list

    echo "Updating package list after adding repos..."
    sudo apt update
    
    echo "Installing packages with apt..."
    sudo apt install -y \
        extrepo gh neovim nodejs npm zoxide fastfetch fish \
        ffmpeg eza tailscale python3 python3-pip \
        python3-venv python3-pynvim golang-go ripgrep lazygit luarocks \
        ruby-full php openjdk-17-jdk xsel xclip # xsel/xclip for server clipboard over SSH/tmux
    
    # Pruned packages for headless:
    # Removed: calibre (GUI e-reader), foot (terminal emulator), variety (wallpaper setter), fonts-firacode (fonts), gnome-calendar (GUI), appimagelauncher (GUI)
}

setup_fedora() {
    print_header "Running Fedora Setup"
    sudo dnf upgrade --refresh -y
    
    echo "Enabling third-party repositories (RPM Fusion, GitHub CLI)..."
    sudo dnf install -y \
      "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    
    # --- REMOVED: AppImageLauncher COPR repository (GUI-related) ---

    echo "Installing packages with dnf..."
    sudo dnf install -y \
        git curl wget unzip fish fzf zoxide ripgrep eza fastfetch lazygit \
        neovim nodejs npm golang go gh tailscale \
        ffmpeg python3-pip python3-virtualenv python3-neovim \
        luarocks ruby php java-17-openjdk-devel xsel xclip # xsel/xclip for server clipboard over SSH/tmux

    # Pruned packages for headless:
    # Removed: foot (terminal emulator), variety (wallpaper setter), calibre (GUI e-reader), gnome-calendar (GUI), fira-code-fonts (fonts), appimagelauncher (GUI)

    # --- REMOVED: Flatpak installation (GUI/Desktop apps) ---
}

# --- Main Execution Logic ---

main() {
    check_dependencies

    # Check for /etc/os-release and source it
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo "❌ Cannot detect distribution: /etc/os-release not found."
        exit 1
    fi
    
    # Determine the distribution and run the appropriate setup function
    DISTRO_ID="${ID_LIKE:-$ID}"

    case "$DISTRO_ID" in
        *arch*)
            setup_arch
            ;;
        *debian* | *ubuntu*)
            setup_debian
            ;;
        *fedora*)
            setup_fedora
            ;;
        *)
            echo "❌ Unsupported distribution: $ID"
            exit 1
            ;;
    esac
    
    # --- Common Setup Steps for All Distributions ---
    
    # --- REMOVED: install_appimages ---
    install_rust
    install_bun
    install_common_dev_tools
    
    print_header "Setting up services and final configurations"
    
    echo "Enabling and starting Tailscale..."
    sudo systemctl enable --now tailscaled
    # Note: `tailscale up` requires interaction.
    sudo tailscale up
    
    # --- REMOVED: Font cache update (No fonts needed on a server) ---
    
    # Clone personal dotfiles
    clone_user_configs
    
    # Set Fish as the default shell if it isn't already
    if [[ "$SHELL" != */bin/fish ]]; then
        echo "Setting Fish as the default shell. You may be prompted for your password."
        if chsh -s "$(which fish)"; then
            echo "Shell changed to Fish. Please log out and back in to see the change."
        else
            echo "❌ Failed to change shell. Please do it manually with: chsh -s $(which fish)"
        fi
    else
        echo "Fish is already the default shell."
    fi
    
    print_header "Finalizing Neovim Setup"
    echo "Running Neovim in headless mode to sync plugins..."
    # Execute as the 'fish' shell to ensure it uses the newly configured environment
    if command -v fish &> /dev/null && command -v nvim &> /dev/null; then
        fish -c "nvim --headless '+Lazy sync' '+qa!'"
    else
        echo "⚠️ Could not find 'fish' or 'nvim' to finalize Neovim setup. Skipping."
    fi
    
    echo ""
    echo "✅ Server setup script finished!"
    echo "Please REBOOT your system for all changes to take full effect."
}

# Run the main function
main
