# Plan: Repository tests ignore the developer's own git setup

From `intent.md` (2026-10-13). Status: accepted.

## Context

Tests at the repository root run as `for f in test/*_test.rb; do ruby -Itest "$f"; done`, one Ruby process per file. Several files run `git` in temporary repositories and inherit the machine's global git config. Etienne's global config (`~/.config/git/config`) sets `commit.gpgsign=true` through 1Password, `core.hooksPath=~/.config/git/hooks` (the lefthook fallback hooks), `core.excludesfile`, aliases and `init.defaultBranch=main`. Each test file patches this piecemeal: some pass `-c commit.gpgsign=false`, others `-c core.hooksPath=/dev/null`, none both. Scripts under test (worktree-create, worktree-pane, the herdr worker scripts) run git themselves with the inherited environment, so per-call `-c` flags cannot reach them.

Measured on 2026-10-13, running each file with `GIT_CONFIG_GLOBAL` pointed at a hostile config:

- Signing on, `gpg.program = false`: `agent_worktree` (10 errors), `herdr_worker_scripts` (2 errors), `worktree_create` (31 errors), `worktree_pane` (20 errors), `worktree_viewer` (25 errors) fail.
- `core.hooksPath` at hooks that all `exit 1`: `change_folder` (7 errors), `herdr_worker_scripts` (39 failures, 4 errors), `review_report_check` (9 errors), `test_guard` (11 errors) fail.
- Every other file passes both. `review_report_check_test.rb` with the real global config took 4 min 44 s and errored once; isolated it takes 16 s.

`lefthook_local_hooks_test.rb`: with `LEFTHOOK_BIN` set, `test_pre_commit_calls_lefthook_with_no_auto_install` and `test_pre_push_calls_lefthook_with_no_auto_install` error with `Errno::ENOENT … commands.log` (reproduced 2026-10-13). `repo_env` merges into the inherited environment, so the global hook shim (`git/.config/git/hooks/*`, `call_lefthook`) runs `$LEFTHOOK_BIN` and never the logging stub on `PATH`.

## Design decisions

- **One shared helper, `test/isolated_git.rb`.** Eleven files need the same isolation, so the rule of three applies. Required with `require_relative "isolated_git"`, like `test/lefthook_binary.rb`. On load it updates `ENV` once for the whole test process: `GIT_CONFIG_GLOBAL=File::NULL`, `GIT_CONFIG_SYSTEM=File::NULL`, and `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` set to `Test` / `test@example.com`.
- **Environment, not `-c` flags.** `ENV` reaches every child: the test's own `system`/`Open3` git calls, in-process library calls (`agent_worktree`), and the scripts under test that run git themselves. `-c` flags reach only the call they sit on. `GIT_CONFIG_GLOBAL` replaces both `~/.gitconfig` and `$XDG_CONFIG_HOME/git/config`, so signing, global hooks, aliases, `core.excludesfile` and `init.defaultBranch` all disappear, exactly as on CI.
- **`/dev/null` over a test-owned config file.** It matches the lefthook test files (`lefthook_local_hooks`, `lefthook_posix_sh`, `lefthook_pull_hooks`), which already use `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_SYSTEM=/dev/null`. No temp file to create or clean up.
- **A fixed identity through `GIT_AUTHOR_*` / `GIT_COMMITTER_*`.** With no global config, a commit by a script under test needs an identity. Git's auto-detection fails on a host name without a dot. The same values as the existing `-c user.name=Test -c user.email=test@example.com` flags, so nothing a test asserts changes. `lefthook_local_hooks_test.rb` `repo_env` already does this.
- **Which files require the helper: every test file that starts git.** That is the eight measured failures plus `consent_guard`, `auto_accept` and `change_scope`, which run `git init` / `git remote add` and pass today only because those commands ignore signing and hooks. The intent lists `guard_parity` and `vendored_skills`; neither runs git (checked: no git call in the file or in `remote_matcher.rb`), so they stay unchanged. `auto_accept` and `change_scope` replace them on the list. The outcome stays the one agreed: every root test file gives the same result as on CI.
- **Leave the existing per-call `-c` flags.** With the helper they become redundant but harmless. Removing them touches many unrelated lines; that cleanup is out of scope.
- **`LEFTHOOK_BIN`: unset it in `repo_env`.** Add `"LEFTHOOK_BIN" => nil` to `repo_env` in `lefthook_local_hooks_test.rb`; a `nil` value removes the variable from the child's environment. `NATIVE_LEFTHOOK` still resolves from `LEFTHOOK_BIN` at load time, so `stub_real_lefthook` keeps wrapping the binary the developer chose. Not in the shared helper: the other lefthook files set `LEFTHOOK_BIN` on purpose.
- **Acceptance tests run real test files, but not the whole suite.** The full suite takes minutes; re-running it twice from inside itself would triple CI time and recurse. `test/git_isolation_test.rb` runs one fast, measured-failing file per hostile config end to end (`agent_worktree_test.rb` for signing, about 3 s; `change_folder_test.rb` for hooks, about 1 s). A structural test then makes every git-running test file use the isolation, so the end-to-end result generalises. The implementer runs the full suite under both hostile configs once, as recorded evidence (the check commands under Proof).

## Integration points

- Scripts under test inherit the test process `ENV`: `git/.config/git/worktree-tools/worktree-create`, `worktree-pane`, `lib/agent_worktree.rb`, the herdr worker scripts, `claude/.claude/skills/plan/scripts/change-folder`, the review-report check, the test guard hook.
- Global hook shims in `git/.config/git/hooks/*` (read `LEFTHOOK_BIN`).
- CI: `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb`; it picks up the new test file with no change.

## Files that change

- `test/isolated_git.rb` — new. Sets the six git environment variables on load, with a short comment saying why.
- `test/git_isolation_test.rb` — new. Acceptance tests and the structural test (see Proof).
- `test/agent_worktree_test.rb`, `test/auto_accept_test.rb`, `test/change_folder_test.rb`, `test/change_scope_test.rb`, `test/consent_guard_test.rb`, `test/herdr_worker_scripts_test.rb`, `test/review_report_check_test.rb`, `test/test_guard_test.rb`, `test/worktree_create_test.rb`, `test/worktree_pane_test.rb`, `test/worktree_viewer_test.rb` — add `require_relative "isolated_git"` after the other requires.
- `test/lefthook_local_hooks_test.rb` — `repo_env` adds `"LEFTHOOK_BIN" => nil`.

## Order of work

1. Write `test/git_isolation_test.rb` with `test_agent_worktree_suite_passes_when_global_signing_fails`. Run it; watch it fail (the child run reports errors from `gpg failed to sign the data`).
2. Add the helper unit tests `test_helper_hides_a_failing_global_signing_program` and `test_helper_hides_failing_global_hooks`. Run them; watch them fail because `isolated_git` does not exist yet.
3. Create `test/isolated_git.rb`. Watch both helper unit tests pass. Require the helper from `test/agent_worktree_test.rb`; watch step 1's test pass.
4. Add `test_change_folder_suite_passes_when_global_hooks_fail`. Run it; watch it fail. Require the helper from `test/change_folder_test.rb`. Watch it pass.
5. Add `test_every_test_file_that_runs_git_isolates_it`. Run it; watch it name the nine files still missing the helper. Add `require_relative "isolated_git"` to each. Watch it pass.
6. Add `test_lefthook_local_logging_tests_pass_with_lefthook_bin_set`. Run it; watch it fail with the `Errno::ENOENT … commands.log` errors in the child output. Add `"LEFTHOOK_BIN" => nil` to `repo_env`. Watch it pass.
7. Run each changed test file on its own, then the full suite as CI runs it. Then run the full suite under both hostile configs with the check script under Proof, and record its output in the PR.
8. `rubocop` on every changed and new Ruby file. Re-read the full diff.

## Risks

- **Git still reads `$XDG_CONFIG_HOME/git/ignore` and `git/attributes`** as default exclude and attribute files, whatever `GIT_CONFIG_GLOBAL` says. Etienne has neither file today (checked 2026-10-13), and setting `XDG_CONFIG_HOME` would change what other tools under test read. Accepted as a residual gap; not handled.
- **A leaked `GIT_DIR` / `GIT_WORK_TREE` / `GIT_INDEX_FILE`** (suite run from inside a git hook) still reaches the tests. Out of scope per the intent (branch `fallback-rubocop-hook-git-dir`).
- **Process-wide `ENV`.** If someone loads several test files into one Ruby process, the helper's settings reach the lefthook files too. Those set `GIT_CONFIG_GLOBAL` explicitly on each call, so they keep their own value.
- **Structural test is a text scan.** It detects argv-style calls (`"git",`). A file that starts git only through a script it calls, never naming git, slips past; the full-suite hostile-config check in step 7 covers that case for today's files.
- **End-to-end tests nest Minitest runs.** They add about 5 s to the suite and depend on `agent_worktree_test.rb` and `change_folder_test.rb` staying git-backed. If either stops running git, its end-to-end test proves nothing; the structural test still guards the rule.
- Rejected: a test-owned global config file (more moving parts than `/dev/null`); per-call `-c` flags in each helper (cannot reach scripts under test); setting `HOME` or `XDG_CONFIG_HOME` (changes what other tools under test read); running the whole suite from inside `git_isolation_test.rb` (triples CI time, recurses).

## Out of scope

- Production scripts, `lefthook.yml`, the git config package, `.github/workflows/`.
- `lefthook_global_hooks_sync`, `lefthook_pull_hooks`, `lefthook_posix_sh` (already isolated), apart from the structural test accepting their `GIT_CONFIG_GLOBAL` setting.
- Removing the now-redundant `-c` flags from existing git helpers.
- The leaked `GIT_DIR` problem; suite speed.

## Proof

- AC1 (failing global signing program, every file passes) → `test/git_isolation_test.rb` `test_agent_worktree_suite_passes_when_global_signing_fails`, plus `test_every_test_file_that_runs_git_isolates_it`; check: the hostile-config script below exits 0 for `sign`.
- AC2 (failing global hooks, every file passes) → `test/git_isolation_test.rb` `test_change_folder_suite_passes_when_global_hooks_fail`, plus `test_every_test_file_that_runs_git_isolates_it`; check: the hostile-config script below exits 0 for `hooks`.
- AC3 (`LEFTHOOK_BIN` set, `lefthook_local_hooks_test.rb` passes) → `test/git_isolation_test.rb` `test_lefthook_local_logging_tests_pass_with_lefthook_bin_set`; check: `LEFTHOOK_BIN=$(ruby -Itest -r lefthook_binary -e 'print LefthookBinary.locate') ruby -Itest test/lefthook_local_hooks_test.rb` passes.
- AC4 (CI stays green) → check: the `Dotfiles tests` workflow on the pull request is green.

Hostile-config check script. Save it outside the repository and run it with `sh <file>` from the worktree root. It lists every failing file and exits non-zero if any fails:

```sh
dir=$(mktemp -d)
mkdir "$dir/hooks"
for hook in pre-commit prepare-commit-msg commit-msg post-commit pre-push post-checkout post-merge post-rewrite; do
  printf '#!/bin/sh\nexit 1\n' > "$dir/hooks/$hook"
done
chmod +x "$dir"/hooks/*
printf '[commit]\n\tgpgsign = true\n[tag]\n\tgpgsign = true\n[gpg]\n\tprogram = false\n' > "$dir/sign.gitconfig"
printf '[core]\n\thooksPath = %s/hooks\n' "$dir" > "$dir/hooks.gitconfig"
status=0
for config in sign hooks; do
  for f in test/*_test.rb; do
    GIT_CONFIG_GLOBAL="$dir/$config.gitconfig" ruby -Itest "$f" > /dev/null 2>&1 || { echo "FAIL $config $f"; status=1; }
  done
done
exit "$status"
```

Per changed file, the unit tests expected:

- `test/isolated_git.rb`: `test_helper_hides_a_failing_global_signing_program` (a child `ruby -r isolated_git` commits in a temp repo under the signing config), `test_helper_hides_failing_global_hooks` (same under the hooks config). Both in `test/git_isolation_test.rb`.
- `test/lefthook_local_hooks_test.rb`: covered by the AC3 test; its existing tests stay unchanged.
- The eleven files gaining the `require_relative`: their existing tests are the proof; no new tests.

Test setup: `test/git_isolation_test.rb` builds both hostile configs in a `Dir.mktmpdir` per test. Signing config: `[commit] gpgsign = true`, `[tag] gpgsign = true`, `[gpg] program = false`. Hooks config: `[core] hooksPath = <tmp>/hooks`, holding `pre-commit`, `prepare-commit-msg`, `commit-msg`, `post-commit`, `pre-push`, `post-checkout`, `post-merge`, `post-rewrite`, each `#!/bin/sh` + `exit 1`. Child runs use `Open3.capture2e({ "GIT_CONFIG_GLOBAL" => config }, "ruby", "-Itest", file, chdir: REPO_ROOT)` and assert success with the child output as the message. This file does not require the helper itself, so its end-to-end tests fail for the right reason before the fix; it names `GIT_CONFIG_GLOBAL`, so the structural scan accepts it. The structural scan reads every `test/*_test.rb`; a file matching `/["']git["']\s*,/` must contain `require_relative "isolated_git"` or `GIT_CONFIG_GLOBAL`; the failure message lists the offenders. The AC3 test gets the binary from `LefthookBinary.locate`; when none is found it flunks on CI and skips locally, as `test/rubocop_fallback_test.rb` does.

---
Domain skills applied: rails-testing (Minitest conventions), ruby-style, dotfiles-maintenance.

## Critique

### Round 1 (codex exec -p terra)

- The AC1/AC2 tests run only two suites and rely on a source scan that misses indirect git use; run every git-using suite under both hostile configs from `git_isolation_test.rb` and drop the scan → dismissed: measured on 2026-10-13, the eleven git-using suites take 5 to 7 minutes per hostile config, so the proposal adds 10 to 14 minutes to every CI and local run. A fixed list also misses the next new test file, which the scan catches. The full-suite hostile-config check script still runs once as recorded evidence.
- The full-suite check commands leave the config paths undefined, and `|| echo` masks failures → fixed (Proof now holds a concrete script that builds both configs, lists every failing file and exits non-zero on any failure)
- The helper unit tests come after the helper exists and get their red by commenting the code out, which is not test-first → fixed (Order of work step 2 now writes both helper unit tests before step 3 creates the helper)

## Re-scope (2026-10-13, after PR #198)

PR #198 (`temp-repo-tests-ignore-global-hooks`) merged to main while this branch was in review. It adds its own `test/isolated_git.rb` (`GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` at `/dev/null`), requires it from every `test/*_test.rb`, and proves it in `test/isolated_git_test.rb` under a failing signing program and a failing global hook. That delivers AC1 and AC2. Keeping this branch's helper next to it would duplicate the mechanism, so the branch drops it: no `test/isolated_git.rb` change, no `test/git_isolation_test.rb`, no `require_relative` lines.

What main still lacks is AC3: `repo_env` in `test/lefthook_local_hooks_test.rb` merges into the inherited environment, so a caller's `LEFTHOOK_BIN` reaches the global hook shim and bypasses the logging stub.

New design for AC3: two regression tests inside `test/lefthook_local_hooks_test.rb`, `test_pre_commit_reaches_the_logging_stub_when_lefthook_bin_is_set` and `test_pre_push_reaches_the_logging_stub_when_lefthook_bin_is_set`. Each sets `ENV["LEFTHOOK_BIN"]` to the real lefthook binary for the test's duration (restored in `ensure`), then runs the same steps as the existing logging tests. They are red on main whatever the caller's environment, and they cost a few seconds instead of a nested Minitest run. The fix stays `"LEFTHOOK_BIN" => nil` in `repo_env`.

Revised Proof:

- AC1 and AC2 → delivered by main (`test/isolated_git_test.rb`, `test_every_test_file_requires_the_helper`); this branch adds nothing. Check: the full suite under both hostile configs, re-run on this branch.
- AC3 → `test/lefthook_local_hooks_test.rb` `test_pre_commit_reaches_the_logging_stub_when_lefthook_bin_is_set`, `test_pre_push_reaches_the_logging_stub_when_lefthook_bin_is_set`.
- AC4 → the `Dotfiles tests` workflow on the pull request.

Order of work: write both tests, watch them error with `Errno::ENOENT … commands.log`, commit; add `"LEFTHOOK_BIN" => nil`, watch them pass, commit; rubocop; full suite plain and under both hostile configs.
