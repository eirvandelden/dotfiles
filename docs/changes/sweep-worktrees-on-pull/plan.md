# Plan: Sweep merged worktrees on pull

From `intent.md` (2026-10-07). Status: accepted.

Context: a merged worktree under `.worktrees/` stays until the next `worktree-create` run in its repository. This change makes every pull that moves the checked-out branch start the same sweep in the background. The pull returns as fast as today. The sweep code moves out of `worktree-create` into a shared library, which `worktree-create` and a new `worktree-sweep` script both use.

## Design decisions

1. **One sweep, two callers.** The sweep methods move from `worktree-create` to `git/.config/git/worktree-tools/lib/sweep.rb` as `WorktreeTools::Sweep`. The code moves; it is not copied. `worktree-create` calls it in its own process. A new executable `worktree-sweep` calls it for the lefthook pull hooks. One code path gives the same removal rules and the same side effects (herdr pane, `worktree-remove`, `git worktree remove`, local branch).
2. **Repository lookup and lock in a library.** `repo_root!` (with its submodule handling), `default_branch!` and `fetch` move from `worktree-create` to `lib/repository.rb` as `WorktreeTools::Repository`, with `root`, `default_branch`, `common_dir`, `fetch_default_branch` and `exclusively { … }`. Both scripts need these, so neither keeps a copy.
3. **One sweep or create at a time per repository.** `Repository#exclusively` takes an exclusive `flock` on `<git-common-dir>/worktree-sweep.lock` and holds it for its block. Another caller waits. `worktree-sweep` holds it for the fetch and the sweep. `worktree-create` holds it from before its fetch until after `worktree-init`, then opens the pane. So a pull sweep never runs while `worktree-create` fetches, sweeps, creates or reuses `.worktrees/<name>`, or initialises it. `worktree-create` can wait for a running pull sweep; that sweep leaves it fewer worktrees to check. Rejected: `worktree-create` runs `worktree-sweep` as a child process. The child opens the lock file again, and `flock` on a second open file waits for the parent forever.
4. **Kept paths.** `Sweep#run(keep:)` never touches a path in `keep`; it compares resolved real paths. `worktree-sweep` keeps the worktree that contains its working directory. Git and lefthook run a hook in the root of the worktree that pulled, so a pull never removes its own worktree. `worktree-create` keeps `.worktrees/<name>`, as today.
5. **Never-pushed branches stay.** Today a clean worktree without a PR is removed when its branch is an ancestor of `origin/<default>` and not at its tip. A worktree branched before a merge, with nothing committed yet, then goes as soon as a pull moves `origin/<default>`. New rule: that ancestor-based removal applies only when `git config branch.<b>.merge` is `refs/heads/<b>`, so the branch was pushed under its own name. A `MERGED` PR still removes the worktree, and the "at the tip of `origin/<default>`, no PR" guard stays. The removal set only gets smaller. This also changes `worktree-create`'s sweep. Etienne decided this on 2026-10-07. It overrides the intent's out-of-scope line "Changes to which worktrees count as removable" for this one case, because the intent's acceptance criteria require that a worktree with no commits beyond `origin/main` survives the pull.
6. **Fetch first, best effort.** `worktree-sweep` runs `git fetch origin <default>` before it sweeps, with `GIT_TERMINAL_PROMPT=0`, and ignores a failure. A pull from a feature branch, a narrowed fetch refspec, or a `post-rewrite` after a local rebase can leave `origin/<default>` stale. `worktree-create` keeps its own fetch, as today. Each caller fetches once.
7. **Detach in Ruby.** `worktree-sweep --detach` opens (and creates) the lock file, then calls `Process.daemon(true)`: a new session, stdin, stdout and stderr on `/dev/null`, working directory kept. Then it takes the lock, fetches and sweeps. The hook command ends when the parent exits. The lock file exists before the hook command returns, so its presence right after a pull shows that a sweep started. Rejected: `nohup … &` in `lefthook.yml`. Lefthook waits until every holder of its output pipes closes them; `Process.daemon` handles the pipes and the session in one call that works the same on macOS and Linux.
8. **Clean git environment.** Before its first git call, `worktree-sweep` deletes `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_PREFIX`, `GIT_COMMON_DIR` and `GIT_OBJECT_DIRECTORY` from its environment. Git exports these to hooks, and lefthook passes them on (seen with the rubocop fallback job). With `GIT_DIR` set, `git -C .worktrees/x status` reads the wrong repository and can call a dirty worktree clean.
9. **Hook command.** `lefthook.yml` gets one command, `sweep-worktrees`, in `post-merge` and in `post-rewrite`: `run: ~/.config/git/worktree-tools/worktree-sweep --detach >/dev/null 2>&1 || true`. A missing script, a missing `ruby` or a failure prints nothing and exits 0. The command has no `glob` and no `{files}`, so lefthook runs it on every such hook. The hook shims do not change: `post-merge` and `post-rewrite` shims exist.
10. **Output.** `Sweep` prefixes its stderr lines with the calling script's name (`worktree-create:` or `worktree-sweep:`). It writes nothing to stdout, so the stdout of `worktree-create` stays the new path only (`hand-off-plan.sh` reads it).

## Integration points

- Lefthook `post-merge` and `post-rewrite`, through the global shims in `git/.config/git/hooks/` and their `LEFTHOOK_CONFIG` fallback to `~/Developer/dotfiles/lefthook.yml`.
- Repositories that reference the global config: through `remotes`, lefthook reads the local clone at `.git/info/lefthook-remotes/dotfiles/lefthook.yml`; through `extends`, it reads the named file. The shims run `lefthook run --no-auto-install`, and the global config sets `no_auto_install: true`. In lefthook's `internal/command/run.go`, `syncHooks` (the only code that fetches remotes, and the only place `refetch` and `refetch_frequency` act) runs only when both are off. So a remote clone never refreshes under these shims; caren's is from 2026-07-14. Etienne decided on 2026-10-07: refresh each clone by hand after the merge; automatic refresh stays out of scope.
- `worktree-pane close` (herdr). It needs `HERDR_ENV=1`, which the detached sweep inherits from the pane where the pull ran. A pull outside herdr closes no pane, as `worktree-create` does today.
- `worktree-remove` (puma-dev and Caddy routes), `git worktree remove`, `git branch -d`/`-D`, `gh pr view`.
- `herdr/.config/herdr/scripts/hand-off-plan.sh` calls `worktree-create` and reads its stdout. That contract does not change.
- Stow: `~/.config/git/worktree-tools/` and its `lib/` hold one link per file. The new `worktree-sweep`, `lib/repository.rb` and `lib/sweep.rb` appear there only after `stow -t "$HOME" --ignore='hooks/(post-merge|pre-commit|pre-push)' git` on each machine. The `--ignore` is needed because `post-merge`, `pre-commit` and `pre-push` in `~/.config/git/hooks/` are real files on purpose (Etienne, 2026-10-07); plain stow aborts on them. Agents never run stow (playbook rule 12); Etienne does it after the merge. Until then the hook command does nothing and prints nothing. `worktree-create` works without the restow: Ruby's `__dir__` resolves the link to the dotfiles checkout (checked on 2026-10-07 with Ruby 4.0.7: a linked script printed its real directory), so its `$LOAD_PATH` finds the new library files.

## Files that change

- `git/.config/git/worktree-tools/lib/repository.rb` — new. `WorktreeTools::Repository`: `root` (moved `repo_root!`, `working_tree?`, `submodule_checkout`, `toplevel!`), `default_branch` (moved), `common_dir`, `fetch_default_branch` (moved `fetch`), `exclusively`.
- `git/.config/git/worktree-tools/lib/sweep.rb` — new. `WorktreeTools::Sweep`: `run(keep:)` and the methods moved from `worktree-create` (`sweep_one`, `clean?`, `worktree_branch`, `pr_state`, `fresh?`, `branch_sha`, `ancestor?`, `remove_worktree`, `git_showing_errors`, `close_pane`, `run_worktree_remove`), plus `pushed_under_own_name?` (decision 5).
- `git/.config/git/worktree-tools/worktree-sweep` — new executable, `#!/usr/bin/env ruby` like its neighbours: options (`--detach`), environment cleanup, kept path, lock file, detach, lock, fetch, sweep.
- `git/.config/git/worktree-tools/worktree-create` — uses `Repository` and `Sweep`; wraps fetch, sweep, create or reuse, and `worktree-init` in `exclusively`.
- `lefthook.yml` — the `sweep-worktrees` command in `post-merge` and `post-rewrite`. The comments above both hooks name the sweep.
- `test/worktree_sweep_test.rb` — new, unit tests for `worktree-sweep` and `Sweep`.
- `test/worktree_sweep_on_pull_test.rb` — new, acceptance tests through a real `git pull`, the global shims and the lefthook binary.
- `test/worktree_create_test.rb` — two new tests (lock, never-pushed branch). The existing tests stay unchanged and green.
- `git/.config/git/worktree-tools/README.md` — `worktree-sweep` in the executables list, and a short "Sweep on pull" section with a rollout note: after the merge, restow `git` on each machine (`cd ~/Developer/dotfiles && stow -t "$HOME" --ignore='hooks/(post-merge|pre-commit|pre-push)' git`), and in each `remotes` repository refresh the clone by hand (`git -C <repo>/.git/info/lefthook-remotes/dotfiles pull`).
- `claude/.claude/skills/worktree-first/SKILL.md` — the Step 1 paragraph says a pull also sweeps and states the never-pushed rule; the last sentence of Step 3 says a pull that brings in the merge sweeps the worktree.

Not changed: the hook shims, `hand-off-plan.sh`, `worktree-pane`, `worktree-remove`, CI (it already installs the latest lefthook release, so `test/lefthook_binary.rb` finds it on `PATH`).

## Order of work

1. Write `test_a_pull_on_main_in_the_main_checkout_removes_a_merged_worktree_its_branch_and_its_pane` in `test/worktree_sweep_on_pull_test.rb`, with the bounded wait helpers. Run it. Watch it fail because `.worktrees/foo` remains.
2. Move the repository lookup to `lib/repository.rb`. Run `test/worktree_create_test.rb`: green.
3. Move the sweep to `lib/sweep.rb` with `run(keep:)`. Run `test/worktree_create_test.rb`: green.
4. Write the never-pushed tests (unit and `worktree-create`). Watch them fail. Add `pushed_under_own_name?`. Green.
5. Write the `worktree-sweep` foreground unit tests (removal, kept path, git environment, stdout, fetch). Watch them fail. Create `worktree-sweep`. Green.
6. Write the lock tests (`worktree-sweep` waits; `worktree-create` waits). Watch them fail. Add `Repository#exclusively` and use it in both scripts. Green.
7. Write the `--detach` unit tests. Watch them fail. Add `--detach`. Green.
8. Add `sweep-worktrees` to `post-merge` and `post-rewrite` in `lefthook.yml`. Run step 1's test: green.
9. Write the other acceptance tests one at a time. Run each, and change production code only if it is red.
10. Update the README and `SKILL.md`.
11. Run every test file: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`, and each file in `git/.config/git/worktree-tools/test/`. Run RuboCop on the changed Ruby files, `yamllint lefthook.yml`, and the no-hardwrap markdownlint check on the changed Markdown. Re-read the diff.
12. Verify as a human: in a scratch clone with a merged worktree, pull with the branch's shims and `lefthook.yml`, see the prompt return, then see `git worktree list` lose the worktree a moment later. Record the commands and output for the review.

## Risks

- **An agent still in a merged worktree.** A pull in the main checkout soon after a merge removes that worktree even when an agent pane is open in it. `worktree-pane` leaves an agent's pane open, so the agent loses its working directory. `worktree-create` does the same today, but pulls happen sooner after a merge. Etienne accepted this on 2026-10-07.
- **Wait in `worktree-create`.** It can wait for a running pull sweep to release the lock: at most one sweep, about one `gh` round trip per worktree, plus one fetch.
- **Ref lock contention.** The detached sweep's `git branch -D` can run while the pull finishes (an autostash pop writes `refs/stash`). Git refuses a contended ref lock without damage. If the sweep loses, its branch stays, and no later sweep sees it, because the worktree directory is gone. Rare; accepted.
- **Never-pushed rule edge.** A branch pushed without `-u` and fast-forward merged without a PR keeps its worktree, because its `merge` config still names `origin/<default>`. Every change here goes through a PR, so `MERGED` covers it.
- **Restow and stale remote clones.** The pull sweep starts on a machine only after the restow, and in a `remotes` repository only after its clone is refreshed by hand.
- **Live `post-merge` is not the shim.** On Etienne's Mac, `~/.config/git/hooks/post-merge` is a lefthook-written file (2026-10-07): it has no `LEFTHOOK_CONFIG` fallback and no `--no-auto-install`. A fast-forward pull in a repository without its own lefthook config then runs no `post-merge` command, so neither migrations nor this sweep. Rebase pulls still sweep through the `post-rewrite` shim, and repositories with their own config or a `remotes`/`extends` reference are not affected. Fixing that hook file is a separate change; this change keeps the shims as they are, and its tests use the repository's shims.
- **More sweeps.** `post-rewrite` also fires on `git commit --amend` and a manual rebase, and `post-merge` on `git merge`. The intent accepts extra sweeps; each costs a fetch and one `gh pr view` per clean worktree, in the background.
- Rejected: a `--sweep-only` flag on `worktree-create`, which avoids a restow but gives "create" a mode that creates nothing.
- Rejected: shell backgrounding in `lefthook.yml` (decision 7), and a child-process sweep inside `worktree-create` (decision 3).

Out of scope, from `intent.md`: repositories with their own lefthook config that does not reference the global one; worktrees outside `.worktrees/`; other changes to which worktrees count as removable (decision 5 is the one exception); sweeps on "Already up to date" or on `git fetch`; any report of what a sweep removed; removing the sweep from `worktree-create`; sweeping another repository. Also out of scope: refreshing lefthook remote clones.

## Proof

- After the PR for `.worktrees/foo` merges, `git pull` on `main` in the main checkout removes `.worktrees/foo`, its local branch and its herdr pane → `test/worktree_sweep_on_pull_test.rb` `test_a_pull_on_main_in_the_main_checkout_removes_a_merged_worktree_its_branch_and_its_pane`
- A `git pull` that moves a feature branch inside `.worktrees/bar` removes the merged `.worktrees/foo` too → `test/worktree_sweep_on_pull_test.rb` `test_a_pull_that_rebases_a_feature_branch_inside_a_worktree_removes_another_merged_worktree`
- `git pull` gives the prompt back as fast as before; `.worktrees/foo` disappears shortly after → `test/worktree_sweep_on_pull_test.rb` `test_the_pull_returns_while_the_sweep_is_still_running`
- After that pull, a dirty worktree, one with an open PR, one with no commits beyond `origin/main` (branched before the merge, never pushed) and one on a detached HEAD all remain → `test/worktree_sweep_on_pull_test.rb` `test_dirty_open_pr_never_pushed_and_detached_worktrees_survive_the_pull_sweep`
- A `git pull` inside the merged `.worktrees/foo` leaves `.worktrees/foo` in place → `test/worktree_sweep_on_pull_test.rb` `test_a_pull_inside_a_merged_worktree_keeps_that_worktree`
- A pull in repository A never removes a worktree of repository B → `test/worktree_sweep_on_pull_test.rb` `test_a_pull_in_one_repository_leaves_another_repositorys_worktrees_alone`
- A pull in a repository with its own `lefthook.yml` and no reference to the global config removes nothing → `test/worktree_sweep_on_pull_test.rb` `test_a_repository_with_its_own_config_and_no_reference_starts_no_sweep`
- A pull in a repository whose `lefthook-local.yml` references the global config through `remotes` removes its merged worktrees → `test/worktree_sweep_on_pull_test.rb` `test_a_repository_that_references_the_global_config_through_remotes_sweeps_on_pull`
- In scope, not in the criteria list: the same through `extends` → `test/worktree_sweep_on_pull_test.rb` `test_a_repository_that_extends_the_global_config_sweeps_on_pull`
- With `gh` logged out, `git pull` succeeds as today, and the sweep adds no error output → `test/worktree_sweep_on_pull_test.rb` `test_with_gh_logged_out_the_pull_succeeds_and_prints_no_sweep_output`
- `worktree-first` still sweeps merged worktrees when it creates a new one → `test/worktree_create_test.rb` `test_sweep_closes_the_pane_rooted_in_a_merged_worktree_before_removing_it` (existing, unchanged)

Per changed file, the unit tests expected:

- `worktree-sweep` and `lib/sweep.rb` (`test/worktree_sweep_test.rb`): `removes a merged clean worktree and its branch`, `removes a branch pushed under its own name once origin/main contains it`, `keeps a never-pushed branch that origin/main moved past`, `keeps the worktree it runs in`, `ignores GIT_DIR and GIT_INDEX_FILE from a hook environment`, `fetches the default branch before it sweeps`, `still sweeps when the fetch fails`, `waits for a running sweep to release the lock`, `with --detach returns before the sweep finishes`, `with --detach creates the lock file before returning`, `with --detach prints nothing`, `writes nothing to stdout`.
- `lib/repository.rb`: covered through `worktree-create` by the existing cases for a subdirectory, a linked worktree, a submodule and a submodule's linked worktree; plus `default branch comes from origin/HEAD` in `test/worktree_sweep_test.rb`.
- `worktree-create` (`test/worktree_create_test.rb`): new `test_waits_for_a_running_sweep_before_it_fetches_or_creates` and `test_a_never_pushed_worktree_survives_the_sweep_after_origin_moved_on`; all existing tests unchanged and green, including the pane-before-remove order, the detached-HEAD message, the locked-worktree error and the reused-worktree cases.
- `lefthook.yml`: the acceptance tests above; `test/lefthook_pull_hooks_test.rb` stays green (its `HOME` has no `worktree-sweep`, so the command must stay silent there).

Test setup: temporary directories only. A bare `origin.git` with `main`, and a clone whose `.git/info/exclude` ignores `.worktrees`. A "merged" worktree has a commit, is pushed with `-u`, and has `MERGED` in the `gh` stub. The global shims are copied from `git/.config/git/hooks/` and set as `core.hooksPath` in a temporary `GIT_CONFIG_GLOBAL`. `HOME` is the temporary directory: it holds `Developer/dotfiles/lefthook.yml` (copied from the branch) and `.config/git/worktree-tools` (a link to the branch's directory). Stubs on `PATH`: `gh` reads branch states from a file (as in `worktree_create_test.rb`), exits 1 with "not logged in" in the logged-out test, and in the timing test blocks until the test creates a release file. `herdr` logs calls (as in `worktree_create_test.rb`), with `HERDR_ENV=1`. The real lefthook binary comes from `test/lefthook_binary.rb`. A test waits for a detached sweep like this: it polls until a worktree that must go is gone, then takes the lock file's `flock` with `LOCK_NB` in a loop. Every wait has a 20-second deadline and fails with a message instead of hanging. A test that expects no sweep checks that the lock file does not exist. The `remotes` test clones a bare repository holding the branch's `lefthook.yml` into `.git/info/lefthook-remotes/dotfiles`, because the shims never fetch it. Teardown creates the release file and waits (bounded) for the lock before it deletes the directory.

---
Domain skills applied: object-oriented-design, ruby-style, dotfiles-maintenance, rails-testing (Minitest conventions).

## Critique

### Round 1 (codex exec -p terra)

- `__dir__` keeps the link's directory, so the linked `worktree-create` cannot find new sibling files before a restow → dismissed: a probe on 2026-10-07 (Ruby 4.0.7) ran a linked script, and `__dir__` printed the real directory; Ruby defines `__dir__` as the directory of the file's real path.
- The lock does not protect the reused `.worktrees/<name>` while `worktree-create` fetches before its sweep → fixed (decision 3: `worktree-create` holds the lock from before the fetch until after `worktree-init`, and calls the sweep in its own process; new test `test_waits_for_a_running_sweep_before_it_fetches_or_creates`).
  - The check also showed a larger gap: the old rule removes a never-pushed worktree once `origin/main` moves past it. Etienne chose decision 5.
- No fetch in the sweep leaves `origin/<default>` stale after a narrowed refspec or a local rebase → fixed (decision 6: best-effort, non-interactive fetch before every `worktree-sweep` run; tests for fetch and failed fetch).
- `--no-auto-install` does not stop `refetch` and `refetch_frequency` → dismissed: in lefthook's `internal/command/run.go`, `syncHooks`, which holds the refetch logic, runs only when neither `--no-auto-install` nor `no_auto_install: true` applies; both apply under these shims.
- The acceptance tests can skip silently on Linux CI because nothing installs lefthook → dismissed: `.github/workflows/dotfiles-tests.yml` installs the latest lefthook release to `/usr/local/bin`, and `LefthookBinary.locate` finds it on `PATH`.
- Polling and a blocking `flock` without a timeout can hang the suite → fixed (test setup: every wait uses `LOCK_NB` in a loop with a 20-second deadline and fails with a message).
- The intent names `extends` but no test covers it → fixed (new test `test_a_repository_that_extends_the_global_config_sweeps_on_pull`).
