#!/usr/bin/env bash
# install/tasks/27_register_work_core.sh
#
# Work core task script (macOS and SteamOS).
#
# Purpose:
# - Start the `work` herdr-core and register it as the `work` machine with the `default` core, so
#   herdr-app shows work and personal as two sidebar groups.
#
# Usage:
#   ./install/tasks/27_register_work_core.sh
#
# Notes:
# - herdr-core arrives with herdr-app's first open, so a fresh machine has no `hc` yet. The task warns
#   and returns; run the installer again after opening herdr-app once.
# - `hc server status` starts a core that is not running, so a status call is also a start. The task
#   never stops or restarts a core, except `hc machine update work` while the work core holds no live
#   terminal (that restart ends nothing). With a live terminal the task dies and changes nothing.
# - A `work` machine with another session or transport is Etienne's call: the task never replaces it.
#
# Idempotency:
# - Designed to be safe to run multiple times; a machine is added only when none is named `work`.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

readonly WORK_CORE_VIA="sh -c"

# Runs hc against the work core.
work_core_hc() { HC_SESSION=work hc "$@"; }

# Runs hc against the default core, the one herdr-app talks to.
default_hc() { HC_SESSION=default hc "$@"; }

work_core_running() { work_core_hc server status --json >/dev/null 2>&1; }

work_core_start() { work_core_hc server start >/dev/null; }

# Prints the machines the default core knows, as JSON.
work_core_machines() { default_hc machine ls --json; }

# True when a machine named work exists, in the JSON on stdin.
work_core_listed() { jq -e '.machines[] | select(.name == "work")' >/dev/null; }

# Dies unless the registered work machine is the work core reached through `sh -c`.
work_core_registered() {
  jq -e --arg via "$WORK_CORE_VIA" \
    '.machines[] | select(.name == "work" and .session == "work" and .via == true and .target == $via)' >/dev/null \
    || die "work core: a machine named work exists with another session or transport; change it by hand"
}

# Dies, naming the count, unless the work core holds no live terminal; then updates it.
work_core_update() {
  local live
  live="$(work_core_hc ls --json | jq '[.terminals[]? | select(.state == "live")] | length')"
  [[ "$live" == "0" ]] || die "work core: too old to register, and ${live} live terminal(s) would end; nothing changed"
  default_hc machine update work >/dev/null
  log "work core: updated."
}

# Registers the work core; on a "too old" refusal, updates an empty core once and tries again.
work_core_register() {
  local output
  if output="$(default_hc machine add --via "$WORK_CORE_VIA" --name work --session work --json 2>&1)"; then
    return 0
  fi

  [[ "$output" == *"too old"* ]] || die "work core: could not register it: ${output}"
  work_core_update
  default_hc machine add --via "$WORK_CORE_VIA" --name work --session work --json >/dev/null
}

# Warns with the machine's own reason when the default core cannot reach the work core.
work_core_reachable() {
  local state why machines
  machines="$(work_core_machines)"
  state="$(jq -r '.machines[] | select(.name == "work") | .state' <<< "$machines")"
  [[ "$state" == "connected" ]] && return 0

  why="$(jq -r '.machines[] | select(.name == "work") | .why // empty' <<< "$machines")"
  warn "work core: the work machine is ${state}${why:+: ${why}}; check that hc is on the default core's PATH."
}

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if [[ "${OS:-Unknown}" != "macOS" && "${OS:-Unknown}" != "SteamOS" ]]; then
    log "work core: not macOS or SteamOS, skipping."
    return 0
  fi

  if ! need_cmd hc; then
    warn "work core: hc is missing; open herdr-app once, then run this step again."
    return 0
  fi

  work_core_running || work_core_start

  local machines
  machines="$(work_core_machines)"
  if work_core_listed <<< "$machines"; then
    work_core_registered <<< "$machines"
    log "work core: already registered."
  else
    work_core_register
    log "work core: registered with the default core."
  fi

  work_core_reachable
}

main "$@"
