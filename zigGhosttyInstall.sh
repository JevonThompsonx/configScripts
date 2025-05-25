# zig install
wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz
tar -xf zig*
rm -rf zig*.xz
mv zig* /opt/zig

# ghostty install 
sudo apt install libgtk-4-dev libadwaita-1-dev git blueprint-compiler gettext libxml2-utils
git clone https://github.com/ghostty-org/ghostty
cd ghostty

/opt/zig/zig build -p /usr -Doptimize=ReleaseFast
