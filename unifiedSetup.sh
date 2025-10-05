#!/bin/bash
#
# Unified Setup Script for Arch, Debian, and Fedora-based Systems
# MODIFIED TO CONTINUE ON ERROR
# This script auto-detects the distribution and installs a common
# set of development tools, applications, and personal configurations.
# It will attempt to run every step, even if a previous one fails.
#

# --- Configuration ---
# The line 'set -e' has been REMOVED.
# This prevents the script from exiting immediately on a command failure.

# --- Helper Functions ---

# [NEW] A "try-catch" wrapper function to run commands and continue on failure.
try_run() {
    echo "▶️  Attempting to run: $@"
    # Execute the command, suppressing its output for a cleaner log
    # and capturing the exit code.
    "$@" &> /dev/null
    local status=$?
    if [ $status -ne 0 ]; then
        echo "❌ Command failed with exit code $status: '$@'"
        echo "   Continuing with the rest of the script..."
    else
        echo "✅ Command succeeded: '$@'"
    fi
    # Always return 0 so the script doesn't trip on this function's return code.
    return 0
}

# Function to print a formatted section header
print_header() {
    echo ""
    echo "===================================================================="
    echo "➡️  $1"
    echo "===================================================================="
}

# --- Pre-flight Checks (These are critical and will still exit the script) ---

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


# --- Installation Functions (Wrapped with try_run) ---

# Function to install Rust and Cargo
install_rust() {
    print_header "Installing Rust and Cargo"
    if ! command -v cargo &> /dev/null; then
        # Use bash -c to handle the piped command correctly
        try_run bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
        
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.profile"
        source "$HOME/.cargo/env"
    else
        echo "Rust is already installed. Skipping."
    fi
}

# Function to install Bun
install_bun() {
    print_header "Installing Bun JavaScript runtime"
    if ! command -v bun &> /dev/null; then
        try_run bash -c "curl -fsSL https://bun.sh/install | bash"
        
        echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.profile"
        # Source profile to make bun available immediately
        if [ -f "$HOME/.profile" ]; then
            source "$HOME/.profile"
        fi
    else
        echo "Bun is already installed. Skipping."
    fi
}

# Function to install common development tools via Cargo and NPM
install_common_dev_tools() {
    print_header "Installing common development tools (NPM packages, Cargo crates)"

    if command -v npm &> /dev/null; then
        echo "Installing global NPM packages..."
        try_run npm install -g neovim tree-sitter-cli @tailwindcss/language-server
    else
        echo "⚠️  npm not found. Skipping NPM package installation."
    fi

    if command -v cargo &> /dev/null; then
        echo "Installing Rust-based tools with Cargo..."
        source "$HOME/.cargo/env" # Ensure cargo is in PATH
        try_run cargo install selene atuin
    else
        echo "⚠️  cargo not found. Skipping Cargo package installation."
    fi
}

# Function to clone personal configuration files
clone_user_configs() {
    print_header "Cloning user configuration files from GitHub"
    
    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI ('gh') not found. Cannot clone configs."
        return 1
    fi

    echo "Attempting GitHub authentication..."
    if ! gh auth status &> /dev/null; then
        # Note: Interactive command, cannot be fully wrapped by try_run
        if ! gh auth login; then
            echo "❌ GitHub authentication failed. Cannot clone configs."
            return 1
        fi
    else
        echo "✅ Already authenticated with GitHub."
    fi

    # Helper function to clone a repo
    clone_repo() {
        local repo_name="$1"
        local destination_dir="$2"
        
        echo "Setting up repository: $repo_name"
        if [ -d "$destination_dir" ]; then
            echo "Backing up existing directory: $destination_dir -> ${destination_dir}.bak"
            mv "$destination_dir" "${destination_dir}.bak.$(date +%s)"
        fi
        
        echo "Cloning $repo_name into $destination_dir..."
        try_run gh repo clone "$repo_name" "$destination_dir"
    }

    # Setting up Alacritty themes
    echo "Cloning Alacritty themes..."
    mkdir -p "$HOME/.config/alacritty/themes"
    if [ ! -d "$HOME/.config/alacritty/themes/alacritty-theme" ]; then
        try_run git clone https://github.com/alacritty/alacritty-theme.git "$HOME/.config/alacritty/themes/alacritty-theme"
    else
        echo "Alacritty themes directory already exists. Skipping."
    fi

    # Clone personal dotfiles
    clone_repo JevonThompsonx/alacritty "$HOME/.config/alacritty"
    clone_repo JevonThompsonx/fish "$HOME/.config/fish"
    clone_repo JevonThompsonx/WPs "$HOME/Pictures/WPs"

    echo "✅ System config cloning finished (check logs for any failures)."
}

# --- Distribution-Specific Setup Functions ---

setup_arch() {
    print_header "Running Arch Linux Setup"
    try_run sudo pacman -Syu --noconfirm

    echo "Installing packages with pacman..."
    local packages=(
        tree git curl wget gnupg unzip ffmpeg calibre github-cli neovim
        npm zoxide fastfetch foot fish eza tailscale ttf-fira-code
        python python-pip go ripgrep lazygit luarocks ruby php jdk-openjdk
        xsel xclip
    )
    if ! command -v node &> /dev/null; then
        packages+=("nodejs")
    fi
    try_run sudo pacman -S --noconfirm --needed --ask 20 "${packages[@]}"

    # Omarchy Specific Setup (interactive, no try_run needed)
    if [ "$ID" == "omarchy" ]; then
        print_header "Omarchy Configuration"
        read -p "Do you want to link wallpapers for Omarchy? (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            OMARCHY_THEME_DIR="$HOME/.config/omarchy/themes"
            if [ -d "$OMARCHY_THEME_DIR" ]; then
                for theme in "$OMARCHY_THEME_DIR"/*/; do
                    if [ -d "$theme" ]; then
                        rm -rf "$theme/backgrounds"
                        ln -s "$HOME/Pictures/WPs/" "$theme/backgrounds"
                    fi
                done
                echo "✅ Wallpaper linking complete."
            else
                echo "⚠️  Warning: Directory not found, skipping: $OMARCHY_THEME_DIR"
            fi
        fi
    fi
}

setup_debian() {
    print_header "Running Debian/Ubuntu Setup"
    try_run sudo apt update
    try_run sudo apt install -y curl wget gpg git lsb-release
    
    echo "Adding external repositories..."
    try_run sudo mkdir -p /etc/apt/keyrings
    try_run bash -c "wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg"
    try_run bash -c 'echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list'
    
    local codename=$(lsb_release -cs)
    echo "Detected Debian/Ubuntu codename: $codename"
    try_run bash -c "curl -fsSL \"https://pkgs.tailscale.com/stable/debian/${codename}.noarmor.gpg\" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null"
    try_run bash -c "curl -fsSL \"https://pkgs.tailscale.com/stable/debian/${codename}.tailscale-keyring.list\" | sudo tee /etc/apt/sources.list.d/tailscale.list"

    echo "Updating package list after adding repos..."
    try_run sudo apt update
    
    echo "Installing packages with apt..."
    try_run sudo apt install -y \
        extrepo calibre gh neovim nodejs npm zoxide fastfetch foot fish \
        ffmpeg eza tailscale variety fonts-firacode python3 python3-pip \
        python3-venv python3-pynvim golang-go ripgrep lazygit luarocks \
        ruby-full php openjdk-17-jdk xsel xclip gnome-calendar
}

setup_fedora() {
    print_header "Running Fedora Setup"
    try_run sudo dnf upgrade --refresh -y
    
    echo "Enabling third-party repositories..."
    try_run sudo dnf install -y \
      "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    try_run sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    
    echo "Installing packages with dnf..."
    try_run sudo dnf install -y \
        git curl wget unzip fish fzf zoxide ripgrep eza fastfetch lazygit \
        foot neovim nodejs npm golang go gh tailscale variety calibre \
        gnome-calendar ffmpeg python3-pip python3-virtualenv python3-neovim \
        luarocks ruby php java-17-openjdk-devel xsel xclip fira-code-fonts

    echo "Installing desktop applications via Flatpak..."
    try_run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    try_run flatpak install flathub -y \
      md.obsidian.Obsidian \
      net.localsend.localsend \
      io.freetubeapp.FreeTube \
      com.librewolf.Librewolf \
      com.nextcloud.desktopclient
}

# --- Main Execution Logic ---

main() {
    check_dependencies

    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo "❌ Cannot detect distribution: /etc/os-release not found."
        exit 1
    fi
    
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
    try_run sudo systemctl enable --now tailscaled
    echo "Attempting to bring Tailscale up. This may require interactive login."
    # Note: `tailscale up` is interactive. `try_run` will report success/failure
    # after the command finishes.
    sudo tailscale up
    
    echo "Updating font cache..."
    try_run sudo fc-cache -fv
    
    clone_user_configs
    
    # Set Fish as the default shell
    if [[ "$SHELL" != */bin/fish ]] && command -v fish &> /dev/null; then
        echo "Setting Fish as the default shell. You may be prompted for your password."
        if ! chsh -s "$(which fish)"; then
             echo "❌ Failed to change shell. Please do it manually with: chsh -s $(which fish)"
        else
             echo "Shell changed to Fish. Please log out and back in to see the change."
        fi
    else
        echo "Fish is already the default shell or is not installed."
    fi
    
    print_header "Finalizing Neovim Setup"
    echo "Running Neovim in headless mode to sync plugins..."
    if command -v fish &> /dev/null && command -v nvim &> /dev/null; then
        try_run fish -c "nvim --headless '+Lazy sync' '+qa!'"
    else
        echo "⚠️ Could not find 'fish' or 'nvim' to finalize Neovim setup. Skipping."
    fi
    
    echo ""
    echo "✅ Setup script finished!"
    echo "Please review the log for any ❌ failure messages."
    echo "A REBOOT is recommended for all changes to take full effect."
}

# Run the main function
main
