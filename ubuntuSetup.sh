#!/bin/bash

# Ensure the script exits if any command fails
set -e

echo "Starting Ubuntu setup script..."

# Basic system update and essential tools
echo "Updating package list and installing core utilities..."
sudo apt update
sudo apt install -y extrepo git curl wget gpg software-properties-common apt-transport-https ca-certificates unzip

# Clone config scripts
echo "Cloning config scripts..."
cd ~
git clone https://github.com/JevonThompsonx/configScripts.git
chmod +x ~/configScripts/*.sh
# Assuming update-debian*.sh is general enough or you have an update-ubuntu.sh in your repo
# If update-debian*.sh specifically targets Debian, you might need to adjust or remove this line.
echo "Running initial config scripts..."
# If you have an Ubuntu specific update script, use that instead.
# For example: ~/configScripts/update-ubuntu.sh
# Otherwise, skip or inspect update-debian*.sh to ensure compatibility.
~/configScripts/update-debian*.sh || echo "Warning: update-debian*.sh might not be fully compatible with Ubuntu. Review its contents."


# Install Ghostty terminal (assuming zig is handled by zig*.sh)
echo "Installing Ghostty terminal dependencies (via zig*.sh)..."
# Make sure zig*.sh properly installs Zig for Ubuntu
~/configScripts/zig*.sh

# LibreWolf install
echo "Installing LibreWolf..."
# Ubuntu typically doesn't use extrepo for major browser installs,
# but if extrepo supports LibreWolf on Ubuntu, this should work.
# A more common Ubuntu approach is adding a PPA or direct repository.
# If extrepo fails, consider the official LibreWolf repository method:
# sudo apt update && sudo apt install -y lsb-release
# DISTRO=$(if [ -f /etc/os-release ]; then . /etc/os-release; echo $ID$VERSION_ID; else echo debian11; fi)
# sudo wget -O /etc/apt/keyrings/librewolf.asc https://deb.librewolf.net/keyring.gpg
# sudo printf "deb [arch=amd64 signed-by=/etc/apt/keyrings/librewolf.asc] https://deb.librewolf.net $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/librewolf.list
# sudo apt update && sudo apt install -y librewolf
sudo extrepo enable librewolf # Keep this if extrepo works for Ubuntu
sudo apt update && sudo apt install -y librewolf

# Webapp Manager install
echo "Installing Webapp Manager..."
# This deb package is from Linux Mint, which is Ubuntu-based, so it should work.
wget http://packages.linuxmint.com/pool/main/w/webapp-manager/webapp-manager_1.4.0_all.deb
sudo apt install -y ./web*.deb
rm ./web*.deb # Clean up the downloaded deb package

# Install common development and system packages
echo "Installing available packages via APT..."
sudo apt install -y gh neovim nodejs npm zoxide fastfetch foot alacritty fish

# Alacritty theme
echo "Applying Alacritty theme..."
mkdir -p ~/.config/alacritty/themes
git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes

# Eza install
echo "Installing Eza (modern ls replacement)..."
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update
sudo apt install -y eza

# Install applications from .deb packages (Obsidian, LocalSend, FreeDownloadManager)
echo "Installing Obsidian, LocalSend, and Free Download Manager..."
# It's better to fetch specific versions or use a loop if you have many
wget https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.10/obsidian_1.8.10_amd64.deb
wget https://github.com/localsend/localsend/releases/download/v1.17.0/LocalSend-1.17.0-linux-x86-64.deb
wget https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb

sudo apt install -y ./obsidian*.deb ./Local*.deb ./free*.deb
rm ./obsidian*.deb ./Local*.deb ./free*.deb # Clean up

# Tailscale install
echo "Installing Tailscale..."
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
# Ubuntu uses 'jammy' for current LTS (22.04). If using a different Ubuntu version, adjust 'jammy'.
# For a server environment, 'jammy' is a safe bet for a recent LTS.
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
sudo apt update
sudo apt install -y tailscale
sudo tailscale up

# GitHub CLI authentication
echo "Authenticating GitHub CLI..."
gh auth login

# Variety wallpaper changer PPA
echo "Adding Variety PPA and installing Variety..."
sudo add-apt-repository -y ppa:variety/stable
sudo apt update
sudo apt install -y variety

# Fira Code Fonts
echo "Installing Fira Code fonts..."
sudo apt install -y fonts-firacode
fc-cache -fv

# Python for Neovim
echo "Setting up Python for Neovim..."
sudo apt install -y python3 python3-pip python3-venv

# AppImage Launcher
echo "Installing AppImage Launcher..."
# Check for the correct Ubuntu version. "bionic" is Ubuntu 18.04.
# For Ubuntu 22.04 (Jammy), you might need a different release or compile from source if it's not available.
# As of current date, AppImageLauncher 2.2.0 is quite old. Check for a newer release or if it's in Ubuntu's repos.
# Let's try fetching the jammy deb if available, otherwise stick to bionic which often has good compatibility.
# For Ubuntu 22.04 LTS (Jammy Jellyfish), the AppImageLauncher release for 'focal' (20.04) or 'jammy' might work better.
# Let's check for 'jammy' or fall back to 'bionic' if not found.
APPIMAGELAUNCHER_DEB_URL="https://github.com/TheAssassin/AppImageLauncher/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb"
# Consider checking for a more recent AppImageLauncher version.
wget "$APPIMAGELAUNCHER_DEB_URL" -O appimagelauncher.deb
sudo apt install -y ./appimagelauncher.deb
rm appimagelauncher.deb # Clean up

echo "Setting up Nextcloud AppImage..."
mkdir -p ~/Apps
cd ~/Apps
wget https://github.com/nextcloud-releases/desktop/releases/download/v3.16.4/Nextcloud-3.16.4-x86_64.AppImage
chmod +x Nextcloud-3.16.4-x86_64.AppImage
cd ~ # Go back to home directory

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
# Cargo needs to be installed first if selene is being installed via cargo
# Ensure cargo is available globally or within the script's PATH
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

## Tailwind CSS language server
echo "Installing Tailwind CSS language server..."
sudo npm install -g @tailwindcss/language-server

## Clipboard utilities
echo "Installing clipboard utilities (xsel, xclip)..."
sudo apt install -y xsel xclip

# Calendar software
echo "Installing Gnome Calendar..."
sudo apt install -y gnome-calendar

# Install eza again (already done, but keeping if it was intended as a separate step)
# This line is redundant if eza was already installed.
# cargo install exa # This installs eza via cargo, not apt. If you want the apt version, remove this.

# Clone config scripts (again, if this is a separate set of clones or actions)
echo "Running clone scripts from configScripts..."
cd ~/configScripts
./clone*.sh # Assuming this script handles additional config clones.
cd ~

# Atuin login
echo "Setting up Atuin (shell history sync)..."
sudo apt install -y atuin
# Atuin login should be interactive or handled by an environment variable.
# For a server environment, you might need to pre-configure credentials or skip this step.
echo "Please log in to Atuin now if prompted:"
atuin login -u Jevonx
atuin sync

# Set Fish user paths (already done for Bun, but ensuring Zig is added)
echo "Setting Fish user paths for Zig and potentially others..."
# This line should ideally be in your fish config file (e.g., ~/.config/fish/config.fish)
# It's better to append to the file rather than run directly in the script for persistence.
echo 'set -U fish_user_paths /opt/zig $fish_user_paths' >> ~/.config/fish/config.fish
# You might need to ensure /opt/zig exists and contains the zig executable after zig*.sh runs.

# Launch Neovim to update plugins
echo "Launching Neovim to trigger plugin updates..."
# This command assumes Neovim is set up to auto-update plugins on first run or on specific commands.
# For a non-interactive server setup, this might not be ideal.
# Consider using `nvim --headless "+PlugInstall" "+qa!"` or similar for automated plugin install.
fish -c "nvim" # Runs nvim in a fish shell context. For automation, consider `nvim --headless ...`

echo "Ubuntu setup script finished!"
echo "Please reboot your system for all changes to take effect."
