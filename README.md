# Linux Workstation Setup

`unifiedSetup.sh` is the supported entrypoint for an interactive, idempotent
workstation setup. It supports Arch/Omarchy, Debian/Ubuntu, Fedora/Rocky/RHEL,
openSUSE, and Alpine package-manager families.

## Quick Start

```bash
./unifiedSetup.sh
./unifiedSetup.sh --dry-run --profile full --desktop auto
./unifiedSetup.sh --non-interactive --profile core --desktop none
./unifiedSetup.sh --non-interactive --profile core --desktop none --ai-tools
./cloneConfigs.sh --private-configs
```

Run `./unifiedSetup.sh --help` for all options. With no flags, the script detects
the current desktop, prompts for profile and desktop with safe defaults, offers
the optional AI CLIs, prints the complete plan, and asks for confirmation before
package or config mutations. Explicit `--profile` and `--desktop` values suppress
their respective selection prompts.

`--non-interactive` never logs into private repositories, replaces existing
config paths, changes the login shell, enables services, runs `tailscale up`, or
enables wallpaper rotation. Private repos additionally require
`--private-configs` and an existing `gh` login in non-interactive mode.
Optional AI tools require `--ai-tools` in non-interactive mode.

For test fixtures, `OS_RELEASE_PATH` may override `/etc/os-release`.

## Profiles

- `core`: shell, development tools, Atuin, Bun, Mise, PowerShell, media utilities,
  Caddy, and Tailscale.
- `workstation`: core plus the selected desktop and desktop applications.
- `full`: workstation plus emulation, Docker, QEMU/libvirt, and virt-manager.

Packages use this order per capability: installed command, available native
package, existing `paru`/`yay` AUR package on Arch, then user-scoped Flatpak.
Unavailable capabilities warn and do not stop unrelated installs. The setup does
not bootstrap AUR helpers or add third-party distro repositories. Flathub is
added idempotently for the current user only when a Flatpak fallback is needed.

On Arch, Rust uses `rustup` rather than conflicting `rust` and `rustup` packages.
If Cargo is absent after `rustup` installation, interactive mode separately asks
before initializing the stable toolchain. Bun, Mise, and PowerShell are tested
against native repositories first and then an existing `paru` or `yay` helper on
Arch (`bun-bin`, `mise-bin`, and `powershell-bin`). Default Debian, Fedora,
openSUSE, and Alpine repositories may not provide all three; unavailable tools
are reported and skipped without adding third-party repositories.

On Debian-family systems, `fd-find` and `bat` provide `fdfind` and `batcat`.
The setup creates non-destructive user-local `~/.local/bin/fd` and `bat` symlinks
when those package commands are present.

## Optional AI Tools

Interactive setup asks whether to install these npm packages. Non-interactive
setup requires `--ai-tools`:

- OpenCode: `opencode-ai`
- Claude: `@anthropic-ai/claude-code`
- Codex: `@openai/codex`
- Copilot: `@github/copilot`
- Pi: `@earendil-works/pi-coding-agent`

Each command is checked first. Missing tools use
`npm install --global --prefix "$HOME/.local"` without sudo or global npm
configuration changes. A failed package does not block the remaining tools.

## Desktop Safety

Use `--desktop hyprland`, `sway`, `gnome`, or `none`; `auto` only detects the
current session and never replaces it. Hyprland and Sway select `wl-clipboard`.
GNOME selects `wl-clipboard` in a Wayland session and `xclip`/`xsel` for X11 or
unknown-session fallback.

Omarchy detection protects its Hyprland, Neovim, Waybar, Wofi, Foot, and theme
defaults. Conflicting config repos require confirmation and are skipped by
default. Wallpaper rotation never changes theme directories or starts another
background daemon. Rotation is offered after a nonempty JPG, PNG, or WebP image
is found in `~/Pictures/WPs`. If rotation is selected but the desktop backend is
unavailable, setup reports a clear failure. The selector passes a randomly
selected image to `omarchy-theme-bg-set` on Omarchy. Generic
Hyprland installs and explicitly enables a user `hyprpaper` backend with the
timer; Sway uses `swaymsg`, and GNOME uses `gsettings`. The timer runs every 30
minutes. Omarchy never starts the generic Hyprpaper service.

Service activation is separate from package installation and always defaults to
no. Under the full profile, existing Docker and libvirt system units receive
separate prompts and use `sudo systemctl`. An existing Syncthing user unit gets a
separate prompt and uses `systemctl --user`. Missing commands or units are never
enabled.

## Configuration Repositories

Public repositories clone over HTTPS without GitHub authentication:

- `JevonThompsonx/nvim` -> `~/.config/nvim`
- `JevonThompsonx/waybar` -> `~/.config/waybar`
- `JevonThompsonx/wofi` -> `~/.config/wofi`
- `JevonThompsonx/falkon` -> `~/.config/falkon`
- `JevonThompsonx/alacritty` -> `~/.config/alacritty`

Private repositories use `gh repo clone` only after selection and authentication:

- `JevonThompsonx/fish` -> `~/.config/fish`
- `JevonThompsonx/opencode` -> `~/.config/opencode`
- `JevonThompsonx/WPs` -> `~/Pictures/WPs`

Destinations must be under `HOME`. Clean matching repos pull with `--ff-only`.
The current branch must track the expected repository through the `origin`
remote. Dirty, unpushed, diverged, mismatched, non-origin, or upstream-less repos
are preserved and skipped. Existing non-Git paths default to skip; an interactive replacement
first clones to a sibling path and then moves the original to a timestamped
backup. User config directories are never recursively deleted.

## Neovim

The native package is preferred when `nvim` is at least 0.11.2. An older native
version is retained unless the user explicitly accepts an official release
install under `~/.local/opt/neovim`. The archive is checked against the matching
upstream `shasum.txt` SHA256 entry before extraction, and an existing managed
install is moved to a timestamped backup. Successful downloads remove only their
exact temporary archive/checksum files and empty temporary directory; failed
downloads or verification retain their temporary directory for diagnosis.

`JevonThompsonx/nvim` remains the only config source. The setup does not generate
Lua. Lazy/Mason bootstrap is optional and runs the existing config headlessly.

## Validation

Tests require only Bash and standard local utilities; they use temporary homes,
fake PATH commands, fake os-release files, and local Git repositories.

```bash
bash tests/run.sh
bash -n unifiedSetup.sh cloneConfigs.sh lib/*.sh tests/run.sh
shellcheck unifiedSetup.sh cloneConfigs.sh lib/*.sh tests/run.sh  # if installed
```

## Legacy Scripts

`archSetup.sh`, `debianSetup.sh`, `fedora.sh`, and other standalone setup scripts
are retained for historical/specialized use. They do not share the safety model
or current package manifest and are not the supported workstation entrypoint.
`server/unifiedSetup.sh`, ClamAV tools, firewall tools, and power-management tools
remain separate and are never invoked by the workstation setup.
