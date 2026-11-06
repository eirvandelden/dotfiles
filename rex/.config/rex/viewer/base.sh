#!/usr/bin/env bash
# Prints "<root><TAB><base sha>" for a directory. Usage: base.sh <dir>
# The root is the git toplevel. The base is the merge-base of HEAD and the base branch, tried in
# this order: origin/HEAD, main, master. With none of them it is HEAD.
# Exit 1 and "Not a git repository" on stderr outside a repository. Only reads.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: base.sh <dir>" >&2
  exit 2
fi

fail() {
  echo "Not a git repository" >&2
  exit 1
}

dir="$1"
[ -n "$dir" ] && [ -d "$dir" ] || fail
root="$(git -C "$dir" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)" || fail
cd "$root"

base_of() {
  local ref
  for ref in origin/HEAD main master; do
    if git rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
      git merge-base HEAD "$ref" 2>/dev/null && return 0
    fi
  done
  return 1
}

base="$(base_of || true)"
[ -n "$base" ] || base="$(git rev-parse --verify --quiet HEAD || echo HEAD)"
printf '%s\t%s\n' "$root" "$base"
