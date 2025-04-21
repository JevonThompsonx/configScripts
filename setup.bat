echo "Let's do some first time setup"
chmod +x /etc/nixos/cloneConfigs.bat
echo "Cloning github configs"
gh auth
/etf/nixos/cloneConfigs.bat
sudo tailscale up
echo "please connect to nextcloud via tailscale ip"
