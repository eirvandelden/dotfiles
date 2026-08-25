#!/usr/bin/env bash
# start-review.sh
#
# Opens a Claude reviewer beside the caller to look at this branch.

set -euo pipefail

if [ "${HERDR_ENV:-}" != "1" ]; then
  echo "Not running inside Herdr: there is no pane to split." >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository: there is no branch to review. Run this from the repository." >&2
  exit 1
fi

# The remote-tracking branch is kept as-is: stripping it to a local name points the reviewer at a
# branch that may be stale, or may not exist at all in a single-branch clone.
base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)

if [ -n "$base" ]; then
  git fetch --quiet origin "${base#origin/}" 2>/dev/null || true
else
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

# Herdr agent names allow [a-z][a-z0-9_-]{0,31}, and pane ids are unique for the life of the
# session, so a name built from the pane id can never collide with a live reviewer.
# Pane ids carry uppercase letters (w1:pV), which those names may not.
reviewer="review-${pane//:/-}"
reviewer=$(printf '%s' "$reviewer" | tr '[:upper:]' '[:lower:]')

herdr agent start "$reviewer" --kind claude --pane "$pane" -- --model opus >/dev/null

# No --wait: the reviewer works in its own pane while the caller carries on.
herdr agent prompt "$reviewer" "Review the work on this branch. Read git diff $base...HEAD for \
what is committed, and git status plus git diff for the uncommitted changes on top of it. Use the \
code-review skill and the applicable agents.md. Report your findings in this pane, worst first, \
and change nothing." >/dev/null

echo "Asked $reviewer to review this branch against $base."
