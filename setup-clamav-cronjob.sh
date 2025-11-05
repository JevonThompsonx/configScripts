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

# Check if cron is installed
if ! command -v crontab &> /dev/null; then
    echo "❌ Error: cron is not installed!"
    echo ""

    # Detect distribution and suggest installation
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        DISTRO_ID="${ID_LIKE:-$ID}"

        case "$DISTRO_ID" in
            *arch*)
                echo "Install with: sudo pacman -S cronie"
                echo "Enable with:  sudo systemctl enable --now cronie"
                ;;
            *debian* | *ubuntu*)
                echo "Install with: sudo apt install cron"
                echo "Enable with:  sudo systemctl enable --now cron"
                ;;
            *fedora*)
                echo "Install with: sudo dnf install cronie"
                echo "Enable with:  sudo systemctl enable --now crond"
                ;;
            *)
                echo "Please install cron/cronie for your distribution"
                ;;
        esac
    fi

    echo ""
    read -p "Do you want to install cron now? (y/N): " install_cron

    if [[ "$install_cron" =~ ^[Yy]$ ]]; then
        case "$DISTRO_ID" in
            *arch*)
                sudo pacman -S --noconfirm cronie && sudo systemctl enable --now cronie
                ;;
            *debian* | *ubuntu*)
                sudo apt install -y cron && sudo systemctl enable --now cron
                ;;
            *fedora*)
                sudo dnf install -y cronie && sudo systemctl enable --now crond
                ;;
        esac

        if command -v crontab &> /dev/null; then
            echo "✅ Cron installed successfully"
        else
            echo "❌ Failed to install cron. Please install manually and re-run this script."
            exit 1
        fi
    else
        echo "Cannot proceed without cron. Exiting."
        exit 1
    fi
else
    echo "✅ Cron is installed"
fi

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

# --- Clamd Daemon Setup ---

print_header "Configuring ClamAV Daemon (clamd)"

echo "Clamd is the ClamAV daemon that:"
echo "  - Keeps virus signatures loaded in memory for faster scanning"
echo "  - Provides on-demand scanning via socket"
echo "  - Can be used by other applications"
echo ""
echo "Benefits:"
echo "  - 10-50x faster scanning compared to clamscan"
echo "  - Lower CPU usage for frequent scans"
echo "  - Recommended for servers and regular scanning"
echo ""

# Check if clamd is installed
if command -v clamd &> /dev/null || command -v clamdscan &> /dev/null; then
    echo "✅ Clamd appears to be installed"
else
    echo "⚠️  Clamd not found. It should be installed with clamav."
    echo "    Install it with:"
    case "$DISTRO_ID" in
        *arch*)
            echo "    sudo pacman -S clamav (includes clamd)"
            ;;
        *debian* | *ubuntu*)
            echo "    sudo apt install clamav-daemon"
            ;;
        *fedora*)
            echo "    sudo dnf install clamd"
            ;;
    esac
    echo ""
fi

read -p "Enable and configure clamd daemon? (Y/n): " enable_clamd

if [[ ! "$enable_clamd" =~ ^[Nn]$ ]]; then
    echo ""
    echo "Configuring clamd..."

    # Distribution-specific clamd setup
    case "$DISTRO_ID" in
        *arch*)
            # Arch Linux
            if systemctl list-unit-files | grep -q "clamav-daemon.service"; then
                if sudo systemctl enable clamav-daemon 2>/dev/null; then
                    echo "✅ Clamd service enabled"
                fi
                if sudo systemctl start clamav-daemon 2>/dev/null; then
                    echo "✅ Clamd service started"
                else
                    echo "⚠️  Clamd service failed to start, check: systemctl status clamav-daemon"
                fi
            else
                echo "⚠️  clamav-daemon.service not found"
            fi
            ;;

        *debian* | *ubuntu*)
            # Debian/Ubuntu
            if systemctl list-unit-files | grep -q "clamav-daemon.service"; then
                if sudo systemctl enable clamav-daemon 2>/dev/null; then
                    echo "✅ Clamd service enabled"
                fi
                if sudo systemctl start clamav-daemon 2>/dev/null; then
                    echo "✅ Clamd service started"
                else
                    echo "⚠️  Clamd service failed to start, check: systemctl status clamav-daemon"
                fi
            else
                echo "⚠️  clamav-daemon.service not found"
            fi
            ;;

        *fedora*)
            # Fedora
            if systemctl list-unit-files | grep -q "clamd@"; then
                # Fedora uses clamd@scan.service
                if sudo systemctl enable clamd@scan 2>/dev/null; then
                    echo "✅ Clamd service enabled"
                fi
                if sudo systemctl start clamd@scan 2>/dev/null; then
                    echo "✅ Clamd service started"
                else
                    echo "⚠️  Clamd service failed to start, check: systemctl status clamd@scan"
                fi
            else
                echo "⚠️  clamd@scan.service not found"
            fi
            ;;
    esac

    # Wait a moment for daemon to initialize
    sleep 2

    # Verify clamd is running
    if pgrep -x "clamd" > /dev/null || pgrep -x "clamav-daemon" > /dev/null; then
        echo "✅ Clamd daemon is running"

        # Test clamdscan
        if command -v clamdscan &> /dev/null; then
            echo ""
            echo "Testing clamdscan..."
            if echo "test" | clamdscan - > /dev/null 2>&1; then
                echo "✅ Clamdscan is working!"

                # Offer to use clamdscan in scan scripts
                echo ""
                echo "Would you like to use clamdscan (faster) instead of clamscan in your scan scripts?"
                echo "This is recommended for better performance."
                read -p "Use clamdscan? (Y/n): " use_clamdscan

                if [[ ! "$use_clamdscan" =~ ^[Nn]$ ]]; then
                    # Create/update a config flag for scan scripts
                    if grep -q "^USE_CLAMDSCAN=" "$ENV_FILE" 2>/dev/null; then
                        sed -i 's/^USE_CLAMDSCAN=.*/USE_CLAMDSCAN=true/' "$ENV_FILE"
                    else
                        echo "" >> "$ENV_FILE"
                        echo "# Use clamdscan (daemon) instead of clamscan for faster scanning" >> "$ENV_FILE"
                        echo "USE_CLAMDSCAN=true" >> "$ENV_FILE"
                    fi
                    echo "✅ Configured to use clamdscan"
                else
                    if grep -q "^USE_CLAMDSCAN=" "$ENV_FILE" 2>/dev/null; then
                        sed -i 's/^USE_CLAMDSCAN=.*/USE_CLAMDSCAN=false/' "$ENV_FILE"
                    fi
                    echo "Will continue using clamscan"
                fi
            else
                echo "⚠️  Clamdscan test failed"
            fi
        fi
    else
        echo "⚠️  Clamd daemon not running"
        echo "    Check status: systemctl status clamav-daemon (or clamd@scan on Fedora)"
    fi
else
    echo "Skipping clamd configuration"
fi

# --- Passwordless Sudo Setup ---

print_header "Configuring Passwordless Sudo for ClamAV"

echo "For automated cronjobs to work, ClamAV commands need to run without password prompts."
echo "This will configure sudo to allow passwordless execution of:"
echo "  - clamscan (virus scanning)"
echo "  - freshclam (database updates)"
echo ""
read -p "Configure passwordless sudo for ClamAV? (Y/n): " setup_sudo

if [[ ! "$setup_sudo" =~ ^[Nn]$ ]]; then
    CURRENT_USER="$USER"
    SUDOERS_FILE="/etc/sudoers.d/clamav-${CURRENT_USER}"

    # Find clamscan, clamdscan and freshclam paths
    CLAMSCAN_PATH=$(which clamscan 2>/dev/null || echo "/usr/bin/clamscan")
    CLAMDSCAN_PATH=$(which clamdscan 2>/dev/null || echo "/usr/bin/clamdscan")
    FRESHCLAM_PATH=$(which freshclam 2>/dev/null || echo "/usr/bin/freshclam")

    # Create the sudoers content
    SUDOERS_CONTENT="# ClamAV passwordless sudo for user: $CURRENT_USER
# Created by setup-clamav-cronjob.sh on $(date)
# Allows automated virus scanning via cronjobs

# Allow clamscan without password
$CURRENT_USER ALL=(root) NOPASSWD: $CLAMSCAN_PATH

# Allow clamdscan (daemon scanner) without password
$CURRENT_USER ALL=(root) NOPASSWD: $CLAMDSCAN_PATH

# Allow freshclam without password
$CURRENT_USER ALL=(root) NOPASSWD: $FRESHCLAM_PATH
"

    # Create temporary file
    TEMP_FILE=$(mktemp)
    echo "$SUDOERS_CONTENT" > "$TEMP_FILE"

    # Validate the sudoers syntax
    if sudo visudo -cf "$TEMP_FILE"; then
        # Install the sudoers file
        if sudo cp "$TEMP_FILE" "$SUDOERS_FILE" && sudo chmod 0440 "$SUDOERS_FILE"; then
            echo "✅ Passwordless sudo configured"
        else
            echo "⚠️  Failed to install sudoers file, continuing anyway..."
        fi
    else
        echo "⚠️  Sudoers syntax validation failed, skipping passwordless sudo setup"
    fi

    rm -f "$TEMP_FILE"
else
    echo "⚠️  Skipping passwordless sudo setup"
    echo "    Note: Cronjobs will fail without this configuration!"
fi

# --- Third-Party Virus Database Setup ---

print_header "Third-Party Virus Database Configuration"

echo "ClamAV can use additional virus signature databases from trusted third parties."
echo "This significantly improves detection rates beyond the official ClamAV database."
echo ""
echo "Available options:"
echo "  1. clamav-unofficial-sigs - Free signatures from Sanesecurity, MalwarePatrol, and more"
echo "  2. Skip (use only official ClamAV databases)"
echo ""
read -p "Install third-party signatures? (1=Yes, 2=Skip): " install_thirdparty

if [ "$install_thirdparty" == "1" ]; then
    echo ""
    echo "Installing clamav-unofficial-sigs..."

    case "$DISTRO_ID" in
        *arch*)
            # Check if available in AUR
            if command -v yay &> /dev/null; then
                if yay -S --noconfirm clamav-unofficial-sigs; then
                    echo "✅ Installed via AUR"
                else
                    echo "⚠️  AUR installation failed"
                fi
            elif command -v paru &> /dev/null; then
                if paru -S --noconfirm clamav-unofficial-sigs; then
                    echo "✅ Installed via AUR"
                else
                    echo "⚠️  AUR installation failed"
                fi
            else
                echo "⚠️  No AUR helper found. Install manually from:"
                echo "    https://github.com/extremeshok/clamav-unofficial-sigs"
            fi
            ;;
        *debian* | *ubuntu*)
            # Download and install the script
            if [ ! -f /usr/local/bin/clamav-unofficial-sigs.sh ]; then
                sudo curl -o /usr/local/bin/clamav-unofficial-sigs.sh https://raw.githubusercontent.com/extremeshok/clamav-unofficial-sigs/master/clamav-unofficial-sigs.sh
                sudo chmod +x /usr/local/bin/clamav-unofficial-sigs.sh
                echo "✅ Installed clamav-unofficial-sigs.sh"

                # Run initial update
                echo "Running initial signature update (this may take a while)..."
                if sudo /usr/local/bin/clamav-unofficial-sigs.sh; then
                    echo "✅ Third-party signatures updated"
                else
                    echo "⚠️  Initial update failed, continuing anyway..."
                fi

                # Add to cron for daily updates (6 AM)
                THIRDPARTY_CRON="0 6 * * * /usr/local/bin/clamav-unofficial-sigs.sh > /dev/null 2>&1"
                if ! sudo crontab -l 2>/dev/null | grep -q "clamav-unofficial-sigs"; then
                    (sudo crontab -l 2>/dev/null; echo "$THIRDPARTY_CRON") | sudo crontab -
                    echo "✅ Added daily update to root crontab (6 AM)"
                fi
            else
                echo "✅ clamav-unofficial-sigs already installed"
            fi
            ;;
        *fedora*)
            # Download and install the script
            if [ ! -f /usr/local/bin/clamav-unofficial-sigs.sh ]; then
                sudo curl -o /usr/local/bin/clamav-unofficial-sigs.sh https://raw.githubusercontent.com/extremeshok/clamav-unofficial-sigs/master/clamav-unofficial-sigs.sh
                sudo chmod +x /usr/local/bin/clamav-unofficial-sigs.sh
                echo "✅ Installed clamav-unofficial-sigs.sh"

                # Run initial update
                echo "Running initial signature update (this may take a while)..."
                if sudo /usr/local/bin/clamav-unofficial-sigs.sh; then
                    echo "✅ Third-party signatures updated"
                else
                    echo "⚠️  Initial update failed, continuing anyway..."
                fi

                # Add to cron for daily updates (6 AM)
                THIRDPARTY_CRON="0 6 * * * /usr/local/bin/clamav-unofficial-sigs.sh > /dev/null 2>&1"
                if ! sudo crontab -l 2>/dev/null | grep -q "clamav-unofficial-sigs"; then
                    (sudo crontab -l 2>/dev/null; echo "$THIRDPARTY_CRON") | sudo crontab -
                    echo "✅ Added daily update to root crontab (6 AM)"
                fi
            else
                echo "✅ clamav-unofficial-sigs already installed"
            fi
            ;;
        *)
            echo "⚠️  Unsupported distribution for automatic installation"
            echo "    Manual installation: https://github.com/extremeshok/clamav-unofficial-sigs"
            ;;
    esac

    echo ""
    echo "ℹ️  Third-party databases include:"
    echo "    - Sanesecurity (free, high quality)"
    echo "    - MalwarePatrol (limited free)"
    echo "    - SecuriteInfo (limited free)"
    echo "    - Additional community signatures"
else
    echo "Skipping third-party signature installation"
    echo "Note: Detection rates will be limited to official ClamAV databases only"
fi

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
