# Intent: bi installs gems through rv

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature.

## Problem

`bi` installs gems with `bundle install`. Its `rv ci` path was switched off in March 2026, because rv did not read Bundler settings then. rv 0.6.0 (June 2026) added that support, but `bi` still goes through Bundler.

`bi` is a zsh function. Agent shells (Claude and Codex) do not load it, so agents cannot run it. Agents call `bundle install` directly, and nothing steers them to `bi`.

The lefthook post-merge `bundle` command has its own copy of the install logic, separate from `bi`.

## Proposed outcome

`bi` installs gems with rv. Bundler only resolves the lockfile; rv does every install.

Humans in zsh, Claude, Codex and the lefthook post-merge hook all run the same `bi`.

Agents install gems only through `bi`. The playbook says so, and a direct install command is refused with a message that names `bi`.

## Affected users and systems

- Etienne, typing `bi` in zsh.
- Claude Code and Codex agents, in every repository (personal and work).
- The lefthook post-merge `migrations` → `bundle` command in this repository.
- The playbook, `core-values.yml`, and the owned `worktree-first` skill.

## Constraints

- rv is the Ruby version manager; no other manager is used (playbook rule 8).
- `bi` must run in agent shells: non-interactive, bash or zsh, without the zsh aliases loaded.
- Work repositories use private gem sources and per-gem build flags (`BUNDLE_BUILD__*` in `~/.bundle/config`).
- Claude and Codex get the same rule and the same block (parity goal).
- Vendored skill text stays as upstream wrote it.

## In scope

- `bi` resolves with Bundler when the lockfile is missing or lacks a Gemfile gem, then installs with `rv ci`.
- `bi` retries with `bundle install` when `rv ci` fails, after a warning.
- `bi` runs `bin/rails app:update:bin` and `solargraph` after the install, only in projects with `bin/rails`.
- `bi` never waits for keyboard input: the binstub step keeps every existing binstub that differs.
- `bi` without a Gemfile says there is nothing to install and succeeds.
- `bi` without rv on the PATH stops with an error.
- `bi` is reachable from agent shells, not only from interactive zsh.
- The lefthook post-merge `bundle` command calls `bi`.
- The playbook and `core-values.yml` tell agents to install gems with `bi`.
- A Claude hook and a Codex rule refuse every install form: `bundle`, `bundle install`, `bundle i`, `bin/bundle install`, with or without flags.
- The owned `worktree-first` skill says `bi` instead of `bundle install`.

## Out of scope

- `bundle exec`, `bundle update <gem>`, `bundle add`, `bundle lock`, and other non-install Bundler commands stay allowed.
- Vendored skills (ruby-upgrade, rails-upgrade, rails-guides, using-sqlite-worktrees) keep their `bundle install` text.
- Installs that a project script runs internally (e.g. `bin/setup`).
- Installing or upgrading rv itself.

## Acceptance criteria

- In a project with an up-to-date Gemfile.lock, `bi` installs the gems with `rv ci`, and `bundle install` does not run.
- In a project without a Gemfile.lock, `bi` writes the lockfile with Bundler, then installs with `rv ci`.
- After a gem is added to the Gemfile, `bi` adds it to the lockfile and installs it with `rv ci`.
- When `rv ci` fails, `bi` prints a warning and installs with `bundle install`.
- On a machine without rv, `bi` stops with an error that says rv is missing, and installs nothing.
- In a directory without a Gemfile, `bi` prints that there is nothing to install and exits with success.
- In a Rails app, `bi` regenerates the binstubs and runs solargraph after the install; in a plain Ruby gem, it only installs.
- In a Rails app with a customised `bin/dev`, `bi` finishes without a prompt, and `bin/dev` keeps its content.
- A Claude agent and a Codex agent can run `bi` from their own shells.
- When a Claude or Codex agent runs `bundle install` (or `bundle`, `bundle i`, `bin/bundle install`), the command is refused, and the message tells it to run `bi`.
- `bundle exec rake` and `bundle update rails` still run for an agent.
- After a pull that changes the Gemfile.lock, the post-merge hook installs through `bi`.

## Flagged concerns

- A missing rv stops `bi`, but a failing `rv ci` falls back to `bundle install`. Chosen: a missing rv is a machine setup fault to report (playbook rule 8); a failing `rv ci` is an rv gap that must not block the install.

## Open questions

None.
