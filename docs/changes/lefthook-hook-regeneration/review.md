# Review: lefthook-hook-regeneration

## Round 1 — 2026-09-28T11:38Z — 6966cc25

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes (Bugs, Security, Compliance) from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` were used. State before review: the four lefthook test files and `test/rv_ci_fallback_test.rb` are green locally on lefthook 2.1.12; `yamllint lefthook.yml` and `rubocop` on the touched test files report nothing.

Security:

- [x] Important: A pulled file name can run shell commands. `{files}` now sits in a trailing shell comment, and a shell comment ends at a newline, even inside lefthook's single quotes. `git diff-tree -z` passes names with raw newlines, and `Gemfile*` and `db/migrate/*` match across them. A commit that adds a file named `Gemfile` + newline + `<command>` runs `<command>` after `git pull`, in the dotfiles repository and in every repository that uses the global fallback, with no Ruby or Rails needed. Before this branch the `migrations` run lines held no file names. Reproduced with lefthook 2.1.12: `printf 'db/migrate/a\ntouch PWNED\n\0' | lefthook run migrations --files-from-stdin` against `run: "echo migrate-ran # {files}"` created `PWNED`. The template must sit where the shell reads it as a quoted argument (for example a no-op command that takes it as arguments), not in a comment; add a test with such a name. — `lefthook.yml:336`, `lefthook.yml:342`, `lefthook.yml:346` → fixed (A pulled file name can no longer run a shell command after git pull)

Bugs: nothing found beyond the finding above.

Compliance:

- Criterion 1 → `test/lefthook_global_hooks_sync_test.rb` `test_pull_in_dotfiles_repo_keeps_global_hooks_linked`.
- Criterion 2 → `test_rebase_in_dotfiles_repo_keeps_global_hooks_linked`.
- Criterion 3 → `test_pull_in_repo_without_own_config_keeps_global_hooks_linked`.
- Criterion 4 → `test/lefthook_pull_hooks_test.rb` `test_pull_touching_only_readme_runs_no_migrations`.
- Criterion 5 → `test_pull_touching_only_nested_gemfile_does_not_bundle`.
- Criterion 6 → `test_pull_deleting_root_gemfile_does_not_bundle_install`.
- Criterion 7 → the six existing tests named in the plan, all present and unchanged.
- Every test in the plan's `## Proof` exists. `test_pull_does_not_overwrite_hook_scripts` was deleted; the plan names this removal and why (it passed on a layout where lefthook refuses by itself), and the three sync tests cover the same behaviour on the real layout, so it is not reported as a weakened test. The `rv_ci_fallback_test.rb` expected strings changed as the plan's Proof says. No unplanned files changed.

- [x] Nit: The three sync tests only assert that the hooks are still links. They also pass if no hook ran at all, for example if the `lefthook` stub or the shim's binary lookup breaks later. An assertion that the hook ran (a stub command in the log, or the puller's `.git/info/lefthook.checksum` state) would keep them from passing without testing anything. — `test/lefthook_global_hooks_sync_test.rb:51` → fixed (Tests: a pulled file name cannot run a command, and the sync tests prove a hook ran)
