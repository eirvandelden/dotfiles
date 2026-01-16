#!/usr/bin/env bash
# install/tasks/00_common.sh
#
# Shared helpers for runnable install task scripts in `install/tasks/`.
#
# Goals:
# - Keep `install.sh` simple by reusing the same underlying functions.
# - Allow running individual steps manually (especially useful for debugging on SteamOS/Debian).
# - Each task script should be able to (re-)load:
#   - installer utilities (`install/utils.sh`)
#   - installer configuration (`packages.conf`)
#
# Usage from a task script:
#   # shellcheck disable=SC1091
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"
#   task_bootstrap
#   determine_os
#   ensure_prereqs
#
# Notes:
# - This file is meant to be sourced by other bash scripts (not executed directly).
# - We intentionally do not print extra output here; tasks should use `log` / `warn`.

set -euo pipefail

task__this_dir() {
  # Directory containing this common script (install/tasks).
  cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1
  pwd
}

task__repo_root() {
  # Repo root is the parent directory of `install/`.
  local tasks_dir install_dir root
  tasks_dir="$(task__this_dir)"
  install_dir="$(cd "${tasks_dir}/.." >/dev/null 2>&1 && pwd)"
  root="$(cd "${install_dir}/.." >/dev/null 2>&1 && pwd)"
  printf '%s\n' "$root"
}

task__source_utils() {
  local root utils_path
  root="$(task__repo_root)"
  utils_path="${root}/install/utils.sh"

  [[ -f "$utils_path" ]] || {
    printf 'error: utils not found: %s\n' "$utils_path" >&2
    exit 1
  }

  # shellcheck disable=SC1090
  source "$utils_path"
}

task__source_packages_conf() {
  local root conf_path
  root="$(task__repo_root)"
  conf_path="${root}/packages.conf"

  [[ -f "$conf_path" ]] || {
    printf 'error: packages.conf not found: %s\n' "$conf_path" >&2
    exit 1
  }

  # shellcheck disable=SC1090
  source "$conf_path"
}

task_bootstrap() {
  # Load utils and config for task scripts.
  #
  # This ensures task scripts can be run standalone and still share logic with `install.sh`.
  task__source_utils
  task__source_packages_conf
}

task_usage() {
  # Usage: task_usage "<script-name>" "<description>"
  local name="${1:-task}"
  local description="${2:-}"
  if [[ -n "$description" ]]; then
    printf 'Usage: %s\n\n%s\n' "$name" "$description" >&2
  else
    printf 'Usage: %s\n' "$name" >&2
  fi
}
