# Plan: Merge intent and plan into one plan.md

From `intent.md` (2026-11-23), accepted. Status: accepted (2026-11-24). Worktree `.worktrees/merge-intent-into-plan`, branch `merge-intent-into-plan`.

## Context

Every change carries `intent.md` and `plan.md` with two gates, and nobody but Etienne reads them. This change folds the intent into `plan.md`, vendors the superpowers-ruby `brainstorming` interview as the entry point, deletes the `intent` skill, and returns plan mode as the interactive gate. The explorers found the real coupling: `intent_metadata.rb` (heading and header fields), `commit-plan`, `auto-accept`, `deliver`, `restore`, `fill-pr-template`, `start-delivery`, three `hand-off-plan.sh` scripts, the statusline and about 30 tests.

## Design

### Domain terms

- Plan: the single change document, `docs/changes/<slug>/plan.md`. Heading `# Plan: <title>`.
- Intent sections: Problem, Proposed outcome, Affected users and systems, Constraints, In scope, Out of scope, Acceptance criteria, Flagged concerns, Decisions. They open `plan.md`, before `## Design`.
- Header paragraph: `Author`, `Status`, `Type`, `Delivery`, `Codex review`, as today, directly under the heading.
- Critique closed: every finding under `## Critique` ends in `fixed` or `dismissed`, or the round says `No findings.`.

### Object model

`IntentMetadata` becomes `PlanMetadata`, same public methods, parsing `# Plan:`. Its heading regex is the only behaviour change.

A new `PlanCritique.closed?(text)` holds the parser that `auto-accept` carries today. `commit-plan` and `start-delivery` both call it. `auto-accept` is deleted: it no longer flips a status, because the human flips it.

Not affected: the `ship`, `change-scope`, `delivery-evidence` and `commit-review` scripts.

### Gates

| Situation | Gate |
|---|---|
| Interactive Claude | The interview and the draft run in plan mode. Approving `ExitPlanMode` counts as accepted. Claude then writes `plan.md` with `Status: accepted (<date>)` and runs `commit-plan`. |
| Interactive Codex | No plan mode exists. Etienne types "accepted" or "agreed". |
| Autonomous (personal repo) | Claude drafts `plan.md`, the other model family critiques it, every finding closes, then Etienne reads it and types "accepted". `commit-plan` refuses an accepted autonomous plan with an open or missing critique. |
| Work repository | Same as interactive. `plan.md` stays local, nothing is committed. |

### Alternatives

- Keep `auto-accept` as a status flipper. Rejected: it contradicts the agreed gate order, critique first and then Etienne.
- Fold the interview into `plan` and skip vendoring. Rejected by Etienne: re-syncing by diff is easier with a separate copy.
- Support old `intent.md` during a transition. Rejected by Etienne: nothing is in flight.

## Design decisions

- `brainstorming` stays close to upstream and carries only edits that the new flow forces: the spec path becomes `docs/changes/<slug>/plan.md`, the terminal state becomes the `plan` skill's design gate, and the visual companion, the reviewer prompt and the `superpowers-ruby:*` cross-references go. The comment `<!-- upstream: lucianghinda/superpowers-ruby@7.5.0 skills/brainstorming — re-sync: ... -->` marks it, as for the other vendored skills. It joins `SKILLS-INDEX.md` and `VENDORED-LICENSES.md` coverage.
- The local rules from the old `intent` skill move into `plan/SKILL.md`: depth by type, the probe list, glossary check, delivery mode, the header format, the template and the red flags. The long autonomous-delivery coordinator section moves to `plan/references/autonomous-delivery.md`.
- `start-delivery` and `delivery-preflight` move to `plan/scripts/`.
- The `intent-pane-<slug>` pane record becomes `plan-pane-<slug>`, in `deliver`, `rex_panes.rb`, `row_record.rb` and `panes.rb`. The plan pane is now the first stage pane.
- The `hand-off-plan` stages become `plan`, `implement` (and `deliver` where it exists). The `plan` pane starts with `--permission-mode plan`, except with `--auto`. All three launchers already forward extra arguments to `claude`.
- Statusline: no `plan.md` shows "interviewing", a draft shows "scheming", an accepted plan moves on as today.
- Playbook rule 17, §7 rule 5 and §7a, and `core-values.yml` change together. Rule 17 now says: interactive Claude accepts through `ExitPlanMode`, everything else through the literal word.
- For this change itself the current rule 17 still applies, so Claude waits for the literal word after approval.

## Integration points

- Private `~/Developer/dotfiles-work`: `ons-client/docs/for-agents.local.md`, `caren/docs/for-agents.local.md` and the `tana-sync` skill mention `intent.md`. They are reported, not edited.
- After merge, Etienne restows and removes the dangling `~/.claude/skills/intent` and `~/.agents/skills/intent` links. Claude hands over a `trash` command.

## Files that change

- `agents/.agents/skills/`: `intent/` deleted, `brainstorming/` added, `plan/` rewritten (`SKILL.md`, `scripts/`, `references/`), plus `implement`, `deliver`, `review`, `finish`, `glossary`, `code-review` and `new-repo-setup` (and its `REVIEW.md`).
- Scripts: `plan/scripts/{plan_metadata.rb,plan_critique.rb,commit-plan,change-folder,start-delivery,delivery-preflight}`, `deliver/scripts/{deliver,restore,rex_panes.rb}`, `finish/scripts/fill-pr-template`.
- Launchers: `hand-off-plan.sh` and `start-review.sh` in `herdr/`, `herdr-app/` and `rex/`, and `herdr-app/.local/share/herdr-app-pane/{row_record,panes}.rb`.
- Agents, hooks and display: `claude/.claude/agents/{reviewer,test-writer,architect}.md`, the regenerated `codex/.codex/agents/*.toml`, `claude/.claude/statusline-command.rb`, `claude/.claude/core-values.yml`, the `claude/.claude/skills/intent` link (removed) and `brainstorming` link (added).
- Docs: `agents/.agents/PLAYBOOK.md`, `SKILLS-INDEX.md`, `GLOSSARY.md`, `VENDORED-LICENSES.md`.
- Tests: about 30 files under `test/`, `delivery_harness.rb`, and `claude/.claude/test/statusline_command_test.rb`. `intent_interview_depth_test.rb` becomes a plan interview test.

## Order of work

Each step is one commit, tests green before the next.

1. Walking skeleton: a failing test that a folder with only `plan.md` (intent sections and `Status: accepted`) commits through `commit-plan`. Then `PlanMetadata`, `PlanCritique`, `commit-plan`, `change-folder`; delete `auto-accept`. Update `auto_accept_test` into critique and metadata tests, and `commit_plan_test`.
2. Delivery scripts: `deliver`, `restore`, `rex_panes.rb`, `fill-pr-template`, and the move of `start-delivery` and `delivery-preflight`. Update their tests and `delivery_harness.rb`.
3. Launchers: stage lists, prompts, `--permission-mode plan`, the `plan-pane` record, `start-review.sh`. Update the worker script and pane tests.
4. Skills: vendor `brainstorming`, rewrite `plan`, add `references/autonomous-delivery.md`, delete `intent`, update the other skills and the link set. Update `artifact_chain_skills_test`, `autonomy_contract_test`, `approval_word_test`, `skill_parity_test`, `glossary_skill_test`, `pull_request_flow_test`.
5. Agents, hooks, display, docs: agent prompts, `bin/generate-codex-agents`, statusline and its test, playbook, `core-values.yml` and its mirror test, `SKILLS-INDEX.md`, `GLOSSARY.md`.
6. Sweep: a repo-wide test that no file outside `docs/changes/` names `intent.md` or the `intent` skill. Fix what it finds.

## Risks

- Plan mode may allow writing only its own plan file. The interactive draft therefore lives in `~/.claude/plans/` until approval, so a dropped session resumes from there and not from `plan.md`. Checked now: this very session works that way.
- Rewriting rule 17 and `core-values.yml` in lockstep: `test_rule_mirror_test` catches drift.
- `--permission-mode plan` in a pane is unverified by a run. The test asserts the command line, and Claude starts one pane by hand to confirm before step 3 closes.
- Wide diff. The six commits keep each review small, and Claude may split the pull request if review asks.
- The private overlay still mentions `intent.md` until Etienne edits it.

## Proof

- Starting a change produces one `plan.md` and no `intent.md` → `test/artifact_chain_skills_test.rb` `plan skill writes the intent sections into plan.md`.
- Approving `ExitPlanMode` marks the plan accepted → `test/artifact_chain_skills_test.rb` `plan skill treats ExitPlanMode approval as accepted for Claude only`.
- An autonomous plan cannot be committed accepted with an open critique → `test/commit_plan_test.rb` `refuses an accepted autonomous plan with an open critique`.
- `commit-plan`, `deliver`, `restore` and `start-delivery` work from `plan.md` alone → `commit_plan_test`, `deliver_test`, `restore_test`, `start_delivery_test`, one example each.
- A folder with only `intent.md` is not a plan → `test/commit_plan_test.rb` `refuses a folder that holds only intent.md`.
- No file refers to `intent.md` or the `intent` skill → `test/no_intent_references_test.rb` `names no intent artefact outside change folders`.
- The `plan` pane starts in plan mode except in auto → `test/herdr_worker_scripts_test.rb` `starts the plan pane in plan mode`, plus the `auto` counterpart, and the same for Rex and herdr-app.
- Statusline stages → `claude/.claude/test/statusline_command_test.rb` `shows_interviewing_when_the_folder_has_no_plan_yet` and `shows_scheming_for_a_draft_plan`.
- Invariant: playbook and `core-values.yml` agree, enforced by `test/test_rule_mirror_test.rb`.
- Final check: `bin/test`, `ruby claude/.claude/test/statusline_command_test.rb` and `lefthook run pre-commit --all-files` all pass.

Test setup: existing fixtures in `delivery_harness.rb` and the isolated git helpers. Fixtures swap `intent.md` for the intent sections inside `plan.md`.

---
Domain skills applied: software-design, glossary, ruby-style, plan.

Out of scope: behaviour changes to implement, review and deliver beyond reading `plan.md`; editing the private overlay; running `stow`.
