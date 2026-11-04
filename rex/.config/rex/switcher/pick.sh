#!/usr/bin/env bash
# Runs fzf over a snapshot of panes. Usage: pick.sh <snapshot> <client_id>
# `pick.sh esc` prints the fzf action for the esc key and nothing else.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" = "esc" ]; then
  case "${FZF_PROMPT:-}" in
    "/ "*) echo "disable-search+clear-query+rebind(w,b,d,a,j,k,/)+change-prompt(> )" ;;
    *) echo "abort" ;;
  esac
  exit 0
fi

snapshot="$1"
client="${2:-}"
trap 'rm -f "$snapshot"' EXIT

note="snapshot taken at open"
filter_bind() {
  local key="$1" name="$2"
  printf '%s:reload(%s/rows.sh %s %s)+change-header(%s, %s)' \
    "$key" "$here" "$key" "$snapshot" "$name" "$note"
}

fzf --disabled --delimiter '\t' --with-nth 1..5 --prompt '> ' \
  --header "all, $note" \
  --bind "start:reload($here/rows.sh a $snapshot)" \
  --bind "$(filter_bind w working)" \
  --bind "$(filter_bind b blocked)" \
  --bind "$(filter_bind d "done")" \
  --bind "$(filter_bind a all)" \
  --bind "j:down" \
  --bind "k:up" \
  --bind "/:enable-search+unbind(w,b,d,a,j,k,/)+change-prompt(/ )" \
  --bind "esc:transform($here/pick.sh esc)" \
  --bind "enter:transform($here/jump.sh $client {6} {7} {8})" <"$snapshot" || true
