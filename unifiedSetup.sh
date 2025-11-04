#!/bin/bash
#
# Unified Setup Script for Arch, Debian, and Fedora-based Systems
# This script auto-detects the distribution and installs a common
# set of development tools, applications, and personal configurations.
#

# --- Configuration ---
# Note: We do NOT use 'set -e' to allow the script to continue on non-critical errors
# Critical errors are handled explicitly with exit statements

# --- Pre-flight Checks ---

# Prevent script from being run as root.
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

# --- NEW: Function to install AppImages and their launcher ---
install_appimages() {
    print_header "Installing AppImages (Nextcloud)"
    local app_dir="$HOME/Applications"
    mkdir -p "$app_dir"

    # Define the Nextcloud AppImage details
    local nextcloud_appimage_name="Nextcloud-latest-x86_64.AppImage"
    local nextcloud_url="https://github.com/nextcloud-releases/desktop/releases/latest/download/${nextcloud_appimage_name}"
    local nextcloud_dest="$app_dir/$nextcloud_appimage_name"

    # Download the AppImage if it doesn't exist
    if [ ! -f "$nextcloud_dest" ]; then
        echo "Downloading Nextcloud AppImage..."
        # Use wget as it's a common dependency installed by the script
        wget -q --show-progress -O "$nextcloud_dest" "$nextcloud_url"
        chmod +x "$nextcloud_dest"
        echo "✅ Nextcloud AppImage installed to $nextcloud_dest"
        echo "AppImageLauncher will help integrate it into your system."
    else
        echo "✅ Nextcloud AppImage already exists. Skipping download."
    fi
}


# Function to install Rust and Cargo
install_rust() {
    print_header "Installing Rust and Cargo"
    if ! command -v cargo &> /dev/null; then
        echo "Installing Rust..."
        # The '-y' flag automates the installation
        if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
            # Add cargo to the shell profile for persistence.
            if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
                echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.profile"
            fi
            # Source it for the current session as well.
            source "$HOME/.cargo/env"
            echo "✅ Rust installed successfully."
        else
            echo "⚠️  Rust installation failed. Skipping Rust-based tools."
            return 1
        fi
    else
        echo "✅ Rust is already installed. Skipping."
    fi
}

# Function to install Bun
install_bun() {
    print_header "Installing Bun JavaScript runtime"
    if ! command -v bun &> /dev/null; then
        echo "Installing Bun..."
        if curl -fsSL https://bun.sh/install | bash; then
            if ! grep -q 'export PATH="$HOME/.bun/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
                echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.profile"
            fi
            echo "✅ Bun installed successfully."
        else
            echo "⚠️  Bun installation failed. Continuing anyway..."
            return 1
        fi
    else
        echo "✅ Bun is already installed. Skipping."
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

    # Configure NPM to use a local directory to avoid permission errors
    if command -v npm &> /dev/null; then
        echo "➡️  Configuring NPM to use a user-local directory..."
        local NPM_GLOBAL_DIR="$HOME/.npm-global"
        mkdir -p "$NPM_GLOBAL_DIR"
        npm config set prefix "$NPM_GLOBAL_DIR"

        # Add the new path to the current session's PATH so the command works now
        export PATH="$NPM_GLOBAL_DIR/bin:$PATH"

        # Ensure the path is added to the shell profile for future sessions
        if ! grep -q 'export PATH="$HOME/.npm-global/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
            echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.profile"
            echo "✅ Added NPM global path to $HOME/.profile for future sessions."
        fi

        echo "Installing global NPM packages..."
        # Install packages one by one to continue even if one fails
        for package in neovim tree-sitter-cli @tailwindcss/language-server; do
            if npm install -g "$package"; then
                echo "✅ Installed $package"
            else
                echo "⚠️  Failed to install $package, continuing..."
            fi
        done
    else
        echo "⚠️  NPM not found. Skipping NPM package installation."
    fi

    echo "Installing Rust-based tools with Cargo..."
    if command -v cargo &> /dev/null; then
        # Install packages one by one to continue even if one fails
        for crate in selene atuin; do
            if cargo install "$crate"; then
                echo "✅ Installed $crate"
            else
                echo "⚠️  Failed to install $crate, continuing..."
            fi
        done
    else
        echo "⚠️  Cargo not found in PATH. Skipping installation of Rust tools."
    fi
}

# Function to setup LazyVim
setup_lazyvim() {
    print_header "Setting up LazyVim"

    local nvim_config="$HOME/.config/nvim"
    local nvim_share="$HOME/.local/share/nvim"
    local nvim_state="$HOME/.local/state/nvim"
    local nvim_cache="$HOME/.cache/nvim"

    # Check if LazyVim is already installed
    if [ -d "$nvim_config" ] && [ -f "$nvim_config/lua/config/lazy.lua" ]; then
        echo "LazyVim appears to be already installed. Skipping setup."
        return 0
    fi

    echo "Backing up existing Neovim directories..."
    local timestamp
    timestamp=$(date +%s)

    # Backup directories if they exist
    for dir in "$nvim_config" "$nvim_share" "$nvim_state" "$nvim_cache"; do
        if [ -d "$dir" ]; then
            local backup="${dir}.bak.${timestamp}"
            if mv "$dir" "$backup"; then
                echo "✅ Backed up $(basename "$dir") to ${backup}"
            else
                echo "⚠️  Failed to backup $dir. You may need to manually backup and remove it."
                return 1
            fi
        fi
    done

    echo "Cloning LazyVim starter template..."
    if git clone https://github.com/LazyVim/starter "$nvim_config"; then
        echo "✅ LazyVim starter cloned successfully"

        # Remove .git folder so user can add it to their own repo
        echo "Removing .git folder from LazyVim starter..."
        if rm -rf "$nvim_config/.git"; then
            echo "✅ Removed .git folder"
        else
            echo "⚠️  Failed to remove .git folder, but continuing..."
        fi

        echo "✅ LazyVim setup complete!"
        echo "    Plugins will be automatically installed when you first run Neovim."
        echo "    Run ':LazyHealth' after installation to verify everything works."
    else
        echo "⚠️  Failed to clone LazyVim starter. Skipping LazyVim setup."
        echo "    You can manually install later with:"
        echo "    git clone https://github.com/LazyVim/starter ~/.config/nvim"
        return 1
    fi
}

# Function to clone personal configuration files
clone_user_configs() {
    print_header "Cloning user configuration files from GitHub"

    # Check for gh CLI before trying to use it.
    if ! command -v gh &> /dev/null; then
        echo "⚠️  GitHub CLI ('gh') not found. Skipping dotfile cloning."
        echo "    You can manually clone configs later or install gh and re-run."
        return 1
    fi

    # Change to HOME directory to avoid git permission issues in the current directory
    local ORIGINAL_DIR="$PWD"
    cd "$HOME" || { echo "⚠️  Could not change to HOME directory. Skipping config cloning."; return 1; }

    echo "Authenticating with GitHub CLI. Please follow the prompts."
    # Use `gh auth status` to check if already logged in.
    if ! gh auth status &> /dev/null; then
        echo "Attempting GitHub authentication..."
        if ! gh auth login; then
            echo "⚠️  GitHub authentication failed. Skipping dotfile cloning."
            echo "    You can run 'gh auth login' manually later and clone configs."
            cd "$ORIGINAL_DIR"
            return 1
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
            if ! mv "$destination_dir" "${destination_dir}.bak.$(date +%s)" 2>/dev/null; then
                echo "⚠️  Could not backup existing directory. Skipping $repo_name..."
                return 1
            fi
        fi

        # Ensure parent directory exists
        mkdir -p "$(dirname "$destination_dir")"

        echo "Cloning $repo_name into $destination_dir..."
        if gh repo clone "$repo_name" "$destination_dir"; then
            echo "✅ Successfully cloned $repo_name"
        else
            echo "⚠️  Failed to clone $repo_name. Continuing anyway..."
            return 1
        fi
    }

    # Setting up Alacritty themes separately
    echo "Cloning Alacritty themes..."
    mkdir -p "$HOME/.config/alacritty/themes"
    if [ ! -d "$HOME/.config/alacritty/themes/alacritty-theme" ]; then
        if git clone https://github.com/alacritty/alacritty-theme.git "$HOME/.config/alacritty/themes/alacritty-theme"; then
            echo "✅ Alacritty themes cloned successfully"
        else
            echo "⚠️  Failed to clone Alacritty themes. Continuing anyway..."
        fi
    else
        echo "✅ Alacritty themes directory already exists. Skipping."
    fi

    # Clone personal dotfiles
    clone_repo JevonThompsonx/alacritty "$HOME/.config/alacritty"
    clone_repo JevonThompsonx/fish "$HOME/.config/fish"
    clone_repo JevonThompsonx/WPs "$HOME/Pictures/WPs"

    # Return to original directory
    cd "$ORIGINAL_DIR"

    echo "✅ Config cloning complete!"
}

# --- Distribution-Specific Setup Functions ---

setup_arch() {
    print_header "Running Arch Linux Setup"
    sudo pacman -Syu --noconfirm

    echo "Installing packages with pacman..."

    # [IMPROVEMENT] Use an array for the package list for better readability and modification.
    local packages=(
        tree git curl wget gnupg unzip ffmpeg calibre github-cli neovim
        npm zoxide fastfetch foot fish eza tailscale ttf-fira-code
        python python-pip go ripgrep lazygit luarocks ruby php jdk-openjdk
        xsel xclip appimagelauncher clamav # <-- ADDED ClamAV for malware scanning
    )

    # [FIX] Check for an existing Node.js installation before adding it to the list.
    if ! command -v node &> /dev/null; then
        echo "Node.js not found. Adding 'nodejs' to the installation list."
        packages+=("nodejs")
    else
        echo "✅ Node.js is already installed ($(node -v)). Skipping installation to avoid conflicts."
    fi

    # The --ask 20 is unusual but respected as user preference.
    sudo pacman -S --noconfirm --needed --ask 20 "${packages[@]}"

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
    # Ensure tools for adding repositories are present
    sudo apt install -y curl wget gpg git lsb-release software-properties-common
    
    # Add external repositories
    echo "Adding external repositories..."

    # --- ADDED: AppImageLauncher PPA ---
    echo "Adding AppImageLauncher PPA..."
    sudo add-apt-repository -y ppa:appimagelauncher-team/stable

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
        ruby-full php openjdk-17-jdk xsel xclip gnome-calendar \
        appimagelauncher clamav clamav-daemon # <-- ADDED ClamAV for malware scanning
}

setup_fedora() {
    print_header "Running Fedora Setup"
    sudo dnf upgrade --refresh -y
    
    echo "Enabling third-party repositories (RPM Fusion, GitHub CLI, AppImageLauncher)..."
    sudo dnf install -y \
      "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    
    # --- ADDED: AppImageLauncher COPR repository ---
    sudo dnf copr enable -y atim/appimagelauncher

    echo "Installing packages with dnf..."
    sudo dnf install -y \
        git curl wget unzip fish fzf zoxide ripgrep eza fastfetch lazygit \
        foot neovim nodejs npm golang go gh tailscale variety calibre \
        gnome-calendar ffmpeg python3-pip python3-virtualenv python3-neovim \
        luarocks ruby php java-17-openjdk-devel xsel xclip fira-code-fonts \
        appimagelauncher clamav clamav-update # <-- ADDED ClamAV for malware scanning

    echo "Installing desktop applications via Flatpak..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install flathub -y \
      md.obsidian.Obsidian \
      net.localsend.localsend \
      io.freetubeapp.FreeTube \
      com.librewolf.Librewolf \
      com.nextcloud.desktopclient # Note: This is a Flatpak version. The AppImage provides an alternative.
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
    
    install_appimages # <-- ADDED: Run the new AppImage function
    install_rust
    install_bun
    install_common_dev_tools
    
    print_header "Setting up services and final configurations"

    echo "Enabling and starting Tailscale..."
    if command -v tailscale &> /dev/null; then
        if sudo systemctl enable --now tailscaled 2>/dev/null; then
            echo "✅ Tailscaled service enabled and started"
            # Note: `tailscale up` requires interaction and may disconnect SSH
            echo "Starting Tailscale (this may require interaction)..."
            if sudo tailscale up; then
                echo "✅ Tailscale connected"
            else
                echo "⚠️  Tailscale up failed or was cancelled. You can run 'sudo tailscale up' manually later."
            fi
        else
            echo "⚠️  Failed to enable tailscaled service. You may need to do this manually."
        fi
    else
        echo "⚠️  Tailscale not found. Skipping Tailscale setup."
    fi

    echo "Updating font cache..."
    if command -v fc-cache &> /dev/null; then
        if sudo fc-cache -fv &> /dev/null; then
            echo "✅ Font cache updated"
        else
            echo "⚠️  Font cache update had issues, but continuing..."
        fi
    else
        echo "⚠️  fc-cache not found. Skipping font cache update."
    fi

    # Clone personal dotfiles
    clone_user_configs

    # Setup LazyVim
    setup_lazyvim

    # Set Fish as the default shell if it isn't already
    if command -v fish &> /dev/null; then
        if [[ "$SHELL" != */fish ]]; then
            echo "Setting Fish as the default shell. You may be prompted for your password."
            local FISH_PATH
            FISH_PATH="$(which fish)"
            if chsh -s "$FISH_PATH"; then
                echo "✅ Shell changed to Fish. Please log out and back in to see the change."
            else
                echo "⚠️  Failed to change shell. You can do it manually with: chsh -s $FISH_PATH"
            fi
        else
            echo "✅ Fish is already the default shell."
        fi
    else
        echo "⚠️  Fish shell not found. Skipping shell change."
    fi

    print_header "Finalizing Neovim Setup"
    echo "Running Neovim in headless mode to sync plugins..."
    # Execute as the 'fish' shell to ensure it uses the newly configured environment
    if command -v nvim &> /dev/null; then
        if command -v fish &> /dev/null; then
            if fish -c "nvim --headless '+Lazy sync' '+qa!'" 2>/dev/null; then
                echo "✅ Neovim plugins synced successfully"
            else
                echo "⚠️  Neovim plugin sync had issues. You can run ':Lazy sync' manually in nvim."
            fi
        else
            echo "⚠️  Fish not found, trying with bash..."
            if nvim --headless '+Lazy sync' '+qa!' 2>/dev/null; then
                echo "✅ Neovim plugins synced successfully"
            else
                echo "⚠️  Neovim plugin sync had issues. You can run ':Lazy sync' manually in nvim."
            fi
        fi
    else
        echo "⚠️  Neovim not found. Skipping plugin sync."
    fi

    # Optional: Configure power management for Surface devices
    print_header "Optional: Power Management Configuration"
    echo "This setup includes a power management script for Microsoft Surface devices"
    echo "that disables sleep, suspend, and various power-saving features to keep"
    echo "the device online 24/7."
    echo ""
    read -p "Are you running this on a Microsoft Surface device? (y/N): " is_surface

    if [[ "$is_surface" =~ ^[Yy]$ ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "$SCRIPT_DIR/surfacePowerManagement.sh" ]; then
            echo "Running Surface power management configuration..."
            if bash "$SCRIPT_DIR/surfacePowerManagement.sh"; then
                echo "✅ Power management configured successfully"
            else
                echo "⚠️  Power management script encountered errors. Check the output above."
            fi
        else
            echo "⚠️  surfacePowerManagement.sh not found in $SCRIPT_DIR"
            echo "    You can run it manually if you find it."
        fi
    else
        echo "Skipping Surface-specific power management configuration."
    fi

    echo ""
    echo "=========================================="
    echo "✅ Setup script finished!"
    echo "=========================================="
    echo ""
    echo "IMPORTANT NEXT STEPS:"
    echo "1. REBOOT your system for all changes to take full effect"
    echo "2. After reboot, verify Fish shell is active: echo \$SHELL"
    echo "3. If Tailscale didn't connect, run: sudo tailscale up"
    echo "4. If configs weren't cloned, authenticate and clone manually:"
    echo "   gh auth login"
    echo "   (then clone repos as needed)"
    echo "5. Launch Neovim - LazyVim will auto-install plugins on first run"
    echo "6. Run ':LazyHealth' in Neovim to verify everything is working"
    echo ""
}

# Run the main function
main
