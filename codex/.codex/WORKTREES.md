# Worktree-first workflow

Every task that writes or generates code — in any git repository, not just this one — gets its
own git worktree. Never edit files, commit, or push directly from the main checkout open in the
current pane; that's for read-only work (answering questions, reviewing, exploring) only.

Mechanics: `worktree-first` skill (`codex/.codex/skills/worktree-first/`). It's registered
`allow_implicit_invocation: false`, so it never fires on its own — explicitly invoke it yourself
before starting any code-writing task. It skips itself when already inside a worktree or when
the user asked to work in place.
