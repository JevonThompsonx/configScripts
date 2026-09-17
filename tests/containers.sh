#!/usr/bin/env bash
# Distro-matrix dry-run: exercises OS detection + package dispatch inside the
# target userlands without mutating anything (the setup runs --dry-run).
# Needs a container runtime (docker or podman) and network for image pulls.
# Usage: bash tests/containers.sh [docker|podman]
set -u
RUNTIME=${1:-$(command -v docker >/dev/null 2>&1 && echo docker || echo podman)}
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

# --fleet and --desktop niri dry-runs on Arch (native niri family).
matrix_niri_fleet() {
  local out
  printf -- '--- archlinux:latest (niri + fleet dry-run) ---\n'
  out=$("$RUNTIME" run --rm -v "$REPO:/repo:ro" archlinux:latest \
    sh -c 'cd /repo && bash unifiedSetup.sh --dry-run --non-interactive --profile workstation --desktop niri --skip-configs --fleet 2>&1') || true
  [[ $out == *'desktop=niri'* && $out == *'fleet=1'* && $out == *'Would write'* ]] || return 1
  printf 'ok - archlinux:latest (niri + fleet)\n'; PASS=$((PASS + 1))
}
# Alpine ships without bash; the setup under test requires it.
matrix_alpine() {
  printf -- '--- alpine:latest (expect: apk) ---\n'
  if "$RUNTIME" run --rm -v "$REPO:/repo:ro" alpine:latest \
    sh -c 'apk add --no-cache bash >/dev/null 2>&1 && cd /repo && bash unifiedSetup.sh --dry-run --non-interactive --profile core --desktop none --skip-configs 2>&1' \
    | grep -q 'Detected .* using apk'; then
    printf 'ok - alpine:latest\n'; PASS=$((PASS + 1))
  else
    printf 'not ok - alpine:latest\n'; FAIL=$((FAIL + 1))
  fi
}
matrix() {
  local image=$1 expect=$2
  printf -- '--- %s (expect: %s) ---\n' "$image" "$expect"
  if "$RUNTIME" run --rm -v "$REPO:/repo:ro" "$image" \
    sh -c 'cd /repo && bash unifiedSetup.sh --dry-run --non-interactive --profile core --desktop none --skip-configs 2>&1' \
    | grep -q "Detected .* using $expect"; then
    printf 'ok - %s\n' "$image"; PASS=$((PASS + 1))
  else
    printf 'not ok - %s\n' "$image"; FAIL=$((FAIL + 1))
  fi
}

matrix debian:12 apt
matrix fedora:latest dnf
matrix_alpine
matrix archlinux:latest pacman
matrix_niri_fleet

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
