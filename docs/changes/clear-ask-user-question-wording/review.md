# Review: clear-ask-user-question-wording

## Round 1 — 2026-10-26T14:46:35Z — 7d6aa10d

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the default passes ran. `bin/test`: 90 files, 0 failed. `rubocop` on the five new Ruby files: no offenses. `markdownlint` no-hardwrap on `agents.md` and the change folder: clean. Manual check: a payload with "Should I go?" and the label "I/O" exits 2 with both findings on stderr.

Bugs: none found. Security: none found; the hook reads stdin only and fails open by design.

Compliance, intent acceptance criteria to tests:

- "Should I rebase the branch?" denied, message names the word → `test_a_question_with_i_is_denied_and_the_message_names_the_word`
- Label "I'll push first" denied → `test_a_label_with_i_will_is_denied`
- Label "Rebase onto main" with the full description allowed → `test_a_label_that_names_no_pronoun_with_a_full_description_is_allowed`
- Description with "You do: nothing" allowed → `test_a_description_with_you_do_is_allowed`
- `git rebase` and `I` in backticks allowed → `test_banned_words_inside_backticks_are_allowed`
- Malformed input allowed → `test_malformed_input_is_allowed`
- Other tool untouched → `test_another_tool_is_untouched`
- Playbook rule and mirror agree, session start injects it → `test_core_values_carry_every_line_of_rule_27`, `test_the_session_start_hook_prints_the_question_rule`

Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or deleted.

- [ ] Nit: `module_function` makes `checked_texts`, `question_texts`, `banned_words_in` and `message` public module methods, and `BANNED`, `CODE_SPAN` and `WORD` public constants. `plan.md` calls them private module functions and private constants, and `### Signatures` signs only `denial`. `QuestionWording.public_methods(false)` lists all five. Make the helpers private (for example `private_class_method`) and the constants `private_constant`, or record them as public in the plan — `claude/.claude/hooks/question_wording.rb:14` → fixed (Keep QuestionWording helpers and constants private)
- [ ] Nit: the two longest new `questions` bullets exceed yamllint's 120-character line length (207 and 210 characters; warnings, exit 0). Lines 15 and 21 already warn, so this follows precedent, but a folded scalar (`>-`) would keep the parsed text the mirror test compares and clear the warnings — `claude/.claude/core-values.yml:34` → fixed (Fold the long questions lines in core-values.yml)

## Round 2 — 2026-10-26T15:13:08Z — 42d297d6

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the default passes ran. `bin/test`: 90 files, 0 failed. `rubocop` on the five new Ruby files: no offenses. `yamllint claude/.claude/core-values.yml`: exit 0; the only warnings are on lines 15 and 21, which predate this branch. Manual check: "Should I go?" with the label "I/O first" exits 2 and names both findings; `[1]`, a JSON string and a string option exit 0 with a `question-wording-guard:` warning; a double-backtick span that holds a single backtick hides its text and the "you" after it is still found.

Both round 1 nits hold: `test_denial_is_the_only_public_surface` pins `denial` as the only public method with no public constants, and the folded `>-` scalars keep the parsed text that `test_core_values_carry_every_line_of_rule_27` compares.

Bugs: none found. Security: none found; the hook reads stdin only, runs no subprocess and fails open by design. Compliance: every intent acceptance criterion and every `## Proof` test still maps as in round 1; no test was weakened, skipped or deleted. Design: one public method beside a thin script, the `remote_matcher.rb` pattern, as the plan chose.

No findings.
