# Intent: gclean skips worktree branches and sweeps merged worktrees

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix.

`gclean` fails with `branch '+' not found` and `cannot delete branch ... used by worktree`. `gclean` should delete merged local branches, keep branches with unpushed work, never touch branches checked out in a worktree, and also sweep merged worktrees like `worktree-sweep` does. It may be slow and may use the network.
