#!/bin/bash
# surfacePowerManagement.sh - Complete power management disable script for Surface devices
# Supports Arch, Debian/Ubuntu, and Fedora-based systems

# Exit on error
set -e

echo "=== Disabling all power saving features for Surface device ==="

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

# 2. Install required packages based on distribution
echo "➡️  Installing required packages..."

case "$DISTRO_ID" in
    *arch*)
        sudo pacman -S --noconfirm --needed iw thermald lm_sensors cpupower
        ;;
    *debian* | *ubuntu*)
        sudo apt update
        sudo apt install -y wireless-tools iw thermald lm-sensors linux-cpupower
        ;;
    *fedora*)
        sudo dnf install -y iw thermald lm_sensors kernel-tools
        ;;
    *)
        echo "⚠️  Unsupported distribution: $ID. Attempting to continue with basic setup..."
        ;;
esac

# 3. Disable WiFi power save
echo "➡️  Disabling WiFi power save..."
# Detect WiFi interface name (wlan0, wlp*, etc.)
WIFI_INTERFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')
if [ -n "$WIFI_INTERFACE" ]; then
    sudo iw dev "$WIFI_INTERFACE" set power_save off
    echo "✅ WiFi power save disabled on $WIFI_INTERFACE"
else
    echo "⚠️  No WiFi interface found. Skipping WiFi power save configuration."
fi

# 4. Force network adapter to stay on (the "on" value means always powered)
if [ -n "$WIFI_INTERFACE" ] && [ -e "/sys/class/net/$WIFI_INTERFACE/device/power/control" ]; then
    echo 'on' | sudo tee /sys/class/net/$WIFI_INTERFACE/device/power/control > /dev/null
    echo "✅ Network adapter set to always on"
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
    sudo tee /etc/systemd/system/disable-wifi-powersave.service > /dev/null <<EOF
[Unit]
Description=Disable WiFi Power Save
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'WIFI_IF=\$(iw dev | awk "\$1==\\"Interface\\"{print \$2; exit}"); [ -n "\$WIFI_IF" ] && iw dev \$WIFI_IF set power_save off'

[Install]
WantedBy=multi-user.target
EOF
    echo "✅ WiFi power save service created"
fi

# 8. Configure logind to ignore lid switches and idle
echo "➡️  Configuring systemd-logind to ignore lid switches..."
sudo sed -i 's/#HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#IdleAction=.*/IdleAction=ignore/' /etc/systemd/logind.conf
echo "✅ Logind configured to ignore lid switches"

# 9. Enable and start services
echo "➡️  Enabling and starting services..."
sudo systemctl daemon-reload

if [ -n "$WIFI_INTERFACE" ]; then
    sudo systemctl enable disable-wifi-powersave.service
    sudo systemctl start disable-wifi-powersave.service 2>/dev/null || echo "⚠️  WiFi power save service couldn't start (may need reboot)"
fi

sudo systemctl enable thermald 2>/dev/null || echo "⚠️  thermald not available"
sudo systemctl start thermald 2>/dev/null || echo "⚠️  thermald not started"

# lm_sensors doesn't have a systemd service on all distros
if systemctl list-unit-files | grep -q lm_sensors; then
    sudo systemctl enable lm_sensors
    sudo systemctl start lm_sensors
fi

sudo systemctl restart systemd-logind
echo "✅ Services configured and started"

# 10. Detect sensors (auto-answer yes to all prompts)
echo "➡️  Detecting hardware sensors..."
sudo sensors-detect --auto 2>/dev/null || echo "⚠️  Sensor detection skipped or unavailable"

# 11. Set CPU governor to performance (optional - generates more heat)
# echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

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
    echo "Network adapter power (should show 'on'):"
    cat "/sys/class/net/$WIFI_INTERFACE/device/power/control" 2>/dev/null || echo "⚠️  Could not verify network adapter power"
fi

echo ""
echo "USB autosuspend (should show '-1'):"
cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null || echo "⚠️  Could not verify USB autosuspend"

echo ""
echo "CPU temperatures:"
sensors 2>/dev/null | grep -E "Core|Package" || echo "⚠️  Sensors not available yet (may need reboot)"

echo ""
echo "=== All done! Surface device will now stay online 24/7 ==="
echo "⚠️  Reboot recommended for all changes to take effect"
