# Repository Guidance

## Supported Architecture

`unifiedSetup.sh` is the workstation entrypoint. It sources small, testable Bash
libraries:

- `lib/common.sh`: CLI, prompts, distro/desktop detection, and risky-action gates.
- `lib/packages.sh`: capability manifest, native -> AUR -> Flatpak fallback,
  optional AI npm tools, Debian aliases, and Arch rustup initialization.
- `lib/configs.sh`: public/private auth rules, non-destructive Git handling, and
  primary/mirror remote handling (Forgejo primary, GitHub mirror).
- `lib/desktop.sh`: validated wallpaper selection and opt-in user timer/backends.
- `lib/neovim.sh`: Neovim 0.11.2 check, verified official fallback, optional sync.
- `nvim/bootstrap.lua`: headless Lazy/Mason bootstrap for the nvim config.

All libraries must remain safe to source. Keep the main guard in
`unifiedSetup.sh`. `cloneConfigs.sh` is only a wrapper for `--configs-only`.

## Safety Invariants

- Normal no-flag use prompts for profile and detected desktop defaults, offers AI
  tools, prints the plan, and requires confirmation before package/config writes.
- Track explicit CLI choices with `PROFILE_EXPLICIT`, `DESKTOP_EXPLICIT`, and
  `AI_TOOLS_EXPLICIT`; non-interactive mode must never call `read`.
- Non-interactive mode must not prompt, replace configs, authenticate, change
  shells, enable/start services, run `netbird up`, or enable wallpaper timers.
- Never recursively delete a user config, app profile, theme, or managed install.
- Config clone destinations must be under `HOME`; clone to a temporary sibling
  before moving an existing path to a timestamped backup.
- Public configs clone from the primary remote (Forgejo) and fall back to the
  GitHub mirror; the mirror stays available as the `github` remote. Private
  configs use `gh` only after explicit selection and confirmed authentication.
  Never print auth output or tokens.
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
- The nvim config tracks LazyVim v16, which needs Neovim >= 0.11.2. The
  bootstrap in `nvim/bootstrap.lua` must wait for in-flight mason installs so
  Neovim does not exit with packages still installing.

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
bash -n unifiedSetup.sh cloneConfigs.sh lib/*.sh tests/run.sh tests/containers.sh
```

Run ShellCheck if it is already installed; do not install it solely for a check.
Tests must not use root, network, remote hosts, or real package mutations. Extend
`tests/run.sh` with temporary HOME, fake `OS_RELEASE_PATH`, PATH shims, or local
Git repositories. `tests/containers.sh` is the exception: distro-matrix dry-runs
inside containers (needs a runtime + image pulls, never mutates the host).

## Fleet Scope

`lib/fleet.sh` owns `--fleet` parity: mise session PATH, toolchain sync, NM +
sleep hooks, update-on-boot. Root writes confirm interactively and are skipped
non-interactive; hook templates must stay secret-free. CachyOS (`cachyos`)
detects as `pacman` via `ID_LIKE=arch`. `niri` is a valid `--desktop` with a
`desktop-niri` manifest group and Wayland clipboard; wallpaper rotation warns.
Agent-manual steps live in `docs/FLEET-PARITY.md`, never as code that prints
credentials.

## Qubes Scope

`qubes/qubesSetup.sh` (and `unifiedSetup.sh --qubes`) sets up a Qubes qube or
template. It prompts for a profile (template/personal/docs/media), installs fish
plus an AUR helper on Arch, and skips terminal tooling (Qubes provides its own
terminal). NetBird is installed/enabled only in the template profile, with
`netbird up` using `--allow-server-ssh --enable-ssh-root` (SSH JWT auth disable
is prompted). Running in a non-template qube warns that packages won't persist.

## Legacy Scope

The distro-specific scripts, `server/`, ClamAV, firewall, uninstall, and power
management scripts are legacy or specialized standalone tools. Do not invoke
them from the supported workstation flow. Preserve unrelated changes in them.

## Source Control (Forgejo primary)

Forgejo (`https://forge.jsquaredadventures.com`) is the primary remote; GitHub is a
mirror. Use remote name `forgejo` for pushes. Fish helpers: `forgeCreate`,
`forgeAdd`, `forgeCommit -m "..."`, `forgePush`, `forgePull`. Keep both remotes
in sync after changes.
