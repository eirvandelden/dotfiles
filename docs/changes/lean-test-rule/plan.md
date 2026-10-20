# Plan: Lean test rule

From `intent.md` (2026-10-20). Status: accepted.

## Context

Playbook rule 3 (`agents.md`, read by Claude through `claude/.claude/PLAYBOOK.md` and by Codex through `codex/.codex/PLAYBOOK.md`, both symlinks to `agents.md`) says "Write the test first; never generate code without a corresponding test." and carries a mobile exception. Nine other files repeat that rule or the exception. This change replaces the rule with a lean one, deletes the exception everywhere, and replaces `test/mobile_testing_exception_test.rb` with a drift test for the new rule.

## Design decisions

- Canonical rule text. Four lines, written in Simplified Technical English, identical in every mirror:
  1. `Every code change has tests. Configuration has no tests.`
  2. `A new feature has an integration test that proves it works and keeps working. It also has unit tests of its public methods and classes.`
  3. `Test public methods and classes only. Private methods never get tests of their own.`
  4. `Tests may follow the code. A bug fix is the exception: its regression test comes first and fails before the fix.`
- The playbook is the source. The drift test reads rule 3's list items from `agents.md` (the items between the `3. Tests:` line and the `Run tests after every change` item) and checks that every mirror contains each line verbatim as a substring. A substring check lets a mirror use any list marker, indent or YAML quoting.
- Rule 3's heading changes from `Test-driven development:` to `Tests:`, because test-first is no longer the general rule (intent decision 1). The two remaining items (`Run tests after every change…`, `A task is only done when…`) stay unchanged.
- Mirrors are the files that today carry the rule or the exception, plus `core-values.yml`, which intent names as a mirror. `core-values.yml` gets the four lines under `verification:`. It carries no test rule today; adding it follows intent decision "All mirrors get the new wording".
- `implement` skill, `test-writer` and `implementer` agents (Claude and Codex): the four lines replace the exception paragraph, followed by one sentence: `This pipeline still writes each test before its code, by design.` That keeps the red/green loop test-first (intent decision 4, out-of-scope item 1).
- `code-review` step 2: `(failing test first, per the playbook TDD rule)` plus the exception becomes `Follow the playbook test rule:` with the four lines as nested items. A finding that is a bug then gets its regression test first through line 4.
- `plan` skill: the exception paragraph is replaced by the four lines. The `→ check:` Proof form stays, because configuration now has no tests and still needs a named check. The main Proof contract sentence ("one line per acceptance criterion from `intent.md` naming the test file and test name that proves it") gains "or, for a criterion that needs no test, the check that proves it". The trigger sentence changes from "A criterion under the mobile exception has no test to name." to "A criterion that needs no test, such as a configuration change, has no test to name." `test_plan_skill_defines_the_check_proof_line` keeps guarding `→ check:` and also asserts the phrase `needs no test`.
- `rails-testing`: the `Test-driven development: …create the test first.` item and the exception item are replaced by the four lines.
- `hotwire-native`: the exception paragraph above the validation matrix is replaced by the four lines, then `The matrix below names what "done" means per change.` The matrix follows the new rule: native UI and wiring are code, so they need tests; configuration is not.
  - `Native UI or configuration` splits into two rows. `Native UI`: an automated test covers it; build, lint and a simulator or device check show the change. `Configuration`: build passes, lint passes, and a simulator or device check shows the change; it needs no test.
  - `Simple wiring`: an automated test covers it; build, lint and a simulator or device check exercise the wired path.
  - `Bridge component, native side`: an automated test covers it; build, lint and a simulator or device check send a real message through the component.
  - `Meaningful logic` and `Security-sensitive behaviour` drop "written first", since tests may follow the code (intent decision 1). `Regression fix` stays as it is.
- `test/hotwire_native_skill_test.rb` follows the matrix. `test_matrix_validates_native_ui_with_build_lint_and_a_device_check` becomes `test_matrix_validates_native_ui_with_an_automated_test_and_a_device_check` (row `Native UI`: asserts automated test, build, lint, simulator or device). New `test_matrix_validates_configuration_with_build_lint_and_a_device_check_and_no_test` (row `Configuration`: asserts build, lint, simulator or device, `needs no test`). `test_matrix_names_a_web_side_and_a_native_side_check_for_bridge_components` also asserts `automated test` on the native row. `test_references_leave_the_testing_rule_to_the_mobile_exception` is renamed `test_references_leave_the_testing_rule_to_the_playbook`; its body stays. These changes follow from deleting the exception, not from weakening a check.
- Drift check object: the test file defines a small public `TestRuleMirror` class (`new(playbook_text)`, `#rule_lines`, `#missing_from(mirror_text)`). The real-file test and the two drift unit tests both use it through its public methods, so no private helper gets its own tests.
- `test/mobile_testing_exception_test.rb` is renamed with `git mv` to `test/test_rule_mirror_test.rb`, class `TestRuleMirrorTest`, matching the sibling `*_rule_mirror_test.rb` files.
- Codex agent `.toml` files are never edited by hand. `bin/generate-codex-agents claude/.claude/agents codex/.codex/agents` regenerates them; `test/codex_agent_generation_test.rb` guards the result.

## Integration points

- `claude/.claude/hooks/core-values.rb` prints `core-values.yml` on SessionStart; four more lines appear there.
- `bin/generate-codex-agents` compiles the Claude agents into the Codex `.toml` files.
- `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb`, so the renamed file runs in CI with no workflow change.
- Codex reads the skills through `~/.agents/skills`; Claude reads them through the `claude/.claude/skills/<name>` symlinks into `agents/.agents/skills`. No link changes.

## Files that change

- `test/mobile_testing_exception_test.rb` → `test/test_rule_mirror_test.rb` — rewritten drift test for the new rule.
- `agents.md` — rule 3 heading and its first two items replaced by the four canonical lines.
- `claude/.claude/core-values.yml` — four canonical lines added under `verification:`.
- `agents/.agents/skills/rails-testing/SKILL.md` — TDD item and exception item replaced.
- `agents/.agents/skills/code-review/SKILL.md` — step 2 rewritten.
- `agents/.agents/skills/plan/SKILL.md` — exception paragraph replaced by the four lines; Proof contract sentence and `→ check:` trigger sentence reworded.
- `agents/.agents/skills/implement/SKILL.md` — exception paragraph replaced by the four lines and the pipeline sentence.
- `agents/.agents/skills/hotwire-native/SKILL.md` — exception paragraph replaced by the four lines; validation matrix rewritten as above.
- `claude/.claude/agents/test-writer.md`, `claude/.claude/agents/implementer.md` — exception paragraph replaced by the four lines and the pipeline sentence.
- `codex/.codex/agents/test-writer.toml`, `codex/.codex/agents/implementer.toml` — regenerated.
- `test/hotwire_native_skill_test.rb` — matrix tests follow the new rows; one test renamed.

## Order of work

1. `git mv test/mobile_testing_exception_test.rb test/test_rule_mirror_test.rb`. Write the four playbook acceptance tests in it. Run `ruby -Itest test/test_rule_mirror_test.rb`; watch them fail against the current rule 3.
2. Rewrite rule 3 in `agents.md`. Run the file; the four playbook tests pass.
3. Write the two drift unit tests on fixture text and the `TestRuleMirror` class; watch them fail, then pass. Write the no-legacy test, the drift test on the real files and the extended `test_plan_skill_defines_the_check_proof_line`. Run; the real-file tests fail on every mirror.
4. Update each mirror in turn except `hotwire-native`: `core-values.yml`, `rails-testing`, `code-review`, `plan`, `implement`, `test-writer.md`, `implementer.md`. Run the file after each one.
5. Run `bin/generate-codex-agents claude/.claude/agents codex/.codex/agents`. Run `ruby -Itest test/codex_agent_generation_test.rb`; green.
6. Change the hotwire matrix tests first; run `ruby -Itest test/hotwire_native_skill_test.rb` and watch the new assertions fail. Then rewrite the `hotwire-native` exception paragraph and matrix. Run the hotwire test and `test/test_rule_mirror_test.rb`; both green.
7. Run the full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`. Run markdownlint on every touched `.md`, yamllint on `core-values.yml`, rubocop on both touched test files.
8. Commit in small steps: the test rename and rewrite with the playbook change, then one commit per mirror group (skills, agents plus regenerated Codex agents, core values, hotwire test rename).

## Risks

- A mirror loses its surrounding meaning: a paragraph that said "test first" now sits next to text that assumes it. Each edit re-reads the whole section. `implement`, `test-writer` and `implementer` keep their red/green instructions untouched.
- The drift test extracts rule 3 by position in `agents.md`. A later reorder of rule 3's items breaks extraction. The test fails loudly with "rule 3 not found" in that case, not silently.
- `core-values.yml` lines contain a colon (`exception: its`). They are double-quoted like the existing items, so YAML parses them as strings; yamllint and the core-values hook prove it.
- The `.toml` literal blocks use `'''`. The canonical lines contain no `'''`, so the generator output stays valid TOML.
- Rejected: an HTML comment marker around the rule in each file. It adds noise to every mirror for no gain over the positional read of one file.
- Rejected: keeping the canonical text as a constant in the test only. It would not prove that mirrors match the playbook, which acceptance criterion 6 asks for.
- Out of scope: the `implement` red/green loop and the `test-writer`/`implementer` split; `systematic-debugging`, `37signals-style` and `rails-guides` texts; historical `docs/` plans; removing existing tests anywhere; the `test-driven-development` mentions in the agents' provenance comments (they name a vendored skill, not the rule).

## Proof

- Playbook rule 3 states that code changes need tests and configuration does not. → `test/test_rule_mirror_test.rb` `test_playbook_rule_3_requires_tests_for_code_and_none_for_configuration`
- Playbook rule 3 states that a new feature needs an integration test in addition to unit tests. → `test/test_rule_mirror_test.rb` `test_playbook_rule_3_gives_a_new_feature_an_integration_test_and_unit_tests`
- Playbook rule 3 states that private methods never need tests and public methods and classes do. → `test/test_rule_mirror_test.rb` `test_playbook_rule_3_tests_public_methods_and_classes_and_never_private_methods`
- Playbook rule 3 states that a bug fix still gets its regression test first. → `test/test_rule_mirror_test.rb` `test_playbook_rule_3_keeps_the_regression_test_of_a_bug_fix_first`
- No mirror still says "never generate code without a corresponding test" or carries the mobile exception. → `test/test_rule_mirror_test.rb` `test_no_mirror_keeps_the_blanket_rule_or_the_mobile_exception`
- The drift test fails when one mirror differs from the playbook and passes when they all agree. → `test/test_rule_mirror_test.rb` `test_every_mirror_carries_the_playbook_test_rule`, `test_drift_check_reports_the_line_a_mirror_lacks`, `test_drift_check_reports_nothing_when_the_mirror_agrees`
- The full test suite and the linters are green. → check: `for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`, then markdownlint, yamllint and rubocop on every touched file

Per changed file, the unit tests expected:

- `test/test_rule_mirror_test.rb`: `test_drift_check_reports_the_line_a_mirror_lacks`, `test_drift_check_reports_nothing_when_the_mirror_agrees`, `test_plan_skill_defines_the_check_proof_line` (kept from the old file, extended with `needs no test`).
- `test/hotwire_native_skill_test.rb`: `test_matrix_validates_native_ui_with_an_automated_test_and_a_device_check`, `test_matrix_validates_configuration_with_build_lint_and_a_device_check_and_no_test`, `test_matrix_names_a_web_side_and_a_native_side_check_for_bridge_components` (native row asserts an automated test), `test_references_leave_the_testing_rule_to_the_playbook` (renamed, body unchanged); every other test there stays green.
- `test/codex_agent_generation_test.rb`: unchanged, stays green after regeneration.

Test setup: no fixtures. The real-file tests read the repository files. The two drift unit tests build a `TestRuleMirror` from an inline playbook string and call `#missing_from` with an inline mirror string. The mirror list covers `agents/.agents/skills/{rails-testing,code-review,plan,implement,hotwire-native}/SKILL.md`, `claude/.claude/agents/{test-writer,implementer}.md`, `codex/.codex/agents/{test-writer,implementer}.toml` and `claude/.claude/core-values.yml`; the no-legacy test also covers `agents.md`.

---
Domain skills applied: rails-testing, dotfiles-maintenance.

## Critique

### Round 1 (codex gpt-5.6-terra)

- The hotwire-native skill would fail the drift test, because the plan gave it one sentence instead of the four canonical lines. → fixed (hotwire-native now carries the four lines, then the matrix as supplementary guidance)
- The hotwire matrix kept native UI and wiring done without tests, which keeps the deleted exception alive. → fixed (matrix splits Native UI from Configuration; Native UI, Simple wiring and Bridge component native side need an automated test; hotwire matrix tests follow)
- The drift unit tests exercised a private `missing_lines` helper, against the new rule on private methods. → fixed (a public `TestRuleMirror` class carries the check; tests use its public methods)
- The plan skill's main Proof contract still required a test file and name for every criterion, so a configuration criterion had no valid Proof line. → fixed (the contract sentence now allows a check for a criterion that needs no test; the plan skill test asserts `needs no test`)
