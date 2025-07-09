#!/bin/bash

# Ensure the script exits if any command fails
set -e

echo "Starting Ubuntu server setup script (main).."

# Basic system update and essential tools
echo "Updating package list and installing core utilities..."
sudo apt update
sudo apt install -y extrepo ffmpeg git curl calibre wget gpg software-properties-common apt-transport-https ca-certificates unzip

# Clone config scripts
echo "Ensuring clean configScripts directory and cloning..."
# Check if configScripts directory exists and remove it to avoid "fatal: destination path 'configScripts' already exists"
if [ -d "$HOME/configScripts" ]; then
    echo "Existing configScripts directory found. Removing it..."
    rm -rf "$HOME/configScripts"
fi
cd ~
git clone https://github.com/JevonThompsonx/configScripts.git
chmod +x ~/configScripts/*.sh

# IMPORTANT: Ensure these scripts (ubuntuSetup.sh, zigGhosttyInstall.sh)
# DO NOT call this main setup script again, or any part of it that
# would lead to a loop (e.g., cloning configScripts or re-running apt installs).
# They should contain ONLY their specific, modularized setup steps.

# Execute Ubuntu-specific setup script from your configScripts repository
echo "Running initial Ubuntu-specific setup script from configScripts (if present)..."
if [ -f "$HOME/configScripts/ubuntuSetup.sh" ]; then
    echo "Executing ~/configScripts/ubuntuSetup.sh..."
    "$HOME/configScripts/ubuntuSetup.sh"
else
    echo "Warning: ~/configScripts/ubuntuSetup.sh not found. Skipping Ubuntu-specific configuration from your repo."
fi

# Install Ghostty terminal (assuming zigGhosttyInstall.sh handles dependencies like Zig)
echo "Installing Ghostty terminal and its dependencies (via zigGhosttyInstall.sh, if present)..."
if [ -f "$HOME/configScripts/zigGhosttyInstall.sh" ]; then
    echo "Executing ~/configScripts/zigGhosttyInstall.sh..."
    "$HOME/configScripts/zigGhosttyInstall.sh"
else
    echo "Warning: ~/configScripts/zigGhosttyInstall.sh not found. Skipping Ghostty installation."
fi

# Install common development and system packages (non-GUI)
echo "Installing core development and terminal utilities..."
sudo apt install -y gh neovim nodejs npm zoxide fastfetch foot fish

# Eza install
echo "Installing Eza (modern ls replacement)..."
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update # Update after adding Eza repo
sudo apt install -y eza

# Tailscale install
echo "Installing Tailscale..."
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
# Based on your log, you are running Ubuntu "noble".
# We need to explicitly use the noble repository for Tailscale.
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
sudo apt update # Update after adding Tailscale repo
sudo apt install -y tailscale
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sudo tailscale up

# GitHub CLI authentication
echo "Authenticating GitHub CLI (requires user interaction)..."
# For a truly automated server setup, you would need to pre-configure GitHub CLI with a token.
gh auth login

# Fira Code Fonts (useful for terminals even on servers, for better readability)
echo "Installing Fira Code fonts..."
sudo apt install -y fonts-firacode
fc-cache -fv

# Python for Neovim
echo "Setting up Python for Neovim..."
sudo apt install -y python3 python3-pip python3-venv

# GoLang install
echo "Installing GoLang..."
sudo apt install -y golang-go

# Bun install
echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
echo "Bun version:"
~/.bun/bin/bun -v # Ensure bun is called from its install location or sourced into path
# Add bun to PATH for current session and future sessions
export PATH="$HOME/.bun/bin:$PATH"
echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.profile # For bash/zsh
echo 'set -U fish_user_paths $HOME/.bun/bin $fish_user_paths' >> ~/.config/fish/config.fish # For fish

# Neovim tools
echo "Setting up Neovim tools..."
sudo apt install -y ripgrep lazygit
sudo npm install -g neovim tree-sitter-cli
# Ensure Rust/Cargo is installed before attempting to install Rust-based tools
# The Rust installer below will handle cargo.
cargo install selene # This requires Rust/Cargo to be installed first.

# Neovim languages
echo "Installing Neovim language servers and dependencies..."
## Rust/Cargo
echo "Installing Rust and Cargo..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y # -y for non-interactive install
# Add cargo to PATH for current session
source "$HOME/.cargo/env"

## Luarocks
echo "Installing Luarocks..."
sudo apt install -y luarocks

## Ruby
echo "Installing Ruby..."
sudo apt install -y ruby-full

## PHP
echo "Installing PHP..."
sudo apt install -y php

## Java (OpenJDK 17)
echo "Installing OpenJDK 17..."
sudo apt install -y openjdk-17-jdk

## Tailwind CSS language server (if you plan to edit web projects on the server)
echo "Installing Tailwind CSS language server (for web development on server)..."
sudo npm install -g @tailwindcss/language-server

## Clipboard utilities (useful for tmux/vim clipboard integration even on server)
echo "Installing clipboard utilities (xsel, xclip)..."
sudo apt install -y xsel xclip

# Atuin login
echo "Setting up Atuin (shell history sync - requires user interaction or pre-configuration)..."
sudo apt install -y atuin
# Atuin login requires user interaction or pre-configuration.
echo "Please log in to Atuin now if prompted:"
atuin login -u Jevonx
atuin sync

# Set Fish user paths for Zig and other tools
echo "Ensuring Fish user paths are correctly configured for Zig and other tools..."
# This ensures /opt/zig is in fish's path if zigGhosttyInstall.sh installs zig there.
# Appending to the config file for persistence across sessions.
echo 'set -U fish_user_paths /opt/zig $fish_user_paths' >> ~/.config/fish/config.fish

# Launch Neovim to update plugins (headless for server environment)
echo "Launching Neovim to trigger plugin updates (headless for server)..."
# Using --headless for non-interactive plugin installation. Adjust if your Neovim setup
# uses a different plugin manager or update command.
fish -c "nvim --headless '+Lazy sync' '+qa!'" || echo "Neovim plugin sync might require manual intervention. Verify plugin manager command."
# Note: '+Lazy sync' is specific to the 'lazy.nvim' plugin manager. Adjust if using 'packer', 'vim-plug', etc.

echo "Ubuntu server setup script finished!"
echo "It is recommended to reboot your system now for all changes to take effect: sudo reboot"
