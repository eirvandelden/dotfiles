# Intent: Tighten the autoMode block in settings.json

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-03). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

`claude auto-mode critique` flags six issues in the `autoMode` block of `claude/.claude/settings.json`. Two soft_deny rules guard the wrong things or an absent cluster. The environment text says no secrets manager exists, lists the helper and test files as sensitive, trusts every `eirvandelden/*` repository, and misses the branch and dotfile rules of the playbook.

## Proposed outcome

The `autoMode` block matches the playbook and the repository. The auto-mode classifier blocks the destruction of the credential helper and its tests unless Etienne names the file. It treats `origin` of this repository and the other repositories of the `eirvandelden` GitHub user as trusted remotes.

## Affected users and systems

Etienne's Claude Code sessions in every repository, since the file is the global user `settings.json`. The auto-mode classifier reads the block.

## Constraints

- Edit the source file `claude/.claude/settings.json`, never the symlink in `~/.claude`.
- `soft_deny` keeps `"$defaults"` as its first entry.
- Add no soft_deny rule for `bundle install`, deploys or `--force`. Hooks already enforce them.
- The repository is public. The diff holds no `nedap` or `caren` reference.
- Config has no tests (playbook rule 3).
- One logical change per commit. No push to `main`.
- No extra permissions needed: no gems, system tools, drop migrations or deploy files.

## In scope

The block exists only as an uncommitted edit in the main checkout, so the change starts with two commits:

1. Commit one adds the `autoMode` block as it stands, copied from the main checkout with `git diff | git apply`. The main checkout keeps its uncommitted edit untouched.
2. Commit two applies six edits. Review rounds 1 and 2 then added fix commits for edits 1, 5, 7 and 8 (see Decisions):
   1. `soft_deny`: replace the `Bash(rm -rf:*) in test/ fixtures ...` rule with: "Deleting, truncating or overwriting (rm, git rm, git clean, git checkout --, git restore, mv, `>`) `git/.config/git/credential-1password` or `test/{git_credential_helper,secrets_loader,secrets_scope_menu}_test.rb` requires the user to name the exact file."
   2. `soft_deny`: delete the `kubectl ... -n test` rule. The repository has no cluster.
   3. Environment, Secrets management: change "None configured" to "1Password (`op`); the credential helper and its tests call `op read`".
   4. Environment, Sensitive data locations: list the real secrets (resolved 1Password values, `.env*`, `*.key`, `*.pem`, gitignored paths). Add that the helper and test files are tracked code and fine to push.
   5. Environment, routine bullet: replace the "routine under eirvandelden/ prefix" line with "push/pull to `origin` of this repo is routine; other `eirvandelden/*` repos follow playbook rule 19".
   6. Environment, branches and dotfiles: `main` is protected by a ruleset. Pushes to feature branches on `origin` are routine. Editing shell profiles inside the repository is routine. `stow` and `lefthook install` need an explicit user request (playbook rules 7, 12, 19).

## Out of scope

- New soft_deny rules for `bundle install`, deploys or `--force`.
- Any other key in `settings.json`.
- Changes to the hooks that enforce those rules.
- The uncommitted edit in the main checkout. It stays as it is.

## Acceptance criteria

- `jq . claude/.claude/settings.json` parses.
- `claude auto-mode config` shows the new text, and `soft_deny` still starts with `"$defaults"`.
- `claude auto-mode critique` no longer reports items 1 to 5.
- `soft_deny` holds `"$defaults"` plus one custom rule, the credential-file rule.
- The environment no longer mentions `kubectl` or `-n test`.
- `git diff origin/main...HEAD | grep -iE 'nedap|caren'` prints nothing.

## Decisions

- Carry the block over as its own commit, then tighten it in a second commit — keeps the six edits reviewable as a clean diff.
- Autonomous delivery — chosen at the delivery-mode question.
- Only non-work edits go into the carried block — the repository is public.
- Edit 5 scopes the distrust to repos outside `eirvandelden/*`, and edit 1 adds `git rm` and `git restore` — review round 1 found the verbatim text clashes with playbook rule 19 (2026-11-03).
- The `Source control` and `Trusted repo` lines name the other repos of the `eirvandelden` GitHub user as trusted — review round 2 found they contradicted edit 5 (2026-11-03).

## Open questions

None.
