#!/bin/bash
#
# ClamAV Scan Script with Telegram Notifications
# This script updates ClamAV virus definitions, scans the system,
# and sends a report via Telegram bot.
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
    echo ""
    echo "With the following content:"
    echo "TELEGRAM_BOT_TOKEN=your_bot_token_here"
    echo "TELEGRAM_CHAT_ID=your_chat_id_here"
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
SCAN_DIR="${SCAN_DIR:-/home}"  # Default to /home, can be overridden in .env
LOG_DIR="${LOG_DIR:-$HOME/.clamav-logs}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCAN_LOG="$LOG_DIR/scan_$TIMESTAMP.log"
INFECTED_LOG="$LOG_DIR/infected_$TIMESTAMP.log"

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
echo "ClamAV Scan with Telegram Notifications"
echo "=========================================="
echo "Started at: $(date)"
echo ""

# Send start notification
send_telegram_message "🔍 <b>ClamAV Scan Started</b>
Host: $(hostname)
Scan Directory: $SCAN_DIR
Time: $(date '+%Y-%m-%d %H:%M:%S')"

# Update ClamAV virus database
echo "Updating ClamAV virus database..."
if sudo freshclam > "$LOG_DIR/freshclam_$TIMESTAMP.log" 2>&1; then
    echo "✅ Virus database updated successfully"
    send_telegram_message "✅ Virus database updated on $(hostname)"
else
    echo "⚠️  Warning: freshclam update failed (might be too soon since last update)"
    echo "Continuing with scan anyway..."
fi

# Run ClamAV scan
echo ""
echo "Starting ClamAV scan of $SCAN_DIR..."
echo "This may take a while depending on the size of the directory."
echo "Scan log: $SCAN_LOG"
echo ""

# Run clamscan with options:
# -r: recursive
# -i: only print infected files
# --exclude-dir: exclude certain directories to speed up scan
# -l: log file
SCAN_START_TIME=$(date +%s)

if sudo clamscan -r -i \
    --exclude-dir="^/sys" \
    --exclude-dir="^/dev" \
    --exclude-dir="^/proc" \
    --exclude-dir="^/run" \
    -l "$SCAN_LOG" \
    "$SCAN_DIR" 2>&1 | tee -a "$SCAN_LOG"; then
    SCAN_EXIT_CODE=0
else
    SCAN_EXIT_CODE=$?
fi

SCAN_END_TIME=$(date +%s)
SCAN_DURATION=$((SCAN_END_TIME - SCAN_START_TIME))
SCAN_DURATION_MIN=$((SCAN_DURATION / 60))

echo ""
echo "Scan completed in ${SCAN_DURATION_MIN} minutes"

# Parse scan results
INFECTED_COUNT=$(grep -c "FOUND" "$SCAN_LOG" || true)
SCANNED_FILES=$(grep "Scanned files:" "$SCAN_LOG" | awk '{print $3}' || echo "Unknown")
SCANNED_DIRS=$(grep "Scanned directories:" "$SCAN_LOG" | awk '{print $3}' || echo "Unknown")

# Extract infected files if any
if [ "$INFECTED_COUNT" -gt 0 ]; then
    grep "FOUND" "$SCAN_LOG" > "$INFECTED_LOG"
fi

# Prepare summary message
if [ "$INFECTED_COUNT" -gt 0 ]; then
    SUMMARY_MESSAGE="🚨 <b>ClamAV Scan Complete - THREATS FOUND</b>

Host: $(hostname)
Scan Directory: $SCAN_DIR
Duration: ${SCAN_DURATION_MIN} minutes

📊 <b>Results:</b>
Files Scanned: $SCANNED_FILES
Directories Scanned: $SCANNED_DIRS
⚠️ <b>Infected Files: $INFECTED_COUNT</b>

Time: $(date '+%Y-%m-%d %H:%M:%S')

Check the attached log for details."

    echo "⚠️  WARNING: $INFECTED_COUNT infected file(s) found!"
    echo "See $INFECTED_LOG for details"

    # Send alert with infected files list
    send_telegram_message "$SUMMARY_MESSAGE"

    # Send infected files log
    if [ -f "$INFECTED_LOG" ]; then
        send_telegram_file "$INFECTED_LOG" "Infected files on $(hostname)"
    fi
else
    SUMMARY_MESSAGE="✅ <b>ClamAV Scan Complete - System Clean</b>

Host: $(hostname)
Scan Directory: $SCAN_DIR
Duration: ${SCAN_DURATION_MIN} minutes

📊 <b>Results:</b>
Files Scanned: $SCANNED_FILES
Directories Scanned: $SCANNED_DIRS
✅ No threats detected

Time: $(date '+%Y-%m-%d %H:%M:%S')"

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
echo "Scan completed at: $(date)"
echo "=========================================="

exit $SCAN_EXIT_CODE
