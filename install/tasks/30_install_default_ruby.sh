#!/usr/bin/env bash
# install/tasks/30_install_default_ruby.sh
#
# Default Ruby runtime install task script.
#
# Purpose:
# - Install the default Ruby runtime defined by `ruby/.ruby-version`.
# - Useful for running this step manually while debugging on SteamOS/Debian/macOS.
# - Reuses the same underlying installer functions as `install.sh` (from `install/utils.sh`).
#
# Usage:
#   ./install/tasks/30_install_default_ruby.sh
#
# Notes:
# - This task (re-)loads `packages.conf` even though it doesn't directly use lists,
#   to keep all tasks consistent and self-contained.
# - This task does not install gems. Use the dedicated gems task for that.
# - Requires `rv` to be available on PATH (typically installed via Homebrew step).

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  local root version_file
  root="$(task__repo_root)"
  version_file="${root}/ruby/.ruby-version"

  [[ -f "$version_file" ]] || die "ruby version file not found: ${version_file}"

  log "ruby: installing default runtime (from ruby/.ruby-version)…"
  install_ruby_runtime "ruby/.ruby-version"

  log "ruby: default runtime install complete."
}

main "$@"
