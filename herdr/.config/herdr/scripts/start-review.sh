#!/usr/bin/env bash
# start-review.sh
#
# Opens a Claude reviewer beside the caller to look at this branch. Report-only: it reads
# REVIEW.md, this branch's change folder, and the diff, then appends a round to
# docs/changes/<slug>/review.md and commits that file alone — the same contract the `reviewer`
# agent follows for the in-session backend, so one location satisfies the pre-push freshness
# check regardless of which backend produced it.

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

# No --wait: the reviewer works in its own pane while the caller carries on. It derives its own
# change folder and report path (claude/.claude/skills/plan/scripts/change-folder), the same way
# the reviewer agent does, rather than being handed one — a fixed path computed here would go
# stale the moment the pane checks out a different worktree.
herdr agent prompt "$reviewer" "Review the work on this branch. Fetch from origin first so the \
comparison is against current work, then read git diff $base...HEAD for what is committed, and \
git status plus git diff for the uncommitted changes on top of it. Run \
claude/.claude/skills/plan/scripts/change-folder for this branch's change folder, then read \
REVIEW.md (or REVIEW.local.md) at the repository root plus that folder's spec.md and plan.md. \
Run the Bugs, Security and Compliance passes REVIEW.md describes, worst first; rank Important \
before Nit; cap nits at five. Append your round to that folder's review.md (create it on the \
first round) and commit that file alone — change no code, stage nothing else. Then report back \
to the agent that asked, with herdr agent prompt, sending pane $HERDR_PANE_ID the single line \
Review ready: followed by that file's path. Quote the path yourself. That call is rejected while \
the caller is blocked on a prompt of its own, so if it fails, wait a few seconds and send it \
again, at most twelve times. Then stop and say so in your own pane: the report is committed on \
the branch, so nothing is lost." >/dev/null

echo "Asked $reviewer to review this branch against $base. Findings will land in this branch's docs/changes/<slug>/review.md."
