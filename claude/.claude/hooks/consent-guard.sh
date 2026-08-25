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

# A git command can act on a checkout other than the tool's working directory,
# through `git -C <path>` or a leading `cd <path> &&`. Read the branch and the
# remotes there. A path that cannot be resolved falls back to the working
# directory, so an unparsable command is judged by where the agent stands
# rather than waved through.
git_repo_dir() {
  local dir="$cwd"
  if [[ "$command" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    dir="${BASH_REMATCH[1]}"
  elif [[ "$command" =~ (^|[[:space:]])cd[[:space:]]+([^[:space:]\&\;\|]+) ]]; then
    dir="${BASH_REMATCH[2]}"
  fi
  [[ -d "$dir" ]] || dir="$cwd"
  printf '%s' "$dir"
}

current_branch() {
  local dir
  dir=$(git_repo_dir)
  [[ -n "$dir" ]] || return 0
  git -C "$dir" branch --show-current 2>/dev/null || true
}

# Prints one line per git invocation found in the command, as the subcommand
# followed by its first non-flag argument: "push origin", "commit". Reading the
# command as tokens rather than matching "git push" as text keeps redirects,
# pipes and quoted prose from being mistaken for a remote name, and still finds
# a push that sits behind git's own flags, as in "git -C <dir> push".
git_invocations() {
  local token seen_git=false skip_flag_value=false invocation="" wants_argument=false

  # Runs inside a command substitution, so disabling globbing here cannot leak
  # into the rest of the hook. Without it a token like *.md would expand to
  # whatever happens to be on disk and be read as an argument.
  set -f
  for token in $command; do
    if $wants_argument; then
      [[ "$token" == -* ]] && continue

      # A redirect or shell operator ends the invocation, so anything past it
      # belongs to another command rather than to this subcommand. A bare "git"
      # starts the next invocation and is never an argument to this one.
      if [[ "$token" != *[\|\&\;\<\>]* && "$token" != "git" ]]; then
        invocation="$invocation $token"
      fi

      printf '%s\n' "$invocation"
      invocation=""
      wants_argument=false
      [[ "$token" == "git" ]] && seen_git=true
      continue
    fi

    if $skip_flag_value; then
      skip_flag_value=false
      continue
    fi

    case "$token" in
      git) seen_git=true ;;
      -C | -c | --git-dir | --work-tree | --namespace | --super-prefix)
        $seen_git && skip_flag_value=true
        ;;
      -*) ;;
      *)
        if $seen_git; then
          invocation="$token"
          wants_argument=true
        fi
        # Any other word starts a different command, so a later bare "push" is
        # not this git's push.
        seen_git=false
        ;;
    esac
  done

  if [[ -n "$invocation" ]]; then
    printf '%s\n' "$invocation"
  fi

  return 0
}

remote_allowed() {
  local remote="$1" url
  url=$(git -C "$(git_repo_dir)" remote get-url "$remote" 2>/dev/null) || return 1
  [[ "$url" =~ github\.com[:/]eirvandelden/ ]] && return 0
  [[ "$url" =~ github\.com[:/]nedap/(caren3|ons-client)(\.git)?$ ]] && return 0
  return 1
}

is_git_write=false
is_git_push=false
push_remote=""

while IFS= read -r invocation; do
  case "$invocation" in
    push)
      is_git_write=true
      is_git_push=true
      ;;
    "push "*)
      is_git_write=true
      is_git_push=true
      push_remote="${invocation#push }"
      ;;
    commit | "commit "*) is_git_write=true ;;
  esac
done <<<"$(git_invocations)"

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

  if $is_git_push; then
    remote="${push_remote:-origin}"
    if ! remote_allowed "$remote"; then
      consent_required "Blocked: pushing to remote '$remote' isn't on the unattended allowlist — eirvandelden/*, nedap/caren3, nedap/ons-client (playbook rule 19)."
    fi
  fi
fi

if [[ "$command" =~ gh[[:space:]]+(pr|issue)[[:space:]]+comment ]] || [[ "$command" =~ gh[[:space:]]+pr[[:space:]]+review ]]; then
  consent_required "Blocked: posting comments or reviews on GitHub as the user needs explicit approval for that exact message (playbook rule 6). Draft the text in chat instead."
fi

if [[ "$command" =~ kamal[[:space:]]+(deploy|app[[:space:]]+exec) ]] || [[ "$command" =~ cap[[:space:]]+([a-z]+[[:space:]]+)?deploy ]]; then
  consent_required "Blocked: deploy commands need the user's explicit approval (playbook rule 13)."
fi

exit 0
