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

# Words that run another program, so git can be sitting behind one of them.
# Treating such a word as "not git" would leave `sudo git commit` unguarded.
runs_another_program() {
  case "$1" in
    time | nice | nohup | sudo | env | command | xargs) return 0 ;;
    *) return 1 ;;
  esac
}

# A git command can act on a checkout other than the tool's working directory,
# through `git -C <path>` or a `cd <path> &&` ahead of it. Read the branch and
# the remotes there. Of several `cd`s the last one before the git command wins,
# as it would in the shell, and a `cd` after the command is not what git ran
# in. The shell would expand a leading ~ before git ever saw it, so expand it
# here too. A path that cannot be resolved falls back to the working directory,
# so an unparsable command is judged by where the agent stands rather than
# waved through.
git_repo_dir() {
  local dir="$cwd" token previous="" destination=""

  if [[ "$command" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    dir="${BASH_REMATCH[1]}"
  else
    set -f
    for token in $command; do
      [[ "$token" == "git" ]] && break
      [[ "$previous" == "cd" ]] && destination="$token"
      previous="$token"
    done
    [[ -n "$destination" ]] && dir="$destination"
  fi

  [[ "${dir:0:1}" == '~' ]] && dir="$HOME${dir:1}"
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
  local segment token invocation seen_git skip_flag_value normalised

  # Only a shell operator starts a new command, so splitting on them leaves each
  # segment with its program as the first word. Reading the command as one flat
  # list of words instead would find "git" and "push" inside a commit message and
  # judge the prose as if it were a command.
  normalised=${command//&&/$'\n'}
  normalised=${normalised//||/$'\n'}
  normalised=${normalised//|/$'\n'}
  normalised=${normalised//;/$'\n'}

  # Runs inside a command substitution, so disabling globbing here cannot leak
  # into the rest of the hook. Without it a token like *.md would expand to
  # whatever happens to be on disk and be read as an argument.
  set -f
  while IFS= read -r segment; do
    seen_git=false
    skip_flag_value=false
    invocation=""

    for token in $segment; do
      if $skip_flag_value; then
        skip_flag_value=false
        continue
      fi

      if ! $seen_git; then
        case "$token" in
          # Environment assignments come before the program name.
          *=*) continue ;;
          git) seen_git=true ;;
          *)
            runs_another_program "$token" && continue
            # Anything else is a different program, and this segment is not git's.
            break
            ;;
        esac
        continue
      fi

      case "$token" in
        -C | -c | --git-dir | --work-tree | --namespace | --super-prefix)
          skip_flag_value=true
          ;;
        -*) ;;
        *)
          # A redirect ends the arguments; where it points is not a remote.
          [[ "$token" == *[\|\&\;\<\>]* ]] && break
          invocation="${invocation:+$invocation }$token"
          ;;
      esac
    done

    [[ -n "$invocation" ]] && printf '%s\n' "$invocation"
  done <<<"$normalised"

  return 0
}

remote_allowed() {
  local remote="$1" url
  url=$(git -C "$(git_repo_dir)" remote get-url "$remote" 2>/dev/null) || return 1
  [[ "$url" =~ github\.com[:/]eirvandelden/ ]] && return 0
  [[ "$url" =~ github\.com[:/]nedap/(caren3|ons-client)(\.git)?$ ]] && return 0
  return 1
}

# Prints "yes" when any refspec of the push writes main or master. A refspec's
# destination is what it writes: "source:destination" writes the destination, a
# bare name writes itself, and HEAD writes whichever branch is checked out.
push_writes_default_branch() {
  local checked_out_branch="$1" refspec destination

  set -f
  for refspec in $push_refspecs; do
    destination="${refspec##*:}"
    destination="${destination#+}"
    destination="${destination#refs/heads/}"
    [[ "$destination" == "HEAD" ]] && destination="$checked_out_branch"
    if [[ "$destination" == "main" || "$destination" == "master" ]]; then
      printf 'yes'
      return 0
    fi
  done

  return 0
}

is_git_write=false
is_git_push=false
push_remote=""
push_arguments=""
push_refspecs=""

while IFS= read -r invocation; do
  case "$invocation" in
    push)
      is_git_write=true
      is_git_push=true
      ;;
    "push "*)
      is_git_write=true
      is_git_push=true
      push_arguments="${invocation#push }"
      push_remote="${push_arguments%% *}"
      push_refspecs="${push_arguments#"$push_remote"}"
      push_refspecs="${push_refspecs# }"
      ;;
    commit | "commit "*) is_git_write=true ;;
  esac
done <<<"$(git_invocations)"

if $is_git_write; then
  branch=$(current_branch)
  on_default_branch=false
  [[ "$branch" == "main" || "$branch" == "master" ]] && on_default_branch=true

  if $is_git_push; then
    # A push with no refspec sends the checked-out branch, so the branch is what
    # decides. A push that names refspecs sends only those, so a checkout that
    # merely happens to sit on main does not turn deleting or pushing some other
    # branch into a write to main. The refspecs are read from the parsed push
    # arguments; matching the raw command would find these names in a commit
    # message describing a push.
    if [[ -z "$push_refspecs" ]]; then
      if $on_default_branch; then
        block "Blocked: pushing $branch is never allowed (playbook rule 7). Push a feature branch and open a PR."
      fi
    elif [[ "$(push_writes_default_branch "$branch")" == "yes" ]]; then
      block "Blocked: pushing to main/master is never allowed (playbook rule 7). Push the feature branch and open a PR."
    fi
  elif $on_default_branch; then
    block "Blocked: committing on $branch is never allowed (playbook rule 7). Create a feature branch and open a PR."
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
