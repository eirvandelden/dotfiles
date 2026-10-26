#!/usr/bin/env bash
# open-column.sh <cwd> [--row <slug>] [--new-row | --unlisted]
#
# Opens the next column of a change's row of herdr panes and prints its pane id on stdout.
# The row record, <git-common-dir>/herdr/stage-panes-<slug>, lists one "<pane id> <terminal id>"
# line per listed column, in the order the columns opened; deliver closes the listed panes.
#
# No --row: one pane right of the caller pane, not recorded.
# --row <slug>: right of the last recorded pane when it is live (same terminal id, because pane ids
#   are reused), else right of the caller pane. The new pane is appended to the row record.
# --row <slug> --new-row: below the caller pane, whatever the record holds. Appended.
# --row <slug> --unlisted: placed like --row, never appended, so deliver never closes it.

set -euo pipefail

usage() {
  echo "usage: open-column.sh <cwd> [--row <slug>] [--new-row | --unlisted]" >&2
  exit 1
}

[ "$#" -ge 1 ] || usage
cwd=$1
shift

slug=""
new_row=0
unlisted=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --row)
      [ "$#" -ge 2 ] || usage
      slug=$2
      shift 2
      ;;
    --new-row)
      new_row=1
      shift
      ;;
    --unlisted)
      unlisted=1
      shift
      ;;
    *) usage ;;
  esac
done

if [ -z "$slug" ] && { [ "$new_row" = 1 ] || [ "$unlisted" = 1 ]; }; then usage; fi
if [ "$new_row" = 1 ] && [ "$unlisted" = 1 ]; then usage; fi

# Prints the pane id of a split, or nothing when herdr refuses it.
split_pane() {
  local answer
  answer=$(herdr pane split "$@" --cwd "$cwd" --no-focus 2>/dev/null) || return 0
  printf '%s' "$answer" | jq -r '.result.pane.pane_id // empty' 2>/dev/null || true
}

# Prints the last recorded pane when it is live, else nothing.
row_end() {
  local recorded_pane recorded_terminal answer
  [ -f "${record:-}" ] || return 0
  read -r recorded_pane recorded_terminal <<<"$(tail -n 1 "$record")"
  [ -n "$recorded_pane" ] || return 0
  answer=$(herdr pane get "$recorded_pane" 2>/dev/null) || return 0
  if [ "$(printf '%s' "$answer" | jq -r '.result.pane.terminal_id // empty' 2>/dev/null)" = "$recorded_terminal" ]; then
    echo "$recorded_pane"
  fi
}

record=""
if [ -n "$slug" ]; then
  panes_directory="$(git rev-parse --path-format=absolute --git-common-dir)/herdr"
  mkdir -p "$panes_directory"
  record="$panes_directory/stage-panes-$slug"
fi

pane=""
if [ "$new_row" = 1 ]; then
  pane=$(split_pane --current --direction down)
else
  anchor=$(row_end)
  [ -z "$anchor" ] || pane=$(split_pane "$anchor" --direction right)
  [ -n "$pane" ] || pane=$(split_pane --current --direction right)
fi

if [ -z "$pane" ]; then
  echo "herdr gave no pane for the new column." >&2
  exit 1
fi

# The terminal id tells this pane from a later one that reuses its id; without it, nothing is listed.
if [ -n "$slug" ] && [ "$unlisted" = 0 ]; then
  terminal=$(herdr pane get "$pane" 2>/dev/null | jq -r '.result.pane.terminal_id // empty' || true)
  if [ -n "$terminal" ]; then
    printf '%s %s\n' "$pane" "$terminal" >>"$record"
  fi
fi

echo "$pane"
