#!/usr/bin/env bash
# start-review.sh
#
# Opens a Claude reviewer beside the caller to look at this branch.

set -euo pipefail

if [ "${HERDR_ENV:-}" != "1" ] || [ -z "${HERDR_PANE_ID:-}" ]; then
  echo "Not running inside a Herdr pane: there is no pane to split, and nobody to report back to." >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository: there is no branch to review. Run this from the repository." >&2
  exit 1
fi

# The remote-tracking branch is kept as-is: stripping it to a local name points the reviewer at a
# branch that may be stale, or may not exist at all in a single-branch clone.
base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)

if [ -z "$base" ]; then
  for candidate in main master; do
    if git rev-parse --verify --quiet "refs/heads/$candidate" >/dev/null; then
      base="$candidate"
      break
    fi
  done
fi

# Resolved before the pane is opened: a reviewer with no base branch to compare against would sit
# there with nothing to do.
if [ -z "$base" ]; then
  echo "Cannot tell which branch this one grew from: no origin/HEAD, no main branch, no master branch." >&2
  exit 1
fi

split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')

# Pane ids are unique for the life of the session, so they make a good name. They also carry
# uppercase letters (w1:pV), which Herdr's agent names may not, hence the lowercasing. Two ids
# differing only in case would collide, and Herdr would refuse the duplicate name outright.
reviewer="review-${pane//:/-}"
reviewer=$(printf '%s' "$reviewer" | tr '[:upper:]' '[:lower:]')

herdr agent start "$reviewer" --kind claude --pane "$pane" -- --model opus >/dev/null

# Claude runs on the terminal's alternate screen, so the report cannot be read back out of the
# pane. A file in the shared git directory can be: it never shows up in the tree, and it
# outlives the caller's worktree, which the next task's worktree sweep may remove.
report="$(git rev-parse --path-format=absolute --git-common-dir)/herdr/$reviewer.md"
mkdir -p "$(dirname "$report")"

# No --wait: the reviewer works in its own pane while the caller carries on.
herdr agent prompt "$reviewer" "Review the work on this branch. Fetch from origin first so the \
comparison is against current work, then read git diff $base...HEAD for what is committed, and \
git status plus git diff for the uncommitted changes on top of it. Use the code-review skill and \
the applicable agents.md. Write your findings as Markdown to $report, worst first, and change \
nothing. Then tell the agent that asked for the review, in one line, by running: \
herdr agent prompt $HERDR_PANE_ID 'Review ready: $report'" >/dev/null

echo "Asked $reviewer to review this branch against $base. Findings will land in $report."
