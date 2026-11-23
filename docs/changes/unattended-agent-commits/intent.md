# Intent: Unattended agent commits and pushes

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-23). Type: feature. Delivery: autonomous. Codex review: no.

## Problem

An agent cannot commit or push while Etienne is away. Commits are signed through 1Password (`gpg.ssh.program=op-ssh-sign`, `commit.gpgsign=true`) and pushes go through the 1Password SSH agent, so each one waits for an approval at the computer.

Etienne runs many agents at once, each in its own pane (49 at the time of writing). They stall until he returns.

An agent commit also looks like one of Etienne's own. He cannot tell afterwards which commits he made and which an agent made.

## Proposed outcome

Claude Code and Codex sessions commit and push to branches of personal repositories with no 1Password prompt.

Every agent commit is recognisable by its author, its `Co-Authored-By` trailer and the key that signed it. Etienne's own commits keep the 1Password flow and stay as they are.

## Affected users and systems

- Etienne, who reviews commits afterwards.
- Every Claude Code and Codex session, in any pane (herdr, herdr-app, Rex or a plain terminal).
- The `git` package (`config`, `allowed_signers`), `claude/.claude/settings.json` and `codex/.codex/config.toml` in this repository.
- GitHub settings of the `eirvandelden` account and the `eirvandelden-dev` organisation: a signing key, two tokens, branch protection.

## Constraints

- Personal repositories only: `eirvandelden/` and `eirvandelden-dev/`. Work repositories are a separate intent in the `dotfiles-work` repository, because playbook rule 15 forbids sharing credentials between personal and work. This public repository must not name work repositories.
- No secret in any environment variable. The environment holds paths and identity only. There is no `unlock` step and no per-shell step.
- Each fine-grained PAT has one resource owner, so there are two PATs: one for `eirvandelden`, one for `eirvandelden-dev`. Each has `contents:write` on all repositories of its owner and an expiry date.
- PATs live in the macOS Keychain. The signing key is a plain file with `0600` permissions, outside the repository and every stow package, registered on GitHub as a signing key only, never as an authentication key.
- No private key, token or `master.key` ever enters git. Only the public signing key is committed, in `allowed_signers`.
- Claude never reads, prints or logs a PAT or the private key (playbook rule 10). Etienne creates the key and the tokens and registers them.
- Claude never runs `stow` (rule 12). Etienne restows after the change.
- A missing or expired credential fails with a clear error. It never falls back to the 1Password flow.
- Approved permissions for this change: no gems or packages, no system-tool installs, no migrations, no deploy files. Each GitHub settings change (signing key, branch protection on a repository) needs Etienne's approval at that step.
- The agent-only configuration must reach panes started from herdr, herdr-app and Rex. The plan verifies this.
- Etienne's own shells and commits stay unchanged.

## In scope

- Agent-only git configuration, set in the Claude `settings.json` `env` block and in Codex's `[shell_environment_policy.set]` table. Identity uses `GIT_AUTHOR_*` and `GIT_COMMITTER_*`. The rest uses `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_n` and `GIT_CONFIG_VALUE_n`: the signing key path, SSH signing, the HTTPS rewrite of `git@github.com:` remotes and the Keychain credential helper per owner.
- Author per tool: `Claude (agent) <noreply@anthropic.com>` and `Codex (agent) <codex@openai.com>`. The committer is the tool name with `etienne@vandelden.family`.
- A `Co-Authored-By` trailer on every agent commit.
- The agent public key in `allowed_signers`, so `git log --format='%G? %GK'` tells agent signatures from Etienne's.
- Written one-time setup steps for Etienne: create the key, create both PATs, store them in the Keychain, register the signing key.
- Branch protection on `main` for personal repositories, so a PAT cannot push to `main`.
- A guard that stops any private key or `master.key` from entering git: the key file lives outside every stow package, and a check blocks staging private key material.
- An end-to-end check in a sandbox repository, in a pane with no 1Password approval.
- The hand-off of the work-repo half: once this intent is accepted, start an intent in `~/Developer/dotfiles-work`, in its own pane with its own agent, seeded with this design.

## Out of scope

- Setting up credentials for work repositories. The handed-off intent in `dotfiles-work` does that.
- A per-session trailer such as `Agent-Session`.
- Changes to Etienne's own 1Password signing and push setup.
- Hosted AI agents.
- Merging pull requests and deployment.

## Acceptance criteria

- An agent in an unattended pane commits, and no 1Password prompt appears. `git log --show-signature` shows a good signature.
- `git log --author=agent` lists the agent commit. `git log --format='%G? %GK'` shows the agent key on it and Etienne's key on his own commits.
- An agent pushes a branch to a repository of `eirvandelden` and to a repository of `eirvandelden-dev` with no prompt.
- An agent push to `main` of a personal repository is rejected by GitHub.
- With the signing key file missing, the commit fails with a message that names the key, and no prompt appears.
- With the PAT missing or expired, the push fails with a message that names the token, and no prompt appears.
- Staging a private key file or a `master.key` is refused by the guard.
- A commit Etienne makes in his own shell still signs through 1Password and carries his name.
- A Codex session commit carries the author `Codex (agent)` and a `Co-Authored-By` trailer.
- A pane started from herdr, herdr-app or Rex gets the agent configuration.

## Flagged concerns

- Any process under Etienne's user can read the Keychain items and the key file. Chosen: accept it, and limit the damage with signing-only key use, per-owner tokens and expiry.
- A PAT with `contents:write` can push to `main` if the local consent guard is bypassed. Chosen: add GitHub branch protection to this change.
- GitHub is expected to need a verified committer email to mark a signature Verified. Chosen: use `etienne@vandelden.family` as committer. The plan verifies the behaviour on GitHub.
- Autonomous delivery meets GitHub settings changes. Chosen: each settings change is a stop-and-ask step, not an automatic one.

## Decisions

- Work repositories become their own intent, with its own pane and agent, in `dotfiles-work` — rule 15 forbids shared credentials, and the work half depends on an outside policy answer (rationale offered with the option; Etienne chose it).
- Two fine-grained PATs, one per owner — keeps fine-grained scoping and covers both owners.
- Author uses each tool's own name and email — Etienne: "claude and codex have their own email address that are usually added".
- Codex author address is `codex@openai.com` — the address used by a published audit-trail recipe for Codex CLI (christiantietze.de, 2026-03-17); Etienne confirmed it.
- Committer uses Etienne's verified email — GitHub is expected to need it for the Verified badge.
- The signing key stays a plain `0600` file, not Keychain-encrypted — Etienne picked it over the encrypted option; no reason given.
- No per-session trailer — nothing asks for per-agent tracing yet.
- A missing credential fails with a clear error — a silent fallback brings back the blocking prompt.
- Branch protection joins the scope — no reason given.
- Delivery is autonomous, without the Codex review — no reason given.

## Open questions

None.
