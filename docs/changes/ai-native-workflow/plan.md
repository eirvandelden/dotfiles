# Plan: AI-native workflow (from intent.md 2026-09-18)

Status: accepted (2026-09-21).

This plan is executed phase by phase, each phase in its own worktree and PR, by an agent that gets the phase file and nothing else. Every phase file is self-contained; this file is the map. Decisions marked **talk first** need a conversation with Etienne before that phase starts. Nothing here is implemented by the session that wrote it.

## How this change deviates from its own convention

A normal change keeps documents and code on one branch, in one worktree, with one PR; nothing merges before the work is done. This change cannot: its deliverables are skills, hooks and agents that only go live through stow, and stow links point into the main checkout. Each phase must therefore land on `main` before Etienne can use it. So:

- The documents are merged to `main` first (PRs #140 and #27), so executors and the main checkout both see them: `~/Developer/dotfiles/docs/changes/ai-native-workflow/` and `~/Developer/dotfiles-work/docs/changes/ai-native-workflow/work-specifics.md`.
- Each phase branches from `main` in its own worktree, one PR each, merged in order. When a phase departs from its file, the executor edits the phase file in its own worktree, in the same PR, and says so in its report.
- After phase 7, `/finish` runs on a last branch, removes `docs/changes/ai-native-workflow/` (and `docs/changes/` if empty) in both repositories, and that PR closes the change.

Read in order: `intent.md` → `spec.md` → this file → `habits.md` → the phase file.

## Files that change

Dotfiles (`~/Developer/dotfiles`, public — no employer names):

- `agents.md` (the playbook): §7.17, §7.24, new "Things agents get wrong here", §5 pointer.
- `SKILLS-INDEX.md`: new skills, removed `plan-handoff`.
- `claude/.claude/settings.json`: `enabledPlugins`.
- `claude/.claude/skills/`: new `intent`, `spec`, `plan`, `implement`, `finish`; rewritten `review` (absorbs the pane version); removed `plan-handoff`, `handoff` (absorbed by `implement handoff`); vendored domain skills.
- `claude/.claude/agents/`: new `reviewer.md`, `test-writer.md`, `implementer.md`; `zubat.md` unchanged.
- `claude/.claude/skills/new-repo-setup/references/REVIEW.md`: the review policy template.
- `claude/.claude/skills/plan/scripts/change-folder`, `claude/.claude/skills/finish/scripts/{fill-pr-template,change-scope}`, `bin/generate-codex-agents`, `git/.config/git/worktree-tools/review-report-fresh`: small Ruby scripts, each with a test.
- `agents/.agents/skills/` (new stow package `agents`, also in `STOW_SHARED`): symlinks to the shared skill folders; `codex/.codex/skills/` removed; `packages.conf` updated.
- `codex/.codex/agents/reviewer.toml`, generated from the Claude agent.
- `codex/.codex/config.toml`: plugin off, inline `[hooks]` for the consent guard, `[projects]` and `[hooks.state]` moved out of the committed file.
- `codex/.codex/rules/default.rules`: hand-written `prompt`/`forbidden` rules only.
- `codex/.codex/HEADROOM.md`, `codex/.codex/WORKTREES.md`: become links or one file.
- `lefthook.yml`: pre-push `review-report-fresh`.
- `claude/.claude/hooks/test-guard.rb` + `test/test_guard_test.rb`: blocks test edits during a bugfix once the reproduction test is committed; wired as `PreToolUse` on edit tools in both tools.
- `test/`: `skill_parity_test.rb`, `change_folder_test.rb`, `review_report_check_test.rb`, `codex_agent_generation_test.rb`, `fill_pr_template_test.rb`, `consent_guard_test.rb` (Codex stdin case).
- `herdr/.config/herdr/scripts/hand-off-plan.sh`, `start-review.sh`: read the change folder.
- `claude/.config/claude/settings.json`: removed (orphan).
- Root: stray log file removed.

Dotfiles-work (`~/Developer/dotfiles-work`, private): one phase file with the employer-specific steps (`docs/changes/ai-native-workflow/work-specifics.md`), the stowed `REVIEW.md` per work application, `docs/for-agents.local.md` updates, dangling symlink cleanup, log files removed.

Personal repositories: `REVIEW.md` and `docs/changes/` via `new-repo-setup`, one repo at a time as they are touched. Not a bulk change.

## Order of work

| # | Phase file | Delivers | Habit it enables |
|---|---|---|---|
| 1 | `phases/01-shared-skills.md` | one-source skill linking Claude ↔ Codex, drift test, existing `handoff`/`review`/`worktree-first` migrated onto it | — (mechanics) |
| 2 | `phases/02-artifact-skills.md` | `docs/changes/<slug>/`, `intent`/`spec`/`plan`/`implement` skills, playbook §7.17, `handoff` and `plan-handoff` absorbed | intent, spec, plan, implement |
| 3 | `phases/03-review.md` | `REVIEW.md` template, `reviewer` agent (Claude md + generated Codex toml), `review` skill, pre-push freshness check, `new-repo-setup` step | review |
| 4 | `phases/04-finish.md` | `finish`: review fresh → (work: PR template fill, ADR) → delete → commit → (work: push, review board, reviewers); work details in dotfiles-work | finish |
| 5 | `phases/05-plugins-and-playbook.md` | plugins off in both tools, domain skills vendored, playbook edits, `/audit-token` before/after | mistake twice → one line |
| 6 | `phases/06-codex-guard-parity.md` | consent guard from Codex inline hooks, rules purge with `forbidden`, parity test extended to hooks | switch tools, not process |
| 7 | `phases/07-hygiene.md` | dangling symlinks, config churn, orphan settings, logs, work text out of the public repo | — |

Phases 1–4 are sequential. Phase 5 can start after 2. Phase 6 after 1. Phase 7 items are independent and may be picked up any time by a mechanical (Haiku) worker, one item per commit.

Adoption pace: phases 1–4 are built back-to-back, one PR each, merged in order, with no waiting between them. Together they form one workflow — intent → spec → plan → implement → review → finish — and replace the `handoff` and `review` skills that are already in daily use, so the six workflow habits in `habits.md` (intent, spec, plan, implement, review, finish) start on the same day, when phase 4 merges. Phases 5–7 follow at whatever pace suits; phase 5 needs two weeks of use before judging the plugin removal.

## Risks

- ~~Codex skill path~~ — resolved 2026-09-21. Phase 1's first run confirmed Codex 0.154 does not scan `~/.codex/skills`; Etienne instructed a new `agents` stow package targeting `~/.agents/skills`. Residual risk: Codex must follow a symlinked skill folder whose target sits under another stow package; phase 1 step 0 and its manual verification cover it.
- **Stow `--no-folding`.** New skill files need a re-stow, run by Etienne, never by the agent. Every phase ends with "Etienne: `stow -R claude codex`" as a manual step, and tests run against the repo paths, not `~`.
- **herdr owns `~/.codex/hooks.json` and `~/.claude/hooks/herdr-*`.** Never edit those. Codex hooks from dotfiles go inline in `config.toml` `[hooks]`; verify Codex merges both sources before relying on it.
- **Auto-appended Codex allow rules come back.** Codex writes to `default.rules` on every TUI approval and this cannot be turned off. Mitigation: the hand-written rules use `prompt` and `forbidden`, which win over `allow` when both match; the parity test fails on any `allow` that matches a guarded pattern; `default.rules` is reviewed at every commit touching `codex/`.
- **Plan mode alias.** `opusplan` is not in the public docs. Phase 5 records whatever `settings.json` actually holds and the playbook names that; no reliance on undocumented behaviour.
- **Habit lag.** Tooling ships before habits form. `habits.md` is the mitigation; each phase PR description links the habit it enables.
- **Work repos cannot carry config.** `REVIEW.md` and `docs/changes/` for work land through the stowed project-local package and the branch, respectively. If a work `.gitignore` or lint rejects `docs/changes/`, the work phase file says how to handle it (`.git/info/exclude` is not an option — the folder must be committed on the branch).
- **Playbook rule 13.** `lefthook.yml` is global tooling, not CI, but it affects every repo; phase 3 presents the pre-push command for approval before merging.

## Proof

The change is done when, in a fresh session of each tool, in a throwaway personal repo:

1. `/intent` → `/spec` → `/plan` produce the three files under `docs/changes/<branch>/`, each with a `Status:` line, and `implement` refuses to start on a plan not marked accepted.
2. `/review` appends a round to `docs/changes/<branch>/review.md` and commits it; `git push` fails while the newest code commit is newer than the newest `review.md` commit, passes after re-running.
3. `/finish` in a personal repo deletes the folder in one commit and stops. In a work checkout it fills the PR template, deletes, pushes, puts the PR on the review board, requests reviewers — dry-run mode first.
4. `ruby -Itest -e 'Dir["test/*_test.rb"].each { require "./#{it}" }'` is green in dotfiles, including the parity test.
5. `/audit-token` shows session-start context at or below the playbook plus includes; no plugin injection; no per-subagent injection.
6. `codex exec` in the same repo with `$review` produces the same report shape.
7. Every plugin listed in §5 of the spec shows `false`/`enabled = false`; none uninstalled.

## Out of scope for every phase

See `spec.md` §8. In addition: no phase edits `.github/workflows/`, `~/.claude.json`, or any herdr-owned file; no phase runs `stow`; no phase adds a dependency without asking; no phase touches a work repository's tracked files except on the feature branch of a change.
