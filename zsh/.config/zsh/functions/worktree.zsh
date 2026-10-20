# ~/.config/zsh/functions/worktree.zsh

spin() {
  local branch="${1:?branch name required}"
  git worktree add ".worktrees/$branch" -b "$branch" || return
  cd ".worktrees/$branch" || return
  git worktree-init
  claude
}

# Sweep merged worktrees, delete merged local branches, prune gone remote branches. Branches that a
# worktree has checked out (including the current one) and main/master stay; `git branch -d` keeps
# any branch with unmerged work.
gclean() {
  local sweep="${GCLEAN_SWEEP:-$HOME/.config/git/worktree-tools/worktree-sweep}"
  local branch worktree
  "$sweep"
  git for-each-ref --merged=HEAD --format='%(refname:short) %(worktreepath)' refs/heads |
    while read -r branch worktree; do
      [[ -n "$worktree" ]] && continue
      case "$branch" in
        main | master) ;;
        *) git branch -d "$branch" ;;
      esac
    done
  git remote prune origin
}
