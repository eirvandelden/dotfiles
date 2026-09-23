# Review: herdr-worktree-panes

No `REVIEW.md` or `REVIEW.local.md` at the repository root; passes follow the default policy in
`claude/.claude/skills/new-repo-setup/references/REVIEW.md`.

## Round 1 — 2026-09-23T10:31Z — 2af0227f

State at review: `test/worktree_pane_test.rb` (8 runs), `test/worktree_create_test.rb` (11 runs),
`test/herdr_worker_scripts_test.rb` (30 runs) green; `rubocop` on the two scripts and three tests
clean; `shellcheck -x -S warning` on `hand-off-plan.sh` clean. No uncommitted changes.

### Bugs

- [x] Important: `worktree-create` ignores the exit status of `git worktree add` (and sends its stderr to `/dev/null`), then prints `.worktrees/<name>` and exits 0 anyway. When the add fails — branch `<name>` already exists without a worktree, a stale registered path (see the prune finding), an invalid ref name — the caller gets a path that does not exist or is not on branch `<name>`. `hand-off-plan.sh` then splits the worker pane with `--cwd` at that path and tells the worker it is inside its worktree; plan step 8 promised "a failing `worktree-create` aborts before any pane is split". `run_worktree_init` and `open_pane` also run against the missing path. Related: in `worktree-first/SKILL.md`, `cd "$(worktree-create "$branch")"` becomes `cd ""` when the script dies (empty name, `.worktrees` not ignored), which leaves the agent in the main checkout with only a stderr line to show for it. — `git/.config/git/worktree-tools/worktree-create:125` → fixed (d9b98e03, 86537461)
- [x] Important: `git worktree prune` was dropped in the port. The old Step 1 ran it first; spec requirement 9 says `worktree-create` "prunes", and the new `SKILL.md` prose says it "prunes stale admin files". Without it, a worktree directory deleted by hand stays registered, and `git worktree add` for the same path then fails ("missing but already registered worktree") — which the finding above turns into a silent success. — `git/.config/git/worktree-tools/worktree-create:20` → fixed (d9b98e03)
- [x] Important: a pane with a running agent is never named in the output. `worktree-pane close` prints the pane id on stdout, but `worktree-create#close_pane` captures that stdout with `Open3.capture2` and discards it. Spec requirement 4 and its acceptance criterion ("leaves that pane open, names it") hold for `worktree-pane` alone but not for the sweep the user actually runs. Printing to the caller's stdout would also corrupt the path that `cd "$(…)"` and `hand-off-plan.sh` read, so the name needs stderr. — `git/.config/git/worktree-tools/worktree-create:115` → fixed (953858c4, d9b98e03) — `worktree-pane close` now names the pane on stderr instead of stdout; `worktree-create` captures and forwards that stderr instead of discarding it.
- [x] Important: the herdr refusal warning does not name the herdr error. `herdr` is run with `err: File::NULL`, and `warn_refused` prints a fixed sentence. The spec's acceptance criterion says "one warning line names the herdr error"; the test only counts stderr lines. — `git/.config/git/worktree-tools/worktree-pane:88` → fixed (953858c4)
- [x] Important: `panes_at` runs `herdr pane list` without `--workspace`, so it matches panes in every workspace (herdr 0.9.1 `pane list` takes an optional `--workspace <WORKSPACE_ID>`). Spec requirements 1 and 4 scope both commands to the current workspace. Result: `open` opens no pane here when a pane in another workspace already sits in that worktree, and `close` closes idle panes in other workspaces. Either filter by the caller's workspace or record in the spec that all workspaces are meant. — `git/.config/git/worktree-tools/worktree-pane:55` → fixed (953858c4) — filters by `HERDR_WORKSPACE_ID` when herdr set it, falls back to no filter otherwise (commented).

### Security

Nothing found. All git, gh and herdr calls use argument arrays; no shell interpolation of the
branch name; no secrets read or logged.

### Compliance

Acceptance criteria against tests in the diff:

| Criterion | Test |
| --- | --- |
| Pane in current workspace, rooted, labelled `<repo>/<branch>`, caller keeps focus | `worktree_pane_test` `test_open_splits_a_pane_below_rooted_in_the_worktree_without_focus`, `test_open_labels_the_pane_repo_slash_branch` (workspace scoping not tested — see Bugs) |
| Outside herdr: no pane, no herdr output, worktree exists | `worktree_pane_test` `test_open_outside_herdr_does_nothing_and_exits_zero` (asserts no calls and exit 0; not "no output") |
| herdr refuses the split: worktree exists, exit 0, one warning naming the error | `worktree_pane_test` `test_open_warns_once_and_exits_zero_when_herdr_refuses_the_split` — "names the error" missing |
| Sweep closes the pane, then removes the worktree | `worktree_create_test` `test_a_merged_worktree_is_swept_before_the_new_one_is_created` — order not asserted |
| Sweep leaves a running agent's pane open, names it, removes the worktree | `worktree_pane_test` `test_close_skips_a_pane_with_a_running_agent_and_names_it` — through `worktree-create`: missing |
| Sweep with no pane closes nothing, removes the worktree | `worktree_pane_test` `test_close_with_no_matching_pane_closes_nothing` — removal half not covered at that level |
| `hand-off-plan.sh <plan> <name>` creates the worktree, worker rooted there, "already in worktree" prompt | `herdr_worker_scripts_test` `test_handing_off_with_a_worktree_name_starts_the_worker_inside_that_worktree` |
| `hand-off-plan.sh <plan>` unchanged | existing hand-off tests, unchanged in the diff |
| `implement handoff` passes the branch name | prose, `implement/SKILL.md` §5 (no test, as planned) |
| Twice for the same name opens one pane | `worktree_pane_test` `test_open_reuses_an_existing_pane_rooted_in_the_worktree` |
| `WORKTREES.md` mentions the pane | `claude/.claude/WORKTREES.md:12` |

No existing test was weakened, skipped or deleted.

- [x] Important: a test named in `plan.md`'s `## Proof` does not exist: `test_sweep_closes_the_pane_rooted_in_a_merged_worktree_before_removing_it`. The nearest test, `test_a_merged_worktree_is_swept_before_the_new_one_is_created`, asserts that the pane closed and the worktree is gone, but not that the close came first. Also, plan step 7 says the hand-off test asserts `--no-pane`; the test asserts neither `--no-pane`, the `pane rename … <repo>/some-branch` call, nor that `.worktrees/some-branch` exists. A second `pane split` from `worktree-create` would still pass it. — `test/worktree_create_test.rb:49`, `test/herdr_worker_scripts_test.rb:137` → fixed (d9b98e03, 19da212f) — renamed the test to match Proof and added an order assertion (pane close before `git worktree remove`, via a shared call-order log); the hand-off test now asserts exactly one `pane split` call, the `pane rename` call, and that `.worktrees/some-branch` exists.
- [x] Nit: `hand-off-plan.sh` runs `ruby "$worktree_tools/worktree-create"`, which bypasses the script's `#!/usr/bin/env rv run ruby` shebang and uses whatever `ruby` comes first on `PATH`. Running the script directly would keep the interpreter choice in one place. — `herdr/.config/herdr/scripts/hand-off-plan.sh:49` → fixed (19da212f)
- [x] Nit: `hand-off-plan.sh` calls `herdr pane rename` for a worktree pane itself. Spec requirement 8 says nothing but `worktree-pane` calls `herdr pane` for worktrees; plan step 8 asked for the rename in the script. The spec and plan disagree; record which one holds. — `herdr/.config/herdr/scripts/hand-off-plan.sh:69` → fixed (953858c4, 19da212f) — spec requirement 8 wins: `worktree-pane` gained a `label <path> <pane-id>` command, and `hand-off-plan.sh` calls that instead; `plan.md` step 8 notes the departure.
- [x] Nit: `worktree-create` uses paths relative to the current directory (`.worktrees/*/`, `check-ignore .worktrees`, `worktree add .worktrees/<name>`). Run from a subdirectory of the main checkout, it creates `.worktrees` inside that subdirectory. `git rev-parse --show-toplevel` would pin it to the root. The old prose had the same limit. — `git/.config/git/worktree-tools/worktree-create:63` → fixed (d9b98e03)
- [x] Nit: `--no-pane` is only recognised after the name. `worktree-create --no-pane foo` takes `--no-pane` as the branch name. — `git/.config/git/worktree-tools/worktree-create:21` → fixed (d9b98e03)
- [x] Nit: the Step 1 code block in `worktree-first/SKILL.md` now shows only the issue-number case (`title=… slug=… branch=…`). Without an issue, `$issue_number` is unset and the block produces `branch="-"`; the "otherwise a kebab-case task slug" case exists only in the sentence above it. — `claude/.claude/skills/worktree-first/SKILL.md:31` → fixed (86537461)

Counts: 6 Important, 5 Nit.
