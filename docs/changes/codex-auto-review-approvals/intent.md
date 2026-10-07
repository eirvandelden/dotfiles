# Intent: Codex stops asking for approval of routine commands

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix.

## Problem

Codex asks Etienne to approve almost every command that a build needs: git writes (fetch, add, commit, rebase, worktree, push), herdr pane calls, and `gh` calls. Since September there were 129 such prompts. Answering "always allow" does not help: Codex saves a rule in `codex/.codex/rules/default.rules`, but asks again the next time.

A probe against a fresh `codex app-server` 0.160.0 shows why. An `allow` rule only skips the prompt for a command that runs inside the sandbox. The sandbox keeps `.git` read-only and blocks the herdr socket, so these commands need escalation. An escalated command prompts even when an `allow` rule matches it. Extra `writable_roots` do not make `.git` writable.

## Proposed outcome

During a build, Codex runs the routine commands that the playbook already permits without asking Etienne. The commands that the playbook reserves for Etienne still need his consent: pushes to remotes he does not own, plain `--force`, GitHub comments or reviews posted as him, deploys, and destructive database commands.

## Affected users and systems

- Etienne, in every Codex client that runs through the app-server: the terminal `codex`, the ChatGPT desktop app, and `codex exec`.
- Personal and work machines, because both use `codex/.codex/config.toml`.
- The consent guard hook and lefthook stay as they are.

## Constraints

- The dotfiles repository is public: no work names, repositories or remotes in the change.
- The playbook consent rules (rules 5, 6, 9, 13, 19, 20) keep their meaning.
- No new dependencies and no sandbox removal (`danger-full-access` is out).

## Open questions

- When the automatic reviewer denies a command, does Codex fall back to asking Etienne, or does it refuse? The spec settles this with a probe.
