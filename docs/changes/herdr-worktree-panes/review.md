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

## Round 2 — 2026-09-23T12:05Z — c9185ec9

State at review: `test/worktree_pane_test.rb` (14 runs), `test/worktree_create_test.rb` (16 runs),
`test/herdr_worker_scripts_test.rb` (30 runs) green; `rubocop` on the two scripts and three tests
clean; `shellcheck -x -S warning` on `hand-off-plan.sh` clean. No uncommitted changes. All
round 1 fixes hold.

### Bugs

- [x] Important: the sweep closes panes with a live Claude session. `running?` treats `idle` as "no agent", but herdr 0.9.1 reports `agent_status: "idle"` for a Claude agent that waits for input (live `herdr pane list` on this machine: 10 panes `{"agent":"claude","agent_status":"idle"}`, 8 `done`, 2 `working`, 23 `unknown` with `agent: null`). An idle worker or reviewer pane in a merged worktree gets `herdr pane close`, which ends its session; a `done` pane (also a live agent) is kept, so the two waiting states are handled in opposite ways. Shell panes show `unknown` and `agent: null`. The `agent` field, not `agent_status`, tells "has an agent". The tests use `agent_status: "running"`, which herdr never emits (`working` is the real value), and no fixture sets `agent`. The spec's design decision ("`idle`/`unknown`/absent count as not running") rests on the same wrong assumption; correct it there too. — `git/.config/git/worktree-tools/worktree-pane:56` → fixed (8261d679) — renamed `running?` to `has_agent?`, keyed off the `agent` field; fixtures use realistic `{agent, agent_status}` pairs; `spec.md`'s "Running agents" decision corrected.
- [x] Important: a clean worktree on a detached HEAD is swept, and its commits are lost. `worktree_branch` returns `HEAD`; `fresh?` and `ancestor?` then run `git rev-parse HEAD` / `merge-base --is-ancestor HEAD origin/main` in the main checkout, so they test the main checkout's HEAD, not the worktree's. When the main checkout sits on or behind `origin/main` (the usual case), the detached worktree is removed. Reproduced in a scratch repo: `git worktree add --detach .worktrees/det`, one commit there, `origin/main` moved on, `gh` stubbed to fail; `worktree-create another-branch` removed `.worktrees/det` and its commit became unreachable. The old prose had the same shell bug but also the rule "detached HEAD … leave it — never guess, never remove unmerged work"; the port dropped that sentence from `SKILL.md` and did not implement it. — `git/.config/git/worktree-tools/worktree-create:79` → fixed (9a76f0de) — `sweep_one` skips outright when the worktree's own branch is `HEAD` (detached), naming it on stderr; `fresh?`/`branch_sha`/`ancestor?` also now run `git -C <worktree>` instead of the main checkout's cwd; the sentence is back in `worktree-first/SKILL.md`.
- [x] Important: without `gh` on `PATH`, `worktree-create` crashes (`No such file or directory - gh (Errno::ENOENT)` from `Open3.capture2`) as soon as one clean worktree exists, so no new worktree can be created at all. The old prose ran `gh … 2>/dev/null` and got an empty state, then fell back to the ancestor check. Reproduced with `PATH=/usr/bin:/bin`. Spec requirement 9 says the sweep uses `gh pr view` "as today". — `git/.config/git/worktree-tools/worktree-create:97` → fixed (9a76f0de) — `pr_state` rescues `Errno::ENOENT` and returns nil, same as the old `2>/dev/null` fallback.
- [x] Nit: `worktree-pane` with a missing path or pane id raises (`File.realpath(nil)` → `TypeError`, `herdr pane rename <nil>` → `TypeError`) instead of printing the usage line; `worktree-pane open /missing` raises `Errno::ENOENT`. — `git/.config/git/worktree-tools/worktree-pane:22` → fixed (8261d679) — missing path/pane-id now dies with the usage line; a nonexistent path dies with one line naming it; both exit 1.
- [x] Nit: a failed `git worktree remove` or `git branch -d` during the sweep is silent (`git` helper sends stderr to `/dev/null`), and the worktree's pane has already been closed by then. The old prose showed git's error. — `git/.config/git/worktree-tools/worktree-create:121` → fixed (9a76f0de) — `remove_worktree` now runs those two calls through a `git_showing_errors` helper that forwards git's stderr on failure and still moves to the next worktree.

### Security

Nothing found. All git, gh and herdr calls still use argument arrays; the branch name reaches
`hand-off-plan.sh`'s prompt text only as a path, not as shell code.

### Compliance

Acceptance criteria against tests in the diff:

| Criterion | Test |
| --- | --- |
| Pane in current workspace, rooted, labelled `<repo>/<branch>`, caller keeps focus | `worktree_pane_test` `test_open_splits_a_pane_below_rooted_in_the_worktree_without_focus`, `test_open_labels_the_pane_repo_slash_branch`, `test_open_scopes_the_pane_lookup_to_the_current_workspace` |
| Outside herdr: no pane, no herdr output, worktree exists | `worktree_pane_test` `test_open_outside_herdr_does_nothing_and_exits_zero` (asserts no calls and exit 0, not empty output) |
| herdr refuses the split: exit 0, one warning naming the error | `worktree_pane_test` `test_open_warns_once_and_exits_zero_when_herdr_refuses_the_split` |
| Sweep closes the pane, then removes the worktree | `worktree_create_test` `test_sweep_closes_the_pane_rooted_in_a_merged_worktree_before_removing_it` |
| Sweep leaves a running agent's pane open, names it, removes the worktree | `worktree_create_test` `test_a_pane_with_an_agent_is_named_on_stderr_during_the_sweep`, `worktree_pane_test` `test_close_skips_panes_with_an_agent_whatever_their_status_and_names_them` |
| Sweep with no pane closes nothing, removes the worktree | `worktree_pane_test` `test_close_with_no_matching_pane_closes_nothing` |
| `hand-off-plan.sh <plan> <name>` creates the worktree, worker rooted there, "already in worktree" prompt | `herdr_worker_scripts_test` `test_handing_off_with_a_worktree_name_starts_the_worker_inside_that_worktree` |
| `hand-off-plan.sh <plan>` unchanged | existing hand-off tests, unchanged in the diff |
| `implement handoff` passes the branch name | prose, `implement/SKILL.md` §5 (no test, as planned) |
| Twice for the same name opens one pane | `worktree_pane_test` `test_open_reuses_an_existing_pane_rooted_in_the_worktree` |
| `WORKTREES.md` mentions the pane | `claude/.claude/WORKTREES.md:12` |

Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or
deleted. Files changed match the plan's list; the `label` command is recorded as a departure in
plan step 8.

Counts: 3 Important, 2 Nit.

## Round 3 — 2026-09-23T12:34Z — 0289af84

State at review: `test/worktree_pane_test.rb` (17 runs), `test/worktree_create_test.rb` (19 runs),
`test/herdr_worker_scripts_test.rb` (30 runs) green locally; `rubocop` on the two scripts and
three tests clean; `shellcheck -x -S warning` on `hand-off-plan.sh` clean. No uncommitted
changes. No PR yet, so CI has not run on this branch. All round 2 fixes hold.

### Bugs

- [ ] Important: `implement handoff` fails in the normal flow. The `intent` skill always creates `.worktrees/<slug>` on branch `<slug>` before it writes `intent.md` (`intent/SKILL.md:40-43`), so by handoff time the worktree and branch already exist. `hand-off-plan.sh <plan> <slug>` then runs `worktree-create <slug>`, whose `git worktree add … -b <slug>` fails; the script exits 1 and `set -e` aborts the hand-off before any pane is split. Reproduced in a scratch repo: `git worktree add .worktrees/my-change -b my-change origin/main`, then `worktree-create my-change --no-pane` → `fatal: a branch named 'my-change' already exists`, exit 1. The worker should start in the existing worktree when `.worktrees/<name>` is already a worktree on branch `<name>`. The spec's criterion "`worktree-first` run twice for the same name opens one pane" has the same gap one level up: the second `worktree-create` now exits 1 (the old prose fell through to `cd .worktrees/$branch`), and only `worktree-pane open` is tested for it. — `git/.config/git/worktree-tools/worktree-create:146`, `herdr/.config/herdr/scripts/hand-off-plan.sh:48` →
- [ ] Important: the new hand-off test fails in CI. Since 19da212f `hand-off-plan.sh` runs `worktree-create` directly, so its `#!/usr/bin/env rv run ruby` shebang is used; `.github/workflows/dotfiles-tests.yml` installs Ruby with `ruby/setup-ruby` and no `rv`. Reproduced with `rv` removed from `PATH`: `worktree-create` prints `env: rv: No such file or directory` and `test_handing_off_with_a_worktree_name_starts_the_worker_inside_that_worktree` fails at line 143. The plan's risk note ("the tests run the scripts as `ruby <script>`, so the shebang is not exercised in CI") no longer holds for this test. — `herdr/.config/herdr/scripts/hand-off-plan.sh:48`, `test/herdr_worker_scripts_test.rb:137` →

### Security

Nothing found. Git, gh and herdr calls still use argument arrays; branch names reach `gh` and
`git` only as single arguments, and git refuses branch names that start with `-`.

### Compliance

Acceptance criteria against tests in the diff:

| Criterion | Test |
| --- | --- |
| Pane in current workspace, rooted, labelled `<repo>/<branch>`, caller keeps focus | `worktree_pane_test` `test_open_splits_a_pane_below_rooted_in_the_worktree_without_focus`, `test_open_labels_the_pane_repo_slash_branch`, `test_open_scopes_the_pane_lookup_to_the_current_workspace` |
| Outside herdr: no pane, no herdr output, worktree exists | `worktree_pane_test` `test_open_outside_herdr_does_nothing_and_exits_zero` |
| herdr refuses the split: exit 0, one warning naming the error | `worktree_pane_test` `test_open_warns_once_and_exits_zero_when_herdr_refuses_the_split` |
| Sweep closes the pane, then removes the worktree | `worktree_create_test` `test_sweep_closes_the_pane_rooted_in_a_merged_worktree_before_removing_it` |
| Sweep leaves an agent's pane open, names it, removes the worktree | `worktree_create_test` `test_a_pane_with_an_agent_is_named_on_stderr_during_the_sweep`, `worktree_pane_test` `test_close_skips_panes_with_an_agent_whatever_their_status_and_names_them` |
| Sweep with no pane closes nothing, removes the worktree | `worktree_pane_test` `test_close_with_no_matching_pane_closes_nothing` |
| `hand-off-plan.sh <plan> <name>` creates the worktree, worker rooted there, "already in worktree" prompt | `herdr_worker_scripts_test` `test_handing_off_with_a_worktree_name_starts_the_worker_inside_that_worktree` (red in CI — see Bugs) |
| `hand-off-plan.sh <plan>` unchanged | existing hand-off tests, unchanged in the diff |
| `implement handoff` passes the branch name | prose, `implement/SKILL.md:80` (passes the slug — see Nit) |
| Twice for the same name opens one pane | `worktree_pane_test` `test_open_reuses_an_existing_pane_rooted_in_the_worktree` — through `worktree-create`: missing (see Bugs) |
| `WORKTREES.md` mentions the pane | `claude/.claude/WORKTREES.md:12` |

No existing test was weakened, skipped or deleted.

- [ ] Important: a test named in `plan.md`'s `## Proof` no longer exists: `test_close_skips_a_pane_with_a_running_agent_and_names_it` was renamed to `test_close_skips_panes_with_an_agent_whatever_their_status_and_names_them` in 8261d679, and the Proof line was not updated. — `docs/changes/herdr-worktree-panes/plan.md:123` →
- [ ] Nit: `implement/SKILL.md` passes the change folder's slug, but spec requirement 6 and its criterion say the branch name. `change-folder` strips a leading `<prefix>/`, so for a branch `fix/foo` the hand-off asks for a new worktree and branch `foo` instead of the one the change lives on. — `claude/.claude/skills/implement/SKILL.md:80` →
- [ ] Nit: `repo_root!` uses `git rev-parse --show-toplevel`, which inside a linked worktree returns that worktree, so `worktree-create` run from a worktree creates a nested `<worktree>/.worktrees/<name>` and sweeps nothing. The parent of `--git-common-dir` is the main checkout from anywhere. The skill's skip rule hides this for `worktree-first`, but not for a direct call. — `git/.config/git/worktree-tools/worktree-create:41` →
- [ ] Nit: `worktree-pane open|label` on an existing path outside any git repository raises `NoMethodError` (`git_common_dir` returns nil, then `.dirname`) instead of one line and exit 1, as the missing-path case now does. — `git/.config/git/worktree-tools/worktree-pane:105` →

Counts: 3 Important, 3 Nit.
