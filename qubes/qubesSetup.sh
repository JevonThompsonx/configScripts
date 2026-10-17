#!/usr/bin/env bash

# Qubes OS qube setup. Interactive, idempotent. Run inside a template or app qube.
# Profiles: template (all apps), personal (zen + brave), docs (seafile + libreoffice + obsidian),
#           media (chromium). Qubes do not get terminal tooling; fish + yay/paru are installed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

_incoming_profile=${PROFILE:-}
_incoming_desktop=${DESKTOP:-}
# Reuse common helpers when available.
if [[ -r "$ROOT/lib/common.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
else
  log() { printf '[qubes] %s\n' "$*"; }
  warn() { printf '[warning] %s\n' "$*" >&2; }
  die() { printf '[error] %s\n' "$*" >&2; }
  confirm() { local a; read -r -p "$1 [y/N] " a; [[ $a == y || $a == Y || $a == yes || $a == YES ]]; }
  run() { if (( DRY_RUN )); then printf '[dry-run]'; printf ' %q' "$@"; printf '\n'; return 0; fi; "$@"; }
fi

PROFILE="${PROFILE:-}"
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"
DRY_RUN="${DRY_RUN:-0}"
QUBES_TRIM="${QUBES_TRIM:-1}"

parse_args() {
  while (($#)); do
    case "$1" in
      --profile) PROFILE=$2; shift 2 ;;
      --non-interactive) NON_INTERACTIVE=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --no-trim) QUBES_TRIM=0; shift ;;
      --help) echo "Usage: qubesSetup.sh [--profile template|personal|docs|media] [--non-interactive] [--dry-run] [--no-trim] [--list-profiles]"; return 2 ;;
      --list-profiles)
        echo "Available qube profiles:"
        echo "  template  - install everything (ready for any distro line)"
        echo "  personal  - zen browser + brave browser"
        echo "  docs      - seafile + libreoffice + obsidian"
        echo "  media     - chromium browser"
        return 2 ;;
      --target) shift 2 ;;
      --qubes) shift ;;
      --desktop) shift 2 ;;
      --profile) PROFILE=$2; shift 2 ;;
      --fleet|--ai-tools|--private-configs|--skip-configs|--configs-only) shift ;;
      --non-interactive) NON_INTERACTIVE=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      *) warn "Ignoring option: $1"; shift ;;
    esac
  done
}

detect_platform() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    local ancestry=" ${ID,,} ${ID_LIKE,,} "
    case "$ancestry" in
      *" omarchy "*|*" arch "*) DISTRO_FAMILY=pacman ;;
      *" debian "*|*" ubuntu "*) DISTRO_FAMILY=apt ;;
      *" fedora "*|*" rhel "*|*" centos "*) DISTRO_FAMILY=dnf ;;
      *" opensuse "*|*" suse "*) DISTRO_FAMILY=zypper ;;
      *" alpine "*) DISTRO_FAMILY=apk ;;
      *) die "Unsupported distribution: ${ID:-unknown}"; return 1 ;;
    esac
  else
    die "Cannot read /etc/os-release"; return 1
  fi
  log "Detected ${ID:-unknown} using $DISTRO_FAMILY"
}

choose_profile() {
  (( NON_INTERACTIVE )) && { [[ -n $PROFILE ]] || PROFILE=personal; return 0; }
  if [[ -z $PROFILE ]]; then
    echo "Qube profiles:"
    echo "  1) template  - install everything (ready for any distro line)"
    echo "  2) personal  - zen browser + brave browser"
    echo "  3) docs      - seafile + libreoffice + obsidian"
    echo "  4) media     - chromium browser"
    read -r -p "Select profile [1-4]: " choice
    case "$choice" in
      1|template) PROFILE=template ;;
      2|personal) PROFILE=personal ;;
      3|docs) PROFILE=docs ;;
      4|media) PROFILE=media ;;
      *) die "Invalid choice"; return 1 ;;
    esac
  fi
  case "$PROFILE" in template|personal|docs|media) ;; *) die "Invalid profile: $PROFILE"; return 1 ;; esac
}

# Package names per family for each capability.
pkg_name() {
  local cap=$1 family=$2
  case "$cap:$family" in
    fish:pacman|fish:apt|fish:dnf|fish:zypper|fish:apk) echo fish ;;
    git:pacman) echo git ;; git:apt) echo git ;; git:dnf) echo git ;; git:zypper) echo git ;; git:apk) echo git ;;
    curl:pacman) echo curl ;; curl:apt) echo curl ;; curl:dnf) echo curl ;; curl:zypper) echo curl ;; curl:apk) echo curl ;;
    zen:pacman) echo zen-browser-bin ;;
    zen:apt|zen:dnf|zen:zypper|zen:apk) echo "" ;; # flatpak fallback
    brave:pacman) echo brave-bin ;;
    brave:apt|brave:dnf|brave:zypper|brave:apk) echo "" ;;
    chromium:pacman) echo chromium ;; chromium:apt) echo chromium ;; chromium:dnf) echo chromium ;; chromium:zypper) echo chromium ;; chromium:apk) echo chromium ;;
    seafile:pacman) echo seafile-client ;; seafile:apt) echo seafile-gui ;; seafile:dnf) echo seafile-client ;; seafile:zypper) echo seafile-client ;; seafile:apk) echo seafile-client ;;
    libreoffice:pacman) echo libreoffice-fresh ;; libreoffice:apt) echo libreoffice ;; libreoffice:dnf) echo libreoffice ;; libreoffice:zypper) echo libreoffice ;; libreoffice:apk) echo libreoffice ;;
    obsidian:pacman) echo obsidian ;;
    obsidian:apt|obsidian:dnf|obsidian:zypper|obsidian:apk) echo "" ;;
    netbird:pacman) echo netbird-bin ;; netbird:apt) echo netbird ;; netbird:dnf) echo netbird ;; netbird:zypper) echo netbird ;; netbird:apk) echo netbird ;;
    *) echo "" ;;
  esac
}

flatpak_id() {
  case "$1" in
    zen) echo "app.zen_browser.zen" ;;
    brave) echo "com.brave.Browser" ;;
    obsidian) echo "md.obsidian.Obsidian" ;;
    seafile) echo "com.seafile.Client" ;;
    *) echo "" ;;
  esac
}

profile_caps() {
  case "$PROFILE" in
    template) echo "git curl zen brave chromium seafile libreoffice obsidian netbird" ;;
    personal) echo "git curl zen brave" ;;
    docs) echo "git curl seafile libreoffice obsidian" ;;
    media) echo "git curl chromium" ;;
  esac
}

other_caps() {
  # caps not in this profile but possibly installed by another qube installer/template
  case "$PROFILE" in
    personal) echo "chromium seafile libreoffice obsidian" ;;
    docs) echo "zen brave chromium" ;;
    media) echo "zen brave seafile libreoffice obsidian" ;;
    template) echo "" ;;
  esac
}

install_native() {
  local cap pkg
  for cap in $1; do
    pkg=$(pkg_name "$cap" "$DISTRO_FAMILY")
    [[ -z $pkg ]] && continue
    case "$DISTRO_FAMILY" in
      pacman)
        if pacman -Q "$pkg" >/dev/null 2>&1; then log "$cap already installed"; continue; fi
        if pacman -Si "$pkg" >/dev/null 2>&1; then
          run sudo pacman -S --needed --noconfirm "$pkg" || warn "Failed: $pkg"
        elif command -v yay >/dev/null 2>&1 && yay -Si "$pkg" >/dev/null 2>&1; then
          run yay -S --needed --noconfirm "$pkg" || warn "Failed: $pkg"
        elif command -v paru >/dev/null 2>&1 && paru -Si "$pkg" >/dev/null 2>&1; then
          run paru -S --needed --noconfirm "$pkg" || warn "Failed: $pkg"
        else
          warn "$cap unavailable natively: $pkg"
        fi
        ;;
      apt)
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then log "$cap already installed"; continue; fi
        if apt-cache show "$pkg" >/dev/null 2>&1; then
          run sudo apt-get install -y "$pkg" || warn "Failed: $pkg"
        else
          warn "$cap unavailable natively: $pkg"
        fi
        ;;
      dnf)
        if rpm -q "$pkg" >/dev/null 2>&1; then log "$cap already installed"; continue; fi
        if dnf --quiet list --available "$pkg" >/dev/null 2>&1; then
          run sudo dnf install -y "$pkg" || warn "Failed: $pkg"
        else
          warn "$cap unavailable natively: $pkg"
        fi
        ;;
      zypper)
        if rpm -q "$pkg" >/dev/null 2>&1; then log "$cap already installed"; continue; fi
        run sudo zypper --non-interactive install "$pkg" || warn "Failed: $pkg"
        ;;
      apk)
        if apk info -e "$pkg" >/dev/null 2>&1; then log "$cap already installed"; continue; fi
        run sudo apk add "$pkg" || warn "Failed: $pkg"
        ;;
    esac
  done
}

install_flatpak_fallbacks() {
  local cap fid
  for cap in $1; do
    fid=$(flatpak_id "$cap")
    [[ -z $fid ]] && continue
    pkg=$(pkg_name "$cap" "$DISTRO_FAMILY")
    # only fallback if native pkg missing/unavailable
    if [[ -n $pkg ]]; then
      case "$DISTRO_FAMILY" in
        pacman) pacman -Q "$pkg" >/dev/null 2>&1 && continue ;;
        apt) dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' && continue ;;
        dnf) rpm -q "$pkg" >/dev/null 2>&1 && continue ;;
      esac
    fi
    if ! command -v flatpak >/dev/null 2>&1; then
      warn "flatpak unavailable; cannot install $cap via flatpak"
      continue
    fi
    if flatpak info --user "$fid" >/dev/null 2>&1; then log "$cap flatpak already installed"; continue; fi
    run flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    run flatpak install --user -y flathub "$fid" || warn "Flatpak failed: $fid"
  done
}

ensure_aur_helper() {
  [[ $DISTRO_FAMILY == pacman ]] || return 0
  if command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1; then
    log "AUR helper already available"
    return 0
  fi
  # Bootstrap yay from AUR (standard Arch method, no curl-pipe-shell)
  if (( NON_INTERACTIVE )) || confirm "Bootstrap yay from AUR (requires git, base-devel)?"; then
    run sudo pacman -S --needed --noconfirm git base-devel || { warn "base-devel install failed"; return 1; }
    local tmpdir
    tmpdir=$(mktemp -d)
    run git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" || { warn "yay clone failed"; rm -rf "$tmpdir"; return 1; }
    (cd "$tmpdir/yay" && run makepkg -si --noconfirm) || warn "yay build failed"
    rm -rf "$tmpdir"
  else
    warn "No AUR helper installed"
  fi
}

trim_qube() {
  (( QUBES_TRIM )) || return 0
  local caps_to_remove cap pkg
  caps_to_remove=$(other_caps)
  [[ -z $caps_to_remove ]] && return 0
  log "Trimming packages from other qube profiles: $caps_to_remove"
  for cap in $caps_to_remove; do
    pkg=$(pkg_name "$cap" "$DISTRO_FAMILY")
    [[ -z $pkg ]] && continue
    case "$DISTRO_FAMILY" in
      pacman)
        if pacman -Q "$pkg" >/dev/null 2>&1; then
          run sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null || warn "Could not remove $pkg"
        fi
        ;;
      apt)
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
          run sudo apt-get remove -y "$pkg" 2>/dev/null || warn "Could not remove $pkg"
        fi
        ;;
      dnf)
        if rpm -q "$pkg" >/dev/null 2>&1; then
          run sudo dnf remove -y "$pkg" 2>/dev/null || warn "Could not remove $pkg"
        fi
        ;;
    esac
    # flatpak fallback removal
    fid=$(flatpak_id "$cap")
    if [[ -n $fid ]] && command -v flatpak >/dev/null 2>&1 && flatpak info --user "$fid" >/dev/null 2>&1; then
      run flatpak uninstall --user -y "$fid" 2>/dev/null || warn "Could not remove flatpak $fid"
    fi
  done
  # Clean package caches from trimmed/unused downloads.
  case "$DISTRO_FAMILY" in
    apt) run sudo apt-get clean 2>/dev/null || true ;;
    dnf) run sudo dnf clean all 2>/dev/null || true ;;
    pacman) run sudo pacman -Sc --noconfirm 2>/dev/null || true ;;
    zypper) run sudo zypper clean --all 2>/dev/null || true ;;
    apk) run sudo apk cache clean 2>/dev/null || true ;;
  esac
}

install_fish_shell() {
  local pkg
  pkg=$(pkg_name fish "$DISTRO_FAMILY")
  case "$DISTRO_FAMILY" in
    pacman)
      pacman -Q "$pkg" >/dev/null 2>&1 || run sudo pacman -S --needed --noconfirm "$pkg" || warn "fish install failed"
      ;;
    apt) dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' || run sudo apt-get install -y "$pkg" || warn "fish install failed" ;;
    dnf) rpm -q "$pkg" >/dev/null 2>&1 || run sudo dnf install -y "$pkg" || warn "fish install failed" ;;
    zypper) rpm -q "$pkg" >/dev/null 2>&1 || run sudo zypper --non-interactive install "$pkg" || warn "fish install failed" ;;
    apk) apk info -e "$pkg" >/dev/null 2>&1 || run sudo apk add "$pkg" || warn "fish install failed" ;;
  esac
}

netbird_up() {
  command -v netbird >/dev/null 2>&1 || return 0
  if command -v systemctl >/dev/null 2>&1; then
    run sudo systemctl enable --now netbird 2>/dev/null || warn "Could not enable NetBird service"
  fi
  local nb_flags=(--allow-server-ssh --enable-ssh-root)
  if (( NON_INTERACTIVE )) || confirm "Disable SSH JWT auth (authless SSH for any peer with network access)?"; then
    nb_flags+=(--disable-ssh-auth)
  fi
  if (( NON_INTERACTIVE )) || confirm "Run 'sudo netbird up' now?"; then
    run sudo netbird up "${nb_flags[@]}" || warn "NetBird login did not complete"
  fi
}

qubes_env_check() {
  if command -v qubesdb-read >/dev/null 2>&1 || [[ -d /var/lib/qubes ]]; then
    log "Qubes environment detected"
    if [[ ! -f /usr/share/qubes/marker-template ]]; then
      warn "This does not look like a template (marker-template missing). Packages installed in an appVM will not persist; run in a template instead."
    fi
  fi
}

main() {
  parse_args "$@" || { local s=$?; (( s == 2 )) && return 0; return $s; }
  qubes_env_check
  detect_platform || return 1
  choose_profile || return 1
  log "Profile: $PROFILE"

  install_fish_shell
  ensure_aur_helper
  caps=$(profile_caps)
  log "Installing profile packages: $caps"
  install_native "$caps"
  install_flatpak_fallbacks "$caps"

  if [[ $PROFILE == template ]]; then
    netbird_up
  fi

  trim_qube

  log "Qubes setup completed for profile: $PROFILE"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi