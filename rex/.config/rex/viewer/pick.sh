#!/usr/bin/env bash
# Opens the changed-files viewer. Usage: pick.sh <dir>
# `pick.sh toggle` prints the fzf action that flips the view, from $FZF_PROMPT ("default> " or
# "alternate> "). The view lives only in the prompt and in the preview command, so there is no state file.
# `pick.sh notice <message>` prints the message and waits for one key.
# The binds hold no paths. fzf runs them through a shell that inherits the VIEWER_* variables below,
# so a space or a bracket in a path cannot split a bind.
set -euo pipefail

preview_action() {
  printf 'change-prompt(%s> )+change-preview("$VIEWER_DIR"/preview.sh "$VIEWER_ROOT" "$VIEWER_BASE" %s {1} {2})' \
    "$1" "$1"
}

notice() {
  printf '%s\n' "$1"
  read -rsn1 || true
}

if [ $# -eq 0 ]; then
  echo "usage: pick.sh <dir>" >&2
  exit 2
fi

if [ "$1" = "toggle" ]; then
  case "${FZF_PROMPT:-}" in
    "alternate> ") preview_action default ;;
    *) preview_action alternate ;;
  esac
  exit 0
fi

if [ "$1" = "notice" ]; then
  notice "${2:-}"
  exit 0
fi

VIEWER_DIR="$(cd "$(dirname "$0")" && pwd)"
if ! located="$("$VIEWER_DIR"/base.sh "$1" 2>/dev/null)"; then
  notice "Not a git repository"
  exit 0
fi
VIEWER_ROOT="${located%%$'\t'*}"
VIEWER_BASE="${located#*$'\t'}"
export VIEWER_DIR VIEWER_ROOT VIEWER_BASE

rows="$("$VIEWER_DIR"/list.sh "$VIEWER_ROOT" "$VIEWER_BASE")"
if [ -z "$rows" ]; then
  notice "No changed files"
  exit 0
fi

fzf --disabled --layout=reverse --delimiter '\t' --with-nth 1.. --prompt 'default> ' \
  --preview '"$VIEWER_DIR"/preview.sh "$VIEWER_ROOT" "$VIEWER_BASE" default {1} {2}' \
  --preview-window 'right,70%' \
  --header 'j/k move, ctrl-d/u scroll, v diff or content, q close' \
  --bind 'j:down' \
  --bind 'k:up' \
  --bind 'ctrl-d:preview-half-page-down' \
  --bind 'ctrl-u:preview-half-page-up' \
  --bind 'v:transform("$VIEWER_DIR"/pick.sh toggle)' \
  --bind 'q:abort' \
  --bind 'esc:abort' <<<"$rows" || true
