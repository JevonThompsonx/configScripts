#!/bin/bash
#
# Unified Setup Script for Arch, Debian, and Fedora-based Systems
# This script auto-detects the distribution and installs a common
# set of development tools, applications, and personal configurations.
#

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status.
set -e

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
        # Add cargo to the current session's PATH
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
        # Add Bun to PATH for future shell sessions
        # Note: The fish path is handled in the final config cloning
        echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.profile"
    else
        echo "Bun is already installed. Skipping."
    fi
    # Display version
    "$HOME/.bun/bin/bun" -v
}

# Function to install common development tools via Cargo and NPM
install_common_dev_tools() {
    print_header "Installing common development tools (NPM packages, Cargo crates)"
    
    # Source cargo env to ensure it's available
    source "$HOME/.cargo/env"
    
    echo "Installing global NPM packages..."
    sudo npm install -g neovim tree-sitter-cli @tailwindcss/language-server
    
    echo "Installing Rust-based tools with Cargo..."
    cargo install selene atuin
}

# Function to clone personal configuration files
clone_user_configs() {
    print_header "Cloning user configuration files from GitHub"
    
    echo "Authenticating with GitHub CLI. Please follow the prompts."
    if ! gh auth login; then
      echo "❌ GitHub authentication failed. Cannot clone configs."
      exit 1
    fi
    
    echo "Authentication successful. Cloning repositories..."

    # Helper function to clone a repo to a specific destination
    clone_repo() {
        local repo_name="$1"
        local destination_dir="$2"
        
        echo "Setting up repository: $repo_name"
        # Remove the destination directory if it already exists for a clean clone
        if [ -d "$destination_dir" ]; then
            echo "Removing existing directory: $destination_dir"
            rm -rf "$destination_dir"
        fi
        
        echo "Cloning $repo_name into $destination_dir..."
        gh repo clone "$repo_name" "$destination_dir" || { echo "❌ Failed to clone $repo_name."; exit 1; }
    }

    # Setting up Alacritty themes separately
    echo "Cloning Alacritty themes..."
    mkdir -p "$HOME/.config/alacritty/themes"
    if [ ! -d "$HOME/.config/alacritty/themes/alacritty-theme" ]; then
        git clone https://github.com/alacritty/alacritty-theme.git "$HOME/.config/alacritty/themes"
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
    sudo pacman -S --noconfirm --needed --ask 20 \
        tree git curl wget gnupg unzip ffmpeg calibre github-cli neovim \
        nodejs npm zoxide fastfetch foot fish eza tailscale ttf-fira-code \
        python python-pip go ripgrep lazygit luarocks ruby php jdk17-openjdk \
        xsel xclip
    # ... (this comes after the 'sudo pacman' command in setup_arch)

    # --- Omarchy Specific Setup ---
    # Check if the specific distribution ID is 'omarchy'
    if [ "$ID" == "omarchy" ]; then
        print_header "Omarchy Configuration"
        echo "Omarchy detected. This script can link your '$HOME/Pictures/WPs' folder"
        echo "to the system theme directories for custom backgrounds."
        
        # Ask the user for confirmation
        read -p "Do you want to perform this action? (y/N): " response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            OMARCHY_THEME_DIR="$HOME/.config/omarchy/themes"
            
            if [ -d "$OMARCHY_THEME_DIR" ]; then
                echo "Linking wallpapers to Omarchy themes..."
                for theme in "$OMARCHY_THEME_DIR"/*/; do
                    # Ensure the item is actually a directory
                    if [ -d "$theme" ]; then
                        echo "  -> Linking for theme: $(basename "$theme")"
                        # Remove the existing 'backgrounds' directory to prevent conflicts
                        rm -rf "$theme/backgrounds"
                        # Create the symbolic link
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
    sudo apt install -y curl wget gpg git
    
    # Add external repositories (eza, Tailscale)
    echo "Adding external repositories..."
    # eza
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    
    # Tailscale
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

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
      https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
      https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
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
    sudo tailscale up # Requires user interaction to log in
    
    echo "Updating font cache..."
    sudo fc-cache -fv
    
    # Clone personal dotfiles (this will prompt for GitHub login)
    clone_user_configs
    
    # Set Fish as the default shell if it isn't already
    if [[ "$SHELL" != */bin/fish ]]; then
        echo "Setting Fish as the default shell. You may be prompted for your password."
        chsh -s "$(which fish)"
        echo "Shell changed to Fish. Please log out and back in to see the change."
    else
        echo "Fish is already the default shell."
    fi
    
    print_header "Finalizing Neovim Setup"
    echo "Running Neovim in headless mode to sync plugins..."
    # Execute as the 'fish' shell to ensure it uses the newly configured environment
    fish -c "nvim --headless '+Lazy sync' '+qa!'"
    
    echo ""
    echo "✅ Setup script finished!"
    echo "Please REBOOT your system for all changes to take full effect."
}

# Run the main function
main
