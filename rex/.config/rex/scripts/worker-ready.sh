#!/usr/bin/env bash
# Sourced by hand-off-plan.sh and start-review.sh. Defines:
#   wait_until_idle <block>   waits for an agent record (claude-code or codex) in the block's program_status to be idle; 1 on timeout
#   send_prompt <block> <text>   types the text into the block and presses enter
# REX_READY_TIMEOUT (default 60) and REX_READY_POLL (default 1) are seconds.

block_state() {
  local request
  request=$(jq -cn --arg id "$1" '{block_id: $id, method: "program_status"}')
  rex api call -s "$REX_SESSION" block.method "$request" 2>/dev/null |
    jq -r 'first(.records[]? | select(.app == "claude-code" or .app == "codex") | select(.state == "idle") | .state) // empty' 2>/dev/null || true
}

wait_until_idle() {
  local block=$1 deadline
  deadline=$((SECONDS + ${REX_READY_TIMEOUT:-60}))
  while [ "$(block_state "$block")" != "idle" ]; do
    [ "$SECONDS" -lt "$deadline" ] || return 1
    sleep "${REX_READY_POLL:-1}"
  done
}

send_prompt() {
  rex send -s "$REX_SESSION" -b "$1" "$2" >/dev/null
  rex send-key -s "$REX_SESSION" -b "$1" enter >/dev/null
}

# Closes a worker that never became ready, so no block is left behind.
abandon_worker() {
  echo "The $2 in block $1 was not ready (state idle) in time; closed it." >&2
  rex block close -s "$REX_SESSION" "$1" >/dev/null 2>&1 || true
}
