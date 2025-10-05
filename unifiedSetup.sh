#!/bin/bash
#
# Unified Setup Script for Arch, Debian, and Fedora-based Systems
# This script auto-detects the distribution and installs a common
# set of development tools, applications, and personal configurations.
#

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Pre-flight Checks ---

# [FIX] Prevent script from being run as root.
if [ "$EUID" -eq 0 ]; then
  echo "❌ This script must not be run as root. Use sudo internally when prompted."
  exit 1
fi

# [IMPROVEMENT] Function to check for essential dependencies.
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

# Function to install Rust and Cargo
install_rust() {
    print_header "Installing Rust and Cargo"
    if ! command -v cargo &> /dev/null; then
        # The '-y' flag automates the installation
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        # [FIX] Add cargo to the shell profile for persistence.
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
        # Note: The script already correctly adds this to .profile.
        echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.profile"
    else
        echo "Bun is already installed. Skipping."
    fi
    # [IMPROVEMENT] Source the profile to make bun available immediately.
    # It's better to use the absolute path if we can't guarantee it's in the PATH yet.
    if [ -x "$HOME/.bun/bin/bun" ]; then
        "$HOME/.bun/bin/bun" --version
    fi
}

# Function to install common development tools via Cargo and NPM
install_common_dev_tools() {
    print_header "Installing common development tools (NPM packages, Cargo crates)"

    # Source cargo env to ensure it's available in this shell
    source "$HOME/.cargo/env"

    echo "Installing global NPM packages..."
    # [FIX] Avoid running `npm install -g` with sudo.
    # This requires the user to have configured npm to use a local directory.
    echo "ℹ️  Note: Installing global NPM packages without sudo."
    echo "This requires NPM to be configured correctly. If this fails, run:"
    echo 'mkdir -p "$HOME/.npm-global" && npm config set prefix "$HOME/.npm-global"'
    echo 'And add export PATH="$HOME/.npm-global/bin:$PATH" to your .profile'
    npm install -g neovim tree-sitter-cli @tailwindcss/language-server

    echo "Installing Rust-based tools with Cargo..."
    cargo install selene atuin
}

# Function to clone personal configuration files
clone_user_configs() {
    print_header "Cloning user configuration files from GitHub"
    
    # [IMPROVEMENT] Check for gh CLI before trying to use it.
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
        # [IMPROVEMENT] Use `mv` for a backup instead of destructive `rm -rf`.
        if [ -d "$destination_dir" ]; then
            echo "Backing up existing directory: $destination_dir -> ${destination_dir}.bak"
            mv "$destination_dir" "${destination_dir}.bak.$(date +%s)"
        fi
        
        echo "Cloning $repo_name into $destination_dir..."
        gh repo clone "$repo_name" "$destination_dir" || { echo "❌ Failed to clone $repo_name."; exit 1; }
    }

    # Setting up Alacritty themes separately
    echo "Cloning Alacritty themes..."
    mkdir -p "$HOME/.config/alacritty/themes"
    if [ ! -d "$HOME/.config/alacritty/themes/alacritty-theme" ]; then
        git clone https://github.com/alacritty/alacritty-theme.git "$HOME/.config/alacritty/themes/alacritty-theme"
    else
        echo "Alacritty themes directory already exists. Skipping."
    fi

    # Clone personal dotfiles
    clone_repo JevonThompsonx/alacritty "$HOME/.config/alacritty"
    clone_repo JevonThompsonx/fish "$HOME/.config/fish"
    clone_repo JevonThompsonx/WPs "$HOME/Pictures/WPs"

    echo "✅ System config cloning complete!"
}

# --- Distribution-Specific Setup Functions ---

setup_arch() {
    print_header "Running Arch Linux Setup"
    sudo pacman -Syu --noconfirm
    
    echo "Installing packages with pacman..."
    # The --ask 20 is unusual but respected as user preference.
    sudo pacman -S --noconfirm --needed --ask 20 \
        tree git curl wget gnupg unzip ffmpeg calibre github-cli neovim \
        nodejs npm zoxide fastfetch foot fish eza tailscale ttf-fira-code \
        python python-pip go ripgrep lazygit luarocks ruby php jdk-openjdk \
        xsel xclip

    # --- Omarchy Specific Setup ---
    # This logic is sound, no changes needed.
    if [ "$ID" == "omarchy" ]; then
        print_header "Omarchy Configuration"
        echo "Omarchy detected. This script can link your '$HOME/Pictures/WPs' folder"
        echo "to the system theme directories for custom backgrounds."
        
        read -p "Do you want to perform this action? (y/N): " response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            OMARCHY_THEME_DIR="$HOME/.config/omarchy/themes"
            
            if [ -d "$OMARCHY_THEME_DIR" ]; then
                echo "Linking wallpapers to Omarchy themes..."
                for theme in "$OMARCHY_THEME_DIR"/*/; do
                    if [ -d "$theme" ]; then
                        echo "  -> Linking for theme: $(basename "$theme")"
                        rm -rf "$theme/backgrounds"
                        ln -s "$HOME/Pictures/WPs/" "$theme/backgrounds"
                    fi
                done
                echo "✅ Wallpaper linking complete."
            else
                echo "⚠️  Warning: Directory not found, skipping: $OMARCHY_THEME_DIR"
            fi
        else
            echo "Skipping Omarchy wallpaper linking."
        fi
    fi
}

setup_debian() {
    print_header "Running Debian/Ubuntu Setup"
    sudo apt update
    sudo apt install -y curl wget gpg git lsb-release # [IMPROVEMENT] ensure lsb-release is present
    
    # Add external repositories (eza, Tailscale)
    echo "Adding external repositories..."
    # eza
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    
    # [FIX] Dynamically get the distro codename instead of hardcoding 'trixie'.
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
        extrepo calibre gh neovim nodejs npm zoxide fastfetch foot fish \
        ffmpeg eza tailscale variety fonts-firacode python3 python3-pip \
        python3-venv python3-pynvim golang-go ripgrep lazygit luarocks \
        ruby-full php openjdk-17-jdk xsel xclip gnome-calendar
}

setup_fedora() {
    print_header "Running Fedora Setup"
    sudo dnf upgrade --refresh -y
    
    echo "Enabling third-party repositories (RPM Fusion, GitHub CLI)..."
    sudo dnf install -y \
      "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    
    echo "Installing packages with dnf..."
    sudo dnf install -y \
        git curl wget unzip fish fzf zoxide ripgrep eza fastfetch lazygit \
        foot neovim nodejs npm golang go gh tailscale variety calibre \
        gnome-calendar ffmpeg python3-pip python3-virtualenv python3-neovim \
        luarocks ruby php java-17-openjdk-devel xsel xclip fira-code-fonts

    echo "Installing desktop applications via Flatpak..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install flathub -y \
      md.obsidian.Obsidian \
      net.localsend.localsend \
      io.freetubeapp.FreeTube \
      com.librewolf.Librewolf \
      com.nextcloud.desktopclient
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
    # ID_LIKE is used to catch derivatives (e.g., Ubuntu for Debian, Garuda for Arch)
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
    
    install_rust
    install_bun
    install_common_dev_tools
    
    print_header "Setting up services and final configurations"
    
    echo "Enabling and starting Tailscale..."
    sudo systemctl enable --now tailscaled
    # Note: `tailscale up` requires interaction. Consider adding `--authkey` for true automation.
    # For now, this is fine.
    sudo tailscale up
    
    echo "Updating font cache..."
    sudo fc-cache -fv
    
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
    echo "✅ Setup script finished!"
    echo "Please REBOOT your system for all changes to take full effect."
}

# Run the main function
main
