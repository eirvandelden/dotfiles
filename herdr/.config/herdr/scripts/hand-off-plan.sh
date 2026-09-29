#!/usr/bin/env bash
# hand-off-plan.sh <stage> <change-slug>
#
# Hands a stage (spec, plan, or implement) of docs/changes/<change-slug> to a fresh Claude worker
# in a pane below the caller. The worktree is created first and the worker starts inside it,
# already past worktree-first.

set -euo pipefail

if [ "${HERDR_ENV:-}" != "1" ] || [ -z "${HERDR_PANE_ID:-}" ]; then
  echo "Not running inside a Herdr pane: there is nothing to split, and nobody to report back to." >&2
  exit 1
fi

stage="${1:-}"
slug="${2:-}"

accepted_then_push="Once Etienne says the literal word \"accepted\" and the skill has committed \
the artifact, push the branch (git push -u origin HEAD)."

case "$stage" in
  spec)
    model="opus"
    ready_word="Spec ready:"
    role_instruction="Invoke the spec skill's here backend for docs/changes/$slug; it reads \
docs/changes/$slug/intent.md, the only context you get."
    acceptance_instruction="$accepted_then_push"
    report_instruction="Then write what spec.md decided and anything Etienne deferred, as \
Markdown to"
    ;;
  plan)
    model="opus"
    ready_word="Plan ready:"
    role_instruction="Invoke the plan skill's Write role, here backend, for docs/changes/$slug; \
it reads docs/changes/$slug/intent.md and docs/changes/$slug/spec.md, the only context you get."
    acceptance_instruction="$accepted_then_push"
    report_instruction="Then write what plan.md decided and anything Etienne deferred, as \
Markdown to"
    ;;
  implement)
    model="sonnet"
    ready_word="Handoff done:"
    role_instruction="Invoke the implement skill's here backend for docs/changes/$slug; you are \
already inside the worktree, so no further pane split is needed. It reads \
docs/changes/$slug/plan.md. Done means all tests green, all linters green, and a self-reviewed \
diff."
    acceptance_instruction="Once the skill is done, stop there and leave the branch for the \
review pane and /finish to send onward."
    report_instruction="Then write what you did, and anything you could not finish, as Markdown \
to"
    ;;
  *)
    echo "Usage: hand-off-plan.sh <stage> <change-slug>. <stage> must be one of spec, plan, \
implement." >&2
    exit 1
    ;;
esac

if [ -z "$slug" ]; then
  echo "Usage: hand-off-plan.sh <stage> <change-slug>. The change slug names both the change \
folder and the worktree." >&2
  exit 1
fi

# The worker starts in its own worktree off the main checkout, not the caller's worktree:
# worktree-first skips itself when it is already inside a linked worktree, which would put a
# second agent on the caller's own branch and directory.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository: the worker has nowhere to create its worktree." >&2
  exit 1
fi

common_git_dir=$(git rev-parse --path-format=absolute --git-common-dir)

# git worktree list's first "worktree <path>" line is the main working tree, except inside a
# submodule, where git prints the submodule's git directory there instead (reproduced with git
# 2.54.0) — from the submodule's own checkout and from any linked worktree of it alike. That git
# directory's core.worktree points back at the submodule checkout, resolved relative to the git
# directory itself, so it works from both.
main_checkout=$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')
if [ "$(git -C "$main_checkout" rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then
  submodule_worktree=$(git -C "$main_checkout" config --get core.worktree 2>/dev/null || true)
  if [ -n "$submodule_worktree" ]; then
    main_checkout=$(cd "$main_checkout" && cd "$submodule_worktree" && pwd)
  else
    main_checkout=$(git rev-parse --show-toplevel)
  fi
fi

# Claude runs on the terminal's alternate screen, so the report cannot be read back out of the
# pane. A file in the shared git directory can be: it never shows up in the tree, and it outlives
# the caller's worktree, which the next task's worktree sweep may remove.
report_directory="$common_git_dir/herdr"

if ! mkdir -p "$report_directory"; then
  echo "Cannot create that report directory: the worker would have nowhere to report." >&2
  exit 1
fi

# --no-pane: this script splits the worker's own pane below, so worktree-create must not also
# open one, or the worktree ends up with two panes rooted in it.
worktree_tools="${WORKTREE_TOOLS_DIR:-$HOME/.config/git/worktree-tools}"
worker_cwd=$(cd "$main_checkout" && "$worktree_tools/worktree-create" "$slug" --no-pane)

split=$(herdr pane split --current --direction down --cwd "$worker_cwd" --no-focus)
pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')

# Pane ids are unique for the life of the session, so they make a good name. They also carry
# uppercase letters (w1:pV), which Herdr's agent names may not, hence the lowercasing. Two ids
# differing only in case would collide, and Herdr would refuse the duplicate name outright.
worker="${stage}-${pane//:/-}"
worker=$(printf '%s' "$worker" | tr '[:upper:]' '[:lower:]')

# Pane ids are recycled across sessions, so the file is emptied before the worker can write to it:
# a coordinator must never read a report left by an earlier worker as if it were this one.
report="$report_directory/$worker.md"
: >"$report"

# worktree-pane is the only thing that calls `herdr pane` for a worktree; label reuses that
# instead of renaming the pane here directly.
"$worktree_tools/worktree-pane" label "$worker_cwd" "$pane" >/dev/null

case "$stage" in
  plan)
    herdr agent start "$worker" --kind claude --pane "$pane" -- --model "$model" \
      --permission-mode plan >/dev/null
    ;;
  *)
    herdr agent start "$worker" --kind claude --pane "$pane" -- --model "$model" >/dev/null
    ;;
esac

intro="You are taking over the $stage stage of docs/changes/$slug, in your own git worktree, \
already created at $worker_cwd. Do not invoke worktree-first, and do not create another worktree."

# No --wait: the caller hands the work over and carries on.
herdr agent prompt "$worker" "$intro $role_instruction Read the applicable agents.md and \
CLAUDE.md first. $report_instruction $report. $acceptance_instruction Then report back to the \
agent that handed this over, with \
herdr agent prompt, sending pane $HERDR_PANE_ID the single line $ready_word followed by that \
file path. Quote the path yourself. That call is rejected while the coordinator is blocked on a \
prompt of its own, so if it fails, wait a few seconds and send it again, at most twelve times. \
Whether that report line gets through or not, then run herdr pane close \$HERDR_PANE_ID (your \
own pane's id from your shell, not the coordinator's id above) to close your own pane; the \
report is on disk regardless, so nothing is lost." >/dev/null

echo "Handed the $stage stage of docs/changes/$slug to $worker in a pane below. Its report will \
land in $report."
