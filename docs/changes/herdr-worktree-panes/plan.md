# Plan: a herdr pane rooted in every new worktree

From `intent.md` and `spec.md` (2026-09-23). Status: accepted (2026-09-23).

Executor: this branch and its worktree already exist at `~/Developer/dotfiles/.worktrees/herdr-worktree-panes` with `intent.md`, `spec.md` and this file committed. `cd` there first; `worktree-first` then skips itself (already inside a linked worktree). Do not create another worktree.

## Context

The herdr file viewer roots at the focused pane's directory. No pane is ever in a worktree: `worktree-first` only runs `git worktree add`, and `hand-off-plan.sh` starts workers in the main checkout on purpose. Decided: a pane in the current workspace per new worktree (split down, `--no-focus`, labelled `<repo>/<branch>`), closed when the worktree is swept; no new workspaces; unchanged outside herdr. Full requirements in `spec.md`.

Facts that shape the plan (verified 2026-09-23):
- `herdr pane split --current --direction down --cwd <path> --no-focus` returns JSON `{"result":{"pane":{"pane_id":"w1:pV"}}}`; `herdr pane list` returns panes with `pane_id`, `cwd`, `agent_status`, `workspace_id`; `herdr pane rename <id> <label>`; `herdr pane close <id>`.
- `git/.config/git/worktree-tools/` scripts are Ruby (`#!/usr/bin/env rv run ruby`), shell out with `Open3`, share `lib/common.rb` (`Helpers#log/warn/die`, exit codes). Their own `test/` directory is **not** run by CI; `.github/workflows/dotfiles-tests.yml` runs `test/*_test.rb` at the repo root only.
- `test/herdr_worker_scripts_test.rb` builds a stub `herdr` on `PATH` that logs every call to `$HERDR_CALL_LOG` and fakes `pane split` JSON; `herdr_calls` returns the log. Same pattern for the new tests.
- `hand-off-plan.sh` (`herdr/.config/herdr/scripts/`) refuses when `HERDR_ENV != 1` or `HERDR_PANE_ID` is empty, takes one argument (the plan path), splits with `--cwd "$main_checkout"`, and prompts the worker to invoke `worktree-first`.
- `worktree-first/SKILL.md` Step 1 is a shell script in prose (prune, fetch, sweep merged worktrees with `gh pr view` + `worktree-remove`, `git worktree add`); Step 2 runs `git worktree-init` and dependency installs. Shared with Codex via `agents/.agents/skills/worktree-first` (folder symlink); `openai.yaml` has `allow_implicit_invocation: false`.
- `implement/SKILL.md` §5 "Handoff mode" calls `hand-off-plan.sh <absolute path to plan.md>` from the main checkout.

## Files that change

- `git/.config/git/worktree-tools/worktree-pane` (new, Ruby): `open <path>` and `close <path>`; the only place that runs `herdr pane …` for worktrees.
- `git/.config/git/worktree-tools/worktree-create` (new, Ruby): the sweep-and-create logic lifted from `worktree-first` Step 1, calling `worktree-pane close` per swept worktree and `worktree-pane open` for the new one; prints the new worktree's absolute path.
- `test/worktree_pane_test.rb`, `test/worktree_create_test.rb` (new): stub `herdr` and stub `gh` on `PATH`, temp git repos with a fake `origin`.
- `herdr/.config/herdr/scripts/hand-off-plan.sh`: optional second argument `<worktree-name>`; with it, `worktree-create` runs first and the worker pane splits with `--cwd <worktree>`; prompt tells the worker it is already in its worktree.
- `test/herdr_worker_scripts_test.rb`: two new cases for the second argument; existing cases unchanged.
- `claude/.claude/skills/worktree-first/SKILL.md`: Step 1 becomes "run `~/.config/git/worktree-tools/worktree-create <name>`" plus the existing skip conditions and naming rule; Step 2 unchanged; one sentence on the pane.
- `claude/.claude/skills/implement/SKILL.md` §5: pass the change's branch name as the second argument.
- `claude/.claude/WORKTREES.md`: one sentence on the pane.
- `git/.config/git/worktree-tools/README.md`: two new entries in the executables list.

## Order of work

1. **RED — first acceptance test.** `test/worktree_pane_test.rb`: with `HERDR_ENV=1`, `HERDR_PANE_ID=w1:p1` and the stub `herdr` on `PATH`, `worktree-pane open <tmp worktree>` records `pane split --current --direction down --cwd <realpath> --no-focus` and `pane rename w1:pV <repo>/<branch>` where `<repo>` is the main checkout's basename and `<branch>` the worktree's branch. Run: fails, script missing.
2. **GREEN** `worktree-pane open`: read `HERDR_ENV`; find `herdr` on `PATH` (`Open3.capture2("which", "herdr")` as `lib/common.rb` does); `herdr pane list` first — if a pane's `cwd` already equals the real path, do nothing (criterion: twice opens one pane); else split, parse `pane_id`, rename. Any non-zero herdr exit or unparsable JSON → one `warn` line, exit 0. `HERDR_ENV` unset or no `herdr` → exit 0, no output. Requires `lib/common.rb` for `Helpers`.
3. **RED/GREEN** the remaining `open` cases: outside herdr (no calls, no output, exit 0); herdr refuses the split (stub exits 1 for `pane split` when `HERDR_STUB_FAIL_SPLIT=1`): warning to stderr, exit 0; existing pane with same `cwd`: no split.
4. **RED/GREEN** `worktree-pane close <path>`: stub `pane list` returns JSON from `$HERDR_STUB_PANES` (a file the test writes); close records `pane close <id>` for each pane whose `cwd` equals the real path and whose `agent_status` is absent, `idle` or `unknown`; a pane with another status is skipped and named on stdout; no matching pane → nothing, exit 0; outside herdr → nothing.
5. **RED — `worktree-create`.** `test/worktree_create_test.rb`: temp bare repo as `origin` with `main`, a clone as the main checkout; stub `gh` on `PATH` returning `MERGED`/`OPEN`/nothing per branch from `$GH_STUB_STATES`; stub `herdr` as above. Cases: creates `.worktrees/<name>` on branch `<name>` off `origin/main` and prints the path; inside herdr it calls `worktree-pane open` (assert the `pane split … --cwd <path>` call); a merged worktree is swept — `worktree-pane close` call recorded, then `git worktree remove` happened (directory gone, branch deleted with `-D`); a dirty worktree is kept; an open-PR worktree is kept; a fresh worktree at `origin/main` with no PR is kept; refuses on empty name or when `.worktrees` is not ignored (`git check-ignore -q .worktrees`) with exit 1 and a message.
6. **GREEN** `worktree-create`: port Step 1 of the skill line for line into Ruby with `Open3`; call `worktree-remove` (same directory) and `worktree-pane` by path relative to `__dir__`; keep the skill's comments as code comments only where the reason is non-obvious (the "fresh worktree" and `-D` rules). Then, decided 2026-09-23: after creating the worktree, run `git worktree-init` inside it when `git config --get alias.worktree-init` succeeds (test: a stub alias in the temp repo's config pointing at a script that records its cwd; assert it ran in the new worktree; a repo without the alias runs nothing). Dependency installs stay with the agent (skill Step 2).
7. **RED** `test/herdr_worker_scripts_test.rb`: `run_script(HAND_OFF_PLAN, plan_file, "some-branch")` records a `pane split … --cwd <repo>/.worktrees/some-branch --no-focus` call and a prompt that says the worker is already in its worktree and must not run `worktree-first`; without the second argument the existing assertions hold unchanged (they already exist). Stub `worktree-create` on `PATH`? No — the script calls it by absolute installed path; in the test, point `WORKTREE_TOOLS_DIR` (new env var read by the script, default `~/.config/git/worktree-tools`) at the repo's `git/.config/git/worktree-tools/`.
8. **GREEN** `hand-off-plan.sh`: `name="${2:-}"`; when set, `worktree=$("${WORKTREE_TOOLS_DIR:-$HOME/.config/git/worktree-tools}/worktree-create" "$name")`, split with `--cwd "$worktree"`, rename the pane `<repo>/<name>`, and use the "already in your worktree" prompt variant; otherwise the current path. `set -euo pipefail` stays; a failing `worktree-create` aborts before any pane is split.
   Review round 1 departure (spec requirement 8 wins): `worktree-pane` gained a third command,
   `label <path> <pane-id>`, and `hand-off-plan.sh` calls that instead of `herdr pane rename`
   itself, so it stays the only place that calls `herdr pane` for a worktree.
9. **Skill and docs.** `worktree-first/SKILL.md` Step 1 → run `worktree-create` (keep Skip when, the naming rule, and the `.worktrees` ignore check as prose; drop the embedded script). Step 2 → dependency installs only; `git worktree-init` is now run by `worktree-create`. One sentence: "Inside herdr, a pane rooted in the new worktree opens below; focus it for the file viewer." `implement/SKILL.md` §5 step 2: `hand-off-plan.sh <plan.md> <branch>` where `<branch>` is the change folder's slug. `WORKTREES.md`: one sentence. `worktree-tools/README.md`: two entries.
10. Lint: `rubocop` on the two scripts and three tests; `shellcheck -x -S warning` on `hand-off-plan.sh`; `cspell` on all touched files; `test/skill_parity_test.rb` still green (skill body changed, frontmatter not).
11. Commits, one per logical change: `worktree-pane` open (test+script), `worktree-pane` close, `worktree-create` (test+script), `hand-off-plan.sh` (test+script), skill + docs. Push, open the PR. Do not merge.

## Risks

- **`rv run ruby` shebang in CI.** CI runners have no `rv`. The tests run the scripts as `ruby <script>`, as `remove_test.rb` does, so the shebang is not exercised in CI; on the machine `rv` exists. Same situation as `review-report-fresh` today. Accepted.
- **Behaviour change in the sweep.** Moving Step 1 from prose to a script changes nothing intended, but the prose had subtle rules (fresh-worktree skip, `-D` only after `MERGED`). Each rule gets its own test case in step 5; the script is a port, not a redesign.
- **Two agents creating worktrees at once.** `worktree-create` sweeps like the skill did; the fresh-worktree rule protects a concurrent brand-new worktree. Unchanged risk.
- **Pane lookup by `cwd`.** A pane whose shell has `cd`'d elsewhere is not found at sweep time and stays open. Accepted: the label still names it; a later sweep finds nothing and exits 0.
- **`--current` in `hand-off-plan.sh` vs `worktree-create`'s own pane.** With the second argument, `worktree-create` opens a shell pane *and* the script splits a worker pane — two panes for one worktree. Avoid by passing `--no-pane` to `worktree-create` from `hand-off-plan.sh` (flag skips `worktree-pane open`); the worker pane is the rooted pane. Add that flag in step 6 and assert it in step 7.
- **Rejected:** a workspace per worktree (sidebar clutter); labels as the sweep key (renamed panes break it); leaving the sweep script in prose and adding herdr calls there (untestable).

## Proof

- Creating a worktree inside herdr opens a rooted pane labelled `<repo>/<branch>`, caller keeps focus → `test/worktree_pane_test.rb` `test_open_splits_a_pane_below_rooted_in_the_worktree_without_focus` and `test_open_labels_the_pane_repo_slash_branch`
- Outside herdr: no pane, no output, worktree exists → `test/worktree_pane_test.rb` `test_open_outside_herdr_does_nothing_and_exits_zero`
- herdr refuses the split: worktree exists, exit 0, one warning → `test/worktree_pane_test.rb` `test_open_warns_once_and_exits_zero_when_herdr_refuses_the_split`
- Sweeping a merged worktree closes its pane, then removes the worktree → `test/worktree_create_test.rb` `test_sweep_closes_the_pane_rooted_in_a_merged_worktree_before_removing_it`
- Sweeping leaves a pane with a running agent open and names it → `test/worktree_pane_test.rb` `test_close_skips_a_pane_with_a_running_agent_and_names_it`
- Sweeping with no pane closes nothing → `test/worktree_pane_test.rb` `test_close_with_no_matching_pane_closes_nothing`
- `hand-off-plan.sh <plan> <name>` creates the worktree and starts the worker in a pane rooted there with the "already in your worktree" prompt → `test/herdr_worker_scripts_test.rb` `test_handing_off_with_a_worktree_name_starts_the_worker_inside_that_worktree`
- `hand-off-plan.sh <plan>` unchanged → existing `test_handing_off_splits_a_pane_below_here_without_taking_the_screen` and its siblings
- `implement handoff` passes the branch name → prose in `implement/SKILL.md` §5 (no test; skill text)
- `worktree-first` twice for the same name opens one pane → `test/worktree_pane_test.rb` `test_open_reuses_an_existing_pane_rooted_in_the_worktree`
- `WORKTREES.md` mentions the pane → `grep -c pane claude/.claude/WORKTREES.md` ≥ 1 (manual check in the PR)

Per changed file, unit tests expected:
- `worktree-pane`: `open` splits/renames; `open` reuses; `open` silent outside herdr; `open` warns on failure; `close` closes matching idle panes; `close` skips running agents; `close` silent when none.
- `worktree-create`: creates from `origin/<default>`; prints the path; sweeps MERGED; keeps dirty; keeps OPEN; keeps fresh; refuses empty name; refuses when `.worktrees` not ignored; `--no-pane` skips the pane; runs `git worktree-init` in the new worktree when the alias exists; runs nothing when it does not.
- `hand-off-plan.sh`: with name → `worktree-create --no-pane`, `--cwd <worktree>`, rename, prompt variant; without name → unchanged.

Test setup: temp directories only; a bare `origin` repo plus a clone for `worktree-create`; stub `herdr` and stub `gh` written to a temp bin on `PATH` (herdr stub extended with `$HERDR_STUB_PANES` for `pane list` and `$HERDR_STUB_FAIL_SPLIT`); `HOME` pointed at a temp dir so `~/.config/git/ignore.global` is absent and the test writes `.git/info/exclude` itself.

## Out of scope

The superpowers worktree under `~/.config/superpowers/worktrees/`. Wiring `git/.config/git/worktree-tools/test/` into CI (separate change; the new tests live at the repo root and run in CI). `start-review.sh` (already splits with `--cwd "$PWD"`). Any herdr file-viewer plugin change. Running `stow` — Etienne restows `git`, `claude` and `herdr` after merge.
