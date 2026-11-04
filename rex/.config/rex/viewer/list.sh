#!/usr/bin/env bash
# Prints "<status><TAB><path>" rows for every file changed against a base, sorted by path.
# Usage: list.sh <root> <base>
# Sources: tracked changes against <base> (committed and uncommitted), and untracked files as "?".
# A path with a tab or newline is not supported. Only reads.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: list.sh <root> <base>" >&2
  exit 2
fi

cd "$1"
base="$2"

tracked() {
  git -c core.quotepath=off --no-optional-locks diff --no-renames --name-status "$base" -- |
    awk -F '\t' '{ print substr($1, 1, 1) "\t" $2 }'
}

untracked() {
  git -c core.quotepath=off --no-optional-locks ls-files -o --exclude-standard |
    awk '{ print "?\t" $0 }'
}

{ tracked; untracked; } | LC_ALL=C sort -t "$(printf '\t')" -k2,2
