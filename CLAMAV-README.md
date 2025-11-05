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

# 3. The setup will configure:
#    - Telegram bot credentials
#    - Passwordless sudo (for automated scans)
#    - Third-party virus databases (optional, recommended)
#    - Dual scan schedule (5 AM fast, 8 PM deep)

# 4. Test with a quick scan
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

## Third-Party Virus Databases

ClamAV's official database is supplemented with free, high-quality signatures from trusted third parties:

### What's Included

**clamav-unofficial-sigs** provides:
- **Sanesecurity**: High-quality phishing, scam, and malware signatures
- **MalwarePatrol**: Limited free malware signatures (full version is commercial)
- **SecuriteInfo**: Limited free signatures (full version is commercial)
- **Additional community databases**: Specialized detection for specific threats

### Benefits

- 🎯 **Higher Detection Rates**: 2-5x more signatures than ClamAV alone
- 🆓 **Free**: All databases used are free or have free tiers
- 🔄 **Auto-Updated**: Daily updates at 6 AM (separate from official ClamAV updates)
- ✅ **Trusted Sources**: Well-maintained, reputable signature providers

### Management

```bash
# Manual update
sudo /usr/local/bin/clamav-unofficial-sigs.sh

# Check what's installed
sudo clamav-unofficial-sigs.sh --show-config

# View database locations
ls -lh /var/lib/clamav/*.{ndb,hdb,ldb,cdb}
```

### Setup on Existing Systems

If you already have ClamAV installed but want to add third-party databases:

```bash
# Re-run the setup and choose option 1 when asked about third-party databases
bash ~/scripts/configScripts/setup-clamav-cronjob.sh
```

## ClamAV Daemon (clamd)

Clamd is the ClamAV daemon that dramatically improves scanning performance by keeping virus signatures loaded in memory.

### Benefits

- ⚡ **10-50x Faster**: Scans complete in seconds instead of minutes
- 💪 **Lower CPU Usage**: More efficient for frequent/scheduled scans
- 🔄 **Always Ready**: Signatures pre-loaded in RAM
- 🔌 **Socket Access**: Other applications can use the scanner
- ✅ **Recommended**: Especially for servers and regular scanning

### Performance Comparison

| Scan Type | clamscan | clamdscan | Improvement |
|-----------|----------|-----------|-------------|
| Small directory (100 files) | 15s | <1s | 15x faster |
| Medium directory (10,000 files) | 5 min | 15s | 20x faster |
| Large directory (100,000 files) | 45 min | 2 min | 22x faster |

### Setup

The setup script automatically configures clamd:

```bash
bash ~/scripts/configScripts/setup-clamav-cronjob.sh
# Choose "Y" when asked about enabling clamd
# Choose "Y" when asked about using clamdscan
```

### Manual Setup

If already configured but want to enable clamd:

**Arch:**
```bash
sudo systemctl enable --now clamav-daemon
```

**Debian/Ubuntu:**
```bash
sudo systemctl enable --now clamav-daemon
```

**Fedora:**
```bash
sudo systemctl enable --now clamd@scan
```

### Verify Clamd is Running

```bash
# Check service status
systemctl status clamav-daemon  # Arch/Debian/Ubuntu
systemctl status clamd@scan     # Fedora

# Check process
pgrep -a clamd

# Test clamdscan
echo "test" | clamdscan -
```

### Configuration

Enable clamdscan in `~/.clamav-telegram.env`:

```bash
# Use daemon scanner for much faster scans
USE_CLAMDSCAN=true
```

### Differences: clamscan vs clamdscan

| Feature | clamscan | clamdscan |
|---------|----------|-----------|
| Speed | Slow | Very Fast |
| Memory | Low | High (daemon uses ~500MB) |
| Startup time | Loads signatures each run | Instant (pre-loaded) |
| --exclude-dir support | ✅ Yes | ❌ No |
| Multithreading | Single-threaded | Multi-threaded (--multiscan) |
| Best for | One-time scans | Regular/scheduled scans |

**Note:** clamdscan doesn't support `--exclude-dir`, but it's so fast that it doesn't matter for most use cases.

### Troubleshooting Clamd

**Daemon not starting:**
```bash
# Check logs
journalctl -xeu clamav-daemon  # Arch/Debian/Ubuntu
journalctl -xeu clamd@scan     # Fedora

# Common issue: Not enough RAM
# Clamd needs ~500MB-1GB depending on signature databases
free -h

# Check config
cat /etc/clamav/clamd.conf  # Arch/Fedora
cat /etc/clamav/clamd.conf  # Debian/Ubuntu
```

**Connection refused:**
```bash
# Check if socket exists
ls -la /var/run/clamav/clamd.sock  # Common location

# Check permissions
# Your user needs access to the clamd socket
groups  # Make sure you're in 'clamav' group if needed
```

## Passwordless Sudo

Automated scans require passwordless execution of ClamAV commands. The setup script configures this automatically.

### What's Configured

Creates `/etc/sudoers.d/clamav-$USER` allowing:
- `sudo clamscan` (without password)
- `sudo clamdscan` (without password)
- `sudo freshclam` (without password)

### Security

- ✅ Only allows specific ClamAV commands
- ✅ Only for your user account
- ✅ Doesn't grant blanket sudo access
- ✅ Standard practice for automated security tools

### Manual Setup

If needed, run the standalone script:
```bash
bash ~/scripts/configScripts/setup-clamav-sudo.sh
```

To remove:
```bash
sudo rm /etc/sudoers.d/clamav-$USER
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

**Arch/Fedora:**
```bash
sudo freshclam
```

**Ubuntu/Debian:**
The `clamav-freshclam` service updates automatically. To check status:
```bash
sudo systemctl status clamav-freshclam
sudo tail /var/log/clamav/freshclam.log
```

To force manual update (if needed):
```bash
sudo systemctl stop clamav-freshclam
sudo freshclam
sudo systemctl start clamav-freshclam
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
