#!/usr/bin/env bash
# hand-off-plan.sh <stage> <change-slug> [--auto]
#
# Hands a stage (intent, plan, or implement) of docs/changes/<change-slug> to a fresh
# Claude worker. The intent stage opens in a block below the caller, a new row; plan and implement
# open as the next column of the change's row, right of its last block (open-column.sh).
# The worktree is created first and the worker starts inside it, already past worktree-first.
# Every stage but implement, once accepted, starts the next one in the chain itself.
# The intent stage leaves intent.md uncommitted; the plan stage commits intent.md and plan.md together.
# --auto (plan, implement; autonomous delivery on a personal repository): the worker runs the
# skill in its auto mode, never waits for Etienne's word "accepted", never starts the next stage
# (the coordinator does), and puts open decisions in its report as "Decision needed:" lines.

set -euo pipefail

if [ -z "${REX_SESSION:-}" ] || [ -z "${REX_BLOCK:-}" ]; then
  echo "Not running inside a Rex block: there is nothing to split, and nobody to report back to." >&2
  exit 1
fi

stage="${1:-}"
slug="${2:-}"
auto=0
case "${3:-}" in
  "") ;;
  --auto) auto=1 ;;
  *)
    echo "Usage: hand-off-plan.sh <stage> <change-slug> [--auto]. The only option is --auto." >&2
    exit 1
    ;;
esac

accepted_then_push="Once Etienne says the literal word \"accepted\" or \"agreed\" and the skill has committed \
intent.md and plan.md, push the branch (git push -u origin HEAD). On a work repository commit-plan commits \
nothing and both files stay local: skip the push."
intent_accepted="Once Etienne says the literal word \"accepted\" or \"agreed\", the skill flips the status and \
you leave intent.md uncommitted: do not commit it and do not push. The plan stage commits it."

case "$stage" in
  intent)
    model="opus"
    ready_word="Intent ready:"
    role_instruction="Invoke the intent skill for docs/changes/$slug; there is no upstream \
artifact yet — this interview is what creates intent.md."
    acceptance_instruction="$intent_accepted"
    report_instruction="Then write what intent.md decided and anything Etienne deferred, as \
Markdown to"
    ;;
  plan)
    model="opus"
    ready_word="Plan ready:"
    role_instruction="Invoke the plan skill's Write role, here backend, for docs/changes/$slug; \
it reads docs/changes/$slug/intent.md, the only context you get. \
Write docs/changes/$slug/plan.md and touch nothing else in this worktree until Etienne says the \
literal word \"accepted\" or \"agreed\"."
    acceptance_instruction="$accepted_then_push"
    report_instruction="Then write what plan.md decided and anything Etienne deferred, as \
Markdown to"
    ;;
  implement)
    model="sonnet"
    ready_word="Handoff done:"
    role_instruction="Invoke the implement skill's here backend for docs/changes/$slug; you are \
already inside the worktree, so no further block split is needed. It reads \
docs/changes/$slug/plan.md. Done means all tests green, all linters green, and a self-reviewed \
diff."
    acceptance_instruction="Once the skill is done, push the branch (git push -u origin HEAD); if \
the push is refused, say so in your report and never use --no-verify. Then stop there and leave \
the branch for the review block and the delivery step to send onward."
    report_instruction="Then write what you did, and anything you could not finish, as Markdown \
to"
    ;;
  *)
    echo "Usage: hand-off-plan.sh <stage> <change-slug>. <stage> must be one of intent, \
plan, implement." >&2
    exit 1
    ;;
esac

if [ "$auto" = 1 ] && [ "$stage" = "intent" ]; then
  echo "--auto is not valid for the intent stage: the intent interview is the human gate." >&2
  exit 1
fi

# Autonomous delivery: the skill's auto mode replaces Etienne's "accepted" with a recorded
# critique, and the coordinator, not the worker, starts the next stage.
auto_instruction=""
if [ "$auto" = 1 ]; then
  auto_instruction=" Put every open decision, one per line, in your report as a line starting \
\"Decision needed:\"; never ask Etienne anything yourself."
  case "$stage" in
    plan)
      role_instruction="Invoke the plan skill's Write role, here backend, with the auto argument \
for docs/changes/$slug; it reads docs/changes/$slug/intent.md, the only context you get. Write docs/changes/$slug/plan.md and touch nothing else in this worktree."
      ;;
    implement)
      role_instruction="Invoke the implement skill's here backend with the auto argument for \
docs/changes/$slug; you are already inside the worktree, so no further block split is needed. It \
reads docs/changes/$slug/plan.md. Done means all tests green, all linters green, and a \
self-reviewed diff."
      ;;
  esac
  if [ "$stage" != "implement" ]; then
    acceptance_instruction="Do not wait for Etienne's word \"accepted\": the skill's auto mode \
accepts the artifact itself after its recorded critique. Once the skill has committed intent.md \
and plan.md, push the branch (git push -u origin HEAD). Do not start the next stage."
  fi
fi

if [ -z "$slug" ]; then
  echo "Usage: hand-off-plan.sh <stage> <change-slug>. The change slug names both the change \
folder and the worktree." >&2
  exit 1
fi

# "plan --auto" with the slug forgotten would otherwise run a non-auto worker on a folder named --auto.
if [[ "$slug" == --* ]]; then
  echo "The change slug \"$slug\" looks like an option: give the slug before --auto." >&2
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
# block. A file in the shared git directory can be: it never shows up in the tree, and it outlives
# the caller's worktree, which the next task's worktree sweep may remove.
report_directory="$common_git_dir/rex"

if ! mkdir -p "$report_directory"; then
  echo "Cannot create that report directory: the worker would have nowhere to report." >&2
  exit 1
fi

# --no-pane: this script splits the worker's own block, so worktree-create must not also
# open one, or the worktree ends up with two blocks rooted in it.
worktree_tools="${WORKTREE_TOOLS_DIR:-$HOME/.config/git/worktree-tools}"
worker_cwd=$(cd "$main_checkout" && "$worktree_tools/worktree-create" "$slug" --no-pane)

# open-column.sh places the block and lists it in the row record, which deliver reads to close this
# change's idle stage blocks once the PR exists.
scripts_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
placement=""
position="in the next column of its row"
if [ "$stage" = "intent" ]; then
  placement="--new-row"
  position="in a block below"
fi
# shellcheck source=worker-ready.sh
source "$scripts_dir/worker-ready.sh"
block=$("$scripts_dir/open-column.sh" "$worker_cwd" --row "$slug" $placement -- claude --model "$model")

# Block ids never repeat, so they make a good name and a report file never belongs to an earlier worker.
worker="${stage}-${block}"

# The file is emptied before the worker gets its prompt: a coordinator must never read a stale report.
report="$report_directory/$worker.md"
: >"$report"

rex block rename -s "$REX_SESSION" "$block" "$worker" >/dev/null

if ! wait_until_idle "$block"; then
  abandon_worker "$block" "$stage worker"
  exit 1
fi

intro="You are taking over the $stage stage of docs/changes/$slug, in your own git worktree at \
$worker_cwd, already created. Do not invoke worktree-first, and do not create another worktree."

# The skill's Accept step owns the chain, so the prompt only names the coordinator: the chained
# stage must report to it, not to this block, which closes itself right after starting that stage.
# implement has no accepted status line to flip, so it is the one stage that chains nowhere.
chain_instruction=""
if [ "$stage" != "implement" ] && [ "$auto" = 0 ]; then
  chain_instruction=" Your coordinator's block id is $REX_BLOCK; the skill's Accept step starts \
the next stage with REX_BLOCK set to that id. If starting the next stage fails, do not retry: \
include one line in your own report file, named next, saying so and why."
fi

# Autonomous delivery: the intent session itself coordinates the stages, so its stage blocks report
# to it, and the block that started it hears only the final account. The condition comes before the
# report-and-close steps, so the last instruction the worker reads never closes a coordinator.
intent_branch=""
if [ "$stage" = "intent" ]; then
  intent_branch=" If intent.md records Delivery: autonomous, follow the intent skill's Autonomous \
delivery section instead of the chain above and the report steps below. You coordinate that \
delivery yourself: pass your own block id (\$REX_BLOCK in your shell) to every stage, never the \
coordinator's id above, and keep your block open after the intent. When the delivery ends, write \
the account file path into $report, send block $REX_BLOCK the single line Delivery done: \
followed by the account file path with rex send -b $REX_BLOCK and rex send-key -b $REX_BLOCK enter, then close your own block. Unless intent.md records Delivery: \
autonomous, do the following."
fi

send_prompt "$block" "$intro $role_instruction Read the applicable agents.md and \
CLAUDE.md first. $acceptance_instruction$chain_instruction$auto_instruction$intent_branch $report_instruction $report. Then \
report back to the agent that handed this over, in block $REX_BLOCK: run rex send -b $REX_BLOCK with the single line \
$ready_word followed by that file path, then rex send-key -b $REX_BLOCK enter. Quote the path yourself. \
That call can fail while the coordinator is busy, so if it fails, wait a few seconds and send it \
again, at most twelve times. Whether that report line gets through or not, then run \
rex block close \$REX_BLOCK (your own block's id from your shell, not the coordinator's id above) to \
close your own block; the report is on disk regardless, so nothing is lost."

echo "Handed the $stage stage of docs/changes/$slug to $worker $position. Its \
report will land in $report."
