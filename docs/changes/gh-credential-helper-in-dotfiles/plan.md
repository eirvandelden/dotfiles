# Plan: Git credentials come from 1Password, set in the dotfiles config

From `intent.md` (2026-10-06). Status: accepted.

## Context

`~/.gitconfig` exists only because `gh auth setup-git` created it. While it exists, `git config --global` never reads the dotfiles config, so lefthook's global `core.hooksPath` check (PR #168) does not work. Its one unique setting, the gh credential helper, reads the macOS Keychain. This change moves GitHub HTTPS credentials into `git/.config/git/config`, read from 1Password, and removes every Keychain read from that file. After merge, Etienne removes `~/.gitconfig` by hand.

## Design decisions

- **One helper script, named by its path in the checkout.** `git/.config/git/credential-1password` is a POSIX sh script. Both GitHub sections run it as `helper = "!~/Developer/dotfiles/git/.config/git/credential-1password"`. Git runs a `!` helper through the shell, so no program on `PATH` can replace it (review round 1), and the path exists as soon as the merge is pulled, with no restow (review round 2). The global hooks already assume the checkout at `~/Developer/dotfiles` (`set_global_config`). This replaces the first design, a git alias named `credential-1password`, which a `git-credential-1password` program on `PATH` would override.
- **Only `get` reads 1Password.** The script exits 0 at once for `store` and `erase` (criterion 3).
- **The account is named.** The script runs `op read op://Familie/Github/token --account vandelden`. `zsh/.config/zsh/functions/secrets.zsh` uses the same personal account name. Etienne chose this on 2026-10-06, so a recent work-account sign-in or `OP_ACCOUNT` cannot redirect the read.
- **Output.** On success the script prints `username=x-access-token` and `password=<token>`. When `op read` fails, it prints `quit=1`. Git then stops with `credential helper '1password' told us to quit`: no terminal prompt, and no helper configured after it runs (criterion 4). Etienne chose this on 2026-10-06. The script prints nothing else; `op` writes its own error to stderr.
- **Inherited helpers are cleared.** Xcode's git ships a system config (`/Applications/Xcode.app/Contents/Developer/usr/share/git-core/gitconfig`) with `credential.helper = osxkeychain`. Removing the dotfiles line alone leaves that helper active. An empty `[credential] helper =` in the dotfiles config clears every helper set before it, the system one included. The GitHub sections come after it in the file, so the reset does not clear them: git applies `credential.*` entries in file order. Verified on git 2.54.
- **`[github] token` is removed.** Its value runs `security find-generic-password`, a Keychain read. Nothing in this repository reads `github.token`. Etienne chose on 2026-10-06 to remove it in this change. `github.user` stays.
- **POSIX sh only.** The script starts with `#!/bin/sh`, which is dash on Debian. Use `[ ]`, never `[[ ]]`.

Target config shape:

```gitconfig
[credential]
  # An empty helper clears every helper set before this file, Xcode's
  # osxkeychain included, so no credential comes from the Keychain.
  helper =
[credential "https://github.com"]
  helper = "!~/Developer/dotfiles/git/.config/git/credential-1password"
[credential "https://gist.github.com"]
  helper = "!~/Developer/dotfiles/git/.config/git/credential-1password"
```

## Integration points

- Git's credential protocol: `git credential fill|approve|reject`; helper actions `get|store|erase`; attributes `username`, `password`, `quit`.
- 1Password CLI `op read` through the desktop app; it needs no terminal (tested 2026-10-02, per intent).
- Xcode's system gitconfig on macOS (osxkeychain). Debian and Arch ship no system helper.
- `~/.gitconfig` on Etienne's machine. Git loads it after the dotfiles config. Its empty `helper =` lines clear the 1Password helper, so gh stays the GitHub helper until Etienne removes the file.
- `~/.config/git/work-remotes.config` and `work.config` (dotfiles-work) set no credential helper and no `[github]` key (checked 2026-10-06).
- Lefthook's global hooks-path check (PR #168) works again once `~/.gitconfig` is gone. This change does not test it.

## Files that change

- `git/.config/git/credential-1password` — new: the helper script.
- `git/.config/git/config` — add the empty `[credential] helper`, and the two GitHub sections. Remove `helper = osxkeychain`. Remove the `token = !security …` line from `[github]`.
- `test/git_credential_helper_test.rb` — new file with the tests under Proof.
- `docs/changes/gh-credential-helper-in-dotfiles/plan.md` — only if reality departs from this plan, in the same commit as the departing code.

## Order of work

1. Write the test harness (Test setup below) and `test_github_credentials_come_from_the_1password_item`. Run it with `ruby -Itest test/git_credential_helper_test.rb -n test_github_credentials_come_from_the_1password_item`. Watch it fail: the Keychain stand-in answers `password=from-keychain`, and `op` is never called.
2. Write the remaining tests under Proof. Run each one and confirm it fails for its own reason (the stand-in answers, or the config still names `osxkeychain` or `find-generic-password`). Split mode: test-writer does steps 1–2 and commits `Tests for gh-credential-helper-in-dotfiles`.
3. Config: replace `helper = osxkeychain` with the empty `helper =` and its comment. Criteria 5 and 6 (and 3) go green. Commit: `Clear inherited git credential helpers`.
4. Config: add the helper (first as an alias; review rounds 1 and 2 moved it into the script) and the two GitHub sections. Criteria 1, 2 and 4 go green. Commit: `Read GitHub HTTPS credentials from 1Password`.
5. Config: remove `token = !security …` from `[github]`. `test_the_config_reads_nothing_from_the_keychain` goes green. Commit: `Drop the Keychain-backed github.token`.
6. Run the whole file, then the full suite as CI runs it: `set -o pipefail; for f in test/*_test.rb; do ruby -Itest "$f" || break; done`. Run `rubocop test/git_credential_helper_test.rb`. Re-read the full diff.
7. Do not run criterion 7. Put this manual check in the report for Etienne. He runs it after a valid token is in the item, from this worktree before merge: it runs the worktree's script directly, so it needs no restow and ignores `~/.gitconfig`. After merge, `printf 'protocol=https\nhost=github.com\n\n' | git credential fill` gives the same password from anywhere. Neither command prints the token:

   ```sh
   token=$(printf 'protocol=https\nhost=github.com\n\n' | git/.config/git/credential-1password get | sed -n 's/^password=//p')
   curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $token" https://api.github.com/user
   curl -s -H "Authorization: Bearer $token" https://api.github.com/user | jq -r .login
   unset token
   ```

   Expected output: `200`, then `eirvandelden`.

## Risks

- Until Etienne removes `~/.gitconfig`, gh stays the GitHub helper. The change has no effect on GitHub until then.
- After removal, `gh auth setup-git` and any `git config --global` write land in the dotfiles repository through the link. Guarding against that is out of scope per intent; `git status` in the dotfiles checkout shows it.
- The token in `Familie` is rejected today (401). Until Etienne replaces it, every GitHub HTTPS fetch fails with an authentication error. SSH remotes are not affected.
- Every other HTTPS host loses its saved Keychain credentials and prompts in the terminal, or fails without one. This is criterion 5, by intent. It affects HTTPS clones and HTTPS git gems from GitLab, Bitbucket and similar hosts.
- A machine without `op` gets `op: not found`, and git stops for GitHub HTTPS. Adding `op` to `packages.conf` is out of scope per intent.
- Each GitHub HTTPS operation runs `op read`. With 1Password locked, that raises a Touch ID prompt.
- A config file loaded later that sets an empty `credential.https://github.com.helper` disables this helper without a warning. Git has no protection against that.
- Test safety: git's exec path holds the real `git-credential-osxkeychain`. While tests are red against the old config, a run could ask the real Keychain. The harness sets `GIT_EXEC_PATH` to an empty directory and `PATH` to the stub directory, `/usr/bin` and `/bin` only. On macOS, Xcode's own gitconfig still loads and names `osxkeychain`, so this isolation holds only while no `git-credential-osxkeychain` sits in those directories (review round 1). Verified on git 2.54: git then reports `'credential-osxkeychain' is not a git command`, and a `!` helper still works.
- Rejected: the 1Password gh shell plugin (needs a terminal, per intent). Rejected: naming the script by its stowed path `~/.config/git/credential-1password`, because `~/.config/git` is linked file by file (dotfiles-work shares the directory), so the new file needs a restow first and git would have no GitHub helper until then (review round 2). Rejected: a git alias, which a `git-credential-1password` program on `PATH` overrides (review round 1). Rejected: the same shell snippet inline in both host sections (duplicated logic). Rejected: a `https://*.github.com` section, wider than the two hosts the intent names.

## Out of scope

- Everything the intent lists as out of scope: token creation or rotation, vault moves, `~/.gitconfig` removal, `gh auth logout`, `stow`, `packages.conf`, other hosts' credentials, guarding `~/.config/git/config`, `.github/workflows/`.
- `github.user` stays in `[github]`.
- The README does not mention git credentials; it does not change.

## Proof

- 1 GitHub credentials from 1Password → `test/git_credential_helper_test.rb` `test_github_credentials_come_from_the_1password_item`
- 2 Gist credentials from 1Password → `test/git_credential_helper_test.rb` `test_gist_credentials_come_from_the_1password_item`
- 3 Store and erase do nothing → `test/git_credential_helper_test.rb` `test_storing_a_github_credential_leaves_1password_alone`, `test_erasing_a_github_credential_leaves_1password_alone`
- 4 Failed `op read` gives no password → `test/git_credential_helper_test.rb` `test_a_failed_op_read_gives_git_no_github_password`
- 5 Other hosts get nothing → `test/git_credential_helper_test.rb` `test_another_host_gets_no_credentials_from_any_helper`
- 6 No `osxkeychain` helper → `test/git_credential_helper_test.rb` `test_the_config_names_no_osxkeychain_helper`
- 7 Live GitHub check → manual, by Etienne, with the commands in Order of work step 7. It needs his unlocked 1Password and a valid token.

Per changed file, the unit tests expected, named as behaviour:

- `git/.config/git/config`: the tests above, plus `test_the_config_reads_nothing_from_the_keychain` (no `find-generic-password` anywhere in the file; covers the `[github] token` removal).
- Review round 1: a `git-credential-1password` program on `PATH` does not replace the helper → `test/git_credential_helper_test.rb` `test_a_git_credential_1password_program_on_path_does_not_replace_the_helper`. Fix: the helper moves from the alias into the script `git/.config/git/credential-1password`, and both GitHub sections name it by path, which git runs through the shell without a `PATH` lookup.
- Review round 2: GitHub credentials work before the `git` package is restowed → every GitHub test in `test/git_credential_helper_test.rb`, whose temporary HOME holds only the checkout at `~/Developer/dotfiles`. Fix: the helper path points into the checkout (`~/Developer/dotfiles/git/.config/git/credential-1password`), not at the stowed link.

What each test asserts:

- Criteria 1 and 2: `git credential fill` exits 0; stdout holds `username=x-access-token` and `password=stub-token`; the `op` log holds `read op://Familie/Github/token --account vandelden`; the stand-in log is empty.
- Criterion 3: `git credential approve` and `git credential reject` (with a username and password on stdin) exit 0; the `op` log and the stand-in log are both empty.
- Criterion 4: the `op` stub exits 1; `fill` runs with `-c credential.helper=<stand-in>`, so a helper also sits after the GitHub one. Git exits non-zero; stdout holds no `password=`; stderr holds `told us to quit`; the stand-in log is empty.
- Criterion 5: `fill` for `gitlab.com` exits non-zero; stdout holds no `password=`; the `op` log and the stand-in log are both empty.
- Criterion 6 and the Keychain test read the config file text only; they run no git.

Test setup: each test gets a temporary directory as `HOME`. In it: a `bin/op` stub that logs its arguments and prints `stub-token` (the failure test's stub writes an error to stderr and exits 1); a Keychain stand-in script that logs its action and answers `username=keychain` and `password=from-keychain`; a system config file naming that stand-in as `credential.helper`, passed as `GIT_CONFIG_SYSTEM`, to play Xcode's osxkeychain; an empty directory passed as `GIT_EXEC_PATH`. Git runs with `chdir` to the temporary directory (outside any repository), `GIT_CONFIG_GLOBAL` set to the repository's `git/.config/git/config`, the stub `bin` first on `PATH`, and `GIT_TERMINAL_PROMPT=0`. `GIT_DIR`, `GIT_WORK_TREE`, `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT`, `GIT_ASKPASS`, `SSH_ASKPASS` and `XDG_CONFIG_HOME` are unset. Patterns to follow: `test/secrets_loader_test.rb` (the `op` stub), `test/lefthook_posix_sh_test.rb` (git config isolation). `stub-token` is a placeholder, not a secret.

---
Domain skills applied: dotfiles-maintenance (edit sources only, no stow, no new package), dependencies via playbook rule 11 (no new dependency; `op` is already on the machine).
