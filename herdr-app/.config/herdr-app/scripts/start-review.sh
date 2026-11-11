#!/usr/bin/env bash
# start-review.sh
#
# Opens a Claude reviewer in herdr-app as the next column of the change's row, right of its last pane, to
# look at this branch. Report-only: it reads REVIEW.md, this branch's change folder, and the diff, then
# appends a round to docs/changes/<slug>/review.md and leaves it uncommitted until the review
# converges, then commits it through commit-review and pushes the branch — the same contract the
# `reviewer` agent follows for the in-session backend, so one location satisfies the pre-push
# freshness check regardless of which backend produced it.
# The reviewer reports to HERDR_APP_COORDINATOR (the dispatcher sets it from COORDINATOR), else this terminal.

set -euo pipefail

if [ -z "${HC_TERMINAL_ID:-}" ]; then
  echo "Not running inside a herdr-app terminal: there is no pane to split, and nobody to report back to." >&2
  exit 1
fi

coordinator="${HERDR_APP_COORDINATOR:-$HC_TERMINAL_ID}"
scripts_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
# The reviewer runs this path from its own shell, so the prompt carries it in full.
pane_cli="${HERDR_APP_PANE:-$(cd "$scripts_dir/../../../.local/bin" && pwd -P)/herdr-app-pane}"

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

# deliver closes this change's idle stage panes once the PR exists, and only the panes listed in
# <git-common-dir>/herdr-app/stage-panes-<slug>; herdr-app-pane open --row lists this one. A branch with no
# change folder (main, a detached HEAD) opens right of the coordinator and lists nothing.
skills_dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
folder=$("$skills_dir/plan/scripts/change-folder" 2>/dev/null || true)

# No --wait: the reviewer works in its own pane while the caller carries on. It derives its own
# change folder and report path (~/.claude/skills/plan/scripts/change-folder), the same way
# the reviewer agent does, rather than being handed one — a fixed path computed here would go
# stale the moment the pane checks out a different worktree.
prompt="Review the work on this branch. Fetch from origin first so the \
comparison is against current work, then read git diff $base...HEAD for what is committed, and \
git status plus git diff for the uncommitted changes on top of it. Run \
~/.claude/skills/plan/scripts/change-folder for this branch's change folder, then read \
REVIEW.md (or REVIEW.local.md) at the repository root plus that folder's intent.md and plan.md. \
Run the Bugs, Security, Compliance and Design passes REVIEW.md describes, worst first; rank Important \
before Nit; cap nits at five. Append your round to that folder's review.md (create it on the \
first round) and leave review.md uncommitted — change no code, stage nothing else. Then run \
~/.claude/skills/review/scripts/commit-review, which commits that file alone only when no finding \
is open (on a work repository it commits nothing and exits 0: review.md stays local). Push the branch (git push -u origin HEAD) only when commit-review exits 0; if the push is \
refused, say so in your report and never use --no-verify. Then run ~/.claude/skills/deliver/scripts/deliver --check, which changes nothing. \
Then report back to the terminal that asked: run hc send $coordinator with a single line: \
Review clean: when the check exits 0, else Review ready: when it exits non-zero, \
followed in both cases by that file's path, as one quoted argument. Quote the path yourself. \
That call can fail while the caller is busy, so if it fails, wait a few seconds and send it \
again, at most twelve times. Once the line gets through, on the first try or a retry, run \
$pane_cli close (it closes the pane of your own terminal, \$HC_TERMINAL_ID, not the caller's) to \
close your own pane. If all twelve attempts fail, leave your pane open and say so there: the \
report is in the change folder's review.md, so nothing is lost."

# herdr-app-pane waits until hc shows claude; a claude that never starts closes its pane again.
terminal=$("$pane_cli" open "$(pwd -P)" ${folder:+--row "${folder##*/}"} -- claude --model opus "$prompt")

echo "Asked the reviewer in terminal $terminal to review this branch against $base. Findings will land in this branch's docs/changes/<slug>/review.md."
