#!/bin/bash
# powerManagement.sh - General power management disable script for server/always-on devices
# Supports Arch, Debian/Ubuntu, and Fedora-based systems
# This is a general version that works on any device, not just Microsoft Surface

# Exit on error
set -e

echo "=== Disabling all power saving features for server operation ==="

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "❌ Cannot detect distribution: /etc/os-release not found."
    exit 1
fi

DISTRO_ID="${ID_LIKE:-$ID}"

# 1. Mask all sleep/suspend/hibernate targets
echo "➡️  Masking sleep/suspend/hibernate targets..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
echo "✅ Sleep targets masked"

# 2. Install required packages based on distribution (minimal for servers)
echo "➡️  Installing required packages..."

case "$DISTRO_ID" in
    *arch*)
        sudo pacman -S --noconfirm --needed iw lm_sensors
        ;;
    *debian* | *ubuntu*)
        sudo apt update
        sudo apt install -y wireless-tools iw lm-sensors
        ;;
    *fedora*)
        sudo dnf install -y iw lm_sensors
        ;;
    *)
        echo "⚠️  Unsupported distribution: $ID. Attempting to continue with basic setup..."
        ;;
esac

# 3. Disable WiFi power save (if WiFi interface exists)
echo "➡️  Disabling WiFi power save..."
# Detect WiFi interface name (wlan0, wlp*, etc.)
WIFI_INTERFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
if [ -n "$WIFI_INTERFACE" ]; then
    sudo iw dev "$WIFI_INTERFACE" set power_save off 2>/dev/null && echo "✅ WiFi power save disabled on $WIFI_INTERFACE" || echo "⚠️  Could not disable WiFi power save"

    # Force network adapter to stay on (the "on" value means always powered)
    if [ -e "/sys/class/net/$WIFI_INTERFACE/device/power/control" ]; then
        echo 'on' | sudo tee /sys/class/net/$WIFI_INTERFACE/device/power/control > /dev/null
        echo "✅ Network adapter set to always on"
    fi
else
    echo "⚠️  No WiFi interface found. Skipping WiFi power save configuration."
fi

# 4. Disable Ethernet power management (if Ethernet interface exists)
echo "➡️  Disabling Ethernet power management..."
ETH_INTERFACE=$(ip link show | awk -F: '/^[0-9]+: e/ {print $2; exit}' | tr -d ' ')
if [ -n "$ETH_INTERFACE" ]; then
    if command -v ethtool &> /dev/null; then
        sudo ethtool -s "$ETH_INTERFACE" wol d 2>/dev/null || echo "⚠️  Could not configure WoL on $ETH_INTERFACE"
        echo "✅ Ethernet power management configured on $ETH_INTERFACE"
    fi

    # Disable power management for Ethernet
    if [ -e "/sys/class/net/$ETH_INTERFACE/device/power/control" ]; then
        echo 'on' | sudo tee /sys/class/net/$ETH_INTERFACE/device/power/control > /dev/null
        echo "✅ Ethernet adapter set to always on"
    fi
else
    echo "⚠️  No Ethernet interface found. Skipping Ethernet power management."
fi

# 5. Disable USB autosuspend immediately
echo "➡️  Disabling USB autosuspend..."
echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend > /dev/null
echo "✅ USB autosuspend disabled"

# 6. Make USB autosuspend persistent across reboots
echo 'options usbcore autosuspend=-1' | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf > /dev/null
echo "✅ USB autosuspend configuration persisted"

# 7. Create systemd service to disable WiFi power save on boot
if [ -n "$WIFI_INTERFACE" ]; then
    echo "➡️  Creating systemd service for WiFi power save..."
    sudo tee /etc/systemd/system/disable-wifi-powersave.service > /dev/null <<'EOF'
[Unit]
Description=Disable WiFi Power Save
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'WIFI_IF=$(iw dev 2>/dev/null | awk "$1==\"Interface\"{print $2; exit}"); [ -n "$WIFI_IF" ] && iw dev $WIFI_IF set power_save off'

[Install]
WantedBy=multi-user.target
EOF
    echo "✅ WiFi power save service created"
fi

# 8. Configure logind to ignore idle (keep lid switch handling for servers without displays)
echo "➡️  Configuring systemd-logind..."
sudo sed -i 's/#IdleAction=.*/IdleAction=ignore/' /etc/systemd/logind.conf
echo "✅ Logind configured to ignore idle"

# 9. Enable and start services
echo "➡️  Enabling and starting services..."
sudo systemctl daemon-reload

if [ -n "$WIFI_INTERFACE" ]; then
    sudo systemctl enable disable-wifi-powersave.service 2>/dev/null
    sudo systemctl start disable-wifi-powersave.service 2>/dev/null || echo "⚠️  WiFi power save service couldn't start (may need reboot)"
fi

sudo systemctl restart systemd-logind
echo "✅ Services configured and started"

# 10. Detect sensors (auto-answer yes to all prompts)
echo "➡️  Detecting hardware sensors..."
if command -v sensors-detect &> /dev/null; then
    sudo sensors-detect --auto 2>/dev/null || echo "⚠️  Sensor detection skipped or unavailable"
else
    echo "⚠️  sensors-detect not available"
fi

# 11. Disable CPU frequency scaling (optional - comment out if not needed)
# This keeps CPU at full performance but generates more heat and power consumption
# Uncomment the following line to enable:
# echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

echo ""
echo "=== Setup complete! ==="
echo ""
echo "=== Verification ==="

# Verify all settings
echo "➡️  Verifying configuration..."
echo ""

echo "Sleep targets (should show 'masked'):"
systemctl status sleep.target 2>/dev/null | grep -i masked || echo "⚠️  Could not verify sleep target status"

if [ -n "$WIFI_INTERFACE" ]; then
    echo ""
    echo "WiFi power save on $WIFI_INTERFACE (should show 'off'):"
    iw dev "$WIFI_INTERFACE" get power_save 2>/dev/null || echo "⚠️  Could not verify WiFi power save"

    echo ""
    echo "WiFi adapter power (should show 'on'):"
    cat "/sys/class/net/$WIFI_INTERFACE/device/power/control" 2>/dev/null || echo "⚠️  Could not verify network adapter power"
fi

if [ -n "$ETH_INTERFACE" ]; then
    echo ""
    echo "Ethernet adapter power (should show 'on'):"
    cat "/sys/class/net/$ETH_INTERFACE/device/power/control" 2>/dev/null || echo "⚠️  Could not verify Ethernet adapter power"
fi

echo ""
echo "USB autosuspend (should show '-1'):"
cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null || echo "⚠️  Could not verify USB autosuspend"

echo ""
echo "CPU temperatures:"
sensors 2>/dev/null | grep -E "Core|Package|temp" || echo "⚠️  Sensors not available yet (may need reboot)"

echo ""
echo "=== All done! Device will now stay online 24/7 ==="
echo "⚠️  Reboot recommended for all changes to take effect"
