#!/usr/bin/env bash
# Jumps to a pane: select its session and tab in the app, then focus it.
# Prints an fzf action on stdout and always exits 0.
set -uo pipefail

client="${1:-}"
session="${2:-}"
window="${3:-}"
block="${4:-}"

gone="change-header(Pane no longer exists)"
refused="change-header(Rex refused the jump: turn on Remote Control in Rex settings)"

[ -n "$block" ] || exit 0

pane_exists() {
  rex block ls -s "$session" --json 2>/dev/null |
    jq -e --arg id "$block" '.blocks | any(.block_id == $id)' >/dev/null 2>&1
}

if ! pane_exists; then
  echo "$gone"
elif ! rex -C "$client" "do" session.select "session_id=$session" "window_id=$window" >/dev/null 2>&1; then
  echo "$refused"
elif ! rex focus -s "$session" "$block" >/dev/null 2>&1; then
  echo "$gone"
else
  echo "abort"
fi
exit 0
