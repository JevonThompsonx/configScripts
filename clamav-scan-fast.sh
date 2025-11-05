#!/bin/bash
#
# ClamAV Fast Scan Script with Telegram Notifications
# Optimized for daily quick scans - focuses on critical directories
# and excludes caches/build artifacts for faster execution.
#

# --- Configuration ---
set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Look for .env file in script directory or user's home directory
if [ -f "$SCRIPT_DIR/.env" ]; then
    ENV_FILE="$SCRIPT_DIR/.env"
elif [ -f "$HOME/.clamav-telegram.env" ]; then
    ENV_FILE="$HOME/.clamav-telegram.env"
else
    echo "❌ Error: .env file not found!"
    echo "Create either:"
    echo "  - $SCRIPT_DIR/.env"
    echo "  - $HOME/.clamav-telegram.env"
    exit 1
fi

# Load environment variables from .env file
echo "Loading Telegram credentials from $ENV_FILE..."
# shellcheck source=/dev/null
source "$ENV_FILE"

# Validate required environment variables
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
    echo "❌ Error: TELEGRAM_BOT_TOKEN not set in $ENV_FILE"
    exit 1
fi

if [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    echo "❌ Error: TELEGRAM_CHAT_ID not set in $ENV_FILE"
    exit 1
fi

# --- Configuration Variables ---
# Fast scan targets - critical directories only
FAST_SCAN_TARGETS="${FAST_SCAN_TARGETS:-$HOME/Documents $HOME/Downloads $HOME/Desktop $HOME/scripts}"
LOG_DIR="${LOG_DIR:-$HOME/.clamav-logs}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCAN_LOG="$LOG_DIR/fast_scan_$TIMESTAMP.log"
INFECTED_LOG="$LOG_DIR/infected_fast_$TIMESTAMP.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# --- Helper Functions ---

# Function to send Telegram message
send_telegram_message() {
    local message="$1"
    local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

    # Use curl to send the message
    if curl -s -X POST "$api_url" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="HTML" > /dev/null 2>&1; then
        echo "✅ Telegram notification sent successfully"
        return 0
    else
        echo "⚠️  Failed to send Telegram notification"
        return 1
    fi
}

# Function to send Telegram message with file
send_telegram_file() {
    local file_path="$1"
    local caption="$2"
    local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"

    if curl -s -X POST "$api_url" \
        -F chat_id="$TELEGRAM_CHAT_ID" \
        -F document=@"$file_path" \
        -F caption="$caption" > /dev/null 2>&1; then
        echo "✅ Telegram file sent successfully"
        return 0
    else
        echo "⚠️  Failed to send Telegram file"
        return 1
    fi
}

# --- Main Script Logic ---

echo "=========================================="
echo "ClamAV Fast Scan with Telegram Notifications"
echo "=========================================="
echo "Started at: $(date)"
echo ""

# Get hostname reliably early for notifications
HOSTNAME=$(hostname -f 2>/dev/null || hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown")

# Send start notification
send_telegram_message "⚡ <b>ClamAV Fast Scan Started</b>
Host: $HOSTNAME
Scan Type: Quick scan (critical directories only)
Time: $(date '+%Y-%m-%d %H:%M:%S')"

# Note: Skip freshclam for fast scans to save time
# The deep scan will update the database
echo "ℹ️  Skipping virus database update (fast scan mode)"
echo "   Database updates happen during deep scans"

# Run ClamAV fast scan
echo ""
echo "Starting ClamAV fast scan..."
echo "Scan log: $SCAN_LOG"
echo ""

SCAN_START_TIME=$(date +%s)

# Build scan command with exclusions for speed
EXCLUDE_ARGS=(
    "--exclude-dir=\.cache"
    "--exclude-dir=node_modules"
    "--exclude-dir=\.cargo/registry"
    "--exclude-dir=\.npm"
    "--exclude-dir=\.rustup"
    "--exclude-dir=\.git"
    "--exclude-dir=\.local/share/Steam"
    "--exclude-dir=\.local/share/Trash"
)

# Determine which scanner to use
USE_CLAMDSCAN="${USE_CLAMDSCAN:-false}"
if [ "$USE_CLAMDSCAN" = "true" ] && command -v clamdscan &> /dev/null; then
    SCANNER="clamdscan"
    echo "Using clamdscan (daemon mode) for faster scanning"
else
    SCANNER="sudo clamscan"
    echo "Using clamscan (standard mode)"
fi

# Scan each target directory
TOTAL_SCANNED=0
for target in $FAST_SCAN_TARGETS; do
    if [ -d "$target" ]; then
        echo "Scanning: $target"
        # Note: Removed -i flag to get full output including summary stats
        if [ "$SCANNER" = "clamdscan" ]; then
            # clamdscan doesn't support --exclude-dir, but it's much faster
            # and works through the daemon
            if $SCANNER --multiscan "$target" 2>&1 | tee -a "$SCAN_LOG"; then
                :
            else
                echo "⚠️  Scan of $target completed with warnings"
            fi
        else
            # clamscan with exclusions
            if $SCANNER -r "${EXCLUDE_ARGS[@]}" "$target" 2>&1 | tee -a "$SCAN_LOG"; then
                :
            else
                echo "⚠️  Scan of $target completed with warnings"
            fi
        fi
    else
        echo "⚠️  Directory not found, skipping: $target"
    fi
done

SCAN_END_TIME=$(date +%s)
SCAN_DURATION=$((SCAN_END_TIME - SCAN_START_TIME))
SCAN_DURATION_MIN=$((SCAN_DURATION / 60))
if [ "$SCAN_DURATION_MIN" -eq 0 ] && [ "$SCAN_DURATION" -gt 0 ]; then
    SCAN_DURATION_MIN="<1"
fi

echo ""
echo "Fast scan completed in ${SCAN_DURATION_MIN} minutes"

# Parse scan results - try multiple patterns for better compatibility
INFECTED_COUNT=$(grep -c "FOUND" "$SCAN_LOG" 2>/dev/null || echo "0")

# Try multiple parsing methods for scan statistics
SCANNED_FILES=$(grep -E "Scanned files:|Known viruses:" "$SCAN_LOG" | grep "Scanned files:" | tail -1 | awk '{print $3}' 2>/dev/null)
if [ -z "$SCANNED_FILES" ]; then
    SCANNED_FILES=$(grep -oP "Scanned files: \K\d+" "$SCAN_LOG" | tail -1 2>/dev/null || echo "0")
fi
[ -z "$SCANNED_FILES" ] && SCANNED_FILES="0"

SCANNED_DIRS=$(grep "Scanned directories:" "$SCAN_LOG" | tail -1 | awk '{print $3}' 2>/dev/null)
if [ -z "$SCANNED_DIRS" ]; then
    SCANNED_DIRS=$(grep -oP "Scanned directories: \K\d+" "$SCAN_LOG" | tail -1 2>/dev/null || echo "0")
fi
[ -z "$SCANNED_DIRS" ] && SCANNED_DIRS="0"

# Extract infected files if any
if [ "$INFECTED_COUNT" -gt 0 ]; then
    grep "FOUND" "$SCAN_LOG" > "$INFECTED_LOG"
fi

# Prepare summary message
if [ "$INFECTED_COUNT" -gt 0 ]; then
    SUMMARY_MESSAGE="🚨 <b>ClamAV Fast Scan Complete - THREATS FOUND</b>

Host: $HOSTNAME
Scan Type: Fast Scan (critical directories)
Duration: ${SCAN_DURATION_MIN} minutes

📊 <b>Results:</b>
Files Scanned: $SCANNED_FILES
Directories Scanned: $SCANNED_DIRS
⚠️ <b>Infected Files: $INFECTED_COUNT</b>

Time: $(date '+%Y-%m-%d %H:%M:%S')

⚡ This was a fast scan - consider running a deep scan."

    echo "⚠️  WARNING: $INFECTED_COUNT infected file(s) found!"
    echo "See $INFECTED_LOG for details"

    # Send alert with infected files list
    send_telegram_message "$SUMMARY_MESSAGE"

    # Send infected files log
    if [ -f "$INFECTED_LOG" ]; then
        send_telegram_file "$INFECTED_LOG" "Infected files found in fast scan on $HOSTNAME"
    fi
else
    SUMMARY_MESSAGE="✅ <b>ClamAV Fast Scan Complete - Clean</b>

Host: $HOSTNAME
Scan Type: Fast Scan (critical directories)
Duration: ${SCAN_DURATION_MIN} minutes

📊 <b>Results:</b>
Files Scanned: $SCANNED_FILES
Directories Scanned: $SCANNED_DIRS
✅ No threats detected

Time: $(date '+%Y-%m-%d %H:%M:%S')

⚡ Fast scan mode - excludes caches and build artifacts"

    echo "✅ No infected files found"

    # Send clean report
    send_telegram_message "$SUMMARY_MESSAGE"
fi

# Clean up old logs (keep last 30 days)
echo ""
echo "Cleaning up old log files..."
find "$LOG_DIR" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
echo "✅ Old logs cleaned up (kept last 30 days)"

echo ""
echo "=========================================="
echo "Fast scan completed at: $(date)"
echo "=========================================="

exit 0
