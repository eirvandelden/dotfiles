#!/usr/bin/env bash
# open-column.sh <cwd> [--row <slug>] [--new-row | --unlisted] [-- <command>...]
#
# Opens the next column of a change's row of Rex blocks and prints its block id on stdout.
# The row record, <git-common-dir>/rex/stage-panes-<slug>, lists one block id per line, in the
# order the columns opened; deliver closes the listed blocks. Block ids never repeat.
#
# No --row: one block right of the caller block, not recorded.
# --row <slug>: right of the last recorded block when `rex block ls` lists it, else right of the
#   caller block. The new block is appended to the row record.
# --row <slug> --new-row: below the caller block, whatever the record holds. Appended.
# --row <slug> --unlisted: placed like --row, never appended, so deliver never closes it.
# -- <command>...: the new block runs that command instead of a shell.

set -euo pipefail

usage() {
  echo "usage: open-column.sh <cwd> [--row <slug>] [--new-row | --unlisted] [-- <command>...]" >&2
  exit 1
}

[ "$#" -ge 1 ] || usage
cwd=$1
shift

slug=""
new_row=0
unlisted=0
command_words=()
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
    --)
      shift
      command_words=("$@")
      break
      ;;
    *) usage ;;
  esac
done

if [ -z "$slug" ] && { [ "$new_row" = 1 ] || [ "$unlisted" = 1 ]; }; then usage; fi
if [ "$new_row" = 1 ] && [ "$unlisted" = 1 ]; then usage; fi

# Prints the block id of a split, or nothing when Rex refuses it. Rex's own reason goes to
# stderr; the caller silences it for a split that has a fallback.
split_block() {
  local anchor=$1 direction=$2 answer
  local extra=()
  [ "${#command_words[@]}" -eq 0 ] || extra=(-- "${command_words[@]}")
  answer=$(rex split -s "$REX_SESSION" -b "$anchor" --split="$direction" -c "$cwd" --focus=false --json ${extra[@]+"${extra[@]}"}) || return 0
  printf '%s' "$answer" | jq -r '.block_ids[0] // empty' 2>/dev/null || true
}

# Prints the last recorded block when Rex still lists it, else nothing.
row_end() {
  local recorded
  [ -f "${record:-}" ] || return 0
  recorded=$(tail -n 1 "$record")
  [ -n "$recorded" ] || return 0
  if rex block ls -s "$REX_SESSION" --json 2>/dev/null | jq -e --arg id "$recorded" '.blocks[] | select(.block_id == $id)' >/dev/null 2>&1; then
    echo "$recorded"
  fi
}

record=""
if [ -n "$slug" ]; then
  blocks_directory="$(git rev-parse --path-format=absolute --git-common-dir)/rex"
  mkdir -p "$blocks_directory"
  record="$blocks_directory/stage-panes-$slug"
fi

block=""
if [ "$new_row" = 1 ]; then
  block=$(split_block "$REX_BLOCK" below)
else
  anchor=$(row_end)
  [ -z "$anchor" ] || block=$(split_block "$anchor" right 2>/dev/null)
  [ -n "$block" ] || block=$(split_block "$REX_BLOCK" right)
fi

if [ -z "$block" ]; then
  echo "Rex gave no block for the new column." >&2
  exit 1
fi

if [ -n "$slug" ] && [ "$unlisted" = 0 ]; then
  printf '%s\n' "$block" >>"$record"
fi

echo "$block"
