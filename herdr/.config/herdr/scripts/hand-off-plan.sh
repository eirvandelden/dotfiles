#!/usr/bin/env bash
# hand-off-plan.sh <plan-file>
#
# Hands a written plan to a fresh Claude worker in a new Herdr tab.

set -euo pipefail

if [ "${HERDR_ENV:-}" != "1" ] || [ -z "${HERDR_PANE_ID:-}" ]; then
  echo "Not running inside a Herdr pane: there is no session to open a tab in, and nobody to report back to." >&2
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

common_git_dir=$(git rev-parse --path-format=absolute --git-common-dir)
main_checkout=$(dirname "$common_git_dir")

tab=$(herdr tab create \
  --workspace "$HERDR_WORKSPACE_ID" \
  --cwd "$main_checkout" \
  --label handoff \
  --no-focus)
pane=$(printf '%s' "$tab" | jq -r '.result.root_pane.pane_id')

# Pane ids are unique for the life of the session, so they make a good name. They also carry
# uppercase letters (w1:pV), which Herdr's agent names may not, hence the lowercasing. Two ids
# differing only in case would collide, and Herdr would refuse the duplicate name outright.
worker="handoff-${pane//:/-}"
worker=$(printf '%s' "$worker" | tr '[:upper:]' '[:lower:]')

herdr agent start "$worker" --kind claude --pane "$pane" -- --model sonnet >/dev/null

# Claude runs on the terminal's alternate screen, so the report cannot be read back out of the
# pane. A file in the shared git directory can be: it never shows up in the tree, and it
# outlives the caller's worktree, which the next task's worktree sweep may remove.
report="$common_git_dir/herdr/$worker.md"
mkdir -p "$(dirname "$report")"
# Pane ids are recycled across sessions, so emptied first: a caller must never read a report
# left by an earlier worker as if it were this one.
: >"$report"

# No --wait: the caller hands the work over and carries on.
herdr agent prompt "$worker" "You are taking over a plan written by another agent. Read $plan in \
full; it is the only context you get. Invoke the worktree-first skill before writing anything, so \
all work happens in its own git worktree instead of the main checkout. Read the applicable \
agents.md and CLAUDE.md, then execute only that plan: do not widen the scope and do not hand the \
work onward. Done means all tests green, all linters green, and a self-reviewed diff. Then write \
what you did, and anything you could not finish, as Markdown to $report. Then report back to the \
agent that handed this over, with herdr agent prompt, sending pane $HERDR_PANE_ID the single line \
Handoff done: followed by that file path. Quote the path yourself. That call is rejected while the \
initiator is blocked on a prompt of its own, so if it fails, wait a few seconds and send it again \
until it is accepted." >/dev/null

echo "Handed $plan to $worker in a new tab. Its report will land in $report."
