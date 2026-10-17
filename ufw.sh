#!/bin/bash
#
# This script configures UFW to work securely with Docker and NetBird.
#
# 1. Sets default policies: deny incoming, allow outgoing.
# 2. Allows SSH to prevent accidental lockout.
# 3. Allows all traffic on the 'wt0' interface.
# 4. Idempotently adds the 'ufw-docker' fix to /etc/ufw/after.rules.
# 5. Reloads and enables UFW.
#

set -e # Exit immediately if any command fails

echo "🚀 Starting UFW configuration for NetBird and Docker..."

# --- 1. Set Default Policies ---
echo "[1/5] Setting default policies (deny incoming, allow outgoing)..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
# --- 2. Allow Essential & NetBird Traffic ---
echo "[2/5] Allowing SSH and NetBird..."
sudo ufw allow ssh comment 'Allow SSH connections'
sudo ufw allow in on wt0 comment 'Allow all traffic from NetBird tailnet'

# --- 3. Apply Docker Fix ---
echo "[3/5] Applying ufw-docker fix..."

# Define the rules to be added, including the markers
DOCKER_RULES=$(cat <<'EOF'

# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

-A DOCKER-USER -p udp -m udp --sport 53 --dport 1024:65535 -j RETURN

-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 172.16.0.0/12

-A DOCKER-USER -j RETURN

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF
)

# Check if the rules are already in /etc/ufw/after.rules
if ! grep -q "# BEGIN UFW AND DOCKER" /etc/ufw/after.rules; then
    echo "Adding Docker rules to /etc/ufw/after.rules..."
    # Append the rules to the end of the file
    echo "$DOCKER_RULES" | sudo tee -a /etc/ufw/after.rules > /dev/null
else
    echo "Docker rules already found in /etc/ufw/after.rules. Skipping."
fi

# --- 4. (Optional) Allow Specific LAN Access ---
echo "[4/5] Skipping optional LAN rules. (Edit this script to enable)"
#
# Uncomment and customize the line below if you need to access
# a specific port from your local network (e.g., 192.168.1.0/24).
#
# sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp comment 'Allow Port 8080 from LAN'


# --- 5. Enable and Show Status ---
echo "[5/5] Reloading and enabling UFW..."
sudo ufw reload # Apply changes if UFW is already active
sudo ufw --force enable # Enable UFW (non-interactive)

echo -e "\n✅ UFW configuration complete!"
echo "Current status:"
sudo ufw status verbose
