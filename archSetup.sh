#!/bin/bash

echo "Updating system and installing base tools..."
sudo pacman -Syu 
sudo pacman -S git curl neovim nodejs npm fish fzf cargo 

echo "creating project folder" 

mkdir ~/Documents/Projects

## cli helper 
cargo install atuin

echo "Installing AUR helper (yay)..."
if ! command -v yay &> /dev/null; then
  cd ~
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si 
fi

echo "Cloning config scripts..."
cd ~
git clone https://github.com/JevonThompsonx/configScripts.git
chmod +x ~/configScripts/*.sh


echo "Alacritty theme setup..."
mkdir -p ~/.config/alacritty/themes
git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes

echo "Setting up Tailscale..."
sudo systemctl enable --now tailscaled
sudo tailscale up

echo "Authenticating GitHub CLI..."
yay -S  github-cli zoxide unzip tlp tlp-rdw ripgrep npm nodejs python-pip brightnessctl mbpfan-git hyprlock hypridle nextcloud-client zoxide python-virtualenv gcc base-devel wget zoxide fastfetch alacritty foot librewolf-bin vivaldi eza obsidian localsend freetube-bin tailscale lazygit selene-bin webapp-manager ttf-fira-code ttf-firacode-nerd freedownloadmanager
gh auth login

echo "battery management" 
sudo systemctl enable tlp
sudo systemctl start tlp

echo "Installing Variety wallpaper manager..."
yay -S  variety wpaperd 

echo "Installing FiraCode font..."

yay -S ttf-firacode-nerd
fc-cache -fv

echo "Installing other necessaties..." 

yay -Syu exa waybar nwg-drawer nwg-bar foot alacritty librewolf 
echo "Installing AppImageLauncher..."
yay -S  appimagelauncher

echo "installing openssh..." 

yay -Syu openssh

echo "Installing Go (golang)..."
sudo pacman -S  go

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
# Ruby, php, java
sudo pacman -S  ruby php jdk17-openjdk luarocks xsel xclip

# TailwindCSS LSP
sudo npm install -g @tailwindcss/language-server


echo "Installing Calendar Client..."
sudo pacman -S  gnome-calendar

echo "Installing EXA replacement (already installed: eza)..."

echo "Finalizing Config Setup..."
cd ~/configScripts
./clone*.sh || echo "No clone*.sh script found."

echo "mbpfan settings" 

sudo systemctl enable mbpfan
sudo systemctl start mbpfan

echo -e '\nmin_fan_speed = 2000\nmax_fan_speed = 6200\nlow_temp = 50\nhigh_temp = 70\nmax_temp = 85' | sudo tee -a /etc/mbpfan.conf > /dev/null

echo "Installing ghostty" 

yay -Syu zig ghostty

yay -Syu cargo 
yay -Syu atuin
atuin login -u Jevonx
atuin sync

echo "Launching fish and Neovim..."
fish -c "set -U fish_user_paths /opt/zig \$fish_user_paths"

nvim
