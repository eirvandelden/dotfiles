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

- [ ] Nit: Git tries a dashed external on `PATH` before it expands an alias. A `git-credential-1password` executable on `PATH` therefore replaces the alias without a warning, and git takes its answer instead of `op read`. `credential-1password` is the obvious name for any third-party 1Password helper. Verified with a stub `git-credential-1password` in `PATH`: `git credential fill` for `github.com` returned the stub's password. — `git/.config/git/config:13` →
- [ ] Nit: The test harness keeps the real Keychain helper out only while `git-credential-osxkeychain` is absent from `PATH`; it passes the full user `PATH`. On macOS, `GIT_CONFIG_SYSTEM` does not replace Xcode's gitconfig: git loads it with scope `unknown` and it still names `osxkeychain`. The empty `helper =` clears it today, but a red run (as in plan step 1) on a machine with that helper on `PATH` would ask the real Keychain. The plan's risk note ("whatever the config says") and the test comment ("the Keychain helper that Xcode's system gitconfig would name") overstate this isolation. — `test/git_credential_helper_test.rb:178` →
