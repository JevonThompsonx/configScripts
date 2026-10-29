# Fleet Parity Runbook (Hermes provisioning, 2026-09-16)

What `./unifiedSetup.sh --fleet` automates vs what an agent (or human) must do
by hand. Scripted steps are idempotent; manual steps need credentials or a
physical presence that must never be stored in this repo.

## Scripted (`--fleet`)

- Package baseline per distro family via the manifest (podman, flatpak,
  syncthing, chromium, docker under `full`).
- `~/.config/environment.d/60-fleet-mise.conf` — mise shims on PATH for all
  shells including non-session SSH. Applies at next login.
- `mise install` from the existing `~/.config/mise/config.toml` (no-op if the
  file is absent).
- NetworkManager dispatcher `/etc/NetworkManager/dispatcher.d/50-fleet-tailscale`
  + suspend/resume hook `/usr/lib/systemd/system-sleep/50-fleet-net-resume`
  (root; confirmed interactively, skipped non-interactive).
- Update-on-boot unit `fleet-update-boot.service`, per-family package manager,
  log-only, no auto-reboot (root; confirmed interactively, skipped
  non-interactive). Standing owner-approved policy: unattended upgrades at
  every boot are intended on fleet hosts.

## Manual (agent checklist, in order)

1. `gh auth login` (interactive, one time) + `git config user.name/email`.
2. `sudo tailscale set --operator=<user>` on hosts where sudo needs a
   password — without it the exit-node timer fails hourly with `checkprefs
   access denied`.
3. Opencode: copy `opencode.json` (structure only) anytime; copy `auth.json`
   by file transfer only (scp), mode 600, never print or log values.
4. App credentials (`~/.config/qbctl*/`, `jdctl`, `gamectl`, `gh/hosts.yml`,
   `.git-credentials`): file-copy only, dirs 700 / files 600, never `cat`.
5. Syncthing: enable the user unit for a fresh device ID, then pair device IDs
   in the GUI on both ends and share folder IDs explicitly.
6. Seafile client: install the package scripted, but account login is GUI/CLI
   interactive. For bulk seeding between two hosts on the same LAN, prefer
   `rsync -aH` host-to-host and let the client reconcile — measure first:
   sustained throughput must project under 30 minutes or use removable media.
7. Reboot once after driver/kernel work; verify return via Tailscale ping and
   re-check service states. Never reboot unattended without a return path.

## Per-distro notes

- Arch/CachyOS (`ID_LIKE=arch`, incl. `cachyos`, `garuda`): AUR via existing
  `paru`/`yay` only — never bootstrap a helper. Rust via `rustup`, never the
  `rust` package. CachyOS ships `tiny-dfr` but that build targets Apple
  Silicon DRM devices, not Intel T1/T2 bars.
- Debian/Ubuntu: `fd`/`bat` arrive as `fdfind`/`batcat`; the setup symlinks
  user-local names non-destructively.
- Fedora/RHEL/Rocky: `dnf` paths; `power`/`SELinux`/firewall untouched.
- Alpine: minimal manifest subset; no AUR/Flatpak assumptions.

## MacBook (Intel T1, e.g. MacBookPro14,3) notes

- WiFi (BCM43602/brcmfmac), keyboard/trackpad (applespi), bluetooth, fans
  (applesmc + mbpfan), TRIM, zram, microcode all standard Arch packages.
- Touch Bar: `apple-ib-drv` (DKMS) exposes the bar; with no host renderer the
  T1 firmware shows its default strip and Fn toggles F-keys natively. There is
  no per-app strip support on Linux — the row is static.
- Keyboard backlight lives at `/sys/class/leds/spi::kbd_backlight` (T1) or
  `smc::kbd_backlight` (newer). `unifiedSetup.sh` automates this when Apple
  hardware with a Touch Bar is detected (vendor Apple + `spi::`/`smc::` LED,
  `apple_touchbar`/`apple-ibridge` module, or iBridge USB `05ac:8600`):
  installs `brightnessctl`, writes
  `/etc/udev/rules.d/90-apple-kbd-backlight.rules` (`video:rw` for both
  devices, root-confirmed, skipped non-interactive), installs
  `~/.local/bin/kbd-backlight-up/down` UPower helpers (no root needed), and
  on COSMIC merges `XF86KbdBrightnessUp/Down` into
  `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom`
  (upstream bug pop-os/cosmic-epoch#2925; GNOME/KDE need no mapping).
  See `lib/macbook-touchbar.sh` (`MACBOOK_DMI_BASE`, `MACBOOK_LEDS_BASE`,
  `MACBOOK_MODULE_BASE`, `MACBOOK_USB_IDS_FILE`, `MACBOOK_UDEV_RULE_PATH`
  overrides for tests).
- FaceTime camera appears only when the iBridge USB config is forced; no
  driver action needed beyond the udev rule.
- Charge-threshold sysfs does not exist on Apple SMC — there is nothing to set.
- Early microcode needs an `initrd=/intel-ucode.img` stanza in the bootloader
  config; verify with the `early` line in the kernel log.

## Niri notes

- `--desktop niri` installs the `niri` package on Arch-family systems only
  (other families report it unavailable; no third-party repos are ever added)
  and includes Wayland clipboard support. Wallpaper rotation is unsupported
  (warns).
- Keybinds live in `~/.config/niri/cfg/keybinds.kdl`; validate with
  `niri validate` (exit 0) after edits. Back up before merging.
- Launcher/search aliases: `Mod+D` / `Mod+Space` spawning the launcher of
  choice (e.g. `noctalia msg panel-toggle launcher`).

## COSMIC notes (System76 desktop environment)

- `--desktop cosmic` is supported on Arch/CachyOS (and other families where the
  `cosmic` meta package is available). COSMIC is a Wayland compositor, so it
  inherits the `desktop-wayland` group (Wayland clipboard tools).
- COSMIC packages installed: `cosmic-desktop` (meta), `cosmic-comp`,
  `cosmic-settings`, `cosmic-files`, `cosmic-term`, `cosmic-edit`,
  `cosmic-greeter`. No third-party repos are added; on distros where these are
  unavailable the package manager reports them missing and the setup continues.
- COSMIC manages its own wallpaper through `cosmic-settings` / the compositor's
  background service (`com.system76.CosmicBg`). The configScripts wallpaper
  rotation timer is therefore **disabled** on COSMIC (warns and skips) — set
  wallpapers via COSMIC settings or by editing
  `~/.config/cosmic/com.system76.CosmicBg/` directly.
- COSMIC does not use waybar/wofi (those are hyprland/sway only). Its panel,
  applets, and launcher are built into the compositor.
- Config files live under `~/.config/cosmic/` and `~/.config/com.system76.*`.
  Back up this directory before applying any external config.
- Keybinds and compositor settings are managed by COSMIC settings GUI or via
  the `cosmic-comp` config; validate by launching `cosmic-comp --version` or
  checking `systemctl --user status cosmic-session` after changes.
- On MacBookPro14,3 (Intel T1): COSMIC runs on the Intel Iris Plus 640/650
  via the standard `i915` driver. No special GPU config needed beyond the
  standard Arch/CachyOS kernel. Touch Bar and keyboard backlight fixes from
  the MacBook notes above still apply.
