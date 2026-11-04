#!/usr/bin/env bash
# Picks a git project and opens or reuses its Rex session. Usage: pick.sh <client_id>
# Roots come from REX_PROJECT_ROOTS (colon separated). Always exits 0.
set -euo pipefail

client="${1:-}"
roots="${REX_PROJECT_ROOTS:-$HOME/Developer:$HOME/Sites}"

rows() {
  local root dir
  IFS=: read -r -a root_list <<<"$roots"
  for root in "${root_list[@]}"; do
    [ -d "$root" ] || continue
    for dir in "$root"/*/; do
      dir="${dir%/}"
      [ -e "$dir/.git" ] && printf '%s\t%s\n' "$(basename "$dir")" "$dir"
    done
  done
  return 0
}

session_id_for() {
  local name="$1" path="$2" id
  id="$(rex ls --json | jq -r --arg name "$name" '[.sessions[] | select(.label == $name)][0].session_id // empty')"
  [ -n "$id" ] || id="$(rex new "$name" -c "$path" --json | jq -r .session_id)"
  printf '%s\n' "$id"
}

picked="$(rows | fzf --delimiter '\t' --with-nth 1 --prompt 'project> ')" || exit 0
[ -n "$picked" ] || exit 0

name="${picked%%$'\t'*}"
path="${picked#*$'\t'}"
id="$(session_id_for "$name" "$path")"

if ! rex -C "$client" "do" session.select "session_id=$id"; then
  echo "Session \"$name\" is open, but Rex refused to switch to it."
  echo "Turn on Remote Control in Rex Settings > Rex Server, then press Enter."
  read -r _ || true
fi
exit 0
