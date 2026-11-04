#!/usr/bin/env bash
# Writes the rendering of one changed file to stdout. Usage: preview.sh <root> <base> <view> <status> <path>
# <view> is "default" or "alternate". Default: markdown through glow, an untracked file through bat,
# anything else as a diff through delta. Alternate is the other one. A deleted file is always a diff.
# A missing tool falls back to cat or a plain git diff.
# Every renderer gets "./<path>" or "-- <path>", so a path that starts with "-" is safe. Only reads.
set -euo pipefail

if [ $# -ne 5 ]; then
  echo "usage: preview.sh <root> <base> <view> <status> <path>" >&2
  exit 2
fi

root="$1" base="$2" view="$3" status="$4" path="$5"
cd "$root"

have() {
  command -v "$1" >/dev/null 2>&1
}

show_diff() {
  if have delta; then
    git --no-optional-locks diff "$base" -- "$path" | delta
  else
    git --no-optional-locks diff "$base" -- "$path"
  fi
}

show_markdown() {
  if have glow; then
    glow -s auto -w "${FZF_PREVIEW_COLUMNS:-80}" "./$path"
  else
    cat "./$path"
  fi
}

show_content() {
  if have bat; then
    bat --style=numbers --color=always "./$path"
  else
    cat "./$path"
  fi
}

markdown() {
  case "$path" in
    *.md) return 0 ;;
    *) return 1 ;;
  esac
}

default_view() {
  if markdown; then
    show_markdown
  elif [ "$status" = "?" ]; then
    show_content
  else
    show_diff
  fi
}

alternate_view() {
  if [ "$status" != "?" ] && markdown; then
    show_diff
  else
    show_content
  fi
}

if [ "$status" = "D" ]; then
  show_diff
elif [ "$view" = "alternate" ]; then
  alternate_view
else
  default_view
fi
