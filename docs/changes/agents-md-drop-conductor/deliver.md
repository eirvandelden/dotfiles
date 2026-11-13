# Delivery account: agents-md-drop-conductor

## Behaviour delivered

- `agents.md` (and `CLAUDE.md`, its symlink) no longer names the removed `conductor` stow package; its package line equals the `STOW` list in `packages.conf`.
- `test/state_dirs_install_test.rb` requires `isolated_git` again, so `IsolatedGitTest` passes. PR #285 had removed the line as unused.
- `run_secrets` in `test/secrets_loader_test.rb` runs `zsh -f -c`, so the test's `op` stub answers even when the real 1Password CLI is on the Homebrew path.

## Evidence

- Before: `main` CI run 43256905299 failed `repo_agents_file_test.rb` and `isolated_git_test.rb`. Locally `secrets_loader_test.rb` failed 5 tests, with the real `op` answering (`"token" isn't an item in the "Private" vault`).
- After, on this machine with `/opt/homebrew/bin/op` installed: `bin/test test/repo_agents_file_test.rb` passes (9 runs), `bin/test test/isolated_git_test.rb` passes, `bin/test test/secrets_loader_test.rb` passes (28 runs).

## Checks

- Full `bin/test`, run by the coordinator: 121 files, 94 runs, 0 failures, 0 errors, 0 skips.
- `rubocop` on both touched test files: no offenses. markdownlint no-hardwrap on `agents.md` and the change artefacts: clean.
- Brakeman and Bundler Audit: not applicable; this repository has no Rails app and no Gemfile.

## Review

- Round 1 (Claude reviewer): two Important findings (second red test on `main`; local secrets loader failures) and two nits. Etienne chose to fold both Important fixes into this change; the intent and plan were widened and re-accepted. All four fixed.
- Round 2 (Claude reviewer): no findings. Codex review was off.

## Follow-ups

- The wider Conductor cleanup (READMEs, playbook rule 22, `docs/plans`, worktree-tools Conductor support, the Codex trust entry) gets its own intent.
- The plan noted a possible guard test against `zsh -c` without `-f` in tests; out of scope here.
