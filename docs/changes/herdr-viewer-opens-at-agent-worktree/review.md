# Review: herdr-viewer-opens-at-agent-worktree

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default policy from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` applies.

## Round 1 — 2026-10-02T08:00Z — 72bf6c6d

State at review: `test/agent_worktree_test.rb` (8 runs), `test/worktree_create_test.rb` (29 runs) and `test/worktree_viewer_test.rb` (18 runs) are green. `rubocop` on the six touched Ruby files reports no offenses. Uncommitted: only the untracked change folder.

Bugs: no Important findings. Checked against the real plugin scripts and a real `herdr pane list`: one pane carries `focused: true` across all workspaces, `terminal_id` is on every pane, and the plugin's `open-file-viewer*.sh` are written to run from a `type = "shell"` binding, so the hand-over keeps today's behaviour.

Security: no findings. The record path is sanitised to `[A-Za-z0-9_-]`; every herdr call uses array form.

Compliance: every file the plan names changed as described; nothing unplanned. Acceptance criteria 1–18 each have the test the plan's `## Proof` names, and every named unit test exists. No existing test was weakened, skipped or deleted (`worktree_create_test.rb` only gains a state folder, a `pane get` stub answer and four tests).

- [x] Nit: `open_direction` passes the program's output straight into `--direction`. The plugin's own script re-validates it with a `case` (only `down`, else `right`); here an empty or unexpected value makes `pane split` fail and the launcher abandons without the hand-over the plan promises for a failing flag — `git/.config/git/worktree-tools/worktree-viewer:102` → fixed (Open the split to the right on an unexpected direction answer)
- [x] Nit: the launcher calls `herdr` from `PATH` and ignores `HERDR_BIN_PATH`, which the plugin scripts prefer. An `Errno::ENOENT` from `Open3.capture3` is not rescued, so a binding run with a `PATH` lacking `/opt/homebrew/bin` dies with a backtrace instead of a warning. Works today: the herdr server's `PATH` includes it — `git/.config/git/worktree-tools/worktree-viewer:167` → fixed (Call the herdr named in HERDR_BIN_PATH and warn when herdr is missing)
- [x] Nit: the tab hand-over test feeds `SWITCH_TAB w1:t9`, but the token the plugin prints has no underscore (see its `scripts/open-file-viewer-tab.sh`). The test still passes because any non-`OPEN` answer hands over, but it does not exercise the real token — `test/worktree_viewer_test.rb:51` → fixed (Feed the tab hand-over test the token the plugin prints)
- [x] Nit: `intent.md`, `spec.md` and `plan.md` are untracked; earlier changes committed their change folder, and `finish` removes it by commit. After this round the folder on the branch holds only `review.md` — `docs/changes/herdr-viewer-opens-at-agent-worktree/plan.md:1` → fixed (Add intent, spec and plan for herdr-viewer-opens-at-agent-worktree)
- [x] Nit: no commit or note records the plan's order-of-work step 8 (real herdr check of root, label, placement, picker and `q` closing the pane), which criterion 16's proof relies on. Confirm it ran before the PR — `docs/changes/herdr-viewer-opens-at-agent-worktree/plan.md:44` → fixed (Record the real herdr check in the plan)
