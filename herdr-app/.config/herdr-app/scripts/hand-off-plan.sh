#!/usr/bin/env bash
# hand-off-plan.sh <stage> <change-slug> [--auto]
#
# Hands a stage (intent, plan, or implement) of docs/changes/<change-slug> to a fresh Claude worker in
# herdr-app. The intent stage opens in a pane below the coordinator, a new row; plan and implement open as
# the next column of the change's row, right of its last pane (herdr-app-pane open --row).
# The coordinator is HERDR_APP_COORDINATOR (the dispatcher sets it from COORDINATOR), else this terminal.
# The worktree is created first and the worker starts inside it, already past worktree-first. The prompt
# is claude's first argument, so nothing is typed into the pane afterwards.
# Every stage but implement, once accepted, starts the next one in the chain itself.
# The intent stage leaves intent.md uncommitted; the plan stage commits intent.md and plan.md together.
# --auto (plan, implement; autonomous delivery on a personal repository): the worker runs the
# skill in its auto mode, never waits for Etienne's word "accepted", never starts the next stage
# (the coordinator does), and puts open decisions in its report as "Decision needed:" lines.

set -euo pipefail

if [ -z "${HC_TERMINAL_ID:-}" ]; then
  echo "Not running inside a herdr-app terminal: there is nothing to split, and nobody to report back to." >&2
  exit 1
fi

coordinator="${HERDR_APP_COORDINATOR:-$HC_TERMINAL_ID}"
scripts_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
# The worker runs this path from its own shell, so the prompt carries it in full.
pane_cli="${HERDR_APP_PANE:-$(cd "$scripts_dir/../../../.local/bin" && pwd -P)/herdr-app-pane}"

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
already inside the worktree, so no further pane split is needed. It reads \
docs/changes/$slug/plan.md. Done means all tests green, all linters green, and a self-reviewed \
diff."
    acceptance_instruction="Once the skill is done, push the branch (git push -u origin HEAD); if \
the push is refused, say so in your report and never use --no-verify. Then stop there and leave \
the branch for the review pane and the delivery step to send onward."
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
docs/changes/$slug; you are already inside the worktree, so no further pane split is needed. It \
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
# submodule, where git prints the submodule's git directory there instead. That git directory's
# core.worktree points back at the submodule checkout, resolved relative to the git directory itself.
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
report_directory="$common_git_dir/herdr-app"

if ! mkdir -p "$report_directory"; then
  echo "Cannot create that report directory: the worker would have nowhere to report." >&2
  exit 1
fi

# --no-pane: this script opens the worker's own pane, so worktree-create must not also
# open one, or the worktree ends up with two panes rooted in it.
worktree_tools="${WORKTREE_TOOLS_DIR:-$HOME/.config/git/worktree-tools}"
worker_cwd=$(cd "$main_checkout" && "$worktree_tools/worktree-create" "$slug" --no-pane)

# A new, unique, empty file before the worker starts: a coordinator must never read a stale report.
# BSD mktemp fills only trailing X's, so the .md comes after.
report=$(mktemp "$report_directory/$stage-XXXXXX")
mv "$report" "$report.md"
report="$report.md"

placement=()
position="in the next column of its row"
if [ "$stage" = "intent" ]; then
  placement=(--new-row)
  position="in a pane below"
fi

intro="You are taking over the $stage stage of docs/changes/$slug, in your own git worktree at \
$worker_cwd, already created. Do not invoke worktree-first, and do not create another worktree."

# The skill's Accept step owns the chain, so the prompt only names the coordinator: the chained
# stage must report to it, not to this pane, which closes itself right after starting that stage.
# implement has no accepted status line to flip, so it is the one stage that chains nowhere.
chain_instruction=""
if [ "$stage" != "implement" ] && [ "$auto" = 0 ]; then
  chain_instruction=" Your coordinator's herdr-app terminal is $coordinator; the skill's Accept step \
starts the next stage with COORDINATOR=$coordinator. If starting the next stage fails, do not retry: \
include one line in your own report file, named next, saying so and why."
fi

# Autonomous delivery: the intent session itself coordinates the stages, so its stage panes report
# to it, and the terminal that started it hears only the final account. The condition comes before the
# report-and-close steps, so the last instruction the worker reads never closes a coordinator.
intent_branch=""
if [ "$stage" = "intent" ]; then
  intent_branch=" If intent.md records Delivery: autonomous, follow the intent skill's Autonomous \
delivery section instead of the chain above and the report steps below. You coordinate that \
delivery yourself: pass your own terminal id (\$HC_TERMINAL_ID in your shell) as COORDINATOR to every \
stage, never the coordinator's id above, and keep your pane open after the intent. When the delivery \
ends, write the account file path into $report, send terminal $coordinator the single line Delivery done: \
followed by the account file path with hc send $coordinator, then close your own pane with $pane_cli close. \
Unless intent.md records Delivery: autonomous, do the following."
fi

prompt="$intro $role_instruction Read the applicable agents.md and \
CLAUDE.md first. $acceptance_instruction$chain_instruction$auto_instruction$intent_branch $report_instruction $report. Then \
report back to the agent that handed this over, in herdr-app terminal $coordinator: run hc send $coordinator with \
the single line $ready_word followed by that file path, as one quoted argument. Quote the path yourself. \
That call can fail while the coordinator is busy, so if it fails, wait a few seconds and send it \
again, at most twelve times. Whether that report line gets through or not, then run \
$pane_cli close (it closes the pane of your own terminal, \$HC_TERMINAL_ID, not the coordinator's) to \
close your own pane; the report is on disk regardless, so nothing is lost."

# herdr-app-pane places the pane, lists it in the row record (deliver closes the row's idle stage panes
# once the PR exists), and waits until hc shows claude; a claude that never starts closes its pane again.
terminal=$("$pane_cli" open "$worker_cwd" --row "$slug" ${placement[@]+"${placement[@]}"} -- claude --model "$model" "$prompt")

echo "Handed the $stage stage of docs/changes/$slug to terminal $terminal $position. Its \
report will land in $report."
