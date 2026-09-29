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

## Round 2 — 2026-09-28T12:10Z — 1aa21a21

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` were used. State before review: `test/lefthook_*_test.rb` and `test/rv_ci_fallback_test.rb` green on lefthook 2.1.12; `yamllint lefthook.yml` clean. No uncommitted changes.

Security: nothing found. The Round 1 fix holds: `{files}` is now an argument of `:`, and lefthook quotes each name. Probed with lefthook 2.1.12 against `run: ": {files}; echo migrate-ran"` using names that hold `'$(touch P1)'`, a backtick command, `";touch P3;"` and a leading `-e`: no file was created, and the command ran once. The two new tests cover the newline case.

Bugs: nothing Important.

Compliance: every criterion and every test in the plan's `## Proof` still maps as in Round 1; the two Round 1 security tests and `assert_after_pull_hook_ran` exist. No unplanned files changed.

- [x] Nit: Spec requirement 5 says `bundle` runs only when a root `Gemfile` exists, but the guard sits on the `bundle install` branch only. A pull that deletes `Gemfile` and keeps `Gemfile.lock` still runs `rv ci`. The plan (step 7) chose this on purpose to keep `test_changed_gemfile_lock_triggers_rv_ci` green, so the behaviour is planned; the spec's wording is now wider than what was built. Either narrow requirement 5 to "`bundle install` runs only when …" or note the exception there. — `lefthook.yml:333` → fixed (Spec: only bundle install needs a root Gemfile)
- [x] Nit: The lefthook binary lookup (`RV_LEFTHOOK_GLOB`, `env_lefthook_bin`, `path_lefthook_bin`, `locate_native_lefthook`, the skip message) now exists in four test files. Plan step 8 says to share it once a third copy appears. Extract it to a helper under `test/` (separate change is fine). — `test/lefthook_global_hooks_sync_test.rb:10` → fixed (Tests find the lefthook binary through one shared helper)
- [x] Nit: With `{files}` in `run`, lefthook splits a very long file list into several runs of the same command. Probed: 3000 migration names ran `rails db:migrate` once, 6000 ran it twice. The second run is a no-op migrate, so the effect is only time; worth one line in the `lefthook.yml` comment so nobody is surprised. — `lefthook.yml:343` → fixed (Say why a long pull can run a migration command twice)

## Round 3 — 2026-09-29T08:28Z — 73376a77

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` were used. Scope: the Round 2 fix commits `769fc42e..73376a77` on top of the full branch diff. State before review: `test/lefthook_*_test.rb` and `test/rv_ci_fallback_test.rb` green on lefthook 2.1.12 (41 runs, 0 failures, 0 skips); `yamllint lefthook.yml` clean; `rubocop` stopped at load time in this worktree (a gem activation error in `rubygems.rb`, not a lint report), so the linter pass on the test files is not confirmed here. No uncommitted changes. The branch base `d696a495` is behind `origin/main` (`d3eada23`); `origin/main` changed no file this branch touches, so a rebase before push has no conflict to expect.

Bugs: nothing found. `test/lefthook_binary.rb` keeps the same three-step lookup (`LEFTHOOK_BIN`, `which lefthook`, the rv glob) and the same skip message; all four lefthook test files use it and no old copy is left.

Security: nothing found. The Round 2 changes touch only comments, spec wording and test setup; the `{files}` argument form from Round 1 is unchanged.

Compliance: the three Round 2 nits are closed as the plan's Proof says (requirement 5 narrowed to `bundle install`, the long-list comment at `lefthook.yml` above `migrations`, the shared helper). Every criterion and every Proof test still maps as in Round 1. No unplanned files changed.

## Round 4 — 2026-09-29T09:00Z — ba2032c6

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` were used. Scope: the full branch diff against `origin/main` (`d3eada23`), now the branch base after a rebase. `git range-diff` shows every code and doc commit identical to the ones reviewed in Round 3; only the Round 3 report commit is new. State before review: `test/lefthook_*_test.rb` and `test/rv_ci_fallback_test.rb` green (41 runs, 0 failures, 0 skips); `yamllint lefthook.yml` clean; `rubocop` on `test/lefthook_binary.rb` and the four lefthook test files: no offenses (the Round 3 load error does not occur now). No uncommitted changes.

Bugs: nothing found.

Security: nothing found. `{files}` is still only an argument of `:` in the three `migrations` commands, and the two newline-name tests are green.

Compliance: every criterion and every Proof test still maps as in Round 1; no unplanned files changed.

- [x] Nit: The lefthook on this machine, the one the tests found (`~/.local/share/rv/gems/ruby/4.0.0/bin/lefthook`), reports version `2.1.2`, but `spec.md`, `plan.md` and Rounds 1–3 say the tests ran on 2.1.12. The spec also says CI "pins" that version; `.github/workflows/dotfiles-tests.yml` fetches `releases/latest` (the plan's Risks section says so correctly). Correct the version number and change "the version CI pins" to "CI installs the latest release" in the spec, so the PR report names the version the tests were red and green on. — `docs/changes/lefthook-hook-regeneration/spec.md` (Integration points) → fixed (Spec: name both lefthook versions the tests ran on, and that CI installs the latest)

## Round 5 — 2026-09-29T13:04Z — cb211819

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` were used. Scope: the full branch diff against `origin/main`; new since Round 4 is `cb211819` (spec wording and the Round 4 checkbox only). State before review: `test/lefthook_*_test.rb` and `test/rv_ci_fallback_test.rb` green (41 runs, 0 failures, 0 skips) on lefthook 2.1.2 from `which lefthook`; `yamllint lefthook.yml` clean. No 2.1.12 binary is on this machine and `LEFTHOOK_BIN` is unset, so the spec's 2.1.12 red/green claim was not re-run here. No uncommitted changes. `origin/main` moved to `30cf94dd` (branch base still `d3eada23`); it changed only `herdr/.config/herdr/config.toml` and `test/herdr_config_test.rb`, no file this branch touches, so a rebase before push has no conflict to expect.

Bugs: nothing found.

Security: nothing found. `{files}` is still only an argument of `:` in the three `migrations` commands.

Compliance: the Round 4 nit is closed as reported: the spec now names 2.1.12 and 2.1.2 and says CI installs the latest release, which matches `.github/workflows/dotfiles-tests.yml`. Every criterion and every Proof test still maps as in Round 1; no unplanned files changed.

- [ ] Nit: `plan.md` still describes the `{files}`-in-a-shell-comment form that Round 1 found unsafe. The Risks section says "In a trailing shell comment they are never executed", which is the claim Round 1 disproved, and Context ends with "YAML also reads an unquoted trailing ` # {files}` as its own comment, so those `run` values are quoted". The code and the Round 1 Proof line use `: {files}`. Update both sentences so the plan does not state the unsafe form as safe. — `docs/changes/lefthook-hook-regeneration/plan.md:47`, `docs/changes/lefthook-hook-regeneration/plan.md:17`
