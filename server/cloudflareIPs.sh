#!/bin/bash

# --- UFW Cloudflare Whitelist Script ---
# This script interactively adds UFW rules to allow traffic from Cloudflare's
# IP ranges to a user-specified port.

# Arrays of Cloudflare's official IP ranges
CLOUDFLARE_IPV4=(
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
)

CLOUDFLARE_IPV6=(
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
)

# Main loop to continuously ask for ports
while true; do
    # Prompt the user for a port number or to quit
    read -p "Enter the port number to open (e.g., 8096), or type 'q' to quit: " PORT

    # Exit condition
    if [[ "$PORT" == "q" || "$PORT" == "quit" ]]; then
        echo "Exiting script."
        break
    fi

    # Check for valid port number format (1-65535)
    if ! [[ "$PORT" =~ ^[1-9][0-9]*$ && "$PORT" -le 65535 ]]; then
        echo "⚠️ Invalid input. Please enter a valid port number."
        echo
        continue
    fi

    echo "--------------------------------------------------"
    echo "⚙️  Adding UFW rules for port $PORT..."
    echo "--------------------------------------------------"

    # Loop through and add rules for all IPv4 ranges
    for ip in "${CLOUDFLARE_IPV4[@]}"; do
        sudo ufw allow from "$ip" to any port "$PORT" proto tcp
    done

    # Loop through and add rules for all IPv6 ranges
    for ip in "${CLOUDFLARE_IPV6[@]}"; do
        sudo ufw allow from "$ip" to any port "$PORT" proto tcp
    done

    echo "--------------------------------------------------"
    echo "✅ Successfully added all Cloudflare rules for port $PORT."
    echo "--------------------------------------------------"
    echo
done

echo
echo "All tasks complete! Don't forget to apply your changes by reloading UFW:"
echo "sudo ufw reload"
