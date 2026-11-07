# Review: shared-lefthook-wrapper

## Round 1 — 2026-11-07T08:15Z — e5bd6742

Checks: `bin/test` 114 of 115 files green. `test/secrets_loader_test.rb` fails 5 tests on a 1Password "authorization timeout" from live `op read` calls; it does not touch this branch. `shellcheck -s sh -S warning git/.config/git/hooks/*` and `rubocop` on the 10 changed test files: clean.

Compliance: every acceptance criterion has its Proof test in the diff. Personal repo with own config → `test_a_personal_repo_with_its_own_config_runs_shared_and_own_jobs`. Personal repo without config → `test_a_personal_repo_without_a_config_runs_the_shared_jobs`. Own job overrides shared → `test_an_own_job_overrides_the_shared_job_of_the_same_name`. No `GIT_DIR` on pre-push in a linked worktree → `test_a_pre_push_job_in_a_linked_worktree_does_not_see_git_dir`. No hook rewrite → `test_pull_in_a_personal_repo_whose_config_lacks_no_auto_install_keeps_global_hooks_linked` and `test_every_hook_script_passes_its_own_name_and_no_auto_install`. Other origin → `test_a_repo_with_another_origin_runs_only_its_own_config` and `test_a_repo_without_origin_runs_only_its_own_config`. All invariant and unit tests named in `## Proof` exist. No existing assertion was weakened, skipped or deleted; the two own-config tests now reach their origin through a non-personal `insteadOf` path, as the plan asks. The repair note belongs in the PR body; check it at `deliver`.

Manual check: a personal repo whose `lefthook.yml` extends `"${HOME}/Developer/dotfiles/lefthook.yml"` (as `ambx2mqtt` and `keyboardio2mqtt` do) commits through the wrapper with lefthook 2.2.2, with no "possible recursion in extends" error, and leaves no runtime config in `TMPDIR`.

- [ ] Nit: The dedupe check is a substring match on the whole file, not a match on an `extends:` entry. A repo config that names the shared path only in a comment, or a longer path that starts with it, silently loses the shared config. The plan says "a literal path match". — `git/.config/git/hooks/lefthook-wrapper:131` → fixed (match extends entries and write paths with printf in the hook wrapper)
- [ ] Nit: The parity test passes for a personal URL when the lefthook stub never logs, because `none?` on an empty list is true. Assert that exactly one `config:` line was logged before comparing. — `test/lefthook_wrapper_test.rb:128` → fixed (match extends entries and write paths with printf in the hook wrapper)
- [ ] Nit: Comments still say the "global hook shim" prefers `LEFTHOOK_BIN` and runs lefthook. The lookup chain now lives in the hook wrapper, and the glossary lists "shim" under Avoid for that term. Same word at `test/worktree_sweep_on_pull_test.rb:14`, `test/lefthook_rubocop_git_gem_test.rb:15` and `test/lefthook_global_hooks_sync_test.rb:197`. — `test/lefthook_local_hooks_test.rb:282` → fixed (say hook, not shim, for the global hook scripts)
- [ ] Nit: `echo` writes paths into the runtime config. Under dash, `echo` expands backslash escapes, so a toplevel path that holds a backslash is written wrong. `printf '%s\n'` avoids it. — `git/.config/git/hooks/lefthook-wrapper:107` → fixed (match extends entries and write paths with printf in the hook wrapper)

## Round 2 — 2026-11-07T10:10Z — 8219cf58

Scope: the two fix commits since round 1 (`8cd8028e`, `8219cf58`), plus a re-read of the full branch diff against `origin/main`.

Checks: `bin/test` 114 of 115 files green. `test/secrets_loader_test.rb` still fails 5 tests on live `op read` calls ("token" isn't an item in the "Private" vault); the branch does not touch it. `shellcheck -s sh -S warning git/.config/git/hooks/*` and `rubocop -c rubocop/.rubocop.yml` on the 10 changed Ruby files: clean.

Round 1 fixes: `extends_shared` matches whole `- <path>` entries, quoted or not, so a comment or a longer path keeps the shared config; two new tests prove both cases. `printf '%s\n'` replaces `echo` for every runtime config line; macOS `sh` expands `\n` in `echo`, so the new backslash test is a real regression test. The parity test now asserts exactly one `config:` line per URL. No glossary "Avoid" word (shim, runner) is left in the changed code or tests.

Manual check: the wrapper, run with a stub lefthook in `~/Developer/ambx2mqtt` (origin `git@github.com:eirvandelden/ambx2mqtt.git`, `extends: "${HOME}/Developer/dotfiles/lefthook.yml"`), writes both paths to the runtime config, and `lefthook dump` (2.2.2) loads the merged config without a recursion error. The runtime directory in `TMPDIR` was gone afterwards.

Compliance: unchanged from round 1; every acceptance criterion and every `## Proof` test is present, and no existing assertion was weakened, skipped or deleted. The repair note belongs in the PR body; check it at `deliver`.

Nothing found.
