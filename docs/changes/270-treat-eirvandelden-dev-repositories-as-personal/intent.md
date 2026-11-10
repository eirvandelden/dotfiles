# Intent: Treat `eirvandelden-dev` repositories as personal

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-10). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

Etienne's personal repositories move from the `eirvandelden` account to the new GitHub org `eirvandelden-dev` (eirvandelden/homelab-iac#19). The tooling decides "personal repository" by the `eirvandelden` owner alone (`RemoteMatcher.personal?`, pattern `github.com[:/]eirvandelden/`). A repository under `eirvandelden-dev` does not match. After a move, the consent guard asks before every push, `change-scope` no longer prints `personal`, autonomous delivery and `auto-accept` refuse, and the session gets no persona. The rule texts and gh-dash also name only `eirvandelden`, and `ghp` opens only `github.com/eirvandelden/...`.

## Proposed outcome

A repository under `eirvandelden-dev` is a personal repository everywhere a repository under `eirvandelden` is one. Both owners stay personal: homelab-iac, dotfiles and dotfiles-work stay under `eirvandelden`.

## Affected users and systems

- Etienne, and every Claude and Codex session in a personal repository.
- `claude/.claude/hooks/remote_matcher.rb` and its callers: `consent-guard.rb`, `agent-voice.rb`, `finish/scripts/change_scope.rb` (`change-scope`, used by intent, plan, review, deliver and finish), and `plan/scripts/auto-accept`.
- The texts that state the rule: `GLOSSARY.md` (Personal repository), `agents/.agents/PLAYBOOK.md` rule 19 and §7a, the consent guard's refusal message, and the trust text in `claude/.claude/settings.json`.
- `github/.config/gh-dash/config.yml` (Personal PRs section).
- `zsh/.config/zsh/functions/gh.zsh` (`ghp`).

## Constraints

- No new dependencies, system tools, migrations or deploy files are needed.
- Must ship before the first repository moves to `eirvandelden-dev` (eirvandelden/homelab-iac#19).
- The dotfiles repository is public. The work allowlist stays in dotfiles-work and is not touched.
- Edit source files in the dotfiles repository only; never the stowed symlinks, and never run `stow`.

## In scope

- `RemoteMatcher.personal?` matches both owners, so all its callers follow.
- GLOSSARY, PLAYBOOK rules 19 and §7a, the consent guard message and the `settings.json` trust text name both owners.
- gh-dash "Personal PRs" lists open pull requests from both owners.
- `ghp <repo> [path...]` opens `github.com/eirvandelden-dev/<repo>/...` when that repository exists, else `github.com/eirvandelden/<repo>/...`. Bare `ghp` still opens the `eirvandelden` profile.

## Out of scope

- Moving any repository (eirvandelden/homelab-iac#19).
- Gem source examples in skills (`github: "eirvandelden/mvpa.css"`, `rubocop-eirvandelden`) and README links. They change when those repositories move, in their own issues.
- The work allowlist file and its format.
- The uncommitted edits in the main checkout's `settings.json` and `config.toml`.

## Acceptance criteria

- Pushing a branch to `git@github.com:eirvandelden-dev/clocky.git` passes the consent guard without asking, as a push to `git@github.com:eirvandelden/clocky.git` does.
- In a repository whose origin is `https://github.com/eirvandelden-dev/appkit.git`, `change-scope` prints `personal`.
- `auto-accept` flips a plan in an `eirvandelden-dev` repository under the same conditions as in an `eirvandelden` repository.
- A session that starts in an `eirvandelden-dev` repository gets a persona.
- An owner that only starts with the same letters, such as `github.com/eirvandelden-devtools/x` or `github.com/eirvandeldenx/x`, is not personal.
- Every case the existing guard tests cover for `eirvandelden` behaves the same for `eirvandelden-dev`.
- gh-dash "Personal PRs" shows an open pull request in `eirvandelden-dev/clocky` and one in `eirvandelden/homelab-iac`.
- `ghp clocky issues` opens `https://github.com/eirvandelden-dev/clocky/issues` once clocky lives there; `ghp homelab-iac` opens `https://github.com/eirvandelden/homelab-iac`; `ghp` opens `https://github.com/eirvandelden/`.
- When the lookup for `ghp` fails (no network, `gh` not signed in), `ghp` opens the `eirvandelden` URL, and GitHub's redirect does the rest.
- GLOSSARY, PLAYBOOK and the consent guard message name both owners.

## Decisions

- Type chore, short interview — the cause and the single fix point (`RemoteMatcher`) are clear.
- Cover the guards, the rule texts, gh-dash and the `ghp` opener — moved repositories must behave and show up as personal everywhere, and gh-dash would otherwise hide their pull requests.
- `ghp` opens the owner that has the repository — it should reach the right page without relying on redirects, which break if an old name is ever reused.
- Autonomous delivery without a Codex review — a small change with existing guard tests.

## Open questions

None.
