# Repository Guidance

## Supported Architecture

`unifiedSetup.sh` is the workstation entrypoint. It sources small, testable Bash
libraries:

- `lib/common.sh`: CLI, prompts, distro/desktop detection, and risky-action gates.
- `lib/packages.sh`: capability manifest, native -> AUR -> Flatpak fallback,
  optional AI npm tools, Debian aliases, and Arch rustup initialization.
- `lib/configs.sh`: public/private auth rules and non-destructive Git handling.
- `lib/desktop.sh`: validated wallpaper selection and opt-in user timer/backends.
- `lib/neovim.sh`: Neovim 0.11.2 check, verified official fallback, optional sync.

All libraries must remain safe to source. Keep the main guard in
`unifiedSetup.sh`. `cloneConfigs.sh` is only a wrapper for `--configs-only`.

## Safety Invariants

- Normal no-flag use prompts for profile and detected desktop defaults, offers AI
  tools, prints the plan, and requires confirmation before package/config writes.
- Track explicit CLI choices with `PROFILE_EXPLICIT`, `DESKTOP_EXPLICIT`, and
  `AI_TOOLS_EXPLICIT`; non-interactive mode must never call `read`.
- Non-interactive mode must not prompt, replace configs, authenticate, change
  shells, enable/start services, run `tailscale up`, or enable wallpaper timers.
- Never recursively delete a user config, app profile, theme, or managed install.
- Config clone destinations must be under `HOME`; clone to a temporary sibling
  before moving an existing path to a timestamped backup.
- Public configs use Git HTTPS. Private configs use `gh` only after explicit
  selection and confirmed authentication. Never print auth output or tokens.
- Do not add third-party distro repositories, bootstrap an AUR helper, use
  curl-pipe-shell, change firewall/storage/power/SELinux settings, or reboot.
- Flatpak is user-scoped and is only a fallback after native and existing Arch
  AUR options fail.
- Omarchy defaults and theme directories are protected. Use its native
  `omarchy-theme-bg-set` with a selected nonempty image argument; do not add
  wallpaper daemons or start the generic Hyprpaper service.
- Generic Hyprland rotation requires the selected `hyprpaper` capability and its
  user service. Sway uses `swaymsg`; GNOME uses `gsettings`.
- Docker/libvirt are separately confirmed system services. Syncthing is a
  separately confirmed user service. Verify units exist before enabling them.
- `JevonThompsonx/nvim` is the config source of truth. Do not generate Lua or
  clone a starter over it.

## Package Manifest

Manifest records use:

```text
group|capability|command|pacman|apt|dnf|zypper|apk|aur|flatpak
```

The first package in a comma-separated native field represents the capability.
Install available secondary packages independently; a missing secondary must not
block the valid primary package.
Install failures are capability-local and must not abort the manifest loop.
Desktop groups must remain isolated to the selected desktop.

Arch Rust maps only to `rustup`; never combine it with `rust`. Stable toolchain
initialization is a separate explicit prompt when Cargo is absent. AI tools use
only `npm install --global --prefix "$HOME/.local"`, never sudo or global npm
configuration. `--ai-tools` is the only non-interactive opt-in.

GNOME clipboard grouping depends on `XDG_SESSION_TYPE`: Wayland uses
`wl-clipboard`; X11/unknown uses `xclip` and `xsel`. Debian command aliases for
`fdfind`/`batcat` belong under `~/.local/bin` and must preserve existing files.

## Tests

Run before reporting changes:

```bash
bash tests/run.sh
bash -n unifiedSetup.sh cloneConfigs.sh lib/*.sh tests/run.sh
```

Run ShellCheck if it is already installed; do not install it solely for a check.
Tests must not use root, network, remote hosts, or real package mutations. Extend
`tests/run.sh` with temporary HOME, fake `OS_RELEASE_PATH`, PATH shims, or local
Git repositories.

## Legacy Scope

The distro-specific scripts, `server/`, ClamAV, firewall, uninstall, and power
management scripts are legacy or specialized standalone tools. Do not invoke
them from the supported workstation flow. Preserve unrelated changes in them.
