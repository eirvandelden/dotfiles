# Worktree-first workflow

Every task that writes or generates code — in any git repository, not just this one — gets its
own git worktree. Never edit files, commit, or push directly from the main checkout open in the
current pane; that's for read-only work (answering questions, reviewing, exploring) only.

Mechanics: `worktree-first` skill. Invoke it before starting any code-writing task; it also skips
itself when already inside a worktree or when the user asked to work in place.
