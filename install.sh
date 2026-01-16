#!/usr/bin/env bash
# install.sh
#
# Cross-platform dotfiles installer (idempotent).
#
# Supported OS:
# - macOS
# - SteamOS (Arch)
# - Debian-based Linux
#
# Strategy (see agents.md):
# - Prefer Homebrew on all platforms.
# - Use native managers only for explicitly configured lists:
#   - SteamOS/Arch: yay (AUR)
#   - Debian: apt/apt-get
#   - Linux: flatpak (FLATPAK)
# - Safe to run repeatedly.
#
# This installer is intentionally kept simple. Each major step is implemented
# as a runnable task script in `install/tasks/`, so you can:
# - run the full install via this script
# - run individual steps manually while debugging (SteamOS/Debian, etc.)
#
# Manual OS updates:
# - OS updates are intentionally NOT run automatically by `install.sh`.
# - To update your OS manually, run:
#     ./install/tasks/10_update_os.sh

set -euo pipefail

print_logo() {
  local os="${OS:-Detecting…}"
  local host user shell_name repo ruby_ver node_ver
  host="$(hostname 2>/dev/null || true)"
  user="${USER:-}"
  shell_name="${SHELL:-}"
  repo="$(pwd 2>/dev/null || true)"

  ruby_ver="$(cat ruby/.ruby-version 2>/dev/null || echo "unknown")"
  node_ver="$(cat node/.node-version 2>/dev/null || echo "unknown")"

  cat <<EOF
=========================================
    E T I E N N E ' S   D O T F I L E S
=========================================
 Target OS : ${os}
 Host      : ${host}
 User      : ${user}
 Shell     : ${shell_name}
 Repo      : ${repo}

 Ruby      : ${ruby_ver}
 Node      : ${node_ver}

 Manager   : brew-first
 Fallbacks : yay (arch) | apt (debian) | flatpak (linux)

 Press Ctrl+C to abort at any time.
-----------------------------------------
EOF
}

run_task() {
  local task="$1"
  local root="$2"
  local path="${root}/install/tasks/${task}"

  [[ -x "$path" ]] || {
    printf 'error: task is missing or not executable: %s\n' "$path" >&2
    exit 1
  }

  "$path"
}

main() {
  clear
  print_logo

  # Ensure we run relative to repo root, regardless of invocation location.
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$root"

  # Detect OS early (for nicer splash output). This is informational only;
  # the task scripts do their own OS detection.
  if [[ -f "${root}/install/utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${root}/install/utils.sh"
    determine_os || true
  fi

  log "Detected OS: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  # Re-render splash with detected OS for a nicer UX
  clear
  print_logo

  # Steps (each also runnable manually):
  #
  # NOTE (manual step): OS updates are intentionally NOT run by this installer.
  # If you want to update your OS now, run this in a separate command:
  #
  #   ./install/tasks/10_update_os.sh
  #
  log "Manual step (not run automatically): update OS with: ./install/tasks/10_update_os.sh"
  run_task "15_ensure_prereqs.sh" "$root"
  run_task "20_install_brew_packages.sh" "$root"
  run_task "21_install_aur_packages.sh" "$root"
  run_task "22_install_apt_packages.sh" "$root"
  run_task "23_install_flatpak_packages.sh" "$root"
  run_task "30_install_default_ruby.sh" "$root"
  run_task "31_install_default_node.sh" "$root"
  run_task "40_install_default_ruby_gems.sh" "$root"
  run_task "41_install_default_npm_packages.sh" "$root"
  run_task "50_stow_all.sh" "$root"

  log "Setup complete! You may want to restart your shell (or reboot)."
}

main "$@"
