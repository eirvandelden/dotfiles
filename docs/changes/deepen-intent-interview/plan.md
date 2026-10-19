# Plan: Deepen the intent interview

From `intent.md` (2026-10-19). Status: accepted.

## Context

The `intent` skill (`agents/.agents/skills/intent/SKILL.md`, shared by Claude and Codex) interviews the user and writes `docs/changes/<slug>/intent.md`. Today it reads only the GitHub issue, walks seven fixed topics, and asks for "accepted". This change makes the interview read the repository first, check scope, probe edge cases for features and refactors, read the draft back, self-review it, and record decisions in a new `## Decisions` section. The `plan` skill learns to check its steps against that section. The behaviour is the skill text: tests read the text, the way `test/artifact_chain_skills_test.rb` and `test/approval_word_test.rb` already do.

## Design decisions

- Keep the numbered top-level headings (`## 1. Find the folder`, `## 2. Interview`, `## 3. Write`, `## 4. Accept`). Existing tests slice the skill on those exact headings. New guidance goes inside them as bold-labelled paragraphs, never as new `#`-prefixed lines inside `## 4. Accept`, because `test/approval_word_test.rb` ends that section at the next line that starts with `#`.
- `## 2. Interview` gets, in this order, before the seven numbered topics: **Explore first**, **Scope check**, **Depth by type**. After the seven topics: **Probe** (the checklist) and **Record decisions**. The order in the text is the order the agent works in.
- **Explore first**: before the first interview question (the `Type:` question included), read the issue, the files the request names or implies, nearby docs, `git log --oneline -20` on those paths, and the current behaviour (run it when it is cheap and safe). State what the repository already answers as premises the user can correct. Ask only what the repository cannot answer.
  - Step 1's request for an issue number is folder setup, not an interview question, and stays where it is: the folder must exist before the draft can persist. Step 1 already skips that request when the user named an issue or a task. The acceptance criterion covers the interview in `## 2`, and its test asserts that **Explore first** precedes every other paragraph and the numbered topics there.
- **Scope check**: before refining details, flag a request that bundles independent changes. Propose the split, one intent per change, each with its own slug and worktree. Continue the interview with the first change only. Two changes are independent when either one could ship and be useful without the other.
- **Depth by type**: settle `Type:` early (from issue labels, confirmed, or asked). `bugfix` and `chore` with a clear cause ask 1–3 questions and default the rest, stating the defaults in the draft. `feature` and `refactor` cover the seven topics and the full probe checklist. A bug fix whose cause or scope is unclear is not "clear" and gets probed like a feature.
  - Rewrite the current sentence "There is no fixed question count: keep asking until every template section below can be filled without guessing." so it applies to `feature` and `refactor` only: "For `feature` and `refactor` there is no fixed question count: keep asking until every template section below can be filled without guessing." The existing tests `test_the_interview_has_no_fixed_question_count` and `test_the_interview_stops_when_every_section_can_be_filled_without_guessing` still match it, and the 1–3 rule for `bugfix` and `chore` no longer contradicts it.
- **Probe checklist** for `feature` and `refactor`: current behaviour today; edge cases (empty, one, many, boundary values, concurrent use); failure modes (what happens when a dependency is missing, slow, refused or wrong); existing patterns in the repository to follow or break; one "what happens when X" question per acceptance criterion; compatibility with existing data, config or callers.
- **Record decisions**: each time the user picks between options or overrides a default, add a line to `## Decisions` in the draft right away, as `- <decision, in the user's words or close to them> — <one-line rationale>`. Defaults the agent chose without asking are not decisions; they stay in the section they affect. Never invent a rationale: when the user gave no reason, ask for it in the same turn, and write "no reason given" if they decline.
- The `## Decisions` template section sits after `## Flagged concerns` and before `## Open questions`. It is always present, holding "None." when the user made no explicit decision. The accept gate does not check it: rule "the gate still refuses open questions, empty criteria or an unresolved concern" stays exactly as it is.
- Self-review and read-back go at the top of `## 4. Accept`, before the refusal list, as one paragraph each. Self-review scans for placeholders (`<...>`, "TBD", "TODO"), contradictions between sections, scope (more than one independent change), and ambiguous words (an acceptance criterion with no concrete example). Fix what it finds before the read-back.
- Read-back: present the draft section by section, in template order, and correct each section the user disputes, updating the file. For `bugfix` and `chore` the read-back is one message listing every section in order and ending with the request for "accepted", so a clear bug fix still ends after 1–3 questions. For `feature` and `refactor`, confirm each section, or a small group of short sections, before moving on. The read-back is not counted as an interview question.
- `plan` checks fidelity in the `here` backend step 2: read `intent.md`'s `## Decisions` and check every design decision and step against it. A conflict is never resolved silently. Outside auto mode, name it in `## Design decisions` and raise it with the user before acceptance. In auto mode it becomes a `Decision needed:` line (the existing auto-mode rule, now naming `## Decisions` explicitly). An `intent.md` without `## Decisions` (written before this change) means there is nothing to check.
- The `plan` skill's `## Critique` role also checks the plan against `intent.md`'s `## Decisions`, so the second model catches a contradiction the author missed.
- Refresh the vendored-from comment: name the newly adapted parts (explore project context, the scope/decomposition check, the spec self-review), keep the left-out list (design exploration, hand-off to `writing-plans`, visual companion) and add the fresh-context reviewer subagent to it. Update the date to 2026-10. Upstream is still superpowers-ruby 7.5.0. Write the comment one line per paragraph (playbook rule 26).
- Mirror: one new `workflow` line in `claude/.claude/core-values.yml` and one new bullet in `agents.md` rule 17 (`claude/.claude/PLAYBOOK.md` is a symlink to `agents.md`). Both carry the same two sentences, word for word: "Intent interviews read the repository first, split bundled requests, probe edge cases, read the draft back and record decisions." and "Bug fixes and chores stay at 1–3 questions; features and refactors probe fully." Each sentence stays at 20 words or fewer. The self-review is part of reading the draft back and is not named separately, so the core values stay short.
- The skill's `## Codex` section gains one sentence: explore first, the scope check, the probe checklist and the read-back apply unchanged; Codex reads files with its own tools.
- Leave the frontmatter `description`, `agents/openai.yaml` and `SKILLS-INDEX.md` unchanged. The skill still interviews for the same four things and writes the same file; changing three mirrored descriptions adds churn without changing when the skill fires.

## Integration points

- `agents/.agents/skills/intent/SKILL.md`: read by Claude (through `claude/.claude/skills/intent` link) and Codex (`~/.agents/skills`).
- `agents/.agents/skills/plan/SKILL.md`: consumes `intent.md`.
- `agents/.agents/skills/finish/scripts/fill-pr-template`: reads `intent.md` sections by name (`Problem`, `Proposed outcome`); a new `## Decisions` section does not affect it.
- `agents/.agents/skills/plan/scripts/auto-accept`, `commit-plan`, `deliver`, `restore`, `hand-off-plan.sh`, `start-review.sh`: read only the header lines or the path of `intent.md`; unaffected.
- `claude/.claude/hooks/core-values.rb`: prints `core-values.yml`; a new list item needs no code change.
- Existing text tests: `test/artifact_chain_skills_test.rb`, `test/approval_word_test.rb`, `test/autonomy_contract_test.rb` slice the intent skill on its headings. They must stay green.

## Files that change

- `test/intent_interview_depth_test.rb` (new) — text tests for every acceptance criterion except the gate, which existing tests cover.
- `agents/.agents/skills/intent/SKILL.md` — vendored-from comment; `## 2. Interview` (explore first, scope check, depth by type, probe checklist, record decisions); template in `## 3. Write` (`## Decisions`); `## 4. Accept` (self-review, read-back); `## Codex` (one sentence).
- `agents/.agents/skills/plan/SKILL.md` — `here` backend step 2 (fidelity check against `## Decisions`); template guidance for `## Design decisions` (name conflicts there); `## Auto mode` (name `## Decisions` in the `Decision needed:` rule); `## Critique` (check against `## Decisions`).
- `claude/.claude/core-values.yml` — one `workflow` line.
- `agents.md` — one bullet in rule 17.

## Order of work

1. Create `test/intent_interview_depth_test.rb` with only `test_a_feature_interview_reads_the_repository_before_its_first_question`. Run `ruby -Itest test/intent_interview_depth_test.rb`. Watch it fail because the interview section has no explore-first paragraph.
2. Add the remaining tests named under `## Proof` to the same file. Run it. Every new test fails for the missing text, not for a helper error.
3. Edit `## 2. Interview` in the intent skill: explore first, scope check, depth by type (before the seven topics); probe checklist and record decisions (after them). Run the test file; the interview tests pass.
4. Add `## Decisions` to the template in `## 3. Write`. Run; the template test passes.
5. Add the self-review and read-back paragraphs at the top of `## 4. Accept`. Add the `## Codex` sentence. Refresh the vendored-from comment. Run; the accept and comment tests pass.
6. Edit the plan skill: step 2 fidelity check, `## Design decisions` guidance, auto mode, critique role. Run; the plan test passes.
7. Add the `core-values.yml` line and the rule 17 bullet. Run; the mirror test passes.
8. Run the existing slices: `set -o pipefail; for file in test/artifact_chain_skills_test.rb test/approval_word_test.rb test/autonomy_contract_test.rb test/core_values_test.rb test/skill_parity_test.rb test/markdown_rule_mirror_test.rb; do ruby -Itest "$file" || exit 1; done`.
9. Run the full suite the way CI does: `set -o pipefail; for file in test/*_test.rb; do ruby -Itest "$file" || exit 1; done`.
10. Lint: `rubocop --force-exclusion test/intent_interview_depth_test.rb`; `markdownlint --config ~/.config/markdownlint/no-hardwrap.json --rules ~/.config/markdownlint/no-hardwrap.cjs agents/.agents/skills/intent/SKILL.md agents/.agents/skills/plan/SKILL.md agents.md`; `yamllint claude/.claude/core-values.yml` (lefthook runs yamllint on staged YAML).
11. Verify as a human would: render the core values hook (`claude/.claude/hooks/core-values.rb full` with the worktree's `core-values.yml` under a temporary `HOME/.claude/`) and confirm the new line prints. Read the edited `## 2. Interview` and `## 4. Accept` top to bottom once as an agent would, checking the order of steps reads as a procedure.
12. Re-read the full diff (playbook rule 21) and commit in small steps: tests, intent skill, plan skill, mirror (core values plus playbook in one commit, since they must change together).

## Risks

- Existing tests slice on headings. Adding a `#`-prefixed line inside `## 4. Accept` would cut `test/approval_word_test.rb`'s section short. Mitigation: bold-labelled paragraphs only, no sub-headings.
- The skill grows longer (173 lines now). A long skill gets skimmed. Mitigation: each new paragraph is short, and the probe checklist is one list.
- A bug fix could drift back to a long interview if the read-back or self-review counts as questions. Mitigation: the text states the read-back is not an interview question and is one message for `bugfix` and `chore`.
- "Explore first" could make the agent read the whole repository. Mitigation: the text names a bounded set (the files the request names or implies, nearby docs, recent commits on those paths).
- Text tests prove the words exist, not that an agent obeys them. That is the established test level for skills in this repository; the human check in step 11 covers the reading order.
- Rejected: new numbered top-level sections (`## 2a`, `## 3. Self-review`). They would renumber headings that existing tests and other skills reference.
- Rejected: a gate that refuses acceptance when `## Decisions` is missing. Intent says the gate stays unchanged, and older accepted intents have no such section.
- Rejected: a reviewer subagent for the intent, the visual companion, and proposing solution approaches. Intent puts them out of scope.

## Out of scope

- Solution approaches in intent; the visual companion; the hand-off to `writing-plans`.
- The pane backend, delivery-mode flow and `## Autonomous delivery` section of the intent skill.
- `implement`, `review`, `deliver`, `finish` and their scripts.
- A reviewer subagent for the intent.
- The frontmatter description, `agents/openai.yaml` and `SKILLS-INDEX.md` entries.

## Proof

- Starting an interview on a feature, the skill reads relevant repository files before its first question → `test/intent_interview_depth_test.rb` `test_a_feature_interview_reads_the_repository_before_its_first_question`
- A request that bundles two independent changes is flagged and split before details are refined → `test/intent_interview_depth_test.rb` `test_a_bundled_request_is_flagged_and_split_before_details_are_refined`
- A feature interview asks about edge cases and failure modes, not only the seven topics → `test/intent_interview_depth_test.rb` `test_a_feature_interview_probes_edge_cases_and_failure_modes`
- A clear bug fix still ends after 1–3 questions → `test/intent_interview_depth_test.rb` `test_a_clear_bug_fix_still_ends_after_one_to_three_questions`
- Before asking for "accepted", the skill reads the draft back section by section and corrects it → `test/intent_interview_depth_test.rb` `test_the_draft_is_read_back_section_by_section_before_asking_for_accepted`
- A written `intent.md` has a `## Decisions` section listing each explicit decision with its rationale → `test/intent_interview_depth_test.rb` `test_the_template_records_each_decision_with_its_rationale`
- The `plan` skill reports any plan step that contradicts a recorded decision → `test/intent_interview_depth_test.rb` `test_plan_reports_a_step_that_contradicts_a_recorded_decision`
- The "accepted" gate still refuses an intent with open questions, empty criteria or an unresolved concern → `test/artifact_chain_skills_test.rb` `test_intent_refuses_acceptance_without_acceptance_criteria` and `test_intent_refuses_acceptance_with_open_questions_or_an_undecided_concern` (existing, must stay green)
- `core-values.yml` and playbook rule 17 name the deeper interview, and no mirrored rule contradicts the skill → `test/intent_interview_depth_test.rb` `test_core_values_and_rule_17_name_the_deeper_interview`

Per changed file, the unit tests expected, named as behaviour:

- `agents/.agents/skills/intent/SKILL.md`: explore-first paragraph is the first paragraph of `## 2. Interview` (before the scope check, the depth rule and the numbered topics) and says to ask only what the repository cannot answer; "no fixed question count" applies to `feature` and `refactor` only; a decision without a stated reason is asked for, never invented (`test_a_decision_rationale_is_asked_for_never_invented`); scope check appears before the first numbered topic and says to split; probe checklist names edge cases and failure modes and applies to `feature` and `refactor`; `bugfix` and `chore` keep 1–3 questions; self-review names placeholders, contradictions, scope and ambiguity (`test_the_draft_is_self_reviewed_before_the_read_back`); read-back appears in `## 4. Accept` before the accept words; template holds `## Decisions` between `## Flagged concerns` and `## Open questions` with a rationale placeholder; the vendored-from comment names explore context, scope check and self-review as adapted and still names the visual companion and `writing-plans` as left out (`test_the_vendored_comment_names_what_was_adapted_and_left_out`).
- `agents/.agents/skills/plan/SKILL.md`: names `## Decisions`, says a contradiction is reported and never resolved silently, and names `Decision needed:` for auto mode; the `## Critique` role checks against `## Decisions` (`test_the_plan_critique_checks_the_recorded_decisions`).
- `claude/.claude/core-values.yml` and `agents.md` rule 17: both hold the two mirror sentences word for word (the test reads them from one constant and asserts each file includes both).

Test setup: none beyond `File.read`. The new test file follows `test/artifact_chain_skills_test.rb`: `require "minitest/autorun"`, `require_relative "isolated_git"`, a `section(text, from, to)` helper using `String#index`, and the rule 17 slice from `test/approval_word_test.rb`. Match `1[–-]3` to accept an en dash or a hyphen.

---
Domain skills applied: dotfiles-maintenance (mirror between `agents.md` and `core-values.yml`; `PLAYBOOK.md` is a symlink to `agents.md`), rails-testing (Minitest, behaviour-named tests). No conflicts between them or with the playbook.

## Critique

### Round 1 (codex terra)

- Explore first is only first inside `## 2`; step 1 still asks for an issue earlier, so the test can pass while the criterion fails → fixed (plan now states that step 1's issue request is folder setup that stays, that Explore first precedes every interview question including `Type:`, and the test asserts it is the first paragraph of `## 2`)
- The 1–3 rule for bug fixes conflicts with the existing "no fixed question count" sentence and its test → fixed (plan rewrites that sentence to apply to `feature` and `refactor` only, which keeps both existing tests matching)
- Record decisions demands a rationale but never says how to get one, which invites invented reasons → fixed (plan requires asking for a missing reason and writing "no reason given" on refusal; new test `test_a_decision_rationale_is_asked_for_never_invented`)
- The mirror omits the scope split, self-review and read-back rules → fixed (two shared sentences now name repository-first, split, edge cases, read-back and decisions plus the depth rule; the test asserts both files include them word for word)
- Step 8 lists bare filenames that would not run → fixed (step 8 is now an explicit `ruby -Itest` loop with `set -o pipefail`)
