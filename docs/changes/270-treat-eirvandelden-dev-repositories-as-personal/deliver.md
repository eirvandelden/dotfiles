# Delivery account: 270-treat-eirvandelden-dev-repositories-as-personal

## Behaviour delivered

- A repository under `eirvandelden-dev` is a personal repository everywhere one under `eirvandelden` is. `RemoteMatcher::PERSONAL_OWNERS` holds both owners, and the consent guard, `change-scope`, `auto-accept` and the agent-voice hook follow it.
- An owner that only shares the prefix (`eirvandelden-devtools`, `eirvandeldenx`) is not personal.
- The consent guard refusal names both owners.
- gh-dash "Personal PRs" filters on `user:eirvandelden user:eirvandelden-dev`.
- `ghp <repo> [path...]` opens `eirvandelden-dev/<repo>` when that repository exists, else `eirvandelden/<repo>`, also when the lookup fails. Bare `ghp` opens the profile without a lookup.
- GLOSSARY (Personal repository, new term Personal owner), PLAYBOOK rule 19 and §7a, three `settings.json` trust lines and three script header comments name both owners.

## Evidence

- `change-scope` in fresh repositories: `git@github.com:eirvandelden-dev/appkit.git`, `https://github.com/eirvandelden-dev/appkit.git` and `git@github.com:eirvandelden/homelab-iac.git` print `personal`; `eirvandelden-devtools/x` and `eirvandeldenx/x` exit 1 with "unknown remote".
- The real consent guard, fed a push payload: `git push git@github.com:eirvandelden-dev/clocky.git my-branch` exits 0; the same push to `eirvandelden-devtools/clocky` exits 2 with the refusal that lists `eirvandelden/*, eirvandelden-dev/*`.
- `ghp homelab-iac`, `ghp clocky issues` and bare `ghp` with a stubbed `open` and the real `gh`: `https://github.com/eirvandelden/homelab-iac`, `https://github.com/eirvandelden/clocky/issues` and `https://github.com/eirvandelden/` (clocky has not moved yet).
- Not yet observable: the `eirvandelden-dev` half of `ghp` and of gh-dash "Personal PRs". The org has no repositories until eirvandelden/homelab-iac#19 moves clocky. `test/ghp_test.rb` and `test/gh_dash_config_test.rb` cover both; check `gh dash` by hand after the first move.

## Checks

- `bin/test`: 124 files, 94 runs, 0 failures.
- `lefthook run pre-commit` on every changed file: rubocop, shellcheck-zsh, yamllint, no-hardwrap and the marker checks green.
- `lefthook run pre-commit --all-files` reports shellcheck-zsh, no-fixme and stylelint findings only in files this branch does not touch.
- No Rails application here, so no Brakeman or Bundler Audit.

## Review

- Round 1 (Claude reviewer): four nits. Three fixed in their own commits; one dismissed (the `ghp` path join differs from the plan's signature only because shellcheck rejects the zsh-only form).
- Round 2 (Claude reviewer): nothing found. Codex review was not enabled for this change.
