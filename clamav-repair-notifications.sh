#!/bin/bash
#
# ClamAV Notification Repair Script
# Re-parses old scan logs and sends corrected notifications
#

# --- Configuration ---
set -euo pipefail

LOG_DIR="${LOG_DIR:-$HOME/.clamav-logs}"
ENV_FILE="${HOME}/.clamav-telegram.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: $ENV_FILE not found"
    exit 1
fi

# Load environment variables
# shellcheck source=/dev/null
source "$ENV_FILE"

# Validate credentials
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    echo "❌ Error: Telegram credentials not set"
    exit 1
fi

# --- Helper Functions ---

send_telegram_message() {
    local message="$1"
    local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

    curl -s -X POST "$api_url" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="HTML" > /dev/null 2>&1
}

# Get hostname reliably
HOSTNAME=$(hostname -f 2>/dev/null || hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown")

# --- Main Script ---

echo "=========================================="
echo "ClamAV Notification Repair Script"
echo "=========================================="
echo "Host: $HOSTNAME"
echo "Log directory: $LOG_DIR"
echo ""

# Find recent scan logs
echo "Looking for recent scan logs..."
SCAN_LOGS=$(find "$LOG_DIR" -name "scan_*.log" -o -name "fast_scan_*.log" 2>/dev/null | sort -r | head -10)

if [ -z "$SCAN_LOGS" ]; then
    echo "❌ No scan logs found in $LOG_DIR"
    exit 1
fi

echo "Found $(echo "$SCAN_LOGS" | wc -l) recent scan logs"
echo ""

# Process each log
for log_file in $SCAN_LOGS; do
    echo "----------------------------------------"
    echo "Processing: $(basename "$log_file")"

    # Determine scan type
    if [[ "$log_file" == *"fast_scan"* ]]; then
        SCAN_TYPE="Fast Scan"
        SCAN_ICON="⚡"
    else
        SCAN_TYPE="Deep Scan"
        SCAN_ICON="🔍"
    fi

    # Extract timestamp from filename
    SCAN_TIMESTAMP=$(basename "$log_file" | grep -oP '\d{8}_\d{6}' || echo "unknown")
    if [ "$SCAN_TIMESTAMP" != "unknown" ]; then
        SCAN_DATE=$(echo "$SCAN_TIMESTAMP" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
    else
        SCAN_DATE=$(stat -c %y "$log_file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || echo "unknown")
    fi

    # Parse the log file
    INFECTED_COUNT=$(grep -c "FOUND" "$log_file" 2>/dev/null || echo "0")

    # Try multiple parsing methods
    SCANNED_FILES=$(grep "Scanned files:" "$log_file" | tail -1 | awk '{print $3}' 2>/dev/null)
    if [ -z "$SCANNED_FILES" ]; then
        SCANNED_FILES=$(grep -oP "Scanned files: \K\d+" "$log_file" | tail -1 2>/dev/null || echo "0")
    fi
    [ -z "$SCANNED_FILES" ] && SCANNED_FILES="0"

    SCANNED_DIRS=$(grep "Scanned directories:" "$log_file" | tail -1 | awk '{print $3}' 2>/dev/null)
    if [ -z "$SCANNED_DIRS" ]; then
        SCANNED_DIRS=$(grep -oP "Scanned directories: \K\d+" "$log_file" | tail -1 2>/dev/null || echo "0")
    fi
    [ -z "$SCANNED_DIRS" ] && SCANNED_DIRS="0"

    # Calculate duration if possible
    if grep -q "Elapsed time:" "$log_file" 2>/dev/null; then
        DURATION=$(grep "Elapsed time:" "$log_file" | tail -1 | awk '{print $3, $4}')
    else
        DURATION="Unknown"
    fi

    echo "  Scan type: $SCAN_TYPE"
    echo "  Date: $SCAN_DATE"
    echo "  Files scanned: $SCANNED_FILES"
    echo "  Directories scanned: $SCANNED_DIRS"
    echo "  Infected: $INFECTED_COUNT"
    echo "  Duration: $DURATION"

    # Check if this scan had unknown data
    if [ "$SCANNED_FILES" == "0" ] && [ "$SCANNED_DIRS" == "0" ]; then
        echo "  ⚠️  This scan has incomplete data - cannot repair"
        continue
    fi

    echo ""
    read -p "  Send corrected notification for this scan? (y/N): " send_notif

    if [[ "$send_notif" =~ ^[Yy]$ ]]; then
        if [ "$INFECTED_COUNT" -gt 0 ]; then
            MESSAGE="$SCAN_ICON <b>$SCAN_TYPE - CORRECTED REPORT</b>
🚨 <b>THREATS FOUND</b>

Host: $HOSTNAME
Scan Date: $SCAN_DATE

📊 <b>Corrected Results:</b>
Files Scanned: $SCANNED_FILES
Directories Scanned: $SCANNED_DIRS
⚠️ <b>Infected Files: $INFECTED_COUNT</b>

Duration: $DURATION

ℹ️ This is a corrected notification for a previous scan"
        else
            MESSAGE="$SCAN_ICON <b>$SCAN_TYPE - CORRECTED REPORT</b>
✅ <b>Clean</b>

Host: $HOSTNAME
Scan Date: $SCAN_DATE

📊 <b>Corrected Results:</b>
Files Scanned: $SCANNED_FILES
Directories Scanned: $SCANNED_DIRS
✅ No threats detected

Duration: $DURATION

ℹ️ This is a corrected notification for a previous scan"
        fi

        if send_telegram_message "$MESSAGE"; then
            echo "  ✅ Corrected notification sent!"
        else
            echo "  ❌ Failed to send notification"
        fi
    else
        echo "  Skipped"
    fi
    echo ""
done

echo "=========================================="
echo "Repair complete!"
echo "=========================================="
