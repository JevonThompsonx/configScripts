# ClamAV Setup with Telegram Notifications

Automated malware scanning for Linux systems with dual-scan scheduling and Telegram notifications.

## Overview

This setup provides:
- **Fast Scan** (5 AM): Quick morning scan of critical directories (5-30 minutes)
- **Deep Scan** (8 PM): Full evening scan of entire system (1-4 hours)
- **Telegram Notifications**: Real-time alerts for scan results

## Files

### Core Scripts
- `clamav-scan.sh` - Deep scan script (full system)
- `clamav-scan-fast.sh` - Fast scan script (critical directories only)
- `setup-clamav-cronjob.sh` - Interactive setup for new systems

### Configuration
- `~/.clamav-telegram.env` - Your credentials and scan configuration
- `example.env` - Template for new systems
- `~/.clamav-logs/` - Scan logs and reports

## Quick Start (New System)

```bash
# 1. Ensure ClamAV is installed (happens automatically with unified setup)
sudo pacman -S clamav          # Arch
sudo apt install clamav        # Debian/Ubuntu
sudo dnf install clamav        # Fedora

# 2. Run the setup script
cd ~/scripts/configScripts
bash setup-clamav-cronjob.sh

# 3. Choose "Dual Scan" mode when prompted
# 4. Accept defaults (5 AM fast, 8 PM deep)
# 5. Test with a quick scan
```

## Configuration

### Telegram Bot Setup
1. Message @BotFather in Telegram
2. Send `/newbot` and follow prompts
3. Copy the bot token
4. Message @userinfobot to get your Chat ID
5. Add both to `~/.clamav-telegram.env`

### Scan Directories

Edit `~/.clamav-telegram.env`:

```bash
# Deep Scan (8 PM) - Full system scan
SCAN_DIR=/home

# Fast Scan (5 AM) - Critical directories only
FAST_SCAN_TARGETS="$HOME/Documents $HOME/Downloads $HOME/Desktop $HOME/scripts"
```

## Cronjob Schedule

Current schedule on this system:
```
0 5 * * *  - Fast scan (5:00 AM) - Critical directories
0 20 * * * - Deep scan (8:00 PM) - Full system
```

### View/Edit Cronjobs
```bash
crontab -l                    # View
crontab -e                    # Edit
```

## Manual Scans

```bash
# Run fast scan manually
bash ~/scripts/configScripts/clamav-scan-fast.sh

# Run deep scan manually
bash ~/scripts/configScripts/clamav-scan.sh

# Test fast scan on /tmp
export FAST_SCAN_TARGETS="/tmp"
bash ~/scripts/configScripts/clamav-scan-fast.sh
```

## Logs

```bash
# View all logs
ls -lh ~/.clamav-logs/

# Latest fast scan
tail -f ~/.clamav-logs/fast_scan_*.log | tail -1

# Latest deep scan
tail -f ~/.clamav-logs/scan_*.log | tail -1

# Cronjob output
tail -f ~/.clamav-logs/cron.log

# Check for infections
grep -i "FOUND" ~/.clamav-logs/*.log
```

## Troubleshooting

### No Telegram Notifications
1. Ensure bot is started: Send `/start` to your bot in Telegram
2. Test credentials:
   ```bash
   source ~/.clamav-telegram.env
   curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"
   ```

### Scan Taking Too Long (Deep Scan)
- Normal for first run (2-4 hours)
- Adjust `SCAN_DIR` to exclude large directories
- Fast scans automatically exclude:
  - `.cache`, `node_modules`, `.cargo/registry`
  - `.npm`, `.rustup`, `.git`
  - `.local/share/Steam`, `.local/share/Trash`

### Update Virus Database
```bash
sudo freshclam
```

### Scan Specific Directory
```bash
sudo clamscan -r -i /path/to/directory
```

## Features

### Fast Scan (5 AM)
- Scans only critical directories
- Excludes caches and build artifacts
- Quick morning security check
- 5-30 minute runtime
- Skips database update (uses evening's update)

### Deep Scan (8 PM)
- Full system scan
- Updates virus database first
- Comprehensive malware detection
- 1-4 hour runtime
- Scans compressed files

### Telegram Notifications
- Scan start notification
- Completion report with stats
- Threat alerts with infected file list
- Different icons for fast ⚡ vs deep 🔍 scans

## Security Notes

- `.env` file is secured with 600 permissions (owner-only read/write)
- Bot token should never be shared or committed to git
- Logs contain full file paths - secure them appropriately
- Old logs auto-delete after 30 days

## Integration with Unified Setup

The unified setup scripts (`unifiedSetup.sh` and `server/unifiedSetup.sh`) automatically install ClamAV on all new systems. After running the unified setup:

```bash
cd ~/scripts/configScripts
bash setup-clamav-cronjob.sh
```

This ensures consistent malware protection across all your devices.

## Common Commands Cheat Sheet

```bash
# Status
crontab -l | grep clamav                      # View scheduled scans
ls -lh ~/.clamav-logs/                        # View all logs
ps aux | grep clamscan                        # Check if scan is running

# Manual Operations
sudo freshclam                                # Update virus database
bash ~/scripts/configScripts/clamav-scan-fast.sh   # Run fast scan now
bash ~/scripts/configScripts/clamav-scan.sh        # Run deep scan now

# Configuration
nano ~/.clamav-telegram.env                   # Edit config
bash ~/scripts/configScripts/setup-clamav-cronjob.sh  # Re-run setup

# Logs
tail -f ~/.clamav-logs/cron.log              # Watch cronjob output
grep "FOUND" ~/.clamav-logs/*.log            # Check for threats
find ~/.clamav-logs -name "*.log" -mtime +30 -delete  # Clean old logs
```

## Tested Distributions

- ✅ Arch Linux
- ✅ Debian/Ubuntu
- ✅ Fedora

All scripts auto-detect distribution and configure accordingly.
