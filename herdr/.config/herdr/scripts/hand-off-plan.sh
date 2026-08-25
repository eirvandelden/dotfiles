#!/usr/bin/env bash
# hand-off-plan.sh <plan-file>
#
# Hands a written plan to a fresh Claude worker in a new Herdr tab.

set -euo pipefail

if [ "${HERDR_ENV:-}" != "1" ]; then
  echo "Not running inside Herdr: there is no session to open a tab in." >&2
  exit 1
fi

plan="${1:-}"

if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo "Usage: hand-off-plan.sh <plan-file>. Write the plan first; the worker reads only that file." >&2
  exit 1
fi

# The worker starts in the main checkout, not in the caller's worktree: worktree-first skips
# itself when it is already inside a linked worktree, which would put a second agent on the
# caller's own branch and directory.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository: the worker has nowhere to create its worktree." >&2
  exit 1
fi

main_checkout=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")

tab=$(herdr tab create \
  --workspace "$HERDR_WORKSPACE_ID" \
  --cwd "$main_checkout" \
  --label handoff \
  --no-focus)
pane=$(printf '%s' "$tab" | jq -r '.result.root_pane.pane_id')

# Herdr agent names allow [a-z][a-z0-9_-]{0,31}, and pane ids are unique for the life of the
# session, so a name built from the pane id can never collide with a live worker.
# Pane ids carry uppercase letters (w1:pV), which those names may not.
worker="handoff-${pane//:/-}"
worker=$(printf '%s' "$worker" | tr '[:upper:]' '[:lower:]')

herdr agent start "$worker" --kind claude --pane "$pane" -- --model sonnet >/dev/null

# No --wait: the caller hands the work over and carries on.
herdr agent prompt "$worker" "You are taking over a plan written by another agent. Read $plan in \
full; it is the only context you get. Invoke the worktree-first skill before writing anything, so \
all work happens in its own git worktree instead of the main checkout. Read the applicable \
agents.md and CLAUDE.md, then execute only that plan: do not widen the scope and do not hand the \
work onward. Done means all tests green, all linters green, and a self-reviewed diff." >/dev/null

echo "Handed $plan to $worker in a new tab."
