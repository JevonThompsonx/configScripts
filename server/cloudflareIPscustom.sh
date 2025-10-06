#!/bin/bash

# --- UFW Cloudflare Whitelist Script for All Services ---
# This script adds UFW rules to allow traffic from Cloudflare's IP ranges
# to a predefined list of TCP and UDP ports.

# Arrays of Cloudflare's official IP ranges
CLOUDFLARE_IPV4=(
    "173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22" "103.31.4.0/22"
    "141.101.64.0/18" "108.162.192.0/18" "190.93.240.0/20" "188.114.96.0/20"
    "197.234.240.0/22" "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/13"
    "104.24.0.0/14" "172.64.0.0/13" "131.0.72.0/22"
)

CLOUDFLARE_IPV6=(
    "2400:cb00::/32" "2606:4700::/32" "2803:f800::/32" "2405:b500::/32"
    "2405:8100::/32" "2a06:98c0::/29" "2c0f:f248::/32"
)

# Your specific list of TCP ports
TCP_PORTS=(
    3000 9983 61208 9999 8096 8920 8989 7878 6767 9696 8787 8788
    6789 5055 8265 8266 13378 5000 8090 8484 8585 2283
)

# Your specific list of UDP ports (UFW handles the comma-separated format)
UDP_PORTS=(
    "1900,7359"
)

echo "--- Adding TCP rules for Cloudflare ---"
for port in "${TCP_PORTS[@]}"; do
    echo "⚙️  Processing rules for TCP port $port..."
    for ip in "${CLOUDFLARE_IPV4[@]}"; do
        sudo ufw allow from "$ip" to any port "$port" proto tcp comment 'Cloudflare Access'
    done
    for ip in "${CLOUDFLARE_IPV6[@]}"; do
        sudo ufw allow from "$ip" to any port "$port" proto tcp comment 'Cloudflare Access'
    done
done

echo "--- Adding UDP rules for Cloudflare ---"
for port in "${UDP_PORTS[@]}"; do
    echo "⚙️  Processing rules for UDP port(s) $port..."
    for ip in "${CLOUDFLARE_IPV4[@]}"; do
        sudo ufw allow from "$ip" to any port "$port" proto udp comment 'Cloudflare Access'
    done
    for ip in "${CLOUDFLARE_IPV6[@]}"; do
        sudo ufw allow from "$ip" to any port "$port" proto udp comment 'Cloudflare Access'
    done
done

echo
echo "✅ All done! Don't forget to apply all your new changes by reloading UFW:"
echo "sudo ufw reload"
