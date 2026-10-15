---
name: deliver
description: Ends a change once its review is closed — removes the change folder in its own commit, pushes, opens a draft PR with the filled body, opens a gh-dash pane and closes idle stage panes. Runs without questions, started by the review skill on a clean review or by the autonomous coordinator.
disable-model-invocation: true
---

# Deliver

Delivery is the step between a closed review and `/finish`. It opens a draft pull request. It never marks the PR ready and never merges: `/finish` does that.

Other skills reach this one by path: `~/.claude/skills/deliver/SKILL.md`. Etienne can also type `/deliver`.

## When it runs

- Outside auto mode: the `review` skill runs it without asking when a review reads `Review clean:`, or when `deliver --check` exits 0 in the `here` backend.
- In auto mode: the coordinator runs it once a round of each reviewer leaves no open finding (intent skill, Autonomous delivery). Then it follows `~/.claude/skills/finish/SKILL.md` in its auto mode, which runs `ship --no-merge`.

## Run it

```bash
~/.claude/skills/deliver/scripts/deliver
```

The script asks no questions. It does these steps, in order:

1. Check the preconditions. It stops with every reason when one fails.
2. Look up an open PR for this branch with `gh pr list --head <branch>`. Only an empty answer means "no PR". Any error stops the script, and it never leads to `gh pr create`.
3. Fill the PR body from the repository template, `intent.md` and `plan.md`, and take the title from `intent.md`. Save both under `<git-common-dir>/deliver/`.
4. Remove `docs/changes/<slug>/` in a commit of its own: `Remove change artifacts for <slug>`.
5. Push the branch.
6. Create a draft PR, or edit the body of the PR that exists. Delete the saved body and title.
7. Inside herdr: open a gh-dash pane for the PR with `~/.config/herdr/scripts/open-pr-dash.sh`, then close this change's idle or done stage panes. A stage pane is one that `hand-off-plan.sh` or `start-review.sh` listed in `<git-common-dir>/herdr/stage-panes-<slug>`, and it closes only while its terminal id still matches. Never the delivering agent's own pane, never the intent pane, never another agent's pane. Then delete that list. Outside herdr it prints the PR URL and opens no pane.

A push that fails leaves the folder removed and the saved files in place. Run `deliver` again: it resumes at the push.

`deliver --check` runs step 1 only and changes nothing. It exits 0 when delivery may run, and 1 with the reasons otherwise.

## Preconditions

- `review.md` exists and has a round.
- `~/.config/git/worktree-tools/review-report-fresh` exits 0.
- No finding is open. A finding is a line `- [ ] Important: …` or `- [ ] Nit: …`. It is closed only when the text after its last `→` is `fixed (<commit subject>)` or `dismissed: <reason>` with a reason that is not empty. Any other text, or no text, leaves it open.
- The working tree is clean.
- `~/.claude/skills/finish/scripts/change-scope` prints `personal` or `work`.

## Report

Tell Etienne the PR URL, whether a gh-dash pane opened, and that `/finish` is the next step. Never comment on the PR.

## Codex

Same script, same steps. Invoked as `$deliver`. A Codex coordinator runs it after a clean review round, then follows `$finish` in its auto mode.

## Change requests after delivery

A change request on an open pull request needs the removed documents back. Never recreate them by hand.

1. Run `~/.claude/skills/deliver/scripts/restore`. It refuses unless the branch has an open pull request and a clean tree. It fetches the branch and its base, fast-forwards to the remote branch and drops the one `Remove change artifacts for <slug>` commit with a rebase. It refuses, with the branch unchanged, when that commit is not exactly a deletion of the whole folder or when later commits conflict.
2. Push with `git push --force-with-lease -u origin HEAD`. `restore` prints the command and never runs it, so the consent guard judges the push. A plain `--force` is refused. While the pull request is open, the pre-push check refuses a push whose `review.md` is older than the last code commit; run `/review` until it converges, then push.
3. Edit the restored `intent.md` and `plan.md` in place and commit them with `commit-plan`. Review rounds go through `commit-review`.
4. Run `deliver` again. It edits the open pull request body.

A merged branch, a squash-merged one included, is out of scope: start a new branch from `main`.
