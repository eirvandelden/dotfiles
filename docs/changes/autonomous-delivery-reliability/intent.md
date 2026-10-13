# Intent: Make autonomous delivery reliable from handoff to pull request

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-13). Type: feature. Delivery: autonomous

## Problem

Autonomous delivery of journal_administration #341 produced good first-pass code, but the workflow around it showed four gaps.

- A task accepted in a Codex session has no concrete way to hand coordination to Claude. Codex then coordinates itself, or the handoff needs ad hoc steps, and outside Herdr there is no supported route at all.
- Missing setup surfaces late and one item at a time: Claude authentication, GitHub access to origin, commit signing or SSH, the project runtime and its dependencies, and database or browser tooling. Each one stops costly work halfway.
- Nothing ties a verification result to the code it verified. A migration replay or a browser check can be reported for code that changed afterwards, and uncommitted edits can reuse old proof. A documentation-only commit gives no way to tell that a rerun is not needed.
- The pull request body repeats the plan's promised tests and file list. The actual check results, the independent review outcomes, the browser and migration evidence and the limitations stay in temporary local files, and `finish` deletes the change folder that holds part of them.

## Proposed outcome

- Claude coordinates personal autonomous delivery by default. Codex stays the independent plan critic and code reviewer. A Codex session that accepts an autonomous intent hands the delivery to a Claude coordinator through one supported command, inside Herdr and outside it.
- One preflight runs before delivery and reports every relevant setup item together, each as pass, missing or not applicable with a reason. Blockers are aggregated before costly work starts.
- Each verification result is recorded against the content it verified. A result is fresh only while that content is unchanged, uncommitted edits included. Finishing refuses while required evidence is missing, failed or stale. Changes inside the change folder alone do not invalidate evidence.
- The pull request body is the final handover: delivered behaviour, actual check results, independent review outcomes, browser and migration evidence, and material limitations. The evidence persists outside the change folder before `finish` removes it.

## Affected users and systems

- Etienne, who approves the intent and decides the merge, and who reads the pull request as the handover.
- Claude and Codex sessions that run autonomous delivery on personal repositories.
- The shared skills `intent`, `plan`, `implement`, `review`, `code-review` and `finish`, their scripts, `hand-off-plan.sh`, the playbook §7a and its core-values mirror where a mirrored rule changes.
- The shared git directory reports under `<git-common-dir>/herdr/`.

## Constraints

- Explicit approval: Etienne reviewed journal_administration #341, asked whether the workflow needed improvement, and on 2026-10-13 replied "approved" to exactly the four improvements in this intent. That reply authorizes their implementation through a tested, dual-reviewed pull request to origin `eirvandelden/dotfiles`. It does not change the general rule that a stage moves on only on the literal word "accepted" or "agreed".
- Personal project, origin `git@github.com:eirvandelden/dotfiles.git`. Work-project policy and delivery stay unchanged. Step-by-step delivery stays unchanged.
- Human gates stay: the accepted intent and Etienne's merge decision. Agents never merge and never deploy.
- No new dependencies, no tool installs, no Stow calls or new Stow packages, no deployment or CI configuration changes, no linter-disable comments or config relaxations, no skipped tests, no disabled hooks, no permission bypass flags.
- Dependency, system tooling, database, symlink, deployment, Git identity and force-push protections stay in force.
- Preflight never inspects or prints secrets, installs tools, alters credentials, modifies original databases or invokes production. It uses existing tools, read-only checks or temporary challenge or copy files, and bounded commands. It never turns a required check into a silent skip.
- Shared skill sources stay at `claude/.claude/skills/<name>/`; Codex reads them through the `agents` package links.
- Do not edit journal_administration or its PR #345. Do not touch the dirty `settings.json`, `config.toml` or `default.rules` in the main dotfiles checkout.
- Opening and updating the pull request body is allowed. GitHub comments, replies, formal review submissions or other messages as Etienne are not.

## In scope

- A supported Codex-to-Claude coordinator handoff for an accepted autonomous intent, inside and outside Herdr.
- Skill and playbook text that makes Claude the default coordinator and Codex the critic and reviewer.
- A delivery preflight command.
- A delivery evidence record with freshness checking, and a `finish` gate on it in auto mode.
- A pull request handover body built from the evidence and the review report, persisted outside the change folder before `finish` removes the folder.
- Tests: contract tests for the text, and behavioural tests with fake tool boundaries for every new command.

## Out of scope

- Changing step-by-step delivery or work-repository delivery.
- Changing the literal-acceptance rule for intents or step-by-step plans.
- Running delivery against real personal or work databases to prove this workflow.
- Installing or upgrading Claude, Codex, gh, browsers or database tools.
- Restowing packages so the new scripts are live on this machine; Etienne does that after merge.
- Automating CI waits or merges.

## Acceptance criteria

- A Codex session accepts an autonomous intent for `fix-login` outside Herdr and runs the handoff command. A background Claude coordinator starts in the `fix-login` worktree, and the command prints how to attach to it and where its report lands. Inside Herdr, the same command opens a Claude coordinator pane below instead.
- The handoff command refuses an intent that is not accepted or not autonomous, and refuses a work origin, without starting Claude.
- Codex keeps critiquing plans and reviewing code: the plan critique and the Codex review round still run through the Codex CLI.
- Preflight on a machine where Claude is logged out and signing works prints `missing claude: not logged in` and `pass signing: ...` together, then exits non-zero with one blockers summary.
- Preflight on a repository without database or browser needs reports database and browser as `n/a` with a reason. With `--needs database,browser` and no browser available, it reports `missing browser` and does not skip it.
- Preflight never prints a token, an e-mail address or a key, and never writes to the repository or its databases.
- A test run recorded as passing at one revision stays fresh after a commit that changes only the change folder, and turns stale after a code edit, committed or not.
- A migration replay recorded before a migration changed is stale afterwards; a browser check recorded before a view changed is stale afterwards.
- `finish` in auto mode refuses while a required evidence entry is missing, failed or stale, and names it.
- The pull request body lists the actual recorded checks with their outcome, revision and limitations, and each review round with its source and how its findings closed — not the plan's promised tests.
- After `finish` removes the change folder, the handover and the evidence still exist in the shared git directory.

## Open questions

None.
