# Spec: Lefthook hook rewrites stop blocking work

From `intent.md` (2026-09-25). Status: accepted.

## Flagged concerns

- **Scope growth, small.** The intent names only the `bundle` failure. The cause is that `glob` never filters in the `migrations` group, so `migrate` (`rails db:migrate`) and `client-dependencies` (`yarn install`) also run on every pull in every repository. `bundle` fails first in the dotfiles repository and `piped: true` then skips the other two, so only the Gemfile error was visible. Fixing the glob fixes all three with the same change. Adding only the Gemfile guard would leave `yarn install` and `rails db:migrate` running after every pull in repositories that have `package.json` or Rails but did not change them. This spec fixes all three; say so if that should be a separate change.
- **Residual risk, not covered.** Repositories with their own lefthook config can still sync hooks into the global directory while `~/.gitconfig` hides the global `core.hooksPath` from lefthook: through a nested `lefthook run` in their own config without `--no-auto-install`, or through an agent running `lefthook run` by hand. Lefthook has no environment variable for `no_auto_install`, and this repository does not own those configs. Two ways to close it are out of scope under the intent's constraints: adding `core.hooksPath` to the machine-local `~/.gitconfig` (then lefthook's own refusal works again), or removing `~/.gitconfig` (it holds the gh credential helper). The report after merge names both.

## Requirements

1. Lefthook never syncs hooks into the global hooks directory from a run that uses the dotfiles `lefthook.yml`: in the dotfiles repository and its worktrees (own config), and in repositories without a config of their own (global fallback). This includes the nested `lefthook run migrations` started by `post-merge` and `post-rewrite`.
2. After a pull or a rebase, each hook in the global hooks directory is still the link that stow made, and the file it points to is unchanged.
3. The tests reproduce the real machine layout that let lefthook write: `core.hooksPath` set in `~/.config/git/config`, a separate `~/.gitconfig` present, and the hooks as links to tracked shims. Without the fix, the regression tests fail on that layout.
4. Each `migrations` command runs only when a pulled or rebased file matches its glob.
5. `bundle` runs only when a `Gemfile` exists at the repository root, the same way `brakeman` already checks for `config/application.rb`. This covers a pull that deletes the Gemfile.
6. Everything that already works keeps working: a changed `Gemfile.lock` still runs `rv ci`, a new migration or changed `db/schema.rb` still runs `rails db:migrate`, a changed `yarn.lock` or `package-lock.json` still runs `yarn install`, and a repository with its own lefthook config still ignores the global defaults.

## Design decisions

- **Turn off automatic hook sync in the config: `no_auto_install: true` at the top of `lefthook.yml`.** This is lefthook's documented switch (`docs/configuration/no_auto_install.md`, 2.1.12). The dotfiles `lefthook.yml` is both the dotfiles repository's own config and the global fallback that the shims pass through `LEFTHOOK_CONFIG`, so one key covers requirement 1 for both cases. A nested `lefthook run` loads the same config, so the key covers it too, and no `--no-auto-install` flag has to be added by hand to each nested call.
- **Keep the shims as lefthook's template.** A hand-written shim does not help. Lefthook renames a hook it does not recognise to `<hook>.old` and writes its template in its place, so the link is lost either way. Lefthook's binary lookup in the template stays.
- **Do not protect the hooks directory.** A read-only directory would also block stow and `git`'s own writes. The cause is in lefthook's config, and the fix belongs there (brief question 3).
- **Do not ignore the hook files in git.** That would hide the changed tracked files, but it would not restore the links or the global fallback.
- **Make `glob` filter by adding a `{files}` template to each `migrations` command.** Lefthook docs (`docs/configuration/glob.md`): "This is only used if you use a file template in `run` … or provide your custom `files` command." Outside `pre-commit` and `pre-push`, a glob without a template does nothing. With `{files}` and `--files-from-stdin`, lefthook filters the files it reads from stdin by the glob and skips the command when none match (tested with 2.1.12: `README.md` skipped, `Gemfile.lock` ran, `bundler/Gemfile` skipped). How `{files}` appears in each `run` line is a plan decision.
- **Root Gemfile guard.** `bundle` gains `[ -f Gemfile ]` in front of its current command, next to the existing `Gemfile.lock` check. It covers a pull that deletes the Gemfile, which the glob still matches.

## Integration points

- `lefthook.yml` (repository root): `no_auto_install: true`, the three `migrations` commands, the `bundle` guard.
- `test/lefthook_pull_hooks_test.rb`: the test pattern to extend. Today it sets `GIT_CONFIG_GLOBAL` to a file that holds `core.hooksPath`, so lefthook's own refusal applies and the existing `test_pull_does_not_overwrite_hook_scripts` passes without the fix. The regression tests need the real layout (requirement 3) instead.
- `git/.config/git/hooks/*`: read only. The tests link to them; no change.
- lefthook 2.1.12, the version CI pins in `.github/workflows/dotfiles-tests.yml`. No workflow change.
- After merge: Etienne restows `git` once (`stow -t "$HOME" -R --no-folding git`) after he moves the four real files in `~/.config/git/hooks/` aside.

## Acceptance criteria

1. Pulling a change into the dotfiles repository leaves every global hook as a link to its unchanged tracked shim. (Req. 1, 2, 3)
2. Finishing a rebase in the dotfiles repository leaves every global hook as a link to its unchanged tracked shim. (Req. 1, 2, 3)
3. Pulling a change into a repository without its own lefthook config leaves every global hook as a link to its unchanged tracked shim. (Req. 1, 2, 3)
4. Pulling a change that touches only `README.md` runs neither `bundle`, `rv ci`, `rails db:migrate`, nor `yarn install`. (Req. 4)
5. Pulling a change that touches only a nested `bundler/Gemfile` does not run `bundle` or `rv ci`. (Req. 4)
6. Pulling a change that deletes the root `Gemfile` does not run `bundle install`. (Req. 5)
7. Pulling a changed `Gemfile.lock` still runs `rv ci`; a new migration or changed `db/schema.rb` still runs `rails db:migrate`; a changed `yarn.lock` or `package-lock.json` still runs `yarn install`; a repository with its own lefthook config still ignores the global defaults. (Req. 6 — the existing tests, kept green)

---
Domain skills applied: dotfiles-maintenance (stow layout, hooks package). No Rails, API, UI or dependency skills: the change is lefthook config and its tests.
