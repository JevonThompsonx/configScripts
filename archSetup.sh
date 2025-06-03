#!/bin/bash

echo "Updating system and installing base tools..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git curl neovim nodejs npm fish unzip ripgrep python-pip python-virtualenv gcc base-devel wget zoxide fastfetch alacritty foot

echo "Installing AUR helper (yay)..."
if ! command -v yay &> /dev/null; then
  cd ~
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
fi

echo "Cloning config scripts..."
cd ~
git clone https://github.com/JevonThompsonx/configScripts.git
chmod +x ~/configScripts/*.sh
~/configScripts/update-arch*.sh || echo "No update-arch*.sh script found."
~/configScripts/zig*.sh || echo "No zig*.sh script found."

echo "Installing Librewolf (via extrepo equivalent: Chaotic-AUR or direct AUR)..."
yay -S --noconfirm librewolf-bin

echo "Installing WebApp Manager (Linux Mint version not supported)..."
# Suggest alternative or skip
echo "⚠️ Skipping WebApp Manager (not packaged for Arch). Try 'ice-ssb' as an alternative."

echo "Installing general packages from AUR..."
yay -S --noconfirm eza obsidian localsend freetube-bin tailscale lazygit selene-bin

echo "Alacritty theme setup..."
mkdir -p ~/.config/alacritty/themes
git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes

echo "Setting up Tailscale..."
sudo systemctl enable --now tailscaled
sudo tailscale up

echo "Authenticating GitHub CLI..."
yay -S --noconfirm github-cli
gh auth login

echo "Installing Variety wallpaper manager..."
yay -S --noconfirm variety

echo "Installing FiraCode font..."
sudo pacman -S --noconfirm ttf-fira-code
fc-cache -fv

echo "Installing AppImageLauncher..."
yay -S --noconfirm appimagelauncher

echo "Setting up Nextcloud AppImage..."
mkdir -p ~/Apps
cd ~/Apps
wget https://github.com/nextcloud-releases/desktop/releases/download/v3.16.4/Nextcloud-3.16.4-x86_64.AppImage
chmod +x Nextcloud-3.16.4-x86_64.AppImage

echo "Installing Go (golang)..."
sudo pacman -S --noconfirm go

echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
echo "Bun version:"
~/.bun/bin/bun -v

echo "Setting up Neovim tools and language support..."

# Tree-sitter CLI
sudo npm install -g tree-sitter-cli
# Neovim Python support
pip install pynvim
# Neovim Node support
sudo npm install -g neovim
# Neovim Rust tooling
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# LuaRocks
yay -S --noconfirm luarocks
# Ruby
sudo pacman -S --noconfirm ruby
# PHP
sudo pacman -S --noconfirm php
# Java (OpenJDK 17)
sudo pacman -S --noconfirm jdk17-openjdk
# TailwindCSS LSP
sudo npm install -g @tailwindcss/language-server

# Clipboard tools
sudo pacman -S --noconfirm xsel xclip

echo "Installing Calendar Client..."
sudo pacman -S --noconfirm gnome-calendar

echo "Installing EXA replacement (already installed: eza)..."

echo "Finalizing Config Setup..."
cd ~/configScripts
./clone*.sh || echo "No clone*.sh script found."

echo "Launching fish and Neovim..."
fish -c "set -U fish_user_paths /opt/zig \$fish_user_paths; nvim"
