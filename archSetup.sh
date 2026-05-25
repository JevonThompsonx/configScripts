#!/bin/bash
# Ensure the script exits if any command fails
set -e
echo "Starting Arch Linux server setup script..."

# --- System Update and Package Installation ---
echo "Updating package repositories and installing core packages..."
sudo pacman -Syu --noconfirm

echo "Installing essential utilities, development tools, and applications..."
sudo pacman -S --noconfirm \
    tree \
    git \
    curl \
    wget \
    gnupg \
    unzip \
    ffmpeg \
    calibre \
    github-cli \
    neovim \
    nodejs \
    npm \
    zoxide \
    fastfetch \
    foot \
    fish \
    eza \
    tailscale \
    ttf-fira-code \
    python \
    python-pip \
    go \
    ripgrep \
    lazygit \
    luarocks \
    ruby \
    php \
    jdk17-openjdk \
    xsel \
    xclip \
    atuin

# --- Configuration and OS-Agnostic Installers ---

# Clone config scripts
echo "Ensuring clean configScripts directory and cloning..."
if [ -d "$HOME/configScripts" ]; then
    echo "Existing configScripts directory found. Removing it..."
    rm -rf "$HOME/configScripts"
fi
cd ~ || exit 1
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    gh repo clone JevonThompsonx/configScripts
else
    echo "⚠️  gh CLI not authenticated. Clone manually: gh repo clone JevonThompsonx/configScripts"
    echo "⚠️  Or install gh and run auth first: gh auth login"
fi
chmod +x ~/configScripts/*.sh 2>/dev/null || true

# --- FIX: Execute the DOTFILE setup script, NOT the main setup script ---
# The original script called itself (archSetup.sh), causing a loop.
# We now call 'configScripts.sh' which handles cloning your dotfiles (nvim, fish, etc.).
echo "Running config clone from configScripts repository..."
if [ -f "$HOME/configScripts/cloneConfigs.sh" ]; then
    echo "Executing ~/configScripts/cloneConfigs.sh..."
    bash "$HOME/configScripts/cloneConfigs.sh"
else
    echo "Warning: ~/configScripts/cloneConfigs.sh not found. Skipping dotfile cloning."
fi

# Install Ghostty terminal (assuming zigGhosttyInstall.sh handles dependencies)
echo "Installing Ghostty terminal and its dependencies (via zigGhosttyInstall.sh, if present)..."
if [ -f "$HOME/configScripts/zigGhosttyInstall.sh" ]; then
    echo "Executing ~/configScripts/zigGhosttyInstall.sh..."
    "$HOME/configScripts/zigGhosttyInstall.sh"
else
    echo "Warning: ~/configScripts/zigGhosttyInstall.sh not found. Skipping Ghostty installation."
fi

# Tailscale setup
echo "Enabling and starting Tailscale..."
sudo systemctl enable --now tailscaled
sudo tailscale up

# GitHub CLI authentication
echo "Authenticating GitHub CLI (requires user interaction)..."
gh auth login

# Fira Code Fonts cache update
echo "Updating font cache for Fira Code..."
fc-cache -fv

# Bun install (OS-agnostic)
echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
echo "Bun version:"
~/.bun/bin/bun -v

# Add bun, cargo/bin to PATH
export PATH="$HOME/.bun/bin:$PATH"
echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.profile

# Add cargo/bin + bun/bin to fish PATH (idempotent)
FISH_CONFIG_DIR="$HOME/.config/fish"
mkdir -p "$FISH_CONFIG_DIR"
if ! grep -qF 'cargo/bin' "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
    echo 'set -gx PATH $HOME/.cargo/bin $HOME/.bun/bin $HOME/.local/bin $PATH' >> "$FISH_CONFIG_DIR/config.fish"
    echo "Added cargo/bin, bun/bin to fish config.fish"
fi

# Rust/Cargo install (OS-agnostic)
echo "Installing Rust and Cargo..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y # -y for non-interactive install
# Add cargo to PATH for current session
source "$HOME/.cargo/env"

# Neovim tools and language servers (npm, cargo)
echo "Setting up Neovim tools..."
sudo npm install -g neovim tree-sitter-cli
sudo npm install -g @tailwindcss/language-server
cargo install selene # This requires Rust/Cargo to be installed first.

# Atuin login
echo "Setting up Atuin (shell history sync - requires user interaction or pre-configuration)..."
echo "Please log in to Atuin now if prompted:"
atuin login -u Jevonx
atuin sync

# Set Fish user paths for Zig and other tools
echo "Ensuring Fish user paths are correctly configured for Zig and other tools..."
echo 'set -U fish_user_paths /opt/zig $fish_user_paths' >> ~/.config/fish/config.fish

# Launch Neovim to update plugins (headless for server environment)
echo "Launching Neovim to trigger plugin updates (headless for server)..."
fish -c "nvim --headless '+Lazy sync' '+qa!'" || echo "Neovim plugin sync might require manual intervention. Verify plugin manager command."

echo "Arch Linux server setup script finished!"
echo "It is recommended to reboot your system now for all changes to take effect: sudo reboot"
