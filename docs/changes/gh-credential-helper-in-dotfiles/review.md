# Review: gh-credential-helper-in-dotfiles

## Round 1 — 2026-10-07T19:13Z — 7f37f768

The repository has no `REVIEW.md` or `REVIEW.local.md`. This round uses the default passes: Bugs, Security, Compliance.

Checks run: `ruby -Itest test/git_credential_helper_test.rb` (8 runs, 0 failures). Full suite as CI runs it, every `test/*_test.rb` green. `rubocop test/git_credential_helper_test.rb`: no offenses. The alias body also runs correctly under `dash` (`get` prints both lines; `store` exits 0 with no output). `git config --get-urlmatch credential.helper` gives `1password` for `https://github.com/x/y` and nothing for `https://gitlab.com`, `https://api.github.com` and `http://github.com`.

Bugs: no Important findings. Security: no findings; the token stays in a shell variable and goes out through the builtin `echo`, so it is not in any process argument list; no other helper is left to `store` it.

Compliance:

- Criterion 1 → `test_github_credentials_come_from_the_1password_item`
- Criterion 2 → `test_gist_credentials_come_from_the_1password_item`
- Criterion 3 → `test_storing_a_github_credential_leaves_1password_alone`, `test_erasing_a_github_credential_leaves_1password_alone`
- Criterion 4 → `test_a_failed_op_read_gives_git_no_github_password`
- Criterion 5 → `test_another_host_gets_no_credentials_from_any_helper`
- Criterion 6 → `test_the_config_names_no_osxkeychain_helper`
- Criterion 7 → manual, not run; it waits for Etienne and a valid token (plan step 7).
- Every test in the plan's `## Proof` exists, `test_the_config_reads_nothing_from_the_keychain` included. The diff changes only the files the plan names. The commits follow the plan's order and subjects. No existing test changed.

- [x] Nit: Git tries a dashed external on `PATH` before it expands an alias. A `git-credential-1password` executable on `PATH` therefore replaces the alias without a warning, and git takes its answer instead of `op read`. `credential-1password` is the obvious name for any third-party 1Password helper. Verified with a stub `git-credential-1password` in `PATH`: `git credential fill` for `github.com` returned the stub's password. — `git/.config/git/config:13` → fixed (Name the 1Password credential helper by path, not by alias)
- [x] Nit: The test harness keeps the real Keychain helper out only while `git-credential-osxkeychain` is absent from `PATH`; it passes the full user `PATH`. On macOS, `GIT_CONFIG_SYSTEM` does not replace Xcode's gitconfig: git loads it with scope `unknown` and it still names `osxkeychain`. The empty `helper =` clears it today, but a red run (as in plan step 1) on a machine with that helper on `PATH` would ask the real Keychain. The plan's risk note ("whatever the config says") and the test comment ("the Keychain helper that Xcode's system gitconfig would name") overstate this isolation. — `test/git_credential_helper_test.rb:178` → fixed (Tests: a git-credential-1password program on PATH cannot replace the helper)

## Round 2 — 2026-10-08T09:24Z — bb3a1e72

The repository has no `REVIEW.md` or `REVIEW.local.md`. This round uses the default passes: Bugs, Security, Compliance. It covers the round 1 fixes (`b4a0c98d`, `4fe7e6a0`) and the branch as a whole.

Checks run: `ruby -Itest test/git_credential_helper_test.rb` (9 runs, 0 failures). `rubocop test/git_credential_helper_test.rb`: no offenses. `sh -n` and `dash -n` on `git/.config/git/credential-1password`: no errors. `/usr/bin` holds no `git-credential-osxkeychain`, so the narrowed test `PATH` keeps the real Keychain helper out.

Full suite as CI runs it: four files error in this pane. They are `herdr_worker_scripts_test.rb`, `review_report_check_test.rb`, `worktree_create_test.rb` and `worktree_pane_test.rb`. Every error is a `git commit` in a temporary repository that uses the live global config, with commit signing through 1Password. An unsigned commit in a temporary repository succeeds here. This branch changes none of those files, and the live global config is the main checkout's. Not a finding for this branch.

Bugs: one Important finding, below. Security: no findings. The token stays in a shell variable and leaves through the builtin `echo`. The helper path resolves under `$HOME`, the same place git reads the config from. The `op://Familie/Github/token` reference is public by Etienne's decision (intent, Constraints).

Compliance:

- Criterion 1 → `test_github_credentials_come_from_the_1password_item`
- Criterion 2 → `test_gist_credentials_come_from_the_1password_item`
- Criterion 3 → `test_storing_a_github_credential_leaves_1password_alone`, `test_erasing_a_github_credential_leaves_1password_alone`
- Criterion 4 → `test_a_failed_op_read_gives_git_no_github_password`
- Criterion 5 → `test_another_host_gets_no_credentials_from_any_helper`
- Criterion 6 → `test_the_config_names_no_osxkeychain_helper`
- Criterion 7 → manual, not run. Its pre-merge procedure no longer works; see the second Important finding.
- Every test in the plan's `## Proof` exists, the round 1 test `test_a_git_credential_1password_program_on_path_does_not_replace_the_helper` included. The round 1 test edit narrowed `PATH` and added setup; it removed no assertion. No existing test file changed.

- [x] Important: The helper is now a new file in the `git` package, and git runs it by path from `$HOME`. `~/.config/git` is linked file by file, and it holds no `credential-1password` link today. `~/.gitconfig` is already gone on this machine. So once the main checkout carries this config, every GitHub HTTPS operation fails until the `git` package is restowed. Verified with a temporary `HOME` without the link: git prints `~/.config/git/credential-1password get: … No such file or directory`, then `fatal: could not read Username for 'https://github.com'` (with a terminal, it asks for a username instead). The plan rejected a helper script for this reason (`plan.md:79`). Its Risks list and the handover name no restow step before or right after the merge. The same applies on the Debian and Arch machines. — `git/.config/git/config:19` → fixed (Run the 1Password helper from the checkout, so it works before a restow)
- [x] Important: Plan step 7, the only proof for criterion 7, says Etienne can run the check "from this worktree before merge" with `GIT_CONFIG_GLOBAL="$PWD/git/.config/git/config"`. That worked with the alias, which lived in the config file. The helper now resolves to `~/.config/git/credential-1password` under the real `HOME`, which does not exist before a restow. So the pre-merge check gets no password, and the `curl` calls send an empty bearer token. — `docs/changes/gh-credential-helper-in-dotfiles/plan.md:58` → fixed (Run the 1Password helper from the checkout, so it works before a restow)
- [x] Nit: `plan.md` still describes the alias design in its Design decisions (line 11), the POSIX note (line 17), the target config shape (line 22), Files that change (line 46), Order of work step 4 (line 55) and the test-safety risk ("an alias helper still works", line 78). Only the Proof addendum (line 100) records the move to a script. The plan edit landed in the test commit `b4a0c98d`, not with the departing code in `4fe7e6a0`, as Files that change asks. — `docs/changes/gh-credential-helper-in-dotfiles/plan.md:11` → fixed (Run the 1Password helper from the checkout, so it works before a restow)

## Round 3 — 2026-10-09T08:19Z — 991d2d97

The repository has no `REVIEW.md` or `REVIEW.local.md`. This round uses the default passes: Bugs, Security, Compliance. It covers the round 2 fixes (`e8d36b56`, `29947137`) and the branch as a whole.

Checks run: `ruby -Itest test/git_credential_helper_test.rb` (9 runs, 40 assertions, 0 failures). `rubocop test/git_credential_helper_test.rb`: no offenses. `dash -n git/.config/git/credential-1password`: no errors. `bootstrap.sh` clones into `~/Developer/dotfiles` by default, the path the helper and the global hooks both expect. `launchctl getenv PATH` holds `/opt/homebrew/bin`, so git started from a GUI app also finds `op`.

Full suite as CI runs it: stopped after about ten minutes, because other sessions ran test suites at the same time. Up to then only `review_report_check_test.rb` failed (`fatal: ambiguous argument 'HEAD'`), the temporary-repository commit failure that round 2 recorded. This branch changes no test file except `test/git_credential_helper_test.rb`. Not a finding for this branch.

Bugs: no findings. The helper now runs from `~/Developer/dotfiles/git/.config/git/credential-1password`, so it works as soon as the merge is pulled, with no restow. Git expands the `~` because it runs a `!` helper through the shell; the tests prove this with a temporary `HOME`. The tests would fail against the round 2 config: their temporary `HOME` holds no `~/.config/git/credential-1password`. Security: no findings. The token stays in a shell variable and leaves through the builtin `echo`; the helper still ignores `store` and `erase`.

Compliance:

- Criterion 1 → `test_github_credentials_come_from_the_1password_item`
- Criterion 2 → `test_gist_credentials_come_from_the_1password_item`
- Criterion 3 → `test_storing_a_github_credential_leaves_1password_alone`, `test_erasing_a_github_credential_leaves_1password_alone`
- Criterion 4 → `test_a_failed_op_read_gives_git_no_github_password`
- Criterion 5 → `test_another_host_gets_no_credentials_from_any_helper`
- Criterion 6 → `test_the_config_names_no_osxkeychain_helper`
- Criterion 7 → manual, not run. Plan step 7 now runs the worktree's script directly, so the pre-merge check works without a restow.
- Every test in the plan's `## Proof` exists. The round 2 test edit replaced the stowed link with a link to the checkout and removed no assertion. The plan now describes the script design throughout, and its edit landed with the departing code in `29947137`. The diff changes only the files the plan names.

- [ ] Nit: The class comment wraps unevenly after the round 2 edit: line 11 ends after "in a temporary", and "system config" starts the next line. — `test/git_credential_helper_test.rb:11` →
