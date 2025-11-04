#!/bin/bash
#
# ClamAV Cronjob Setup Script
# Sets up automated ClamAV scanning with Telegram notifications
# Supports Arch, Debian/Ubuntu, and Fedora distributions
#

# --- Configuration ---
set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Prevent script from being run as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ This script must not be run as root."
    echo "It uses sudo internally when needed."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_SCRIPT="$SCRIPT_DIR/clamav-scan.sh"
ENV_FILE="$HOME/.clamav-telegram.env"

# --- Helper Functions ---

print_header() {
    echo ""
    echo "===================================================================="
    echo "➡️  $1"
    echo "===================================================================="
}

# --- Pre-flight Checks ---

print_header "ClamAV Cronjob Setup for Multi-Distribution Support"

# Check if ClamAV is installed
if ! command -v clamscan &> /dev/null; then
    echo "❌ Error: ClamAV is not installed!"
    echo "Please install ClamAV first:"
    echo ""
    echo "Arch:          sudo pacman -S clamav"
    echo "Debian/Ubuntu: sudo apt install clamav clamav-daemon"
    echo "Fedora:        sudo dnf install clamav clamav-update"
    echo ""
    exit 1
fi

echo "✅ ClamAV is installed"

# Check if scan script exists
if [ ! -f "$SCAN_SCRIPT" ]; then
    echo "❌ Error: Scan script not found at $SCAN_SCRIPT"
    echo "Please ensure clamav-scan.sh is in the same directory as this script."
    exit 1
fi

echo "✅ Scan script found at $SCAN_SCRIPT"

# Make scan script executable
chmod +x "$SCAN_SCRIPT"
echo "✅ Made scan script executable"

# --- Telegram Credentials Setup ---

print_header "Telegram Bot Configuration"

if [ -f "$ENV_FILE" ]; then
    echo "Existing .env file found at $ENV_FILE"
    echo ""
    # shellcheck source=/dev/null
    source "$ENV_FILE"

    echo "Current configuration:"
    echo "  Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}..."
    echo "  Chat ID: $TELEGRAM_CHAT_ID"
    echo ""

    read -p "Do you want to keep this configuration? (Y/n): " keep_config

    if [[ ! "$keep_config" =~ ^[Nn]$ ]]; then
        echo "✅ Keeping existing configuration"
    else
        rm "$ENV_FILE"
        echo "Removed old configuration. Creating new one..."
    fi
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "No .env file found. Let's create one!"
    echo ""
    echo "You'll need:"
    echo "  1. Telegram Bot Token (from @BotFather)"
    echo "  2. Your Telegram Chat ID (your user ID or group chat ID)"
    echo ""

    read -p "Do you want to enter credentials now? (Y/n): " enter_now

    if [[ "$enter_now" =~ ^[Nn]$ ]]; then
        echo ""
        echo "Please create $ENV_FILE with the following content:"
        echo ""
        echo "TELEGRAM_BOT_TOKEN=your_bot_token_here"
        echo "TELEGRAM_CHAT_ID=your_chat_id_here"
        echo "SCAN_DIR=/home  # Optional: directory to scan (default: /home)"
        echo ""
        echo "Then run this script again."
        exit 0
    fi

    echo ""
    read -p "Enter Telegram Bot Token: " bot_token
    read -p "Enter Telegram Chat ID: " chat_id
    read -p "Enter scan directory (default: /home): " scan_dir

    scan_dir="${scan_dir:-/home}"

    # Create .env file
    cat > "$ENV_FILE" << EOF
# ClamAV Telegram Bot Configuration
# Keep this file secure - it contains your bot token!

TELEGRAM_BOT_TOKEN=$bot_token
TELEGRAM_CHAT_ID=$chat_id
SCAN_DIR=$scan_dir

# Optional: Log directory (default: \$HOME/.clamav-logs)
# LOG_DIR=/var/log/clamav-scans
EOF

    chmod 600 "$ENV_FILE"  # Secure the file
    echo "✅ Created and secured $ENV_FILE"
fi

# --- Distribution Detection and Service Setup ---

print_header "Detecting Distribution and Configuring ClamAV Service"

if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO_ID="${ID_LIKE:-$ID}"
else
    echo "❌ Cannot detect distribution: /etc/os-release not found."
    exit 1
fi

echo "Detected distribution: $ID"

# Enable and start ClamAV service based on distribution
case "$DISTRO_ID" in
    *arch*)
        echo "Configuring ClamAV for Arch Linux..."

        # Update virus database
        if sudo freshclam; then
            echo "✅ Virus database updated"
        else
            echo "⚠️  Warning: freshclam might have failed, continuing anyway..."
        fi
        ;;

    *debian* | *ubuntu*)
        echo "Configuring ClamAV for Debian/Ubuntu..."

        # Enable and start clamav-freshclam service for automatic updates
        if sudo systemctl enable clamav-freshclam 2>/dev/null; then
            echo "✅ ClamAV freshclam service enabled"
        fi

        if sudo systemctl start clamav-freshclam 2>/dev/null; then
            echo "✅ ClamAV freshclam service started"
        fi

        # Wait for initial database update
        echo "Waiting for initial virus database update..."
        sleep 5
        ;;

    *fedora*)
        echo "Configuring ClamAV for Fedora..."

        # Update SELinux context if SELinux is enabled
        if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
            echo "SELinux detected. You may need to configure SELinux policies for ClamAV."
        fi

        # Update virus database
        if sudo freshclam; then
            echo "✅ Virus database updated"
        else
            echo "⚠️  Warning: freshclam might have failed, continuing anyway..."
        fi
        ;;

    *)
        echo "⚠️  Warning: Unsupported distribution. Continuing with generic setup..."
        ;;
esac

# --- Cronjob Setup ---

print_header "Setting Up Cronjob"

FAST_SCAN_SCRIPT="$SCRIPT_DIR/clamav-scan-fast.sh"

echo "This script can set up ClamAV scans in two modes:"
echo ""
echo "1. Single Scan - One scan per day (deep scan)"
echo "   Example: Daily at 2:00 AM"
echo ""
echo "2. Dual Scan (Recommended) - Fast scan in morning, deep scan at night"
echo "   Fast scan: Quick check of critical directories (5-30 min)"
echo "   Deep scan: Full system scan (1-4 hours)"
echo ""
read -p "Choose scan mode (1=Single, 2=Dual): " scan_mode

if [ "$scan_mode" == "2" ]; then
    echo ""
    echo "Setting up DUAL SCAN mode"
    echo ""

    # Fast scan schedule
    echo "Fast Scan Schedule:"
    echo "Recommended: 0 5 * * * (5:00 AM daily)"
    read -p "Enter fast scan schedule (or press Enter for default '0 5 * * *'): " fast_cron
    fast_cron="${fast_cron:-0 5 * * *}"

    # Deep scan schedule
    echo ""
    echo "Deep Scan Schedule:"
    echo "Recommended: 0 20 * * * (8:00 PM daily)"
    read -p "Enter deep scan schedule (or press Enter for default '0 20 * * *'): " deep_cron
    deep_cron="${deep_cron:-0 20 * * *}"

    # Check if fast scan script exists
    if [ ! -f "$FAST_SCAN_SCRIPT" ]; then
        echo "⚠️  Warning: Fast scan script not found at $FAST_SCAN_SCRIPT"
        echo "Using deep scan only."
        scan_mode="1"
    else
        chmod +x "$FAST_SCAN_SCRIPT"
        FAST_CRON_COMMAND="$fast_cron $FAST_SCAN_SCRIPT >> $HOME/.clamav-logs/cron.log 2>&1"
        DEEP_CRON_COMMAND="$deep_cron $SCAN_SCRIPT >> $HOME/.clamav-logs/cron.log 2>&1"
    fi
else
    echo ""
    echo "Setting up SINGLE SCAN mode"
    echo ""
    echo "Recommended schedule: 0 2 * * * (2:00 AM daily)"
    echo "Cron format: 0 2 * * * (minute hour day month weekday)"
    read -p "Enter cron schedule (or press Enter for default '0 2 * * *'): " cron_schedule
    cron_schedule="${cron_schedule:-0 2 * * *}"
    CRON_COMMAND="$cron_schedule $SCAN_SCRIPT >> $HOME/.clamav-logs/cron.log 2>&1"
fi

# Remove existing ClamAV cronjobs
if crontab -l 2>/dev/null | grep -q "clamav-scan"; then
    echo "⚠️  Existing ClamAV cronjob(s) found."
    echo ""
    crontab -l 2>/dev/null | grep "clamav-scan"
    echo ""
    read -p "Remove existing cronjobs and create new ones? (y/N): " replace_cron

    if [[ "$replace_cron" =~ ^[Yy]$ ]]; then
        # Remove old cronjobs
        crontab -l 2>/dev/null | grep -v "clamav-scan" | crontab -
        echo "✅ Removed existing ClamAV cronjobs"
    else
        echo "Keeping existing cronjobs. Exiting."
        exit 0
    fi
fi

# Add new cronjob(s)
if [ "$scan_mode" == "2" ]; then
    (crontab -l 2>/dev/null; echo ""; echo "# ClamAV Dual Scan - Fast scan (morning) and Deep scan (evening)"; echo "$FAST_CRON_COMMAND"; echo "$DEEP_CRON_COMMAND") | crontab -
    echo "✅ Dual scan cronjobs added successfully!"
    echo ""
    echo "Scheduled scans:"
    echo "  Fast scan: $fast_cron (critical directories only)"
    echo "  Deep scan: $deep_cron (full system scan)"
else
    (crontab -l 2>/dev/null; echo ""; echo "# ClamAV Deep Scan"; echo "$CRON_COMMAND") | crontab -
    echo "✅ Cronjob added successfully!"
fi

echo ""
echo "Current ClamAV crontab entries:"
crontab -l | grep "clamav-scan"

# --- Test Configuration ---

print_header "Testing Configuration"

echo "Would you like to run a test scan now to verify everything works?"
echo "This will:"
echo "  1. Update the virus database"
echo "  2. Run a quick scan of /tmp (or a directory of your choice)"
echo "  3. Send a Telegram notification"
echo ""
read -p "Run test scan? (y/N): " run_test

if [[ "$run_test" =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter directory to test scan (default: /tmp): " test_dir
    test_dir="${test_dir:-/tmp}"

    echo ""
    echo "Running test scan of $test_dir..."
    echo "This will send a notification to your Telegram bot."
    echo ""

    # Temporarily override SCAN_DIR for this test
    export SCAN_DIR="$test_dir"

    if bash "$SCAN_SCRIPT"; then
        echo ""
        echo "✅ Test scan completed successfully!"
        echo "Check your Telegram app for notifications."
    else
        echo ""
        echo "⚠️  Test scan completed with warnings or errors."
        echo "Check the output above for details."
        echo "You may need to review your .env file or Telegram bot configuration."
    fi
else
    echo "Skipping test scan."
fi

# --- Summary ---

print_header "Setup Complete!"

echo ""
echo "Summary:"
echo "  ✅ ClamAV is installed and configured"
echo "  ✅ Telegram credentials configured in $ENV_FILE"
echo "  ✅ Deep scan script: $SCAN_SCRIPT"
if [ "$scan_mode" == "2" ]; then
echo "  ✅ Fast scan script: $FAST_SCAN_SCRIPT"
echo "  ✅ Dual scan schedule:"
echo "      Fast: $fast_cron (5 AM - critical directories)"
echo "      Deep: $deep_cron (8 PM - full system scan)"
else
echo "  ✅ Single scan schedule: ${cron_schedule:-$deep_cron}"
fi
echo "  ✅ Logs directory: $HOME/.clamav-logs"
echo ""
echo "Your system will now automatically scan for malware and notify you via Telegram."
echo ""
echo "Useful commands:"
echo "  View cronjobs:        crontab -l"
echo "  Edit cronjobs:        crontab -e"
echo "  View scan logs:       ls -lh $HOME/.clamav-logs"
echo "  Manual deep scan:     bash $SCAN_SCRIPT"
if [ "$scan_mode" == "2" ]; then
echo "  Manual fast scan:     bash $FAST_SCAN_SCRIPT"
fi
echo "  Update .env:          nano $ENV_FILE"
echo ""
echo "Next steps:"
echo "  1. Check your Telegram app for test notification (if you ran one)"
if [ "$scan_mode" == "2" ]; then
echo "  2. Fast scans run daily at 5 AM, deep scans at 8 PM"
else
echo "  2. Wait for the scheduled scan or run manually"
fi
echo "  3. Monitor logs in $HOME/.clamav-logs"
echo ""
