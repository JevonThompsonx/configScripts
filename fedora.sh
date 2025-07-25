#!/bin/bash

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
sudo dnf install -y \
  git curl wget unzip fish fzf zoxide ripgrep eza fastfetch lazygit \
  alacritty foot neovim nodejs npm golang tlp tlp-rdw brightnessctl \
  calibre gnome-calendar variety ffmpeg openssh \
  python3-pip python3-virtualenv python3-neovim \
  luarocks ruby php java-17-openjdk-devel \
  xsel xclip fira-code-nerd-fonts \
  gcc

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
cargo install atuin selene

# exa
cargo install exa

# wpaperd 

git clone https://github.com/danyspin97/wpaperd
cd wpaperd
cargo build --release

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

# Install Ghostty Terminal
echo "Installing Ghostty terminal..."
if [ ! -d "$HOME/ghostty" ]; then
    sudo dnf install zig -y
    cd "$HOME"
    git clone https://github.com/ghostty-org/ghostty.git
    cd ghostty
    zig build
    echo "Ghostty built in ~/ghostty/zig-out/bin/. Add this to your shell's PATH."
else
    echo "Ghostty directory already exists."
fi


# ---
# SECTION 5: CONFIGURATION & SETUP
# ---
echo "🎨 Applying configurations and setting up services..."

# Create project folder
mkdir -p ~/Documents/Projects

# Clone your personal configuration scripts
echo "Cloning personal config scripts..."
if [ ! -d "$HOME/configScripts" ]; then
    git clone https://github.com/JevonThompsonx/configScripts.git ~/configScripts
    chmod +x ~/configScripts/*.sh
else
    echo "configScripts directory already exists."
fi


# Alacritty theme setup
echo "Setting up Alacritty themes..."
mkdir -p ~/.config/alacritty/themes
if [ ! -d "$HOME/.config/alacritty/themes/alacritty-theme" ]; then
    git clone https://github.com/alacritty/alacritty-theme.git ~/.config/alacritty/themes
else
    echo "Alacritty themes already cloned."
fi


# Enable and start system services
echo "Enabling and starting services (Tailscale, TLP, mbpfan)..."
sudo dnf install tailscale mbpfan -y # Ensure these are installed before enabling
sudo systemctl enable --now tailscaled
sudo systemctl enable --now tlp
sudo systemctl enable --now mbpfan

# Append custom settings to mbpfan.conf
echo "Configuring mbpfan..."
echo -e '\nmin_fan_speed = 2000\nmax_fan_speed = 6200\nlow_temp = 50\nhigh_temp = 70\nmax_temp = 85' | sudo tee -a /etc/mbpfan.conf > /dev/null

# Update font cache
echo "Updating font cache..."
fc-cache -fv

# ---
# SECTION 6: FINAL USER ACTIONS
# ---
echo "🔑 Final user authentications and setup..."

# Authenticate with GitHub CLI
echo "Please authenticate with GitHub. A browser window will open."
gh auth login

# Start Tailscale
sudo tailscale up

# Log in to Atuin and sync
echo "Logging in to Atuin..."
atuin login -u Jevonx
atuin sync

# Run your custom configuration script
if [ -f "$HOME/configScripts/clone*.sh" ]; then
    echo "Running custom clone script..."
    cd ~/configScripts && ./clone*.sh
fi

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
