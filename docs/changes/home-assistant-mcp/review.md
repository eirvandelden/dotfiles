# Review: home-assistant-mcp

## Round 1 — 2026-10-09T21:36:21Z — 8dda327b

Base: `origin/main` (a306cbf9). No `REVIEW.md` in the repository; default passes (Bugs, Security, Compliance) applied.

Suite state: `home_assistant_mcp_test.rb`, `secrets_loader_test.rb`, `guard_parity_test.rb` and the other tests green; RuboCop and the no-hardwrap markdown lint clean on the touched files. `review_report_check_test.rb`, `worktree_create_test.rb`, `worktree_pane_test.rb` and `worktree_viewer_test.rb` error locally because `git commit` in their temp repositories fails on 1Password commit signing ("agent returned an error"). The branch touches none of those scripts; environmental, not a finding.

Compliance, acceptance criteria to proof:

- After `unlock`, `HA_MCP_GATE_TOKEN` is set → `SecretsLoaderTest#test_the_personal_mapping_unlocks_the_home_assistant_gate_token`.
- Codex lists the tools and reads state without approval → `HomeAssistantMcpTest#test_codex_reaches_home_assistant_through_the_gate_with_the_unlocked_token` (static config text; live check deferred to after merge, as the plan says).
- Codex asks before a light, automation, scene or script change → `#test_codex_asks_before_every_home_assistant_tool_that_is_not_read_only`, `#test_no_home_assistant_tool_skips_the_approval_prompt` (static; see the first Important finding).
- Claude shows the server connected after registration → `#test_headroom_registers_home_assistant_for_claude_with_the_token_left_unexpanded` (static; live check deferred).
- Without `unlock` the gate refuses, and `HEADROOM.md` says to run `unlock` first → `#test_headroom_says_to_unlock_before_starting_claude_for_home_assistant`.

Every test named in `plan.md` `## Proof` exists. No existing test was weakened, skipped or deleted.

- [ ] Important: The approval this change relies on likely never reaches Etienne. `config.toml` sets `approvals_reviewer = "auto_review"` (line 4, already on main), and the installed Codex 0.162.0 routes MCP tool-call approvals to that automatic reviewer (the binary carries `GuardianApprovalReviewAction::McpToolCall` and `GuardianAssessmentAction::McpToolCall`). With `default_tools_approval_mode = "writes"`, a model then decides whether to turn on a light or edit an automation. Acceptance criterion 3 and the plan's live proof ("each shows an approval prompt; decline both") assume a human prompt. `plan.md` does not mention `approvals_reviewer`, and it checked the `writes` semantics against Codex 0.160.1, not the installed 0.162.0. The text-only tests cannot detect this. — `codex/.codex/config.toml:199` →
- [ ] Nit: The `writes` and URL/token assertions are plain substring checks on the whole table chunk, so a commented-out line such as `# default_tools_approval_mode = "writes"` also passes. Anchoring to the start of a line would make them prove the active setting. — `test/home_assistant_mcp_test.rb:22` →
- [ ] Nit: `refute_includes body, %(approval_mode = "approve")` only catches that exact spacing; `approval_mode="approve"` (valid TOML) slips through. — `test/home_assistant_mcp_test.rb:29` →
- [ ] Nit: The gate token travels as a bearer header over plain `http://` on the home network, the same as email and fizzy. Anyone on the LAN who can sniff traffic gets full Home Assistant write access, which is a larger blast radius than the mail and card servers. The intent fixes this URL, so this is a note for the ha-mcp deployment, not this branch. — `codex/.codex/config.toml:196` →
