
wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz
tar -xf zig*
rm -rf zig*.xz
mv zig* /opt/zig


/opt/zig/zig build -p /usr -Doptimize=ReleaseFast
