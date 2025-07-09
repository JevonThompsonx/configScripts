# source update

echo "updating..."
sudo apt update && sudo apt install extrepo -y
echo "git install"
sudo apt install git calibre
echo "installing config scripts just in case" 

cd ~
git clone https://github.com/JevonThompsonx/configScripts.git
chmod +x ~/configScripts/*.sh
~/update-debian*.sh
# ghostty terminal install
~/zig*.sh


# update
echo "updating" 
sudo apt update && sudo apt install extrepo -y
echo "librewolf install"
sudo extrepo enable librewolf

sudo apt update && sudo apt install librewolf -y

echo "webapp manager install"

wget http://packages.linuxmint.com/pool/main/w/webapp-manager/webapp-manager_1.4.0_all.deb
sudo apt install ./web*.deb

echo "installs available packages via deb repo"

sudo apt install curl gh neovim nodejs npm zoxide fastfetch foot alacritty fish ffmpeg
# alacritty theme
echo "applying alacritty theme"
mkdir -p ~/.config/alacritty/themes
git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes

echo " eza install..."
sudo apt install -y gpg

sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update
sudo apt install -y eza

echo "obsidian,localsend and freetube..."
wget https://github.com/obsidianmd/obsidian-releases/releases/download/v1.  
8.10/obsidian_1.8.10_amd64.deb

sudo apt install ./obsidian*.deb

wget https://github.com/localsend/localsend/releases/download/v1.17.0/LocalSend-1.17.0-linux-x86-64.deb

sudo apt install ./Local*.deb
wget https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb
sudo apt install ./free*.deb

# Tailscale install
echo "tailscale..."

# Add Tailscale's GPG key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
# Add the tailscale repository
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
# Install Tailscale
sudo apt-get update && sudo apt-get install tailscale

sudo systemctl enable tailscaled
sudo systemctl start tailscaled
# Start Tailscale!
sudo tailscale up

echo "let's get those config repos baybee"
gh auth login

sudo add-apt-repository ppa:variety/stable
sudo apt update
sudo apt install variety

sudo apt install fonts-firacode

fc-cache -fv

#python install for neovim
sudo apt update
sudo apt install python3 python3-pip
sudo apt install python3-pip python3-venv

# App image launcher 

wget https://github.com/TheAssassin/AppImageLauncher/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb
./appim*.deb
echo "nextcloud"
# nextcloud app image
mkdir ~/Apps
cd ~/Apps 

wget https://github.com/nextcloud-releases/desktop/releases/download/v3.16.4/Nextcloud-3.16.4-x86_64.AppImage

# golang install 

sudo apt install golang-go

# bun install
sudo apt install unzip
curl -fsSL https://bun.sh/install | bash
echo "Bun version:"
bun -v

#neovim tools
echo "neovim setup"
sudo apt install ripgrep
sudo npm install -g neovim
sudo apt install python3-pynvim
sudo apt install lazygit
cargo install selene

## treesitter
sudo npm install -g tree-sitter-cli

# nvim languages 
## cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
## luarocks
sudo apt install luarocks
## ruby
sudo apt install ruby-full
## php
sudo apt install php
## java
sudo apt install openjdk-17-jdk
## tailwindcss
sudo npm install -g @tailwindcss/language-server
## clipboard 
sudo apt install xsel
sudo apt install xclip

echo "calendar software"
# install calendar client 
sudo apt install gnome-calendar

cargo install exa 

cd ~/configScripts
./clone*.sh

## atuin login 

sudo apt install cargo 
sudo apt install atuin
atuin login -u Jevonx
atuin sync
# launch neovim to update
fish 
set -U fish_user_paths /opt/zig $fish_user_paths
echo "setting fish as default shell" 

chsh -s /usr/bin/fish
nvim
