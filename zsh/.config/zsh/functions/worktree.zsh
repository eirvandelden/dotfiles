# ~/.config/zsh/functions/worktree.zsh

spin() {
  local branch="${1:?branch name required}"
  git worktree add ".worktrees/$branch" -b "$branch" || return
  cd ".worktrees/$branch" || return
  git worktree-init
  claude
}
