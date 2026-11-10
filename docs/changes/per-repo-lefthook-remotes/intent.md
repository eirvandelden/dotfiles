# Intent: Plain per-repo lefthook config, no global hooks

Author: Etienne van Delden. Status: accepted. Type: refactor. Delivery: step-by-step.

## Problem

PR #269 runs every repository's hooks through a global hook wrapper in `core.hooksPath`. The wrapper builds a runtime config with `extends:` and decides by origin which repos get the shared config. Lefthook does this natively: each repo names the shared config in `remotes:`, and `lefthook-local.yml` overrides a shared job. The global hooks are extra machinery on top of lefthook, and they block lefthook's own install and refetch.

A scratch repo (lefthook 2.2.2, no `core.hooksPath`, plain `lefthook install`) showed on 2026-11-07:

- `lefthook install` clones the remote into `.git/info/lefthook-remotes/<name>` and writes `.git/hooks` for every hook type in the merged config.
- `lefthook run` refetches the remote once its `FETCH_HEAD` is older than `refetch_frequency`.
- Offline, lefthook prints "Couldn't sync … Will continue with old version." and the commit succeeds.
- `lefthook-local.yml` overrides a shared job of the same name.
- A hook type that the shared config adds later gets no `.git/hooks` file until `lefthook install` runs again in that repo.
- Git exports `GIT_DIR` to hooks in a linked worktree, and lefthook passes it to jobs, so `bundle exec` jobs break there.

## Proposed outcome

Each personal repo has its own `lefthook.yml` with the dotfiles config as a remote, `refetch_frequency: 24h`, and its own extra jobs. Overrides live in `lefthook-local.yml`. Each repo runs `lefthook install` once. Dotfiles ships no global hooks. Editing the shared config in the dotfiles repo reaches every repo within a day, with no per-repo edit.

## Affected users and systems

Etienne's personal repositories under `~/Developer`. The `git` stow package: `core.hooksPath` in `git/.config/git/config`, the hook wrapper, the seven hook scripts and their tests. The shared `lefthook.yml` and `lefthook-branch-guard.yml`. The `new-repo-setup` skill. The glossary entries "Hook wrapper", "Hook scripts", "Hooks copy", "Runtime config" and "Shared config".

## Constraints

- Edit sources in `~/Developer/dotfiles/<package>/`, never the links. Never run `stow`.
- The dotfiles repository is public: no work references.
- A hook run must never fail a commit or push because the remote cannot be fetched, offline included.
- No new dependency.

## In scope

- Remove `core.hooksPath` from `git/.config/git/config`.
- Remove the hook wrapper and the seven hook scripts from `git/.config/git/hooks/`, with the tests that exist only for them.
- Shared jobs that load Ruby or run git in another repository clear `GIT_DIR` themselves.
- Remove `no_auto_install: true` from the shared `lefthook.yml`; it only guarded the global hooks.
- An empty section in the shared `lefthook.yml` for each git hook type it does not use yet, except `reference-transaction`, `post-index-change`, `prepare-commit-msg` and `post-commit`, so the first `lefthook install` writes those hooks.
- Rewrite the tests that relied on the global hooks, so that test repos use `remotes:` and `lefthook install`.
- A documented `lefthook.yml` template with the `remotes:` block, for repos and for `new-repo-setup`.
- Rollout steps in the worktree-tools README, run by Etienne after the merge: restow `git`, trash the dangling `~/.config/git/hooks` links, then run `lefthook install` in the dotfiles checkout.
- Glossary updates for the retired terms.

## Out of scope

- Adding or changing `lefthook.yml` in other repositories, or running `lefthook install` there: one change per repo, listed as a follow-up.
- Work repositories: they lose the global hooks too. Running `lefthook install` in each one is a follow-up outside this public repository.
- Running `stow` or touching `~/.config/git/hooks` directly.
- Changing what the shared jobs check.
- Filing anything upstream at lefthook.

## Acceptance criteria

- A repo whose `lefthook.yml` lists the dotfiles remote runs the shared jobs and its own jobs on commit, after one `lefthook install`.
- A job in `lefthook-local.yml` overrides the shared job of the same name.
- After the shared config changes upstream, the repo picks up the change on its first hook run after 24 hours, with no manual step.
- A hook run without network access still commits.
- A `bundle exec` job in a linked worktree on `pre-push` does not see `GIT_DIR`.
- A repo with no `lefthook.yml` and no `lefthook install` runs no hooks at all.
- When the shared config gives jobs to a listed hook type that had none, a repo runs them after its next refetch, with no new `lefthook install`. The four unlisted types (`reference-transaction`, `post-index-change`, `prepare-commit-msg`, `post-commit`) need a new install.

## Flagged concerns

Lefthook gives the remote job priority over the repo's own `lefthook.yml` for a same-named job. Chosen side: document `lefthook-local.yml` as the override file and leave lefthook's rule alone.

A repo with no `lefthook.yml` gets no shared jobs after this change. Chosen side: accepted, since Etienne wants a config per repo.

## Decisions

- No global hooks, just regular lefthook config — Etienne's preferred setup ("my preferred setup is no extra hooks! just regular lefthook config"), chosen during the plan stage on 2026-11-07; it replaces the earlier slim-wrapper intent.
- Use whatever is most native to lefthook — lefthook already clones, refetches and overrides; the scratch repo confirmed each.
- Each repo declares the dotfiles config as a `remotes:` entry — Etienne wants a lefthook config per repo that sets his default as a remote.
- Remove `core.hooksPath` for every repo, work repos included — one plain lefthook setup everywhere, matching "no extra hooks".
- Document `lefthook install` in the dotfiles repo as a rollout step after the merge — `lefthook install` needs `--force` while `core.hooksPath` is still set (its `--help`), and no machine change happens before the merge.
- List the git hook types in the shared `lefthook.yml`, as empty sections where unused, except `reference-transaction`, `post-index-change`, `prepare-commit-msg` and `post-commit` — Etienne does not use them, and they fire on every ref update, index write or commit (decided 2026-11-10). A job for one of them needs a new `lefthook install`.

## Open questions

None.
