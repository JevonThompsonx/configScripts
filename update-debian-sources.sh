#!/bin/bash

# File paths
SOURCES_FILE="/etc/apt/sources.list"
BACKUP_FILE="/etc/apt/sources.list.bak"

# Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root (e.g., sudo ./upgrade-sources.sh)"
  exit 1
fi

# Check if sources.list exists
if [[ ! -f "$SOURCES_FILE" ]]; then
  echo "Error: $SOURCES_FILE not found."
  exit 1
fi

# Backup the original sources.list
cp "$SOURCES_FILE" "$BACKUP_FILE"
echo "Backup created at $BACKUP_FILE"

# Replace 'bookworm' with 'trixie'
sed -i 's/bookworm/trixie/g' "$SOURCES_FILE"
echo "Replaced all instances of 'bookworm' with 'trixie' in $SOURCES_FILE"
