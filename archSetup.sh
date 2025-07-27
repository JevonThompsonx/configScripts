#!/bin/bash
# Ensure the script exits if any command fails
set -e
echo "Starting Arch Linux server setup script..."

# --- System Update and Package Installation ---
echo "Updating package repositories and installing core packages..."
# On Arch, we use 'pacman'. '-Syu' syncs repositories and updates the system.
# '--noconfirm' answers yes to all prompts, similar to '-y' in apt.
# 'base-devel' is a group of essential tools for building packages (e.g., from AUR).
sudo pacman -Syu --noconfirm

echo "Installing essential utilities, development tools, and applications..."
sudo pacman -S --noconfirm \
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
# This part is OS-agnostic and remains the same.
if [ -d "$HOME/configScripts" ]; then
    echo "Existing configScripts directory found. Removing it..."
    rm -rf "$HOME/configScripts"
fi
cd ~
git clone https://github.com/JevonThompsonx/configScripts.git
chmod +x ~/configScripts/*.sh

# Execute Arch-specific setup script from your configScripts repository
echo "Running initial Arch-specific setup script from configScripts (if present)..."
if [ -f "$HOME/configScripts/archSetup.sh" ]; then
    echo "Executing ~/configScripts/archSetup.sh..."
    "$HOME/configScripts/archSetup.sh"
else
    echo "Warning: ~/configScripts/archSetup.sh not found. Skipping Arch-specific configuration from your repo."
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
# '--now' enables the service to start on boot and starts it immediately.
sudo systemctl enable --now tailscaled
sudo tailscale up

# GitHub CLI authentication
echo "Authenticating GitHub CLI (requires user interaction)..."
# This command is the same on any OS.
gh auth login

# Fira Code Fonts cache update
echo "Updating font cache for Fira Code..."
# pacman hooks usually handle this, but running it manually ensures it's done.
fc-cache -fv

# Bun install (OS-agnostic)
echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
echo "Bun version:"
~/.bun/bin/bun -v

# Add bun to PATH for current session and future sessions
export PATH="$HOME/.bun/bin:$PATH"
echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.profile # For bash/zsh
echo 'set -U fish_user_paths $HOME/.bun/bin $fish_user_paths' >> ~/.config/fish/config.fish # For fish

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
# The login process is interactive.
echo "Please log in to Atuin now if prompted:"
atuin login -u Jevonx
atuin sync

# Set Fish user paths for Zig and other tools
echo "Ensuring Fish user paths are correctly configured for Zig and other tools..."
# This ensures /opt/zig is in fish's path if zigGhosttyInstall.sh installs zig there.
echo 'set -U fish_user_paths /opt/zig $fish_user_paths' >> ~/.config/fish/config.fish

# Launch Neovim to update plugins (headless for server environment)
echo "Launching Neovim to trigger plugin updates (headless for server)..."
# Assumes 'lazy.nvim' plugin manager. Adjust command if you use another one.
fish -c "nvim --headless '+Lazy sync' '+qa!'" || echo "Neovim plugin sync might require manual intervention. Verify plugin manager command."

echo "Arch Linux server setup script finished!"
echo "It is recommended to reboot your system now for all changes to take effect: sudo reboot"
