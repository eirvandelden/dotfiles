# Plan: Harden autonomous delivery for personal projects

From the accepted personal-autonomy intent and plan (2026-10-01). Status: accepted.

## Context

PR #182 merged the original feature as `f4adcd4e` during final verification. This follow-up closes review findings within that accepted outcome. It does not change the agreed human gates or permission boundaries. The original implementation and Proof tests remain on main.

## Files that change

- `claude/.claude/skills/plan/scripts/auto-accept` — trust expected metadata fields at column zero and compare their actual status and delivery values.
- `claude/.claude/skills/intent/SKILL.md` — record Delivery in the status paragraph and route coordination through review auto mode.
- `claude/.claude/skills/review/SKILL.md` — require a separate read-only Claude CLI round from Codex coordinators.
- `claude/.claude/skills/finish/SKILL.md` — require an accepted personal autonomous intent, allow coordinator invocation and skip the actual confirmation step.
- `test/auto_accept_test.rb` — add refusals for body examples, quoted metadata and empty intents; strengthen heading and fence cases.
- `test/autonomy_contract_test.rb` — cover review routing, read-only prompt overrides, finish eligibility, coordinator invocation and metadata placement.

## Order of work

1. Reproduce each acceptance bypass and workflow gap with a failing regression or contract.
2. Restrict metadata to Author, Status, Type and Delivery fields in the first paragraph after the title.
3. Route the coordinator through independent Claude and Codex review rounds; make the Claude prompt explicitly report-only.
4. Require the accepted autonomous choice for finish auto mode and remove only its intended confirmation gate.
5. Run targeted tests, the full suite and changed-file linters. Keep every required check strict.
6. Run both reviewers again until each reports no findings. Record each round and commit the report alone.
7. Generate the PR body from these follow-up artifacts. Remove them through finish, publish to origin and stop before merge.

## Proof

- Body and quoted metadata cannot grant autonomy → `test/auto_accept_test.rb` `test_refuses_a_delivery_line_in_a_body_section`, `test_refuses_a_delivery_line_in_a_fenced_body_example`, `test_refuses_a_delivery_line_in_a_fenced_header_example`, `test_refuses_an_accepted_status_only_in_a_body_example`, `test_refuses_a_delivery_line_after_a_second_title_heading`, `test_refuses_a_delivery_line_after_a_setext_heading`, `test_refuses_quoted_metadata_in_a_blockquote`, `test_refuses_quoted_metadata_in_indented_code`, `test_refuses_a_delivery_line_after_body_text_without_a_blank_line`
- Empty intents refuse with a reason; valid header forms still pass → `test/auto_accept_test.rb` `test_refuses_an_empty_intent_with_a_reason`, `test_accepts_a_personal_artifact_with_a_closed_critique`, `test_accepts_a_delivery_line_of_its_own`
- Only actual status and delivery values grant autonomy → `test/auto_accept_test.rb` `test_refuses_status_text_in_another_metadata_field`, `test_refuses_a_draft_status_that_quotes_an_accepted_status_later`, `test_refuses_a_delivery_choice_that_only_starts_with_autonomous`, `test_refuses_step_by_step_even_when_the_header_mentions_autonomous`
- Codex coordination obtains separate model families without herdr → `test/autonomy_contract_test.rb` `test_codex_coordinator_uses_the_claude_cli_review_backend`, `test_codex_auto_review_uses_a_read_only_claude_cli_backend`
- The Claude prompt overrides the reviewer write and fetch steps → `test/autonomy_contract_test.rb` `test_claude_cli_review_replaces_the_reviewer_write_and_fetch_steps`
- Finish skips only the opted-in personal confirmation gate → `test/autonomy_contract_test.rb` `test_finish_auto_mode_skips_the_actual_body_confirmation_step`, `test_finish_auto_mode_requires_an_accepted_autonomous_intent`, `test_finish_auto_mode_is_personal_only`
- Metadata placement and coordinator invocation are explicit → `test/autonomy_contract_test.rb` `test_intent_offers_autonomy_only_on_a_personal_origin`, `test_finish_overview_allows_the_autonomous_coordinator`
- PR text describes this follow-up → exercise `finish/scripts/fill-pr-template` on this intent and plan; check the title and six-file implementation list.

## Risks and limits

The metadata gate accepts the documented template, not arbitrary Markdown. The intent skill emits that format. Instructions and contract tests still require a representative human-use trial to prove full workflow delivery. The `journal_administration` trial follows merge and activation; it is outside this follow-up.

No dependency, deployment, system-tool, symlink or Stow change belongs here. Work and step-by-step rules stay intact. Agents never merge or post GitHub comments.
