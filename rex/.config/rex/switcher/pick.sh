#!/usr/bin/env bash
# Runs fzf over a snapshot of panes. Usage: pick.sh <snapshot> <client_id>
# `pick.sh esc` and `pick.sh slash` print the fzf action for that key and nothing else.
# The prompt holds the state filter: "w> " in list mode, "/w " in search mode. That is how esc
# knows which rows to bring back, without a state file.
# The binds hold no paths and no client id. fzf runs them through a shell that inherits the
# SWITCHER_* variables below, so a space or a bracket in a path cannot split a bind, and an empty
# client id stays an empty argument.
set -euo pipefail

reload_action() {
  printf 'reload("$SWITCHER_DIR"/rows.sh %s "$SWITCHER_SNAPSHOT")' "$1"
}

if [ "${1:-}" = "esc" ]; then
  case "${FZF_PROMPT:-}" in
    "/"?" ")
      filter="${FZF_PROMPT:1:1}"
      printf 'disable-search+clear-query+rebind(w,b,d,a,j,k,/)+%s+change-prompt(%s> )\n' \
        "$(reload_action "$filter")" "$filter"
      ;;
    *) echo "abort" ;;
  esac
  exit 0
fi

if [ "${1:-}" = "slash" ]; then
  echo "enable-search+unbind(w,b,d,a,j,k,/)+change-prompt(/${FZF_PROMPT:0:1} )"
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
  printf '%s:%s+change-header(%s, %s)+change-prompt(%s> )' \
    "$key" "$(reload_action "$key")" "$name" "$note" "$key"
}

fzf --disabled --layout=reverse --delimiter '\t' --with-nth 1..5 --prompt 'a> ' \
  --header "all, $note" \
  --bind "start:$(reload_action a)" \
  --bind "$(filter_bind w working)" \
  --bind "$(filter_bind b blocked)" \
  --bind "$(filter_bind d "done")" \
  --bind "$(filter_bind a all)" \
  --bind "j:down" \
  --bind "k:up" \
  --bind '/:transform("$SWITCHER_DIR"/pick.sh slash)' \
  --bind 'esc:transform("$SWITCHER_DIR"/pick.sh esc)' \
  --bind 'enter:transform("$SWITCHER_DIR"/jump.sh "$SWITCHER_CLIENT" {6} {7} {8})' <"$SWITCHER_SNAPSHOT" || true
