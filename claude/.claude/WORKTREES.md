# Worktree-first workflow

Every task that writes or generates code — in any git repository, not just this one — gets its
own git worktree under `.worktrees/`. Never edit files, commit, or push directly from the main
checkout open in the current pane; that's for read-only work (answering questions, reviewing,
exploring) only. Never `git checkout -b`/`git switch -c` a feature branch in the main checkout
either — that's the same violation with extra steps. The main checkout stays on whatever branch
it's already on.

Mechanics: `worktree-first` skill. Explicitly invoke it yourself before starting any
code-writing task — don't rely on it firing on its own. It skips itself when already inside a
worktree or when the user asked to work in place. Inside herdr, a pane rooted in the new
worktree opens below the caller's.

## Codex

The skill lives at `agents/.agents/skills/worktree-first`, a symlink to
`claude/.claude/skills/worktree-first`. Its `agents/openai.yaml` sets
`allow_implicit_invocation: false`, so it never fires on its own here either.
