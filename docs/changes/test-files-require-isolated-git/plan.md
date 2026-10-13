# Plan: Test files require isolated git

From `intent.md` (2026-10-13). Status: accepted.

## Context

`test/isolated_git.rb` sets `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` to `/dev/null` in `ENV` when a test file requires it. Git then reads no global or system config, in the test process and in every child process.

`test/isolated_git_test.rb` already has `test_every_test_file_requires_the_helper`. It fails today, on this branch and on `main`. That failure is why the `Dotfiles tests` workflow is red on `main` (runs 38404897764, 38405113812, 38406599821). The intent's "nothing notices the omission" is true only in the sense that nobody fixed the omissions. This change makes the check pass and sharpens its message.

Files in `test/` that end in `_test.rb` and lack `require_relative "isolated_git"` (checked on `main` at 489b5988):

- `bi_test.rb`, `review_push_hook_test.rb`, `lefthook_rubocop_git_gem_test.rb` — named in the intent; they run git.
- `worktree_sweep_test.rb` — added on `main` after the intent. It runs `git commit` with no global-config override, so it reads global signing. Same class of bug.
- `worktree_sweep_on_pull_test.rb` — added on `main` after the intent. It passes its own `GIT_CONFIG_GLOBAL` to most children, but not to `git rev-parse` at line 348.
- `worktree_guard_test.rb`, `worktree_first_skill_test.rb` — keep their own `WITHOUT_GLOBAL_GIT_CONFIG` constant, which empties the global config only.
- `gem_install_rule_mirror_test.rb`, `herdr_quieter_tones_test.rb`, `neovim_avante_dependencies_test.rb`, `pull_request_flow_test.rb`, `rbs_inline_tooling_test.rb`, `worktree_rule_mirror_test.rb` — no git, or no git commit; they get the require for uniformity, as the intent's scope says.

Every one of these files was run once with `ruby -Itest -risolated_git test/<file>` during planning (the helper preloaded, same effect as the require). All passed except two tests in `worktree_sweep_test.rb`: `test_gives_up_on_a_fetch_that_hangs` and `test_gives_up_on_a_gh_call_that_hangs`, each "worktree-sweep did not finish within 20 seconds". They fail the same way without the helper, so the helper does not cause them. The machine was under heavy load from other suites at the time. CI has never reached them: the workflow stops at the `isolated_git_test.rb` failure, which comes first alphabetically.

## Design decisions

- Keep the check where it is, in `test/isolated_git_test.rb`. It already lives next to the helper and its own tests. A separate test file adds nothing.
- Extract the check into a private assertion helper `assert_every_test_file_requires_the_helper(root)`. It collects `root/test/*_test.rb` files without the require as paths relative to `root`, such as `test/foo_test.rb`, sorted, and calls `assert_empty` on them with the message "these files must require isolated_git". `test_every_test_file_requires_the_helper` calls it with `ROOT`. The failure message then names `test/foo_test.rb`, not only `foo_test.rb`, which the first acceptance criterion asks for.
- Prove the first acceptance criterion with a temporary root, not by adding a real offending file to `test/`. A new test builds `<tmp>/test/foo_test.rb` without the require and `<tmp>/test/bar_test.rb` with it. It calls the same helper inside `assert_raises(Minitest::Assertion)` and asserts the raised message includes `test/foo_test.rb` and excludes `bar_test.rb`. So the test exercises the real assertion and its message, not only a scan result.
- The match stays `/^require_relative "isolated_git"$/`. Every existing file uses that exact line. Single quotes or a trailing comment fail the check; that is acceptable, since RuboCop enforces double quotes here.
- Add a second check, `test_no_test_file_defines_its_own_git_config_constant`. It scans `test/*.rb` for `/^\s*WITHOUT_GLOBAL_GIT_CONFIG\s*=/` and reports offenders as `test/<name>`. It proves the fourth acceptance criterion. The regex itself does not match the line it sits on, because that line starts with code before the constant name.
- In `worktree_guard_test.rb` and `worktree_first_skill_test.rb`, delete the constant and drop it from the `Open3.capture2` call in `git`. The process `ENV` already carries both values after the require. Also drop the redundant `"GIT_CONFIG_GLOBAL" => "/dev/null"` entry from the environment hash at `worktree_first_skill_test.rb:103`; the child inherits it from `ENV`.
- Place the require as the last line of each file's require block, after any `require_relative "lefthook_binary"`. This matches the existing files.
- Leave other explicit `GIT_CONFIG_GLOBAL` values alone (`lefthook_pull_hooks_test.rb`, `lefthook_posix_sh_test.rb`, `lefthook_local_hooks_test.rb`, `lefthook_rubocop_git_gem_test.rb`, `review_push_hook_test.rb`, `worktree_sweep_on_pull_test.rb`). The intent keeps them: a test that needs its own git config passes it to the child. `review_push_hook_test.rb` passes `"GIT_CONFIG_GLOBAL" => nil` on purpose, so its fake `HOME`'s global config applies; the require does not change that.
- Prove the third acceptance criterion by composition, not by a new child-process test per file. See Risks for the rejected alternative.

## Integration points

- CI workflow `.github/workflows/dotfiles-tests.yml` runs `ruby -Itest test/<file>` for each `test/*_test.rb`. No change to it. With this change, `isolated_git_test.rb` passes there and the workflow turns green, unless something else is red.
- `test/isolated_git.rb` stays unchanged.
- Lint: `rubocop --force-exclusion <files>` from the repository root, with `GIT_DIR` unset, as `lefthook.yml` runs it.

## Files that change

- `test/isolated_git_test.rb` — extract `files_missing_the_helper(root)`; message names `test/<file>`; new test for a temporary root; new test against a local `WITHOUT_GLOBAL_GIT_CONFIG`.
- `test/bi_test.rb`, `test/review_push_hook_test.rb`, `test/lefthook_rubocop_git_gem_test.rb`, `test/worktree_sweep_test.rb`, `test/worktree_sweep_on_pull_test.rb` — add `require_relative "isolated_git"`.
- `test/gem_install_rule_mirror_test.rb`, `test/herdr_quieter_tones_test.rb`, `test/neovim_avante_dependencies_test.rb`, `test/pull_request_flow_test.rb`, `test/rbs_inline_tooling_test.rb`, `test/worktree_rule_mirror_test.rb` — add `require_relative "isolated_git"`.
- `test/worktree_guard_test.rb`, `test/worktree_first_skill_test.rb` — add the require; delete `WITHOUT_GLOBAL_GIT_CONFIG` and its use; drop the redundant environment entry in `worktree_first_skill_test.rb`.

If `main` gains another `test/*_test.rb` without the require before implementation, it gets the same one-line change; the check names it.

## Order of work

1. Rebase on `origin/main`. Run `ruby -Itest test/isolated_git_test.rb -n test_every_test_file_requires_the_helper` and watch it fail, listing the files above. This is the walking skeleton.
2. In `test/isolated_git_test.rb`, write `test_a_file_without_the_helper_is_named_by_its_test_path` against a temporary root. Run it; watch it fail (the helper does not exist). Extract `assert_every_test_file_requires_the_helper(root)` and call it from `test_every_test_file_requires_the_helper`. Run the new test green; the every-file test still fails, now naming `test/<file>` paths.
3. Write `test_no_test_file_defines_its_own_git_config_constant`. Run it; watch it fail, naming `test/worktree_guard_test.rb` and `test/worktree_first_skill_test.rb`. Commit the test changes.
4. Gate first: on a quiet machine (no other test suites running), run `ruby -Itest test/worktree_sweep_test.rb` without the helper. If `test_gives_up_on_a_fetch_that_hangs` or `test_gives_up_on_a_gh_call_that_hangs` fails, stop. That is a pre-existing failure outside this change: report it to the coordinator as a blocker. Under playbook rule 25 it gets its own worktree and pull request, and this branch rebases on that fix before it continues. If both pass, `worktree_sweep_test.rb` must also pass with the helper. Then add the require to the five git-running files (`bi`, `review_push_hook`, `lefthook_rubocop_git_gem`, `worktree_sweep`, `worktree_sweep_on_pull`). Run each file alone; all green. Commit.
5. Add the require to the six files that do not run git. Run each alone. Commit.
6. In `worktree_guard_test.rb` and `worktree_first_skill_test.rb`, add the require, delete the constant, drop it from `git`, drop the redundant entry at `worktree_first_skill_test.rb:103`. Run both files and `test_no_test_file_defines_its_own_git_config_constant`. Commit.
7. Run `test/isolated_git_test.rb` whole: green.
8. Hand-verify the third acceptance criterion with the script below, from the worktree root, in `bash`. It writes the same hostile config as `IsolatedGitTest#write_hostile_config(hook: true, signing: true)` into a temporary `XDG_CONFIG_HOME`. The sanity commit must fail with "no signing agent" or "global hook refused"; otherwise the hostile config does not bite and the check proves nothing. Each of the three test files must then exit 0 with "0 failures, 0 errors". Record the script output in the review evidence.

   ```bash
   set -euo pipefail
   hostile=$(mktemp -d)
   mkdir -p "$hostile/git/hooks"
   printf '#!/bin/sh\necho "global hook refused" >&2\nexit 1\n' > "$hostile/git/hooks/pre-commit"
   cp "$hostile/git/hooks/pre-commit" "$hostile/git/hooks/pre-push"
   printf '#!/bin/sh\necho "no signing agent" >&2\nexit 1\n' > "$hostile/failing-signer"
   chmod 755 "$hostile/git/hooks/pre-commit" "$hostile/git/hooks/pre-push" "$hostile/failing-signer"
   printf '[core]\n\thooksPath = %s/git/hooks\n[commit]\n\tgpgsign = true\n[gpg]\n\tformat = ssh\n\tprogram = %s/failing-signer\n[gpg "ssh"]\n\tprogram = %s/failing-signer\n[user]\n\tsigningkey = ssh-ed25519 AAAAdummy\n' \
     "$hostile" "$hostile" "$hostile" > "$hostile/git/config"
   hostile_env=(env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM XDG_CONFIG_HOME="$hostile")
   sanity=$(mktemp -d)
   git init --quiet "$sanity"
   if refusal=$("${hostile_env[@]}" git -C "$sanity" -c user.name=Test -c user.email=test@example.com \
        commit --quiet --allow-empty -m sanity 2>&1); then
     echo "hostile config does not bite"; exit 1
   fi
   grep -Eq 'global hook refused|no signing agent' <<<"$refusal" || { echo "unexpected refusal: $refusal"; exit 1; }
   for file in bi review_push_hook lefthook_rubocop_git_gem; do
     "${hostile_env[@]}" ruby -Itest "test/${file}_test.rb"
   done
   ```

   `HOME` stays real, because `bi_test.rb` finds Ruby tooling under it. Git reads `~/.gitconfig` after the XDG file; if that file exists and overrides `core.hooksPath` or `commit.gpgsign`, the sanity commit shows it.
9. Run the full suite so that no failure goes unseen: `failed=; for file in test/*_test.rb; do ruby -Itest "$file" || failed="$failed $file"; done; test -z "$failed" || { echo "FAIL:$failed"; false; }`. The command exits 0 only when every file passes.
10. Run RuboCop on every changed file. Re-read the diff: every hunk adds the require, removes the duplicate, or changes `isolated_git_test.rb`.

## Risks

- A file starts to depend on the real global config once the helper is in. Planning ran all eleven intent-era files with the helper preloaded and all passed. The two sweep files get the same check in step 4.
- The two `worktree_sweep_test.rb` deadline tests above were red locally before this change, under load. Once `isolated_git_test.rb` passes, CI runs the sweep tests for the first time since they landed. Step 4 opens with a gate for them, so this branch never ends with a known red test. Do not change those tests or the sweep in this branch.
- `worktree_sweep_on_pull_test.rb` passes its own `GIT_CONFIG_GLOBAL` to children; the require changes only the calls that pass none. If a call relied on the real global config, step 4 shows it.
- Rejected: a child-process test per named file under a hostile config, like `test_review_report_check_passes_under_the_global_no_push_to_main_hook`. `lefthook_rubocop_git_gem_test.rb` took six minutes locally and `bi_test.rb` one; running them again inside `isolated_git_test.rb` would add minutes to CI and local runs. Today's hostile config also does not make these files fail (their git calls are `git init` or carry their own config), so such a test would not start red. The composition proof covers the criterion: the every-file check proves each file requires the helper, and the two existing helper tests prove the helper defeats a refusing hook and signing with no agent.
- Rejected: matching any `"GIT_CONFIG_GLOBAL" => "/dev/null"` in the duplicate check. Several files pass that value to a child on purpose; the intent removes only the named constant.
- Rejected: a separate `test/test_files_require_isolated_git_test.rb`. The check already exists next to the helper.

## Proof

- A new `test/foo_test.rb` without `require_relative "isolated_git"` makes the suite fail, and the failure names `test/foo_test.rb` → `test/isolated_git_test.rb` `test_a_file_without_the_helper_is_named_by_its_test_path`
- Every file in `test/` that ends in `_test.rb` requires `isolated_git` today, and the suite is green → `test/isolated_git_test.rb` `test_every_test_file_requires_the_helper`, plus the full-suite run in step 9
- `bi_test.rb`, `review_push_hook_test.rb` and `lefthook_rubocop_git_gem_test.rb` pass on a machine whose global git config has a refusing hook and signing with no agent → `test/isolated_git_test.rb` `test_every_test_file_requires_the_helper`, `test_a_commit_ignores_the_global_no_push_to_main_hook`, `test_a_commit_ignores_global_signing_with_no_agent`, plus the recorded hand-check script in step 8
- No file in `test/` defines its own `WITHOUT_GLOBAL_GIT_CONFIG` → `test/isolated_git_test.rb` `test_no_test_file_defines_its_own_git_config_constant`

Per changed file, the unit tests expected:

- `test/isolated_git_test.rb`: `the every-file assertion fails and names a file without the require by its test/ path`, `the every-file assertion leaves out a file with the require`, `every test file requires the helper`, `no test file defines WITHOUT_GLOBAL_GIT_CONFIG`.
- The other thirteen files: no new tests; each file's own tests stay green.

Test setup: `Dir.mktmpdir` with a `test/` subfolder and two small files for the temporary-root test, removed in `ensure` or teardown. No fixtures, no stubs.

## Out of scope

- Test suites outside `test/`: `git/.config/git/worktree-tools/test/`, `conductor/.config/conductor/scripts/test/`, `claude/.claude/test/`.
- The CI workflow and `lefthook.yml`.
- What `isolated_git.rb` sets.
- Explicit `GIT_CONFIG_GLOBAL` values that tests pass to children.

---
Domain skills applied: rails-testing (Minitest conventions), ruby-style.

## Critique

### Round 1 (codex exec -p terra)

- The first acceptance criterion tests the scan's return value, not the failing assertion and its message → fixed (Design decisions, Order of work step 2, Proof)
  - The check becomes the assertion helper `assert_every_test_file_requires_the_helper` with a root argument. The new test calls it under `assert_raises` and checks that the message names `test/foo_test.rb`.
- The hostile-config hand check in step 8 has no executable setup or command, so it is not reproducible → fixed (Order of work step 8)
  - Step 8 now holds the exact bash script, a sanity commit that must fail first, and the expected result per file. The sanity part was run during planning and the commit was refused.
- The full-suite loop with `|| echo` reports success after a failure → fixed (Order of work step 9)
  - Step 9 collects the failed files and exits non-zero when any failed.

### Round 2 (codex exec -p terra)

- Step 8 accepts any failed sanity commit, though an unrelated failure from the real `~/.gitconfig` would pass it → fixed (Order of work step 8)
  - The script captures the commit's output and exits unless it holds "global hook refused" or "no signing agent".
- Step 4 lets the known red sweep tests stay red, which conflicts with the green-suite constraint → fixed (Order of work step 4, Risks)
  - Step 4 opens with a gate: run the sweep file without the helper on a quiet machine. If the two tests fail, stop and report a blocker for a separate rule 25 fix. If they pass, the file must pass with the helper.
