#!/usr/bin/env bash
# Claude Code PreToolUse hook: blocks Bash commands that need the user's
# explicit consent (playbook agents.md section 7). Exit 2 blocks the call and
# feeds stderr back to the agent; exit 0 lets it run.
set -euo pipefail

input=$(cat)
command=$(INPUT="$input" python3 -c 'import json, os; print(json.loads(os.environ["INPUT"]).get("tool_input", {}).get("command", ""))')
cwd=$(INPUT="$input" python3 -c 'import json, os; print(json.loads(os.environ["INPUT"]).get("cwd", ""))')

block() {
  echo "$1" >&2
  exit 2
}

has_user_consent() {
  [[ "$command" =~ ^I_HAVE_USER_CONSENT=1[[:space:]] ]]
}

consent_required() {
  has_user_consent && return 0
  block "$1 Ask the user first; once they explicitly agree, re-run the command prefixed with I_HAVE_USER_CONSENT=1."
}

current_branch() {
  [[ -n "$cwd" ]] || return 0
  git -C "$cwd" branch --show-current 2>/dev/null || true
}

is_git_write=false
[[ "$command" =~ git[[:space:]]+(commit|push)([[:space:]]|$) ]] && is_git_write=true

if $is_git_write; then
  branch=$(current_branch)
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    block "Blocked: committing or pushing on $branch is never allowed (playbook rule 7). Create a feature branch and open a PR."
  fi

  if [[ "$command" =~ git[^\|\&\;]*push[^\|\&\;]*[[:space:]](origin[[:space:]]+)?(main|master)([[:space:]]|$) ]] ||
     [[ "$command" =~ :(main|master)([[:space:]]|$) ]]; then
    block "Blocked: pushing to main/master is never allowed (playbook rule 7). Push the feature branch and open a PR."
  fi

  if [[ "$command" == *"--force"* && "$command" != *"--force-with-lease"* ]]; then
    block "Blocked: plain --force overwrites remote history. Use --force-with-lease instead (playbook rule 20)."
  fi

  if [[ "$command" == *"--no-verify"* ]]; then
    consent_required "Blocked: --no-verify skips the git hooks and needs the user's explicit approval (playbook rule 19)."
  fi
fi

if [[ "$command" =~ gh[[:space:]]+(pr|issue)[[:space:]]+comment ]] || [[ "$command" =~ gh[[:space:]]+pr[[:space:]]+review ]]; then
  consent_required "Blocked: posting comments or reviews on GitHub as the user needs explicit approval for that exact message (playbook rule 6). Draft the text in chat instead."
fi

if [[ "$command" =~ kamal[[:space:]]+(deploy|app[[:space:]]+exec) ]] || [[ "$command" =~ cap[[:space:]]+([a-z]+[[:space:]]+)?deploy ]]; then
  consent_required "Blocked: deploy commands need the user's explicit approval (playbook rule 13)."
fi

exit 0
