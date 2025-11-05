#!/bin/bash
#
# Setup Passwordless Sudo for ClamAV
# Allows automated cronjob execution without password prompts
#

set -euo pipefail

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Don't run this script as root. It will use sudo when needed."
    exit 1
fi

echo "=========================================="
echo "ClamAV Passwordless Sudo Setup"
echo "=========================================="
echo ""
echo "This script will configure sudo to allow passwordless execution of:"
echo "  - clamscan (virus scanning)"
echo "  - freshclam (database updates)"
echo ""
echo "This is necessary for automated cronjobs to run without password prompts."
echo ""
read -p "Continue? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Get current user
CURRENT_USER="$USER"
SUDOERS_FILE="/etc/sudoers.d/clamav-${CURRENT_USER}"

echo ""
echo "Creating sudoers configuration..."
echo "File: $SUDOERS_FILE"

# Find clamscan and freshclam paths
CLAMSCAN_PATH=$(which clamscan 2>/dev/null || echo "/usr/bin/clamscan")
FRESHCLAM_PATH=$(which freshclam 2>/dev/null || echo "/usr/bin/freshclam")

echo "  clamscan path: $CLAMSCAN_PATH"
echo "  freshclam path: $FRESHCLAM_PATH"

# Create the sudoers content
SUDOERS_CONTENT="# ClamAV passwordless sudo for user: $CURRENT_USER
# Created by setup-clamav-sudo.sh on $(date)
# Allows automated virus scanning via cronjobs

# Allow clamscan without password
$CURRENT_USER ALL=(root) NOPASSWD: $CLAMSCAN_PATH

# Allow freshclam without password
$CURRENT_USER ALL=(root) NOPASSWD: $FRESHCLAM_PATH
"

# Create temporary file
TEMP_FILE=$(mktemp)
echo "$SUDOERS_CONTENT" > "$TEMP_FILE"

# Validate the sudoers syntax
echo ""
echo "Validating sudoers syntax..."
if sudo visudo -cf "$TEMP_FILE"; then
    echo "✅ Syntax is valid"
else
    echo "❌ Syntax validation failed. Aborting."
    rm "$TEMP_FILE"
    exit 1
fi

# Install the sudoers file
echo ""
echo "Installing sudoers configuration..."
if sudo cp "$TEMP_FILE" "$SUDOERS_FILE"; then
    sudo chmod 0440 "$SUDOERS_FILE"
    echo "✅ Sudoers file installed: $SUDOERS_FILE"
else
    echo "❌ Failed to install sudoers file"
    rm "$TEMP_FILE"
    exit 1
fi

# Clean up temp file
rm "$TEMP_FILE"

# Test the configuration
echo ""
echo "Testing passwordless sudo..."
echo "Running: sudo clamscan --version"

if sudo -n clamscan --version &> /dev/null; then
    echo "✅ Passwordless sudo is working!"
else
    echo "⚠️  Test failed, but configuration should work after you log out and back in"
fi

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "ClamAV can now run without password prompts for user: $CURRENT_USER"
echo ""
echo "Configured commands:"
echo "  sudo clamscan (any arguments)"
echo "  sudo freshclam"
echo ""
echo "To remove this configuration later:"
echo "  sudo rm $SUDOERS_FILE"
echo ""
