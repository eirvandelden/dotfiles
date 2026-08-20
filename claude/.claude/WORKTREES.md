# Worktree-first workflow

Every task that writes or generates code — in any git repository, not just this one — gets its
own git worktree. Never edit files, commit, or push directly from the main checkout open in the
current pane; that's for read-only work (answering questions, reviewing, exploring) only.

Mechanics: `worktree-first` skill. Explicitly invoke it yourself before starting any
code-writing task — don't rely on it firing on its own. It skips itself when already inside a
worktree or when the user asked to work in place.
