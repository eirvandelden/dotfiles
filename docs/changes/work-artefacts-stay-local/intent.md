# Intent: Work-repo change artefacts stay local

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature.
Delivery: autonomous
Codex review: no

## Problem

On work repositories (`employer/their-app`, `employer/their-client`) the agent workflow commits `intent.md`, `plan.md` and `review.md` and later removes them in a separate commit. This adds noise commits to work pull requests. The review commit subject, "Review for <slug>", says nothing about the change it holds.

## Proposed outcome

On a work repository the three artefacts live only as local files and no commit ever holds them. Delivery has nothing to remove. Every commit message the workflow writes describes the change inside that commit, on every repository. A merged worktree is removed even when untracked artefacts remain in it.

## Affected users and systems

- Etienne and the agents that run `intent`, `plan`, `implement`, `review`, `deliver` and `finish` on work repositories.
- Scripts and hooks in `~/Developer/dotfiles`: `commit-plan`, `commit-review`, `deliver`, `restore`, `review-report-fresh`, `consent-guard.rb`, `worktree-sweep` with `lib/sweep.rb`.
- The skills and playbook text that describe this flow: `intent`, `plan`, `implement`, `review`, `deliver`, `finish`, `PLAYBOOK.md` rules 5, 16 and 17.
- The `reviewer` agent and the stage hand-off scripts that run `commit-review`.

## Constraints

- "Work" means `change-scope` prints `work`: origin matches `~/.claude/consent-guard-allowed-remotes.txt` (today `employer/their-app` and `employer/their-client`).
- Personal repositories keep committing and removing artefacts, as today.
- Local-only is done by Etienne once per work repository: `docs/changes` goes into `~/Developer/their-app/.git/info/exclude` and `~/Developer/their-client/.git/info/exclude`. Worktrees share that file. The scripts never write it.
- Playbook rule 6 stays: no GitHub comments as Etienne.
- The pre-push freshness check and the consent guard must not block a work branch because artefacts are untracked.

## In scope

- On work scope, `commit-plan` and `commit-review` commit nothing and exit 0 with a message that the artefact stays local.
- On work scope, `deliver` skips the folder-removal commit and `restore` has nothing to restore. `deliver` still reads the local `intent.md`, `plan.md` and `review.md`, checks review freshness and open findings, pushes and opens the draft PR.
- The consent guard allows `gh pr create` on a work repository while an untracked `docs/changes/<slug>/` exists.
- `review-report-fresh` passes on work scope, since the folder is not in HEAD.
- The review commit subject on personal repositories becomes `docs: review findings for <summary of the first review finding>`. Fix commits after a review keep descriptive subjects too.
- `worktree-sweep` treats untracked files under `docs/changes/` as clean and removes the merged worktree with them present. Other dirt still blocks removal.
- Skill, agent and playbook text matches the new behaviour. The tests of the touched scripts cover work and personal scope.

## Out of scope

- Writing `.git/info/exclude` automatically.
- Branches whose artefacts are already committed.
- Personal-repository artefact lifecycle beyond the commit subject.
- Any change to how `intent.md` and `plan.md` get accepted.

## Acceptance criteria

- On `employer/their-app`, accepting a plan leaves `intent.md` and `plan.md` uncommitted and `git log` shows no commit that touches `docs/changes/`.
- On `employer/their-app`, a clean review leaves `review.md` uncommitted and nothing is committed for it.
- On `employer/their-client`, `deliver` opens the draft PR and the branch has no commit that adds or removes `docs/changes/<slug>/`.
- On a work repository, `gh pr create` is allowed by the guard while the untracked folder exists.
- On a personal repository, the review commit subject describes the change, not "Review for <slug>".
- A merged worktree holding only untracked `docs/changes/<slug>/` files is removed by `worktree-sweep`.
- A merged worktree holding a modified tracked file, or an untracked file outside `docs/changes/`, is left alone.

## Decisions

- Work artefacts stay local via `docs/changes` in each work repo's `.git/info/exclude`, set once by Etienne — chosen over plain untracked files, which risk an accidental `git add .`.
- The descriptive commit-message rule applies to every repository, not only work ones — Etienne chose "apply to all repos".
- `worktree-sweep` ignores only untracked files under `docs/changes/` — protects unsaved code.
- The review commit subject comes from the first review finding — Etienne's choice over the intent title, no reason given.
- Delivery is autonomous, without Codex review — Etienne's choice; no new dependencies, gems or deploy files are needed.

## Open questions

None.
