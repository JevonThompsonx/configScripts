#!/usr/bin/env bash
#
# Uninstall unwanted apps across Arch, Debian/Ubuntu, Fedora, and Alpine Linux
#

# Detect distro
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID_LIKE:-$ID}"
else
    echo "⚠️  Cannot detect distribution. Skipping package uninstallation."
    DISTRO_ID="unknown"
fi

# Remove packages gracefully — skips any that aren't installed
remove_packages() {
    local packages=("$@")
    echo "==> Removing packages: ${packages[*]}"
    case "$DISTRO_ID" in
    *arch*)
        if command -v yay &>/dev/null; then
            yay -Rns --noconfirm "${packages[@]}" 2>/dev/null || true
        else
            sudo pacman -Rns --noconfirm "${packages[@]}" 2>/dev/null || true
        fi
        ;;
    *debian* | *ubuntu*)
        sudo apt remove --purge -y "${packages[@]}" 2>/dev/null || true
        ;;
    *fedora*)
        sudo dnf remove -y "${packages[@]}" 2>/dev/null || true
        ;;
    *alpine*)
        sudo apk del "${packages[@]}" 2>/dev/null || true
        ;;
    *)
        echo "⚠️  Unknown distro ($DISTRO_ID). Skipping package removal."
        ;;
    esac
}

# --- Package Removal ---

# Packages available (or previously installed) across distros
remove_packages gnumeric lollypop xournalpp

# signal-desktop: AUR on Arch, snap on Debian/Ubuntu, not in Fedora/Alpine official repos
case "$DISTRO_ID" in
*arch*)
    remove_packages signal-desktop typora 1password-beta aether
    ;;
*debian* | *ubuntu*)
    remove_packages signal-desktop typora
    # Also attempt snap removal if snap is present
    if command -v snap &>/dev/null; then
        sudo snap remove signal-desktop 2>/dev/null || true
    fi
    ;;
*fedora*)
    # signal/typora may be installed as Flatpaks on Fedora
    if command -v flatpak &>/dev/null; then
        flatpak uninstall -y org.signal.Signal 2>/dev/null || true
    fi
    remove_packages signal-desktop typora
    ;;
*alpine*)
    remove_packages signal-desktop
    ;;
esac

# --- Desktop File Cleanup (distro-agnostic) ---

echo "==> Removing leftover desktop entries and icons..."

desktop_files=(
    Basecamp.desktop
    "chrome-kibeaohagkkgcegdppfkjbpcfjhikide-Default.desktop"
    ChatGPT.desktop
    Discord.desktop
    GitHub.desktop
    "Google Contacts.desktop"
    "Google Keep.desktop"
    "Google Maps.desktop"
    "Google Messages.desktop"
    "Google Photos.desktop"
    aether-protocol-handler.desktop
    Figma.desktop
    Fizzy.desktop
    HEY.desktop
    Proton-Docs.desktop
    "Proton Mail.desktop"
    signal-desktop.desktop
    typora.desktop
    dev.zed.Zed.desktop
    WhatsApp.desktop
    X.desktop
    YouTube.desktop
    Zoom.desktop
)

for entry in "${desktop_files[@]}"; do
    rm -f "$HOME/.local/share/applications/$entry"
done

icon_files=(
    Basecamp.png
    ChatGPT.png
    Discord.png
    GitHub.png
    "Google Contacts.png"
    "Google Maps.png"
    "Google Messages.png"
    "Google-Messages.png"
    "Google Photos.png"
    Figma.png
    Fizzy.png
    HEY.png
    Proton-Mail.png
    zed.png
    WhatsApp.png
    X.png
    YouTube.png
    Zoom.png
)

for icon in "${icon_files[@]}"; do
    rm -f "$HOME/.local/share/applications/icons/$icon"
done

# Chromium web app leftover
rm -rf "$HOME/.config/chromium/Default/Web Applications/Manifest Resources/kibeaohagkkgcegdppfkjbpcfjhikide"

# --- Post-cleanup ---

echo "==> Refreshing desktop database..."
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# Only restart walker if present (Omarchy/Arch specific)
if command -v omarchy-restart-walker &>/dev/null; then
    echo "==> Restarting walker..."
    omarchy-restart-walker
fi

echo "✅ Uninstall complete."
