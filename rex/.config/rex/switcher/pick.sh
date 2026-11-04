#!/usr/bin/env bash
# Runs fzf over a snapshot of panes. Usage: pick.sh <snapshot> <client_id>
# `pick.sh esc` prints the fzf action for the esc key and nothing else.
# The binds hold no paths and no client id. fzf runs them through a shell that inherits the
# SWITCHER_* variables below, so a space or a bracket in a path cannot split a bind, and an empty
# client id stays an empty argument.
set -euo pipefail

if [ "${1:-}" = "esc" ]; then
  case "${FZF_PROMPT:-}" in
    "/ "*) echo "disable-search+clear-query+rebind(w,b,d,a,j,k,/)+change-prompt(> )" ;;
    *) echo "abort" ;;
  esac
  exit 0
fi

SWITCHER_DIR="$(cd "$(dirname "$0")" && pwd)"
SWITCHER_SNAPSHOT="$1"
SWITCHER_CLIENT="${2:-}"
export SWITCHER_DIR SWITCHER_SNAPSHOT SWITCHER_CLIENT
trap 'rm -f "$SWITCHER_SNAPSHOT"' EXIT

note="snapshot taken at open"
filter_bind() {
  local key="$1" name="$2"
  printf '%s:reload("$SWITCHER_DIR"/rows.sh %s "$SWITCHER_SNAPSHOT")+change-header(%s, %s)' \
    "$key" "$key" "$name" "$note"
}

fzf --disabled --delimiter '\t' --with-nth 1..5 --prompt '> ' \
  --header "all, $note" \
  --bind 'start:reload("$SWITCHER_DIR"/rows.sh a "$SWITCHER_SNAPSHOT")' \
  --bind "$(filter_bind w working)" \
  --bind "$(filter_bind b blocked)" \
  --bind "$(filter_bind d "done")" \
  --bind "$(filter_bind a all)" \
  --bind "j:down" \
  --bind "k:up" \
  --bind "/:enable-search+unbind(w,b,d,a,j,k,/)+change-prompt(/ )" \
  --bind 'esc:transform("$SWITCHER_DIR"/pick.sh esc)' \
  --bind 'enter:transform("$SWITCHER_DIR"/jump.sh "$SWITCHER_CLIENT" {6} {7} {8})' <"$SWITCHER_SNAPSHOT" || true
