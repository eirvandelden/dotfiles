#!/usr/bin/env bash
# play-tone.sh <ready|request|done>
#
# Plays one quiet tone from ~/Documents/Tones/herdr/ with afplay. Claude hooks call it:
# ready on session start, request on a notification, done on stop.
# Herdr and herdr-app play their own tones, so nothing plays in a herdr pane (HERDR_ENV=1) or a herdr-app
# terminal (HC_TERMINAL_ID, even with a leaked REX_SESSION), and nothing plays outside Rex.
# A missing file, a missing folder and an unknown name are not errors: the script plays nothing.

set -euo pipefail

[ "${HERDR_ENV:-}" != 1 ] || exit 0
[ -z "${HC_TERMINAL_ID:-}" ] || exit 0
[ -n "${REX_SESSION:-}" ] || exit 0

case "${1:-}" in
  ready) file="ready-to-serve.mp3" ;;
  request) file="milord.mp3" ;;
  done) file="jobs-done.mp3" ;;
  *) exit 0 ;;
esac

tone="$HOME/Documents/Tones/herdr/$file"
[ -f "$tone" ] || exit 0

afplay "$tone"
