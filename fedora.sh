a#!/bin/bash

# A script to set up a Fedora development and desktop environment.

# ---
# SECTION 1: SYSTEM & REPOSITORY SETUP
# ---
echo "🚀 Starting Fedora Setup..."
echo "Updating system and enabling third-party repositories..."

# Update all existing packages
sudo dnf upgrade --refresh -y

# Enable RPM Fusion for free and non-free packages (for codecs like ffmpeg, etc.)
sudo dnf install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y



sudo dnf copr enable che/nerd-fonts -y

# Add GitHub CLI repository
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh -y

# ---
# SECTION 2: DNF PACKAGE INSTALLATION
# ---
echo "⚙️ Installing core packages, CLI tools, and libraries with DNF..."
sudo dnf install git curl wget unzip fish fzf zoxide ripgrep eza fastfetch lazygit alacritty foot neovim nodejs npm golang tlp tlp-rdw go \
brightnessctl calibre gnome-calendar variety ffmpeg openssh python3-pip python3-virtualenv python3-neovim luarocks \
ruby php java-17-openjdk-devel xsel xclip gcc nwg-drawer wofi --skip-unavailable --skip-broken

## fira code
curl -L -O https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip
unzip FiraCode.zip -d FiraCode
mkdir -p ~/.fonts
cp FiraCode/*.ttf ~/.fonts/
sudo mkdir -p /usr/share/fonts/TTF
sudo cp FiraCode/*.ttf /usr/share/fonts/TTF/
fc-cache -fv


# ---
# SECTION 3: FLATPAK & DESKTOP APP INSTALLATION
# ---
echo "📦 Installing desktop applications via Flatpak..."

# Add the Flathub repository if it's not already configured
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install applications from Flathub
flatpak install flathub -y \
  md.obsidian.Obsidian \
  net.localsend.localsend \
  io.freetubeapp.FreeTube \
  com.librewolf.Librewolf \
  com.nextcloud.desktopclient

# Note: AppImageLauncher and Webapp Manager are not available in standard Fedora repos.
# Consider managing AppImages manually in a folder like ~/Applications.

# ---
# SECTION 4: LANGUAGE & DEV TOOL INSTALLATION
# ---
echo "🛠️ Installing language toolchains and developer tools..."

# Install Rust and Cargo
echo "Installing Rust..."
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed."
fi

# Install tools via Cargo
echo "Installing Rust-based tools (atuin, selene)..."
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

cargo install selene

# exa
cargo install exa

# Install global NPM packages for Neovim support
echo "Installing global NPM packages..."
sudo npm install -g neovim tree-sitter-cli @tailwindcss/language-server


# Install Bun
echo "Installing Bun..."
if ! command -v bun &> /dev/null; then
    curl -fsSL https://bun.sh/install | bash
else
    echo "Bun is already installed."
fi


# ---
# SECTION 5: CONFIGURATION & SETUP
# ---
echo "🎨 Applying configurations and setting up services..."

# Create project folder
mkdir -p ~/Documents/Projects


# Enable and start system services
sudo systemctl enable --now tailscaled


# Update font cache
echo "Updating font cache..."
fc-cache -fv

# ---
# SECTION 6: FINAL USER ACTIONS
# ---
echo "🔑 Final user authentications and setup..."

# Start Tailscale
sudo tailscale up

# Log in to Atuin and sync
echo "Logging in to Atuin..."
atuin login
atuin sync


# Set Fish as the default shell
if [ "$SHELL" != "/usr/bin/fish" ]; then
    echo "Setting Fish as the default shell. You may need to enter your password."
    chsh -s /usr/bin/fish
else
    echo "Fish is already the default shell."
fi

echo "✅ Fedora setup complete! Please log out and log back in for all changes to take effect, especially the new shell."
echo "Launching Neovim to finalize plugin setup..."
fish -c "nvim"
