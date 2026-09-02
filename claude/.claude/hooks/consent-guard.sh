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

# Splits the command into one shell command per line. Only an operator starts a
# new command, so each line begins with its own program name. Every reader of
# the command shares this, because a reader that splits differently disagrees
# about which checkout git ran in.
#
# Known limit: quoting is not understood, so an operator inside a quoted
# argument splits it too, and a grouping parenthesis stays glued to the word
# beside it. A message mentioning a command can therefore be read as one, and a
# write inside parentheses can be missed. Closing this needs a quote-aware
# parser; the behaviour it produces today is pinned in the tests named
# "known_limit".
command_segments() {
  local normalised=${command//&&/$'\n'}
  normalised=${normalised//||/$'\n'}
  normalised=${normalised//|/$'\n'}
  normalised=${normalised//;/$'\n'}
  printf '%s\n' "$normalised"
}

# Words that run another program, so git can be sitting behind one of them.
# Treating such a word as "not git" would leave `sudo git commit` unguarded.
runs_another_program() {
  case "$1" in
    time | nice | nohup | sudo | env | command | xargs) return 0 ;;
    *) return 1 ;;
  esac
}

# The subcommand a segment hands to git, empty when the segment does not run
# git. Leading environment assignments and wrappers are stepped over, and git's
# own flags are skipped so `git -C <path> commit` still reads as a commit.
segment_git_subcommand() {
  local segment="$1" token seen_git=false skip_flag_value=false

  set -f
  for token in $segment; do
    if $skip_flag_value; then
      skip_flag_value=false
      continue
    fi

    if ! $seen_git; then
      case "$token" in
        *=*) continue ;;
        git) seen_git=true ;;
        *)
          runs_another_program "$token" && continue
          return 0
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
        printf '%s' "$token"
        return 0
        ;;
    esac
  done

  return 0
}

# A git command can act on a checkout other than the tool's working directory,
# through `git -C <path>` or a `cd <path> &&` ahead of it. Read the branch and
# the remotes there. Each `cd` moves where every later command runs, so they are
# applied in order until the segment that writes is reached — stopping at the
# first mention of git instead would judge `git fetch && cd <elsewhere> && git
# commit` by the directory the fetch ran in. A `cd` after the write is not where
# git ran. The shell would expand a leading ~ before git ever saw it, so expand
# it here too. A path that cannot be resolved falls back to the working
# directory, so an unparsable command is judged by where the agent stands rather
# than waved through.
git_repo_dir() {
  local dir="$cwd" segment destination
  local -a words

  # Known limit: this reads the raw command, so a `git -C <path>` written inside
  # a commit message picks the checkout to judge. See the "known_limit" tests.
  if [[ "$command" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    dir="${BASH_REMATCH[1]}"
  else
    while IFS= read -r segment; do
      case "$(segment_git_subcommand "$segment")" in
        commit | push) break ;;
      esac

      IFS=$' \t' read -ra words <<<"$segment"
      [[ "${words[0]:-}" == "cd" ]] || continue

      destination="${words[1]:-}"
      [[ -n "$destination" ]] || continue
      [[ "${destination:0:1}" == '~' ]] && destination="$HOME${destination:1}"
      [[ -d "$destination" ]] && dir="$destination"
    done <<<"$(command_segments)"
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
# followed by every non-flag argument: "push origin my-branch", "commit".
# Reading the command as tokens rather than matching "git push" as text keeps
# redirects, pipes and quoted prose from being mistaken for a remote name, and
# still finds a push that sits behind git's own flags, as in "git -C <dir> push".
git_invocations() {
  local segment token invocation seen_git skip_flag_value

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
          # A redirect ends the arguments; where it points is not a remote. Only
          # these three can appear, because splitting into segments has already
          # turned every pipe and semicolon into a segment boundary.
          [[ "$token" == *[\&\<\>]* ]] && break
          invocation="${invocation:+$invocation }$token"
          ;;
      esac
    done

    [[ -n "$invocation" ]] && printf '%s\n' "$invocation"
  done <<<"$(command_segments)"

  return 0
}

# True when the push sends every branch rather than named ones. `--all` and
# `--mirror` write main without naming it, and `--mirror` deletes remote refs
# the local side does not have, so neither can be judged by its refspecs.
push_sends_every_branch() {
  local segment token seen_git=false

  set -f
  while IFS= read -r segment; do
    seen_git=false
    for token in $segment; do
      if ! $seen_git; then
        case "$token" in
          *=*) continue ;;
          git) seen_git=true ;;
          *) runs_another_program "$token" || break ;;
        esac
        continue
      fi

      case "$token" in
        --all | --mirror) return 0 ;;
      esac
    done
  done <<<"$(command_segments)"

  return 1
}

remote_allowed() {
  local remote="$1" url
  url=$(git -C "$(git_repo_dir)" remote get-url "$remote" 2>/dev/null) || return 1
  [[ "$url" =~ github\.com[:/]eirvandelden/ ]] && return 0
  [[ "$url" =~ github\.com[:/]nedap/(caren3|ons-client)(\.git)?$ ]] && return 0
  return 1
}

# True when any refspec of the push writes main or master. A refspec's
# destination is what it writes: "source:destination" writes the destination, a
# bare name writes itself, and HEAD writes whichever branch is checked out.
push_writes_default_branch() {
  local refspec destination writes_default_branch=1 globbing_was_enabled=false

  # Splitting the refspecs needs globbing off, or a refspec like *.md expands to
  # whatever is on disk. Unlike the readers that run inside a command
  # substitution, this runs in the hook's own shell, so the previous setting has
  # to be put back.
  [[ -o noglob ]] || globbing_was_enabled=true
  set -f

  for refspec in $push_refspecs; do
    destination="${refspec##*:}"
    destination="${destination#+}"
    destination="${destination#refs/heads/}"
    [[ "$destination" == "HEAD" ]] && destination="$branch"
    if [[ "$destination" == "main" || "$destination" == "master" ]]; then
      writes_default_branch=0
      break
    fi
  done

  $globbing_was_enabled && set +f
  return $writes_default_branch
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
    if push_sends_every_branch; then
      block "Blocked: pushing every branch at once sends main with them (playbook rule 7). Name the branch to push."
    elif [[ -z "$push_refspecs" ]]; then
      if $on_default_branch; then
        block "Blocked: pushing $branch is never allowed (playbook rule 7). Push a feature branch and open a PR."
      fi
    elif push_writes_default_branch; then
      block "Blocked: pushing to main/master is never allowed (playbook rule 7). Push the feature branch and open a PR."
    fi
  elif $on_default_branch; then
    block "Blocked: committing on $branch is never allowed (playbook rule 7). Create a feature branch and open a PR."
  fi

  # Known limit: both flag checks read the raw command, so naming either flag in
  # a commit message refuses the commit. See the "known_limit" tests.
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
