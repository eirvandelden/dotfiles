#!/usr/bin/env bash
# open-pr-dash.sh <slug> <pr-url>
#
# Opens a herdr pane running gh-dash, filtered to this branch's pull request, right of the last
# pane of the change's row (open-column.sh --unlisted). The pane is not in the row record, so
# deliver never closes it.
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

scripts_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
pane=$("$scripts_dir/open-column.sh" "$toplevel" --row "$slug" --unlisted)

herdr pane run "$pane" gh dash --config "$config" >/dev/null

echo "$url"
echo "Opened gh-dash in pane $pane, right of the last pane of the change's row."
