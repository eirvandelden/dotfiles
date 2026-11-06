#!/usr/bin/env bash
# sync-solunized-theme.sh
#
# herdr 0.9.5 reads only config.toml: it has no include and theme.name takes built-in names only,
# so the generated Solunized theme files cannot load. This copies the light and dark tables from
# $SOLUNIZED_DIR/dist/herdr/ (default ~/Developer/solunized) into config.toml, between the
# "# BEGIN solunized" and "# END solunized" lines. Black and white are skipped. Every other line
# stays as it is. Run it again after Solunized changes; test/herdr_config_test.rb flags drift.
# HERDR_CONFIG_PATH picks the config (default: the config.toml next to scripts/).
# This script becomes obsolete if herdr adds `include` or theme files.

set -euo pipefail

BEGIN_MARKER="# BEGIN solunized"
END_MARKER="# END solunized"
dist="${SOLUNIZED_DIR:-$HOME/Developer/solunized}/dist/herdr"
config="${HERDR_CONFIG_PATH:-$(cd "$(dirname "$0")/.." && pwd)/config.toml}"
tmp=""

fail() {
  echo "sync-solunized-theme.sh: $1" >&2
  exit 1
}

cleanup() {
  if [ -n "$tmp" ]; then
    rm -f "$tmp"
  fi
}

check_table() {
  local mode=$1 file="$dist/solunized-$1.toml"
  [ -f "$file" ] || fail "no dist table: $file"
  [ "$(head -n 1 "$file")" = "[theme.custom.$mode]" ] ||
    fail "not a $mode table (first line must be [theme.custom.$mode]): $file"
}

check_markers() {
  local marker count
  [ -r "$config" ] || fail "cannot read the config: $config"
  for marker in "$BEGIN_MARKER" "$END_MARKER"; do
    count=$(grep -cx -- "$marker" "$config" || true)
    [ "$count" = 1 ] || fail "expected one '$marker' line, found $count"
  done
  [ "$(grep -nx -- "$BEGIN_MARKER" "$config" | cut -d: -f1)" -lt "$(grep -nx -- "$END_MARKER" "$config" | cut -d: -f1)" ] ||
    fail "'$END_MARKER' comes before '$BEGIN_MARKER'"
}

splice() {
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v light="$dist/solunized-light.toml" -v dark="$dist/solunized-dark.toml" '
    function copy(file, line) { while ((getline line < file) > 0) print line; close(file) }
    $0 == begin { print; copy(light); print ""; copy(dark); skipping = 1; next }
    $0 == end { skipping = 0 }
    !skipping { print }
  ' "$config"
}

[ $# -eq 0 ] || fail "usage: sync-solunized-theme.sh"
check_table light
check_table dark
check_markers
trap cleanup EXIT
tmp=$(mktemp "$config.XXXXXX")
splice > "$tmp"
# cat writes through the path, so a stow link stays a link.
cmp -s "$tmp" "$config" || cat "$tmp" > "$config"
