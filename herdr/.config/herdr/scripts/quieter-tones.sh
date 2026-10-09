#!/usr/bin/env bash
# quieter-tones.sh <source.mp3>...
#
# herdr plays each notification tone at full level and has no volume setting. This writes a
# copy of each source tone at 0.3 of its level (what `afplay -v 0.3` gives) to
# ~/Documents/Tones/herdr/, under the same file name. config.toml points at those copies.
# Run it again after a tone swap. The source is only ever read.

set -euo pipefail

VOLUME=0.3
out_dir="$HOME/Documents/Tones/herdr"
tmp=""

fail() {
  echo "quieter-tones.sh: $1" >&2
  exit 1
}

cleanup() {
  if [ -n "$tmp" ]; then
    rm -f "$tmp"
  fi
}

check_source() {
  local source=$1
  [ -f "$source" ] || fail "no such file: $source"
  case "$source" in
    *.mp3) ;;
    *) fail "not an mp3 (herdr plays only mp3): $source" ;;
  esac
  [ "$(physical_dir "$(dirname "$source")")" != "$(physical_dir "$out_dir")" ] ||
    fail "already a quieter copy: $source"
}

physical_dir() {
  (cd "$1" 2>/dev/null && pwd -P) || echo "$1"
}

quieten() {
  local source=$1
  local name destination
  name=$(basename "$source")
  destination="$out_dir/$name"
  tmp=$(mktemp "$out_dir/.$name.XXXXXX")
  ffmpeg -hide_banner -loglevel error -y -i "$source" -map_metadata -1 \
    -af "volume=$VOLUME" -c:a libmp3lame -q:a 2 -f mp3 "$tmp"
  mv -f "$tmp" "$destination"
  tmp=""
  echo "$destination"
}

[ $# -gt 0 ] || fail "usage: quieter-tones.sh <source.mp3>..."
command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg is not on PATH"
trap cleanup EXIT

for source in "$@"; do
  check_source "$source"
done
mkdir -p "$out_dir"
for source in "$@"; do
  quieten "$source"
done
