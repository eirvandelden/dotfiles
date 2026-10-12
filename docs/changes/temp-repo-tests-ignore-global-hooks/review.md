# Review: temp-repo-tests-ignore-global-hooks

## Round 1 — 2026-10-12T15:55:33Z — 88dd95f9

No REVIEW.md or REVIEW.local.md in the repository, so the default passes apply: Bugs, Security, Compliance.

Checks run on 88dd95f9 (no uncommitted changes):

- CI loop `for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`: 39 files, 0 failures, 0 errors.
- Same loop with a hostile `XDG_CONFIG_HOME` (global `core.hooksPath` whose `pre-commit` and `pre-push` exit 1, `commit.gpgsign = true`, `gpg.ssh.program` that exits 1) and `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM` unset: 39 files, 0 failures, 0 errors.
- `rubocop` on the 40 changed Ruby files: no offenses.
- Reproduction holds: the `origin/main` version of `test/review_report_check_test.rb` under a hostile `no-push-to-main`-style `pre-commit` gives 1 error (`global hook refused main`, `git commit --quiet -m advance main failed`); the branch version gives 0 errors under the same config.
- `herdr_worker_scripts_test.rb` under the hostile config: 8 separate runs (seeds 25509, 29050, 105, 63591, 2406, 45331, 62553, 20334), all 77 runs green with a summary. The reported "exit 1 with no summary" did not reproduce. A likely cause is the harness, not the test: a shell loop that ends in `[ $s -ne 0 ] && …` itself exits 1 when the last run passes, which this review's own repeat loop did.

Compliance:

- With the global `no-push-to-main` hook active, `review_report_check_test.rb` passes → `IsolatedGitTest#test_review_report_check_passes_under_the_global_no_push_to_main_hook`; also confirmed by hand above.
- With global signing on and no agent, every temporary-repository test passes → `IsolatedGitTest#test_a_commit_ignores_global_signing_with_no_agent` plus `#test_every_test_file_requires_the_helper`; the hostile full-suite run above is the check the plan names.
- The full suite passes locally and in CI → local loop green above; CI has not run yet (no pull request), so the CI half is still open.
- A new temporary-repository test that forgets the setup is caught → `IsolatedGitTest#test_every_test_file_requires_the_helper`.
- Every test named in `plan.md` `## Proof` exists in `test/isolated_git_test.rb` (7 of 7).
- No existing test was weakened, skipped or deleted: the diff outside the change folder adds lines only, one `require_relative "isolated_git"` per existing file.
- The four `lefthook_*` tests still exercise their hooks. `lefthook_local_hooks_test.rb` and `lefthook_posix_sh_test.rb` set `core.hooksPath` in the repository-local config; `lefthook_pull_hooks_test.rb` passes its own `GIT_CONFIG_GLOBAL` file in the hook environment; `lefthook_global_hooks_sync_test.rb` sets `GIT_CONFIG_GLOBAL => nil` and `XDG_CONFIG_HOME => nil` with a temporary `HOME`, so git reads `@home/.config/git/config`. An explicit environment hash wins over the inherited `ENV`, and all four pass.
- `GIT_CONFIG_GLOBAL=/dev/null` hides no bug the tests used to catch. Every test already had to pass in CI, which has no global config. The only behaviour lost is the accidental, machine-only collision of a script with Etienne's own hooks or signing. No test asserts behaviour that comes from `git/.config/git/config` through git (the `worktree-init` alias is stubbed repository-locally in `worktree_create_test.rb`; `editor_test.rb` reads that file as text).

Findings:

- [ ] Nit: The regression check passes on any occurrence of the text, so a commented-out `# require_relative "isolated_git"` or the string inside a heredoc counts as the setup. A line-anchored match closes that gap — `test/isolated_git_test.rb:86` →
- [ ] Nit: The hostile setup keeps the real `HOME`, so a `~/.gitconfig` on the machine is read after the hostile `XDG_CONFIG_HOME` config and wins. The control tests (`refused main`, `no signing agent`) then depend on that file being absent; it is absent on this machine. Pointing `GIT_CONFIG_GLOBAL` at the hostile file in the child makes the controls machine-independent — `test/isolated_git_test.rb:133` →
- [ ] Nit: The helper comment says git reads no global config "in every child process", but an explicit environment hash overrides it, which is how the `lefthook_*` tests keep their hooks. One sentence on that opt-out tells the next hook test how to get a global config back — `test/isolated_git.rb:2` →
- [ ] Nit: `COMMIT_SCRIPT` sits between test methods instead of with `ROOT` at the top of the class — `test/isolated_git_test.rb:30` →
- [ ] Nit: `run_child` destructures the pair from `Open3.capture2e` and rebuilds the same pair; returning the call directly is the same — `test/isolated_git_test.rb:134` →

## Round 2 — 2026-10-12T15:56:19Z — 88dd95f9 (codex)

No findings. `codex review --base origin/main`: the isolation tests pass and no patch defect was found. Its full loop stopped at `rubocop_fallback_test.rb` because the Codex sandbox cannot write the RuboCop cache; outside the sandbox that file passes.
