#!/usr/bin/env bash
# install/tasks/51_configure_glow_style.sh
#
# Glow style task script (macOS only).
#
# Purpose:
# - Point `style:` in glow's live config at the stowed Solunized style.
# - Glow 3.0.0 resolves a style file from every directory only through an absolute path.
#   `~/…` and `$HOME/…` pass glow's own check but fail in glamour. The repository is public
#   and must work for any home directory, so the path is written here from the real $HOME
#   instead of living in a stowed glow.yml.
#
# Usage:
#   ./install/tasks/51_configure_glow_style.sh
#
# Notes:
# - Only the `style:` line changes. Every other line of an existing glow.yml stays.
# - Glow on Linux reads ~/.config/glow/glow.yml; this step does not configure it.
# - Skips with a warning when the stowed style is missing: a `style:` that points at a
#   missing file makes every glow call fail.
#
# Idempotency:
# - Designed to be safe to run multiple times; writes the config only when the result
#   differs from what is there.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

# Replace every `style:` line, or append one when none exists. The path goes in through ENVIRON
# so awk applies no escape processing to it. Comment lines start with `#` and never match.
rewrite_style() {
  local config="$1"

  GLOW_STYLE_PATH="$2" awk '
    /^style:/ { print "style: \"" ENVIRON["GLOW_STYLE_PATH"] "\""; seen = 1; next }
    { print }
    END { if (!seen) print "style: \"" ENVIRON["GLOW_STYLE_PATH"] "\"" }
  ' "$config"
}

# Write through `cat` rather than `mv`, so a config that is a symlink or has its own mode keeps
# that identity.
set_style() {
  local config="$1" style="$2" updated

  mkdir -p "$(dirname "$config")"
  [[ -e "$config" ]] || : >"$config"

  updated="$(mktemp)"
  rewrite_style "$config" "$style" >"$updated"

  if cmp -s "$updated" "$config"; then
    log "glow: style already set, skipping."
  else
    cat "$updated" >"$config"
    log "glow: style set to ${style}."
  fi

  rm -f "$updated"
}

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if [[ "${OS:-Unknown}" != "macOS" ]]; then
    log "glow: not macOS, skipping."
    return 0
  fi

  require_cmd awk cmp mktemp

  local glow_dir="${HOME}/Library/Preferences/glow"
  local style="${glow_dir}/solunized.json"

  if [[ ! -e "$style" ]]; then
    warn "glow: ${style} is missing (stow the glow package first), skipping."
    return 0
  fi

  set_style "${glow_dir}/glow.yml" "$style"
}

main "$@"
