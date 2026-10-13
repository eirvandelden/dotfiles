#!/usr/bin/env bash
# open-pr-dash.sh <slug> <pr-url>
#
# Opens a herdr pane running gh-dash, filtered to this branch's pull request, directly left of the
# pane that wrote the intent. herdr 0.9.3 only splits right or down, so the anchor is split to the
# right and the new pane is swapped into the anchor's place. The intent skill records the anchor in
# <git-common-dir>/herdr/intent-pane-<slug> (pane id, then terminal id). When that pane is gone, or
# its terminal id differs (a recycled pane id), the anchor is this script's own pane.
# Outside herdr it prints the PR URL and opens nothing.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: open-pr-dash.sh <slug> <pr-url>" >&2
  exit 1
fi

slug=$1
url=$2

if [ "${HERDR_ENV:-}" != "1" ] || [ -z "${HERDR_PANE_ID:-}" ]; then
  echo "$url"
  echo "Not inside herdr: no pane opened."
  exit 0
fi

toplevel=$(git rev-parse --show-toplevel)
branch=$(git rev-parse --abbrev-ref HEAD)
common=$(git rev-parse --path-format=absolute --git-common-dir)
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)

config="$common/deliver/$slug.gh-dash.yml"
mkdir -p "$common/deliver"
cat >"$config" <<YAML
defaults:
  view: prs
prSections:
  - title: $slug
    filters: repo:$repo head:$branch
YAML

anchor_for() {
  local file="$common/herdr/intent-pane-$slug" recorded_pane recorded_terminal answer
  if [ -f "$file" ]; then
    recorded_pane=$(sed -n 1p "$file")
    recorded_terminal=$(sed -n 2p "$file")
    if answer=$(herdr pane get "$recorded_pane" 2>/dev/null) &&
      [ "$(printf '%s' "$answer" | jq -r '.result.pane.terminal_id')" = "$recorded_terminal" ]; then
      echo "$recorded_pane"
      return
    fi
  fi
  echo "$HERDR_PANE_ID"
}

anchor=$(anchor_for)
split=$(herdr pane split "$anchor" --direction right --cwd "$toplevel" --no-focus)
pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')

herdr pane swap --source-pane "$pane" --target-pane "$anchor" >/dev/null
herdr pane run "$pane" gh dash --config "$config" >/dev/null

echo "$url"
echo "Opened gh-dash in pane $pane, left of $anchor."
