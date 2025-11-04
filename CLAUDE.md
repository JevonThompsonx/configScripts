# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of system setup and configuration scripts for Linux distributions (Arch, Debian/Ubuntu, Fedora). The scripts automate the installation of development tools, applications, and personal dotfiles to quickly configure new systems or servers.

## Architecture

### Two-Tier Setup System

1. **Desktop/Workstation Setup** (`unifiedSetup.sh`)
   - Full GUI environment with desktop applications
   - Installs terminal emulators, fonts, GUI apps (Calibre, AppImageLauncher, Nextcloud)
   - Includes desktop-specific tools (Variety wallpaper manager, GNOME Calendar)
   - Optional Omarchy desktop environment configuration (Arch only)
   - Optional Surface device power management

2. **Server/Headless Setup** (`server/unifiedSetup.sh`)
   - Minimal CLI-only environment
   - No GUI applications, terminal emulators, or desktop fonts
   - Server-optimized: includes 24/7 always-on power management option
   - Focuses on development tools and remote access (Tailscale)

### Distribution Detection Pattern

All unified setup scripts use `/etc/os-release` to detect the distribution and execute the appropriate `setup_arch()`, `setup_debian()`, or `setup_fedora()` function. The pattern:

```bash
. /etc/os-release
DISTRO_ID="${ID_LIKE:-$ID}"  # Handles derivatives (e.g., Ubuntu → debian)
```

### Common Installation Pattern

Both setup scripts follow this execution order:
1. Dependency checks (curl, git)
2. Distribution-specific package installation
3. Language runtime installation (Rust, Bun)
4. Development tools via Cargo and NPM
5. Service configuration (Tailscale)
6. Personal dotfiles cloning (via GitHub CLI)
7. LazyVim setup (Neovim distribution)
8. Shell configuration (Fish shell)
9. Neovim plugin sync

## Key Scripts

### Setup Scripts

- **`unifiedSetup.sh`** - Desktop setup for Arch/Debian/Fedora with GUI apps
- **`server/unifiedSetup.sh`** - Server setup without GUI dependencies
- **`archSetup.sh`** - Legacy Arch-specific setup (use `unifiedSetup.sh` instead)
- **`debianSetup.sh`** - Legacy Debian-specific setup (use `unifiedSetup.sh` instead)
- **`fedora.sh`** - Legacy Fedora-specific setup (use `unifiedSetup.sh` instead)

### Configuration Scripts

- **`cloneConfigs.sh`** - Clones personal dotfiles (Alacritty, Fish, wallpapers) via GitHub CLI
- **`powerManagement.sh`** - Disables all power-saving features for server/always-on operation
- **`surfacePowerManagement.sh`** - Surface-specific power management (includes thermald, cpupower)

### Server Utilities

- **`server/cloudflareIPsInteractive.sh`** - Interactive UFW rule creator for Cloudflare IP ranges
- **`server/cloudflareIPscustom.sh`** - Presumably custom/non-interactive version

### Security Scripts

- **`clamav-scan.sh`** - Deep scan script with Telegram notifications (full system scan, 1-4 hours)
- **`clamav-scan-fast.sh`** - Fast scan script with Telegram notifications (critical directories, 5-30 min)
- **`setup-clamav-cronjob.sh`** - Interactive setup for automated ClamAV scanning
- **`example.env`** - Template for Telegram bot credentials and scan configuration
- **`CLAMAV-README.md`** - Complete documentation for ClamAV setup

## Personal Configuration Repositories

The scripts clone these GitHub repositories for dotfiles:
- `JevonThompsonx/alacritty` → `~/.config/alacritty`
- `JevonThompsonx/fish` → `~/.config/fish`
- `JevonThompsonx/WPs` → `~/Pictures/WPs` (wallpapers)
- `alacritty/alacritty-theme` → `~/.config/alacritty/themes/alacritty-theme`

## Development Environment

### Core Tools Installed

**Languages & Runtimes:**
- Node.js/NPM (via package manager)
- Bun (via curl install script)
- Rust/Cargo (via rustup)
- Python 3 with pip and venv
- Go
- Ruby
- PHP
- Java (OpenJDK 17)

**CLI Tools:**
- Neovim (primary editor with Lazy plugin manager)
- Fish shell (default shell)
- Git + GitHub CLI (`gh`)
- Tailscale (VPN/mesh network)
- zoxide, eza (modern replacements for cd/ls)
- ripgrep, lazygit
- fastfetch (system info)
- ffmpeg

**Neovim Ecosystem:**
- LazyVim distribution (Neovim configuration framework)
- Tree-sitter CLI
- Language servers: Tailwind CSS LSS
- Linters: Selene (Lua)
- Python support: python3-pynvim
- Clipboard: xsel, xclip

### NPM Global Packages

Installed to `~/.npm-global` to avoid permission issues:
- `neovim` - Neovim Node.js provider
- `tree-sitter-cli` - Parser generator tool
- `@tailwindcss/language-server` - CSS framework LSP (desktop only)

### Cargo Crates

- `selene` - Lua linter
- `atuin` - Shell history sync tool

## Security: ClamAV Malware Scanning

Both `unifiedSetup.sh` and `server/unifiedSetup.sh` now install ClamAV for malware protection. After running the unified setup, configure automated scanning with Telegram notifications.

### Dual-Scan Architecture

**Fast Scan (5:00 AM):**
- Quick morning check of critical directories
- Scans: `~/Documents`, `~/Downloads`, `~/Desktop`, `~/scripts`
- Excludes: caches, build artifacts, `.git`, `node_modules`
- Runtime: 5-30 minutes
- Skips virus database update (uses evening's update)

**Deep Scan (8:00 PM):**
- Full system scan
- Scans: Entire `/home` directory (configurable)
- Updates virus database before scanning
- Runtime: 1-4 hours
- Comprehensive malware detection

### Quick Setup (New System)

```bash
# 1. ClamAV is already installed by unified setup scripts

# 2. Run the ClamAV setup
cd ~/scripts/configScripts
bash setup-clamav-cronjob.sh

# 3. Choose "Dual Scan" mode
# 4. Accept defaults (5 AM fast, 8 PM deep)
# 5. Test notification in Telegram
```

### Telegram Bot Configuration

The setup requires a Telegram bot for notifications:
1. Create bot: Message @BotFather in Telegram, send `/newbot`
2. Get Chat ID: Message @userinfobot to get your user ID
3. Configure: Credentials stored in `~/.clamav-telegram.env` (secured with 600 permissions)

### Configuration Files

- `~/.clamav-telegram.env` - Bot credentials and scan directories (user-specific, not in git)
- `example.env` - Template for new systems
- `~/.clamav-logs/` - Scan logs and reports (auto-cleaned after 30 days)

### Notification Format

Telegram notifications include:
- Scan type indicator (⚡ Fast or 🔍 Deep)
- Hostname and timestamp
- Files/directories scanned count
- Threat detection (✅ Clean or 🚨 Infected)
- Scan duration
- Infected file list (if any threats found)

### Manual Operations

```bash
# Run scans manually
bash ~/scripts/configScripts/clamav-scan-fast.sh  # Fast scan
bash ~/scripts/configScripts/clamav-scan.sh       # Deep scan

# View scheduled scans
crontab -l | grep clamav

# Update virus database
sudo freshclam

# Check logs
ls -lh ~/.clamav-logs/
grep "FOUND" ~/.clamav-logs/*.log  # Check for threats
```

### Distribution-Specific Installation

The unified setup scripts handle ClamAV installation per distribution:
- **Arch**: `clamav` package
- **Debian/Ubuntu**: `clamav clamav-daemon` packages
- **Fedora**: `clamav clamav-update` packages

### Security Notes

- `.env` file permissions: 600 (owner read/write only)
- Bot token is sensitive - never commit to git
- Logs contain file paths - secure appropriately
- Scans run with sudo (required for full system access)
- Database updates happen during deep scan only

See `CLAMAV-README.md` for complete documentation.

## Testing Scripts

### Running Setup Scripts

**IMPORTANT:** Never run setup scripts as root. They use `sudo` internally:

```bash
# Desktop setup
bash unifiedSetup.sh

# Server setup
bash server/unifiedSetup.sh

# Power management (can be run standalone)
bash powerManagement.sh
bash surfacePowerManagement.sh
```

### Cloudflare UFW Configuration

Interactive mode for adding firewall rules:

```bash
bash server/cloudflareIPsInteractive.sh
# Enter port numbers when prompted, then reload UFW:
sudo ufw reload
```

## LazyVim Setup

Both unified scripts now automatically install LazyVim, a modern Neovim distribution built on the Lazy plugin manager.

### Setup Process

The `setup_lazyvim()` function:
1. Checks if LazyVim is already installed by looking for `~/.config/nvim/lua/config/lazy.lua`
2. Backs up existing Neovim directories with timestamps:
   - `~/.config/nvim` → `~/.config/nvim.bak.<timestamp>`
   - `~/.local/share/nvim` → `~/.local/share/nvim.bak.<timestamp>`
   - `~/.local/state/nvim` → `~/.local/state/nvim.bak.<timestamp>`
   - `~/.cache/nvim` → `~/.cache/nvim.bak.<timestamp>`
3. Clones the LazyVim starter template from `https://github.com/LazyVim/starter`
4. Removes the `.git` folder so you can add it to your own repository
5. On first launch, Neovim automatically installs all plugins

### Usage Notes

- The script installs the vanilla LazyVim starter template
- Plugins auto-install on first Neovim launch
- Run `:LazyHealth` after first launch to verify everything works
- To customize LazyVim, edit files in `~/.config/nvim/lua/`
- See LazyVim docs at https://www.lazyvim.org for configuration options

## Script Safety Features

### Error Handling Philosophy

Both unified scripts use **graceful degradation** instead of `set -e`:
- Non-critical failures continue with warnings (⚠️)
- Critical failures exit with clear error messages (❌)
- Success messages confirm completed operations (✅)
- Scripts provide manual recovery steps when automated steps fail

### Git/GitHub CLI Safety

**Critical fix for permission errors:**
- Scripts change to `$HOME` before running `gh auth login` or git operations
- This prevents git permission errors when running from within git repositories
- Original directory is restored after completion

```bash
# Change to HOME to avoid git permission issues
local ORIGINAL_DIR="$PWD"
cd "$HOME" || { echo "⚠️  Could not change to HOME"; return 1; }
# ... do git operations ...
cd "$ORIGINAL_DIR"  # Restore original directory
```

### Existing Directory Handling

Both unified scripts use non-destructive backups when cloning configs:
```bash
# Creates backup with timestamp instead of rm -rf
mv "$destination_dir" "${destination_dir}.bak.$(date +%s)"
```

### Package Installation Guards

- Node.js conflict detection: Checks for existing installation before adding to package list
- NPM permission fix: Configures `~/.npm-global` prefix to avoid sudo requirements
- Idempotency: Uses `--needed` flag (pacman) and checks for existing installations
- Package-by-package installation: Loops through packages individually so one failure doesn't block others

### Resilient Function Pattern

Functions return error codes (`return 1`) instead of calling `exit 1`:
```bash
install_rust() {
    if ! curl https://sh.rustup.rs | sh -s -- -y; then
        echo "⚠️  Rust installation failed. Skipping Rust-based tools."
        return 1  # Return error, don't exit
    fi
}
```

## Manual Post-Setup Tasks

After running setup scripts, these require manual configuration:

1. **Neovim/LazyVim**:
   - Launch Neovim - plugins will auto-install on first run
   - Run `:LazyHealth` to verify everything is working correctly
   - The scripts automatically install the LazyVim starter template
2. **Atuin**: Login with `atuin login -u Jevonx && atuin sync`
3. **Tailscale**: Complete authentication with `sudo tailscale up`
4. **GNOME Calendar**: Add Nextcloud calendar accounts manually (desktop only)
5. **Web apps**: Configure web apps in Web App Manager (Proton Mail, ChatGPT, etc.) (desktop only)

## Common Issues and Solutions

### GitHub Authentication Fails

**Error**: `failed to run git: fatal: failed to stat '/root/configScripts/server': Permission denied`

**Solution**: This is now fixed in the updated scripts. They change to `$HOME` before running git/gh commands. If using old scripts:
```bash
cd ~
gh auth login
gh repo clone JevonThompsonx/fish ~/.config/fish
```

### Script Stops After Single Error

**Solution**: Updated scripts continue on non-critical errors. If using old scripts with `set -e`, comment it out:
```bash
# set -e  # Disable this line
```

### Cargo/NPM Packages Fail to Install

**Solution**: Scripts now install packages individually. Failed packages are skipped with warnings. Install missing packages manually:
```bash
cargo install selene atuin
npm install -g neovim tree-sitter-cli
```

### Tailscale Disconnects SSH Session

**Solution**: When running over Tailscale SSH, the `tailscale up` command warns about disconnection. Accept the risk or run it manually after the main script completes.

## Important Notes

- **Reboot required** after running setup scripts for all changes to take effect
- **Fish shell** becomes default shell (requires logout/login to activate)
- **Power management scripts** mask systemd sleep/suspend targets permanently
- Scripts add PATH exports to `~/.profile` for persistence across reboots
- **Run from anywhere**: Scripts now work correctly regardless of current directory
- **GitHub CLI**: Scripts require interaction for `gh auth login` - prepare to copy the device code to a browser
