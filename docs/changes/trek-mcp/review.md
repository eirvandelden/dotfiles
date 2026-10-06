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

- [x] Nit: `homelab`, `roadtrip` and `vacay` are inserted between `elete` and `Élysées`, out of the file's alphabetical order (`dawarich` is in its correct place). `dawarich`, `roadtrip` and `homelab` occur only in `docs/changes/trek-mcp/plan.md`, so they become unused entries once `finish` removes the change folder — `project-dictionary.txt:175` → dismissed: main deleted `project-dictionary.txt` (PR #180); the rebase dropped the dictionary change
- [x] Nit: `test_no_other_trek_tool_asks_for_approval` and `test_at_most_ten_trek_tools_ask_for_approval` count `[mcp_servers.trek.tools.*]` tables, not tables with `approval_mode = "approve"`. A future table for some other setting would fail them even though that tool does not ask. Also, the at-most-ten test can only fail when the no-other test fails too, because `APPROVAL_TOOLS` has 10 entries. It proves nothing new — `test/codex_config_test.rb:47` → fixed (Tighten TREK Codex config tests)
- [x] Nit: the Codex heading is `### TREK MCP login`, but `plan.md` names it `### TREK MCP server`. The rename avoids MD024, which is reasonable, but the plan does not record it — `claude/.claude/HEADROOM.md:75` → fixed (docs: update trek-mcp plan and intent for main)

## Round 2 — 2026-10-06T18:53:22Z — b909997c

Passes run with defaults (no `REVIEW.md` or `REVIEW.local.md` in the repo). The code is unchanged since round 1 (`fa136aa1`); only the round 1 report was added. `origin/main` has moved 30+ commits ahead: PR #180 removed cspell and deleted `project-dictionary.txt`, and PR #181 merged the spec stage into intent. Current state: `test/codex_config_test.rb` passes (6 runs, 0 skips, codex-cli 0.160.1 present), and rubocop is clean. markdownlint reports only the MD024 errors that already exist on main. The full `test/*_test.rb` loop has one error, `test/review_report_check_test.rb` (`git commit --quiet -m advance main failed`), which is the same local-environment error as round 1. Bugs: the branch conflicts with main (see below). Security: all 10 approval tool names exist exactly in the TREK wiki (`MCP-Tools-and-Resources.md`, `MCP-Addon-Tools.md`, cloned fresh), the URL is `https`, and no token or header is in the repo. Round 1's three nits stay open.

Compliance, acceptance criteria (from `spec.md`; `intent.md` has none) to proof:

- Codex points `trek` at the TREK URL with no bearer token → `test_trek_points_at_the_trek_url_with_no_bearer_token`
- Codex accepts the config and shows the URL → `test_codex_accepts_the_config_and_shows_the_trek_url`, ran here against the real CLI
- Deleting a trip, and every other delete or remove tool, asks for approval → `test_every_listed_trek_tool_asks_for_approval`, for the 10 tools that `plan.md` narrows to on Etienne's instruction. The manual delete-a-trip check (plan step 9) is still open.
- After `codex mcp login trek`, Codex lists trips → manual, plan step 9, not yet done
- After following `HEADROOM.md`, Claude Code lists trips → manual, plan step 9, not yet done

All six tests named in `plan.md` `## Proof` exist. No existing test was weakened, skipped, or deleted.

- [x] Important: the branch does not rebase onto `origin/main`. Main deleted `project-dictionary.txt` in `4e547b6b` (PR #180), and this branch adds `dawarich`, `homelab`, `roadtrip` and `vacay` to it, so `git merge-tree origin/main HEAD` reports `CONFLICT (modify/delete): project-dictionary.txt`. Resolve by accepting the deletion and dropping the dictionary hunk; cspell no longer exists, so the words have no home. Until the rebase, every commit on this branch fails the `spelling` pre-commit hook: the tracked `cspell.yml` is a symlink to `~/.config/cspell/cspell.yml`, which no longer exists now that the main checkout has no cspell package. This round was committed with `LEFTHOOK_EXCLUDE=spelling` for that reason alone; all other hooks ran. This also makes round 1's dictionary-order nit moot. The `project-dictionary.txt` entry in `plan.md`'s file list and the `cspell` call in step 7 are obsolete after the rebase — `project-dictionary.txt:152` → fixed (rebased onto main, dictionary change dropped; plan updated in docs: update trek-mcp plan and intent for main)
- [x] Nit: after the rebase, main's reviewer and test-writer read acceptance criteria from `intent.md` only. This folder's `intent.md` has no `## Acceptance criteria` section; the criteria live in `spec.md`. A later review round on main will report every criterion as missing unless the closer notes where they are — `docs/changes/trek-mcp/intent.md:1` → fixed (docs: update trek-mcp plan and intent for main)
- [x] Nit: the test named "no bearer token" refutes only `bearer_token_env_var`. Codex can also send a token through `http_headers` or `env_http_headers` on the same table, and either one would pass this test — `test/codex_config_test.rb:28` → fixed (Tighten TREK Codex config tests)
- [x] Nit: the approval guard is Codex only. Claude Code runs with `defaultMode: "auto"` and has no `permissions.ask` entry for `mcp__trek__delete_trip` or the other nine tools, so the same deletes are not gated there. The intent scopes approvals to Codex and fizzy has the same gap, so this is not a defect of this branch; propose it as a separate change for Claude/Codex parity — `claude/.claude/settings.json:15` → dismissed: outside this intent, which scopes approvals to Codex; fizzy has the same gap. Proposed as a separate change for Claude/Codex parity
