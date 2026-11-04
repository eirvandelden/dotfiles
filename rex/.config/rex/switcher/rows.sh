#!/usr/bin/env bash
# Prints the snapshot rows for one filter: w (working), b (blocked), d (done) or a (all).
# Reads the snapshot only. It never calls rex. No match prints one sentinel row.
set -euo pipefail

filter="${1:-}"
snapshot="${2:-}"

case "$filter" in
  w) state=working ;;
  b) state=blocked ;;
  d) state="done" ;;
  a) state="" ;;
  *)
    echo "usage: rows.sh <w|b|d|a> <snapshot>" >&2
    exit 1
    ;;
esac

awk -F'\t' -v state="$state" '
  state == "" || $1 == state { print; found = 1 }
  END { if (!found) printf "\t\t\t\tNo panes match\t\t\t\n" }
' "$snapshot"
