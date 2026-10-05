# Review: trek-mcp

## Round 1 — 2026-10-05T12:51:42Z — fa136aa1

Passes run with defaults (no `REVIEW.md` in the repo). Bugs: none found. Security: none found; the TREK entry has no token and no header, so login is OAuth only, and the CLI test uses a tmp `CODEX_HOME`, so `~/.codex` stays untouched. Current state: `test/codex_config_test.rb` passes (6 runs, 0 skips, so the codex CLI test ran), rubocop is clean, and cspell is clean on the touched files. markdownlint reports MD024 on `HEADROOM.md` for the `Launch` and `Meta commands` headings, which were already duplicated on main. In the full suite, `test/review_report_check_test.rb` errors on `git commit ... advance main failed` in its tmp repo. This change does not touch that test or the hooks, so the error comes from the local environment.

Compliance, acceptance criteria to proof:

- Codex points `trek` at the TREK URL with no bearer token → `test_trek_points_at_the_trek_url_with_no_bearer_token`
- Codex accepts the config and shows the URL → `test_codex_accepts_the_config_and_shows_the_trek_url`
- Deleting a trip, and every other delete or remove tool, asks for approval → `test_every_listed_trek_tool_asks_for_approval`, for the 10 listed tools only. `plan.md` narrows this list on Etienne's instruction, so this is not a finding. The manual delete-a-trip check (plan step 9) is still open.
- After `codex mcp login trek`, Codex lists trips → manual, plan step 9, not yet done
- After following `HEADROOM.md`, Claude Code lists trips → manual, plan step 9, not yet done

All six tests named in `plan.md` `## Proof` exist. No existing test was weakened, skipped, or deleted.

- [ ] Nit: `homelab`, `roadtrip` and `vacay` are inserted between `elete` and `Élysées`, out of the file's alphabetical order (`dawarich` is in its correct place). `dawarich`, `roadtrip` and `homelab` occur only in `docs/changes/trek-mcp/plan.md`, so they become unused entries once `finish` removes the change folder — `project-dictionary.txt:175` →
- [ ] Nit: `test_no_other_trek_tool_asks_for_approval` and `test_at_most_ten_trek_tools_ask_for_approval` count `[mcp_servers.trek.tools.*]` tables, not tables with `approval_mode = "approve"`. A future table for some other setting would fail them even though that tool does not ask. Also, the at-most-ten test can only fail when the no-other test fails too, because `APPROVAL_TOOLS` has 10 entries. It proves nothing new — `test/codex_config_test.rb:47` →
- [ ] Nit: the Codex heading is `### TREK MCP login`, but `plan.md` names it `### TREK MCP server`. The rename avoids MD024, which is reasonable, but the plan does not record it — `claude/.claude/HEADROOM.md:75` →
