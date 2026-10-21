# Evidence: gh-dash-review-keys

Recorded 2026-10-21 by the coordinator, at branch HEAD `455118de`, before the merge and before any restow.

## Setup

- gh-dash v4.26.2 ran in a herdr pane: `command gh dash --config <temp copy of config.yml>`. The copy points both merge commands at this worktree's `merge-pr.sh`, with a stub `gh` first on `PATH` and `GIT_CONFIG_GLOBAL` set to a temporary config that includes a temporary `pr-merge.config`. The stub only logs its arguments, so nothing merged.
- Keys went in through `herdr pane send-keys`, and the screen was read with `herdr pane read`. This is herdr's own key encoding, not a physical key press in Ghostty.
- PR under test: `eirvandelden/happiness#140` (a Dependabot bump), first row of "Personal PRs".

## Results

| Criterion | Result |
|---|---|
| `ctrl+↓` / `ctrl+↑` page the preview | Pass. Scroll position 4% → `ctrl+↓` 8% → `ctrl+↓` 12% → `ctrl+↑` 8% → `ctrl+↑` 4%. |
| `d` shows the diff side by side | Pass. delta shows `Gemfile.lock` in two columns: `│ 475│ thruster (0.1.26) │ 475│ thruster (0.1.27)`. |
| `ctrl+m` asks once | Pass. Prompt: `Merge eirvandelden/happiness#140 with merge and delete its branch? Enter merges, anything else cancels:`. herdr delivered `ctrl+m` apart from Enter. |
| `n` and Enter cancel without error | Pass. gh-dash came back with no error; the stub logged no call. |
| `M` behaves like `ctrl+m`; Enter merges with no further prompt | Pass. Same prompt; Enter logged `gh pr merge 140 -R eirvandelden/happiness --merge --delete-branch` and gh-dash came back with no error. |
| Owner squash applies | Pass. With `pr-merge.eirvandelden.method squash`, `ctrl+m` and Enter logged `gh pr merge 140 -R eirvandelden/happiness --squash --delete-branch`. |
| README walkthrough | Pass. Running the README commands in order against the temporary file, the prompt named: no setting → `merge`; owner `squash` → `squash`; repository `merge` over owner `squash` → `merge`; both removed → `merge`. |
| An agent in another repository sets the method | Pass. In a scratch repository with origin `eirvandelden/happiness` and the worktree skill linked in, `claude -p "squash-merge this repository's PRs from gh-dash"` loaded `pr-merge-method` and wrote `pr-merge.eirvandelden/happiness.method squash` to `~/.config/git/pr-merge.config`. It also noted that the script and the git include are not installed before the restow. The setting and the file were removed afterwards. |

## Not checked here

- A real merge, and `r` showing the PR as merged afterwards. That needs a real pull request; Etienne checks it on the first real merge.
- `ctrl+m` as a physical key press in Ghostty, inside and outside herdr.
- The installed files, which exist only after the merge and `stow -R -t "$HOME" github agents claude`.
