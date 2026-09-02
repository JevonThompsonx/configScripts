#!/usr/bin/env bash
# Dynamic function overrides are intentional in this sourced-library harness.
# shellcheck disable=SC2031,SC2317
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { printf 'ok - %s\n' "$1"; ((PASS++)); }
fail() { printf 'not ok - %s\n' "$1"; ((FAIL++)); }
assert_eq() { [[ $1 == "$2" ]] || { printf '  expected <%s>, got <%s>\n' "$2" "$1"; return 1; }; }
assert_file_contains() { grep -q -- "$2" "$1"; }

test_case() {
  local name=$1
  shift
  if (set -u; source "$ROOT/unifiedSetup.sh"; "$@"); then pass "$name"; else fail "$name"; fi
}

make_os_release() {
  local file=$1 id=$2 like=${3:-}
  printf 'ID=%s\nID_LIKE="%s"\n' "$id" "$like" >"$file"
}

test_distro_families() {
  local temp file id like expected
  temp=$(mktemp -d); file=$temp/os-release
  while IFS='|' read -r id like expected; do
    make_os_release "$file" "$id" "$like"
    OS_RELEASE_PATH=$file; HOME=$temp/home; mkdir -p "$HOME"
    DISTRO_FAMILY=; IS_OMARCHY=0
    detect_platform >/dev/null || return 1
    assert_eq "$DISTRO_FAMILY" "$expected" || return 1
  done <<'EOF'
arch||pacman
ubuntu|debian|apt
rocky|rhel fedora|dnf
opensuse-tumbleweed|suse opensuse|zypper
alpine||apk
garuda|arch|pacman
linuxmint|ubuntu debian|apt
EOF
  make_os_release "$file" mystery nowhere
  OS_RELEASE_PATH=$file
  ! detect_platform >/dev/null 2>&1
}

test_cli() {
  local output
  parse_args --profile full --desktop sway --dry-run --non-interactive --private-configs --ai-tools
  assert_eq "$PROFILE" full && assert_eq "$DESKTOP" sway &&
    ((DRY_RUN && NON_INTERACTIVE && PRIVATE_CONFIGS && AI_TOOLS && PROFILE_EXPLICIT && DESKTOP_EXPLICIT)) || return 1
  output=$(main --help) || return 1
  [[ $output == *'Usage: unifiedSetup.sh [options]'* && $output == *'--non-interactive'* ]]
}

test_interactive_choices_and_decline() {
  local output marker=$HOME/mutated os=$HOME/os-release
  unset XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK
  PROFILE=workstation; DESKTOP=gnome; PROFILE_EXPLICIT=0; DESKTOP_EXPLICIT=0; AI_TOOLS=0; AI_TOOLS_EXPLICIT=0
  choose_interactive_options <<'EOF'
full
sway
y
EOF
  assert_eq "$PROFILE" full || return 1
  assert_eq "$DESKTOP" sway || return 1
  (( AI_TOOLS )) || return 1

  make_os_release "$os" debian
  OS_RELEASE_PATH=$os; PROFILE=workstation; DESKTOP=auto; PROFILE_EXPLICIT=0; DESKTOP_EXPLICIT=0
  AI_TOOLS=0; AI_TOOLS_EXPLICIT=0; NON_INTERACTIVE=0; DRY_RUN=0; SKIP_CONFIGS=0; CONFIGS_ONLY=0
  install_profile_packages() { : >"$marker"; }
  setup_selected_configs() { : >"$marker"; }
  ensure_neovim() { :; }
  offer_risky_actions() { :; }
  setup_wallpaper_rotation() { :; }
  output=$(main <<'EOF'


n
n
EOF
  )
  [[ ! -e $marker ]] || return 1
  [[ $output == *'Plan: profile=workstation desktop=none'* && $output == *'Setup cancelled before making changes.'* ]] || return 1

  PROFILE=workstation; DESKTOP=auto; PROFILE_EXPLICIT=0; DESKTOP_EXPLICIT=0; AI_TOOLS=0; AI_TOOLS_EXPLICIT=0
  output=$(main <<'EOF'
core
none
n
y
EOF
  )
  [[ -e $marker && $output == *'Plan: profile=core desktop=none'* ]]
}

test_native_priority() {
  local log_file=$HOME/log
  DISTRO_FAMILY=pacman
  native_spec_ready() { return 0; }
  install_native_spec() { printf 'native\n' >>"$log_file"; }
  ensure_flatpak_ready() { printf 'flatpak\n' >>"$log_file"; }
  command() { builtin command "$@"; }
  install_capability sample definitely-not-a-command native-package aur-package app.example >/dev/null
  assert_eq "$(<"$log_file")" native
}

test_partial_native_spec_and_debian_aliases() {
  local log_file=$HOME/log bin=$HOME/bin
  DISTRO_FAMILY=apt; DRY_RUN=0
  native_is_installed() { return 1; }
  native_is_available() { [[ $1 == primary ]]; }
  run() { printf '%s\n' "$*" >>"$log_file"; }
  install_native_spec primary,missing-secondary || return 1
  assert_file_contains "$log_file" 'apt-get install -y primary' || return 1
  ! assert_file_contains "$log_file" 'missing-secondary' || return 1

  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\n' >"$bin/fdfind"
  printf '#!/usr/bin/env bash\n' >"$bin/batcat"
  chmod +x "$bin/fdfind" "$bin/batcat"
  PATH=$bin:/usr/bin:/bin; export PATH
  run() { "$@"; }
  ensure_debian_command_alias fd && ensure_debian_command_alias bat
  [[ -L $HOME/.local/bin/fd && -L $HOME/.local/bin/bat ]]
}

test_manifest_completeness_and_arch_rust() {
  local manifest
  manifest=$(package_manifest)
  for item in 'core|atuin|atuin|' 'core|bun|bun|' 'core|mise|mise|' 'core|powershell|pwsh|' 'desktop-hyprland|hyprpaper|hyprpaper|' 'io.github.ryubing.Ryujinx'; do
    [[ $manifest == *"$item"* ]] || return 1
  done
  [[ $manifest == *'core|rust|cargo|rustup|rustc,cargo'* ]] || return 1
  [[ $manifest != *'rust,rustup'* ]] || return 1
  [[ $manifest == *'|bun-bin|'* && $manifest == *'|mise-bin|'* && $manifest == *'|powershell-bin|'* ]]
}

test_arch_rust_initialization() {
  local bin=$HOME/bin log_file=$HOME/log
  mkdir -p "$bin"
  cat >"$bin/rustup" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_LOG"
EOF
  chmod +x "$bin/rustup"
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file DISTRO_FAMILY=pacman NON_INTERACTIVE=0
  export PATH TEST_LOG
  command() {
    [[ ${1:-} == -v && ${2:-} == cargo ]] && return 1
    builtin command "$@"
  }
  confirm() { return 0; }
  initialize_arch_rust
  assert_file_contains "$log_file" 'default stable'
}

test_ai_tools_user_local_and_isolated() {
  local bin=$HOME/bin log_file=$HOME/log
  mkdir -p "$bin"
  cat >"$bin/npm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_LOG"
[[ $* == *'@anthropic-ai/claude-code'* ]] && exit 1
exit 0
EOF
  printf '#!/usr/bin/env bash\n' >"$bin/codex"
  chmod +x "$bin/npm" "$bin/codex"
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file AI_TOOLS=1 DRY_RUN=0 FAILURES=0
  export PATH TEST_LOG
  command() {
    if [[ ${1:-} == -v ]]; then
      case ${2:-} in
        npm|codex) builtin command "$@"; return ;;
        opencode|claude|copilot|pi) return 1 ;;
      esac
    fi
    builtin command "$@"
  }
  install_ai_tools >/dev/null 2>&1
  assert_file_contains "$log_file" "install --global --prefix $HOME/.local opencode-ai" || return 1
  assert_file_contains "$log_file" '@anthropic-ai/claude-code' || return 1
  assert_file_contains "$log_file" '@github/copilot' || return 1
  assert_file_contains "$log_file" '@earendil-works/pi-coding-agent' || return 1
  ! assert_file_contains "$log_file" '@openai/codex' || return 1
  (( FAILURES == 1 ))
}

test_aur_then_flatpak() {
  local bin=$HOME/bin log_file=$HOME/log
  mkdir -p "$bin"
  cat >"$bin/paru" <<'EOF'
#!/usr/bin/env bash
printf 'paru %s\n' "$*" >>"$TEST_LOG"
exit 0
EOF
  cat >"$bin/flatpak" <<'EOF'
#!/usr/bin/env bash
printf 'flatpak %s\n' "$*" >>"$TEST_LOG"
[[ $1 == info ]] && exit 1
exit 0
EOF
  chmod +x "$bin/paru" "$bin/flatpak"
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file DISTRO_FAMILY=pacman DRY_RUN=0
  export PATH TEST_LOG
  native_spec_ready() { return 1; }
  install_capability aur-first missing-command missing aur-pkg app.example >/dev/null
  assert_file_contains "$log_file" 'paru -S --needed --noconfirm aur-pkg' || return 1
  ! assert_file_contains "$log_file" 'flatpak install'
}

test_flatpak_fallback_and_idempotency() {
  local bin=$HOME/bin log_file=$HOME/log state=$HOME/installed
  mkdir -p "$bin"
  cat >"$bin/flatpak" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_LOG"
if [[ $1 == info ]]; then [[ -f $TEST_STATE ]]; exit; fi
if [[ $1 == install ]]; then : >"$TEST_STATE"; fi
EOF
  chmod +x "$bin/flatpak"
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file TEST_STATE=$state DISTRO_FAMILY=apt DRY_RUN=0
  export PATH TEST_LOG TEST_STATE
  native_spec_ready() { return 1; }
  install_capability fallback absent-command missing '' app.example >/dev/null
  install_capability fallback absent-command missing '' app.example >/dev/null
  assert_eq "$(grep -c '^install --user' "$log_file")" 1
}

test_dry_run_no_mutation() {
  local before after
  PROFILE=core; DESKTOP=none; NON_INTERACTIVE=1; DRY_RUN=1; SKIP_CONFIGS=1; CONFIGS_ONLY=0
  DISTRO_FAMILY=apt; DISTRO_ID=debian
  package_manifest() { printf 'core|sample|missing|sample|sample|sample|sample|sample||\n'; }
  native_is_installed() { return 1; }
  native_is_available() { return 0; }
  ensure_neovim() { :; }
  before=$(ls -A "$HOME")
  install_profile_packages >/dev/null
  after=$(ls -A "$HOME")
  assert_eq "$after" "$before"
}

test_noninteractive_risky_actions() {
  local bin=$HOME/bin log_file=$HOME/log prompt_file=$HOME/prompted
  mkdir -p "$bin"
  for name in fish tailscale systemctl chsh sudo; do
    cat >"$bin/$name" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$TEST_LOG"
EOF
    chmod +x "$bin/$name"
  done
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file NON_INTERACTIVE=1 SHELL=/bin/bash
  export PATH TEST_LOG
  command() {
    [[ ${1:-} == -v && ${2:-} == syncthing ]] && return 1
    builtin command "$@"
  }
  read() { : >"$prompt_file"; return 0; }
  ! confirm "Must not prompt" || return 1
  offer_risky_actions
  [[ ! -e $log_file && ! -e $prompt_file ]]
}

test_service_scopes_and_units() {
  local bin=$HOME/bin log_file=$HOME/log
  mkdir -p "$bin"
  for name in docker virsh syncthing; do printf '#!/usr/bin/env bash\n' >"$bin/$name"; chmod +x "$bin/$name"; done
  cat >"$bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$TEST_LOG"
[[ $* == *' show '* || $1 == show ]] && printf 'loaded\n'
exit 0
EOF
  cat >"$bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$TEST_LOG"
exit 0
EOF
  chmod +x "$bin/systemctl" "$bin/sudo"
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file PROFILE=full NON_INTERACTIVE=0 DRY_RUN=0
  export PATH TEST_LOG
  confirm() { return 0; }
  offer_selected_services
  assert_file_contains "$log_file" 'sudo systemctl enable --now docker.service' || return 1
  assert_file_contains "$log_file" 'sudo systemctl enable --now libvirtd.service' || return 1
  assert_file_contains "$log_file" 'systemctl --user enable --now syncthing.service' || return 1
  ! assert_file_contains "$log_file" 'sudo systemctl enable --now syncthing.service'
}

test_absent_service_units_are_not_started() {
  local bin=$HOME/bin log_file=$HOME/log
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\n' >"$bin/docker"; chmod +x "$bin/docker"
  cat >"$bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_LOG"
[[ $* == *'show'* ]] && { printf 'not-found\n'; exit 0; }
exit 0
EOF
  cat >"$bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$TEST_LOG"
EOF
  chmod +x "$bin/systemctl" "$bin/sudo"
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file PROFILE=full NON_INTERACTIVE=0; export PATH TEST_LOG
  confirm() { return 0; }
  offer_selected_services
  ! assert_file_contains "$log_file" 'enable --now'
}

prepare_repo() {
  local base=$1
  git init --bare "$base/remote.git" >/dev/null 2>&1
  git clone "$base/remote.git" "$base/work" >/dev/null 2>&1
  git -C "$base/work" config user.email test@example.invalid
  git -C "$base/work" config user.name Test
  printf 'one\n' >"$base/work/file"
  git -C "$base/work" add file
  git -C "$base/work" commit -m initial >/dev/null
  git -C "$base/work" push -u origin HEAD >/dev/null 2>&1
}

test_clone_states() {
  local base=$HOME/repos branch diverge_branch
  mkdir -p "$base"; prepare_repo "$base"
  branch=$(git -C "$base/work" branch --show-current) || return 1
  [[ -n $branch ]] || return 1
  repo_is_safe_to_update "$base/work" "$base/remote" || return 1
  manage_repo "$base/remote" "$base/work" public 0 >/dev/null || return 1
  manage_repo "$base/remote" "$base/work" public 0 >/dev/null || return 1
  git -C "$base/work" remote add other "$base/remote.git"
  git -C "$base/work" fetch other >/dev/null 2>&1
  git -C "$base/work" branch --set-upstream-to="other/$branch" >/dev/null
  ! repo_is_safe_to_update "$base/work" "$base/remote" || return 1
  git -C "$base/work" branch --set-upstream-to="origin/$branch" >/dev/null
  repo_is_safe_to_update "$base/work" "$base/remote" || return 1
  printf 'dirty\n' >>"$base/work/file"
  ! repo_is_safe_to_update "$base/work" "$base/remote" || return 1
  git -C "$base/work" restore file
  printf 'local\n' >>"$base/work/file"
  git -C "$base/work" commit -am local >/dev/null
  ! repo_is_safe_to_update "$base/work" "$base/remote" || return 1
  git clone "$base/remote.git" "$base/diverge" >/dev/null 2>&1
  diverge_branch=$(git -C "$base/diverge" branch --show-current) || return 1
  assert_eq "$diverge_branch" "$branch" || return 1
  git -C "$base/diverge" config user.email test@example.invalid
  git -C "$base/diverge" config user.name Test
  git clone "$base/remote.git" "$base/other" >/dev/null 2>&1
  git -C "$base/other" config user.email test@example.invalid
  git -C "$base/other" config user.name Test
  printf 'remote\n' >>"$base/other/file"
  git -C "$base/other" commit -am remote >/dev/null
  git -C "$base/other" push >/dev/null 2>&1
  printf 'diverged\n' >>"$base/diverge/file"
  git -C "$base/diverge" commit -am diverged >/dev/null
  git -C "$base/diverge" fetch >/dev/null 2>&1
  ! repo_is_safe_to_update "$base/diverge" "$base/remote" || return 1
  git -C "$base/diverge" remote add other "$base/remote.git"
  git -C "$base/diverge" fetch other >/dev/null 2>&1
  git -C "$base/diverge" branch --set-upstream-to="other/$diverge_branch" >/dev/null
  ! repo_is_safe_to_update "$base/diverge" "$base/remote" || return 1
  NON_INTERACTIVE=1
  mkdir -p "$HOME/not git"; printf keep >"$HOME/not git/sentinel"
  manage_repo owner/repo "$HOME/not git" public 0 >/dev/null 2>&1
  [[ -f $HOME/not\ git/sentinel ]] || return 1
  ! manage_repo owner/repo /tmp/outside-home public 0 >/dev/null 2>&1
}

test_private_auth_gate() {
  local bin=$HOME/bin log_file=$HOME/log
  mkdir -p "$bin"
  cat >"$bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_LOG"
exit 1
EOF
  chmod +x "$bin/gh"
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file NON_INTERACTIVE=1 PRIVATE_CONFIGS=1
  export PATH TEST_LOG
  ! private_auth_ready >/dev/null 2>&1 || return 1
  ! grep -q 'auth login' "$log_file"
}

test_omarchy_conflict_skip() {
  local destination=$HOME/.config/nvim
  mkdir -p "$destination"; printf keep >"$destination/sentinel"
  NON_INTERACTIVE=1; IS_OMARCHY=1
  manage_repo JevonThompsonx/nvim "$destination" public 1 >/dev/null 2>&1
  [[ -f $destination/sentinel ]]
}

test_desktop_selection() {
  local output=$HOME/selected
  PROFILE=workstation; DESKTOP=sway
  package_manifest() {
    printf '%s\n' 'desktop-hyprland|hypr|h|h|h|h|h|h||' 'desktop-sway|sway|s|s|s|s|s|s||' 'desktop-gnome|gnome|g|g|g|g|g|g||'
  }
  install_capability() { printf '%s\n' "$1" >>"$output"; }
  DISTRO_FAMILY=apt
  install_profile_packages
  assert_eq "$(<"$output")" sway
}

test_gnome_clipboard_session_selection() {
  PROFILE=workstation; DESKTOP=gnome
  XDG_SESSION_TYPE=wayland
  group_selected desktop-wayland && ! group_selected desktop-x11 || return 1
  XDG_SESSION_TYPE=x11
  group_selected desktop-x11 && ! group_selected desktop-wayland
}

test_wallpaper_units_and_rerun() {
  DESKTOP=gnome; IS_OMARCHY=0; DRY_RUN=0
  write_wallpaper_units
  local timer=$HOME/.config/systemd/user/configscripts-wallpaper.timer first second
  first=$(<"$timer")
  write_wallpaper_units
  second=$(<"$timer")
  assert_eq "$first" "$second" && assert_file_contains "$timer" 'OnUnitActiveSec=30m'
}

test_omarchy_wallpaper_unit() {
  local bin=$HOME/bin wallpaper_dir=$HOME/Pictures/WPs log_file=$HOME/setter.log script
  mkdir -p "$bin" "$wallpaper_dir"
  cat >"$bin/omarchy-theme-bg-set" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$TEST_LOG"
EOF
  chmod +x "$bin/omarchy-theme-bg-set"
  : >"$wallpaper_dir/zero.png"
  printf image >"$wallpaper_dir/nonempty image.jpg"
  PATH=$bin:/usr/bin:/bin TEST_LOG=$log_file DESKTOP=hyprland IS_OMARCHY=1 DRY_RUN=0
  export PATH TEST_LOG
  write_wallpaper_units
  script=$HOME/.local/bin/configscripts-wallpaper-rotate
  SETUP_DESKTOP=omarchy WALLPAPER_DIR=$wallpaper_dir "$script"
  assert_eq "$(<"$log_file")" "$wallpaper_dir/nonempty image.jpg" || return 1
  assert_file_contains "$HOME/.config/systemd/user/configscripts-wallpaper.service" 'ExecStart=%h/.local/bin/configscripts-wallpaper-rotate' || return 1
  [[ ! -e $HOME/.config/systemd/user/configscripts-hyprpaper.service ]]
}

test_hyprpaper_units() {
  local bin=$HOME/bin wallpaper_dir=$HOME/Pictures/WPs unit_dir=$HOME/.config/systemd/user
  mkdir -p "$bin" "$wallpaper_dir"
  printf '#!/usr/bin/env bash\n' >"$bin/hyprpaper"
  printf '#!/usr/bin/env bash\n' >"$bin/hyprctl"
  chmod +x "$bin/hyprpaper" "$bin/hyprctl"
  printf image >"$wallpaper_dir/wall.png"
  PATH=$bin:/usr/bin:/bin DESKTOP=hyprland IS_OMARCHY=0 DRY_RUN=0; export PATH
  wallpaper_backend_available || return 1
  write_wallpaper_units
  assert_file_contains "$unit_dir/configscripts-hyprpaper.service" "ExecStart=\"$bin/hyprpaper\"" || return 1
  assert_file_contains "$unit_dir/configscripts-wallpaper.timer" 'OnUnitActiveSec=30m'
}

test_wallpaper_requires_nonempty_images_before_prompt() {
  local prompt_file=$HOME/prompted
  mkdir -p "$HOME/Pictures/WPs"
  : >"$HOME/Pictures/WPs/empty.jpg"
  DESKTOP=gnome; IS_OMARCHY=0; NON_INTERACTIVE=0
  confirm() { : >"$prompt_file"; return 0; }
  setup_wallpaper_rotation >/dev/null 2>&1
  [[ ! -e $prompt_file ]]
}

test_wallpaper_reports_missing_backend_after_opt_in() {
  local error_file=$HOME/error
  mkdir -p "$HOME/Pictures/WPs"
  printf image >"$HOME/Pictures/WPs/wall.jpg"
  DESKTOP=hyprland; IS_OMARCHY=0; NON_INTERACTIVE=0; FAILURES=0
  confirm() { return 0; }
  command() {
    if [[ $1 == -v && ( $2 == hyprctl || $2 == hyprpaper ) ]]; then return 1; fi
    builtin command "$@"
  }
  setup_wallpaper_rotation 2>"$error_file" && return 1
  assert_file_contains "$error_file" 'requires both hyprctl and hyprpaper' && (( FAILURES == 1 ))
}

test_neovim_versions() {
  version_at_least 0.11.2 0.11.2 && version_at_least 0.12.0 0.11.2 && ! version_at_least 0.10.4 0.11.2
}

test_verified_neovim_install() {
  local fixture=$HOME/fixture bin=$HOME/bin asset tree temp_root
  case "$(uname -m)" in
    x86_64|amd64) asset=nvim-linux-x86_64.tar.gz; tree=nvim-linux-x86_64 ;;
    aarch64|arm64) asset=nvim-linux-arm64.tar.gz; tree=nvim-linux-arm64 ;;
    *) return 0 ;;
  esac
  mkdir -p "$fixture/$tree/bin" "$bin"
  printf '#!/usr/bin/env bash\nprintf "NVIM v0.11.2\\n"\n' >"$fixture/$tree/bin/nvim"
  chmod +x "$fixture/$tree/bin/nvim"
  tar -czf "$fixture/$asset" -C "$fixture" "$tree"
  printf '%s  %s\n' "$(sha256sum "$fixture/$asset" | cut -d' ' -f1)" "$asset" >"$fixture/shasum.txt"
  cat >"$bin/curl" <<'EOF'
#!/usr/bin/env bash
output=
url=
while (($#)); do
  case "$1" in
    -o) output=$2; shift ;;
    http*) url=$1 ;;
  esac
  shift
done
case "$url" in
  */shasum.txt) cp "$NVIM_FIXTURE/shasum.txt" "$output" ;;
  *) cp "$NVIM_FIXTURE/${url##*/}" "$output" ;;
esac
EOF
  chmod +x "$bin/curl"
  temp_root=$HOME/tmp; mkdir -p "$temp_root"
  PATH=$bin:/usr/bin:/bin NVIM_FIXTURE=$fixture TMPDIR=$temp_root DRY_RUN=0
  export PATH NVIM_FIXTURE TMPDIR
  install_official_neovim >/dev/null
  [[ -x $HOME/.local/opt/neovim/bin/nvim && -L $HOME/.local/bin/nvim ]] || return 1
  ! compgen -G "$temp_root/configscripts-nvim.*" >/dev/null || return 1
  printf '%064d  wrong-asset.tar.gz\n' 0 >"$fixture/shasum.txt"
  ! install_official_neovim >/dev/null 2>&1 || return 1
  compgen -G "$temp_root/configscripts-nvim.*" >/dev/null
}

test_family_end_to_end_dry_runs() {
  local bin=$HOME/bin os=$HOME/os-release output before after id like expected
  mkdir -p "$bin"
  cat >"$bin/pacman" <<'EOF'
#!/usr/bin/env bash
[[ $1 == -Si && $2 == arch-package ]]
EOF
  cat >"$bin/apt-cache" <<'EOF'
#!/usr/bin/env bash
[[ $1 == show && $2 == apt-package ]]
EOF
  printf '#!/usr/bin/env bash\nexit 1\n' >"$bin/dpkg-query"
  cat >"$bin/dnf" <<'EOF'
#!/usr/bin/env bash
[[ $* == *'dnf-package'* ]]
EOF
  printf '#!/usr/bin/env bash\nexit 1\n' >"$bin/rpm"
  cat >"$bin/zypper" <<'EOF'
#!/usr/bin/env bash
[[ $* == *'zypper-package'* ]] && printf 'zypper-package\n'
EOF
  cat >"$bin/apk" <<'EOF'
#!/usr/bin/env bash
[[ $1 == search && $3 == apk-package ]]
EOF
  chmod +x "$bin"/*
  PATH=$bin:/usr/bin:/bin; export PATH
  package_manifest() { printf '%s\n' 'core|family-test|missing-family-command|arch-package|apt-package|dnf-package|zypper-package|apk-package||'; }
  ensure_neovim() { :; }
  while IFS='|' read -r id like expected; do
    make_os_release "$os" "$id" "$like"
    PROFILE=workstation; DESKTOP=auto; PROFILE_EXPLICIT=0; DESKTOP_EXPLICIT=0
    NON_INTERACTIVE=0; DRY_RUN=0; SKIP_CONFIGS=0; CONFIGS_ONLY=0; AI_TOOLS=0; AI_TOOLS_EXPLICIT=0
    OS_RELEASE_PATH=$os; DISTRO_FAMILY=; IS_OMARCHY=0; FAILURES=0
    before=$(ls -A "$HOME")
    output=$(main --dry-run --non-interactive --profile core --desktop none --skip-configs)
    after=$(ls -A "$HOME")
    assert_eq "$after" "$before" || return 1
    [[ $output == *"$expected"* ]] || { printf '  missing manager command <%s> in <%s>\n' "$expected" "$output"; return 1; }
  done <<'EOF'
arch||sudo pacman -S --needed --noconfirm arch-package
debian||sudo apt-get install -y apt-package
fedora||sudo dnf install -y dnf-package
opensuse-tumbleweed|suse opensuse|sudo zypper --non-interactive install zypper-package
alpine||sudo apk add apk-package
EOF
}

test_paths_with_spaces() {
  local outside
  HOME="$HOME/home with spaces"; mkdir -p "$HOME"
  outside=$(mktemp -d)
  ln -s "$outside" "$HOME/outside-link"
  path_is_under_home "$HOME/.config/a path" &&
    ! path_is_under_home "$HOME/../escape" &&
    ! path_is_under_home "$HOME/outside-link/config"
}

run_one() {
  local name=$1 fn=$2 temp
  temp=$(mktemp -d)
  HOME="$temp/home"; mkdir -p "$HOME"
  test_case "$name" "$fn"
}

run_one 'five distro families, derivatives, and unknown failure' test_distro_families
run_one 'CLI option parsing' test_cli
run_one 'interactive choices and plan decline prevent mutations' test_interactive_choices_and_decline
run_one 'native package wins over AUR and Flatpak' test_native_priority
run_one 'partial native specs and Debian command aliases' test_partial_native_spec_and_debian_aliases
run_one 'manifest includes restored tools and corrected mappings' test_manifest_completeness_and_arch_rust
run_one 'Arch rustup initialization is explicitly confirmed' test_arch_rust_initialization
run_one 'AI tools use isolated user-local npm installs' test_ai_tools_user_local_and_isolated
run_one 'AUR wins over Flatpak on Arch' test_aur_then_flatpak
run_one 'Flatpak fallback is user scoped and not duplicated' test_flatpak_fallback_and_idempotency
run_one 'dry-run does not mutate HOME' test_dry_run_no_mutation
run_one 'non-interactive mode performs no risky actions' test_noninteractive_risky_actions
run_one 'selected services use correct system and user scopes' test_service_scopes_and_units
run_one 'absent service units are never enabled' test_absent_service_units_are_not_started
run_one 'safe clean, dirty, non-git, and outside-HOME clone states' test_clone_states
run_one 'private authentication is gated' test_private_auth_gate
run_one 'Omarchy conflicts are skipped non-interactively' test_omarchy_conflict_skip
run_one 'desktop package selection is isolated' test_desktop_selection
run_one 'GNOME clipboard follows Wayland or X11 session type' test_gnome_clipboard_session_selection
run_one 'wallpaper timer is 30m and idempotent' test_wallpaper_units_and_rerun
run_one 'Omarchy timer uses native theme command' test_omarchy_wallpaper_unit
run_one 'generic Hyprland generates a hyprpaper user service' test_hyprpaper_units
run_one 'wallpaper rotation requires a nonempty image before prompting' test_wallpaper_requires_nonempty_images_before_prompt
run_one 'wallpaper opt-in clearly fails without its backend' test_wallpaper_reports_missing_backend_after_opt_in
run_one 'Neovim minimum version paths' test_neovim_versions
run_one 'official Neovim archive requires matching SHA256' test_verified_neovim_install
run_one 'all package families complete end-to-end dry-run orchestration' test_family_end_to_end_dry_runs
run_one 'paths with spaces remain safely quoted' test_paths_with_spaces

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
