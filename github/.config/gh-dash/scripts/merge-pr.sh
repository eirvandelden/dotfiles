#!/usr/bin/env bash
# Merge a pull request from gh-dash: ask once, then run the merge with the configured method.
# Usage: merge-pr.sh <owner/repo> <number>
#
# The method comes from git config, repository first, then owner, then "merge":
#   pr-merge.<owner/repo>.method   one repository
#   pr-merge.<owner>.method        every repository of an owner
# Valid values: merge, squash, rebase. Names match case-insensitively.
set -euo pipefail

# Field separator for method and subsection. Unlike a tab, it keeps an empty method as a field.
sep=$'\x1f'

repo=${1:?usage: merge-pr.sh <owner/repo> <number>}
number=${2:?usage: merge-pr.sh <owner/repo> <number>}

lowercase() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# git config exits 1 when nothing matches; any other failure means it cannot read its files.
settings_status=0
settings=$(git config --get-regexp '^pr-merge\..+\.method$' 2>/dev/null) || settings_status=$?
if [ "$settings_status" -gt 1 ]; then
  echo "merge-pr: cannot read the merge method from git config (exit $settings_status); nothing merged" >&2
  exit 2
fi

configured_method() {
  local wanted
  wanted=$(lowercase "$1")
  printf '%s\n' "$settings" | while IFS=" " read -r key value; do
    subsection=${key#pr-merge.}
    subsection=${subsection%.method}
    if [ "$(lowercase "$subsection")" = "$wanted" ]; then
      printf '%s%s%s\n' "$value" "$sep" "$subsection"
    fi
  done | tail -n 1
}

method_for() {
  local setting name
  for name in "$repo" "${repo%%/*}"; do
    setting=$(configured_method "$name")
    if [ -n "$setting" ]; then
      printf '%s\n' "$setting"
      return
    fi
  done
  printf 'merge%s\n' "$sep"
}

IFS=$sep read -r method subsection <<< "$(method_for)"

case "$method" in
  merge | squash | rebase) ;;
  *)
    echo "merge-pr: unknown merge method '$method' in pr-merge.$subsection.method; use merge, squash or rebase" >&2
    exit 2
    ;;
esac

printf 'Merge %s#%s with %s and delete its branch? Enter merges, anything else cancels: ' "$repo" "$number" "$method"
IFS= read -r answer || answer=eof
if [ -n "$answer" ]; then
  echo "Cancelled."
  exit 0
fi

exec gh pr merge "$number" -R "$repo" "--$method" --delete-branch
