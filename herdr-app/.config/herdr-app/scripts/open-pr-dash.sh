#!/usr/bin/env bash
# open-pr-dash.sh <slug> <pr-url>
#
# Opens a herdr-app pane running gh-dash, filtered to this branch's pull request, right of the last
# pane of the change's row (herdr-app-pane open --unlisted). The pane is not in the row record, so
# deliver never closes it.
# Outside herdr-app it prints the PR URL and opens nothing.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: open-pr-dash.sh <slug> <pr-url>" >&2
  exit 1
fi

slug=$1
url=$2

if [ -z "${HC_TERMINAL_ID:-}" ]; then
  echo "$url"
  echo "Not inside herdr-app: no pane opened."
  exit 0
fi

scripts_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
pane_cli="${HERDR_APP_PANE:-$(cd "$scripts_dir/../../../.local/bin" && pwd -P)/herdr-app-pane}"

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

terminal=$("$pane_cli" open "$toplevel" --row "$slug" --unlisted -- gh dash --config "$config")

echo "$url"
echo "Opened gh-dash in terminal $terminal, right of the last pane of the change's row."
