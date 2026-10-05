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

## Round 2 — 2026-10-05T12:41Z — 0e2df098

State at review: `test/agent_worktree_test.rb` (8 runs), `test/worktree_create_test.rb` (29 runs) and `test/worktree_viewer_test.rb` (21 runs) are green. `rubocop` on the six touched Ruby files reports no offenses. Uncommitted: nothing. All five round-1 nits are fixed; each fix has a test (`test_an_unexpected_open_direction_answer_opens_the_split_to_the_right`, `test_the_launcher_calls_the_herdr_named_in_herdr_bin_path`, `test_without_herdr_the_launcher_exits_with_a_warning_instead_of_a_crash`, the `SWITCHTAB` token).

Bugs: no Important findings.

Security: no findings. The new `HERDR_BIN_PATH` value is passed in array form, never through a shell.

Compliance: no Important findings. The fixes since round 1 stay inside the planned files, plus `SWITCHTAB` in `project-dictionary.txt` for cspell. No test was weakened.

- [ ] Nit: the README paragraph order no longer reads. `**Press W to fix it.**` now follows the stow paragraph, so "it" has no referent. The paragraph before it says "no pane is in one", but the paragraph above that describes agent panes that are in a worktree. Move the stow note to the end of the section and reword the `cd` paragraph as the case `W` covers — `herdr/.config/herdr/README.md:38`
- [x] Nit: `test_without_herdr_the_launcher_exits_with_a_warning_instead_of_a_crash` sets `PATH` to the ruby binary's folder. With a Homebrew ruby in `/opt/homebrew/bin`, the folder that also holds `herdr`, the test finds the real `herdr` and talks to the live server. It passes here only because ruby comes from `rv`. Use a folder holding only a `ruby` symlink — `test/worktree_viewer_test.rb:205` → fixed (Run the no-herdr test with a PATH that holds only ruby)
- [x] Nit: `worktree-create` still calls `herdr` from `PATH` for `pane get`, while the launcher now honours `HERDR_BIN_PATH`. The failure is harmless: it records nothing. But the two tools now find herdr differently — `git/.config/git/worktree-tools/worktree-create:218` → fixed (Let worktree-create find herdr the way the launcher does)
