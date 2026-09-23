#!/usr/bin/env bash
# hand-off-plan.sh <plan-file> [<worktree-name>]
#
# Hands a written plan to a fresh Claude worker in a pane below the caller. With a worktree name,
# the worktree is created first and the worker starts inside it, already past worktree-first.

set -euo pipefail

if [ "${HERDR_ENV:-}" != "1" ] || [ -z "${HERDR_PANE_ID:-}" ]; then
  echo "Not running inside a Herdr pane: there is nothing to split, and nobody to report back to." >&2
  exit 1
fi

plan="${1:-}"
name="${2:-}"

if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo "Usage: hand-off-plan.sh <plan-file> [<worktree-name>]. Write the plan first; the worker \
reads only that file." >&2
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
repo_name=$(basename "$main_checkout")

# Claude runs on the terminal's alternate screen, so the report cannot be read back out of the
# pane. A file in the shared git directory can be: it never shows up in the tree, and it outlives
# the caller's worktree, which the next task's worktree sweep may remove.
report_directory="$common_git_dir/herdr"

if ! mkdir -p "$report_directory"; then
  echo "Cannot create that report directory: the worker would have nowhere to report." >&2
  exit 1
fi

if [ -n "$name" ]; then
  # --no-pane: this script splits the worker's own pane below, so worktree-create must not also
  # open one, or the worktree ends up with two panes rooted in it.
  worktree_tools="${WORKTREE_TOOLS_DIR:-$HOME/.config/git/worktree-tools}"
  worker_cwd=$(cd "$main_checkout" && ruby "$worktree_tools/worktree-create" "$name" --no-pane)
else
  worker_cwd="$main_checkout"
fi

split=$(herdr pane split --current --direction down --cwd "$worker_cwd" --no-focus)
pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')

# Pane ids are unique for the life of the session, so they make a good name. They also carry
# uppercase letters (w1:pV), which Herdr's agent names may not, hence the lowercasing. Two ids
# differing only in case would collide, and Herdr would refuse the duplicate name outright.
worker="handoff-${pane//:/-}"
worker=$(printf '%s' "$worker" | tr '[:upper:]' '[:lower:]')

# Pane ids are recycled across sessions, so the file is emptied before the worker can write to it:
# an initiator must never read a report left by an earlier worker as if it were this one.
report="$report_directory/$worker.md"
: >"$report"

if [ -n "$name" ]; then
  herdr pane rename "$pane" "$repo_name/$name" >/dev/null
  intro="You are taking over a plan written by another agent. You are already inside your own git \
worktree, at $worker_cwd; do not invoke worktree-first, and do not create another worktree."
else
  intro="You are taking over a plan written by another agent. Invoke the worktree-first skill \
before writing anything, so all work happens in its own git worktree instead of the main checkout."
fi

herdr agent start "$worker" --kind claude --pane "$pane" -- --model sonnet >/dev/null

# No --wait: the caller hands the work over and carries on.
herdr agent prompt "$worker" "$intro Read $plan in full; it is the only context you get. Read the \
applicable agents.md and CLAUDE.md, then execute only that plan: do not widen the scope and do not \
hand the work onward. Done means all tests green, all linters green, and a self-reviewed diff. Then \
write what you did, and anything you could not finish, as Markdown to $report. Then report back to \
the agent that handed this over, with herdr agent prompt, sending pane $HERDR_PANE_ID the single \
line Handoff done: followed by that file path. Quote the path yourself. That call is rejected while \
the initiator is blocked on a prompt of its own, so if it fails, wait a few seconds and send it \
again, at most twelve times. Then stop and say so in your own pane: the report is on disk and its \
path was printed when you were started, so nothing is lost." >/dev/null

echo "Handed $plan to $worker in a pane below. Its report will land in $report."
