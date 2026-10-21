# ~/.config/zsh/functions/worktree.zsh

spin() {
  local branch="${1:?branch name required}"
  git worktree add ".worktrees/$branch" -b "$branch" || return
  cd ".worktrees/$branch" || return
  git worktree-init
  claude
}

# Sweep merged worktrees, delete local branches merged into origin's default branch, prune gone
# remote branches. Branches that a worktree has checked out (including the current one) and
# main/master stay. A branch in the default branch has its work on the remote, so -D loses nothing;
# -d would refuse when this checkout is behind origin. Without origin/HEAD it measures against HEAD.
gclean() {
  local sweep="${GCLEAN_SWEEP:-$HOME/.config/git/worktree-tools/worktree-sweep}"
  local base branch worktree
  "$sweep"
  base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || echo HEAD)
  git for-each-ref --merged="$base" --format='%(refname:short) %(worktreepath)' refs/heads |
    while read -r branch worktree; do
      [[ -n "$worktree" ]] && continue
      case "$branch" in
        main | master) ;;
        *) git branch -D "$branch" ;;
      esac
    done
  git remote prune origin
}
