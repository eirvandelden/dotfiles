# Plan: Use TREK from Claude Code and Codex

From `intent.md` and `spec.md` (2026-10-01). Status: accepted.

## Context

Claude Code and Codex cannot reach TREK (`https://trips.vandelden.family/mcp`). This change adds a `[mcp_servers.trek]` entry to Codex's config with OAuth login, makes the 10 most destructive TREK tools ask for approval, and documents the one-time Claude Code registration and the Codex login in `HEADROOM.md`. TREK itself (CT111, `APP_URL` from homelab-iac change `trek-app-url`) is not touched.

## Files that change

- `test/codex_config_test.rb` — new. Minitest, same shape as `test/herdr_config_test.rb`: reads `codex/.codex/config.toml` as text with regexes (Ruby has no stdlib TOML), and shells out to `codex` when it is installed. CI runs every `test/*_test.rb` with `ruby -Itest` (`.github/workflows/dotfiles-tests.yml`); CI has no `codex`, so the CLI test skips there.
- `codex/.codex/config.toml` — new `[mcp_servers.trek]` block after the fizzy block (before `[mcp_servers.node_repl]`): `url = "https://trips.vandelden.family/mcp"`, no `bearer_token_env_var`, no `scopes`, and `default_tools_approval_mode = "approve"` so every TREK tool runs without asking by default. Then one `[mcp_servers.trek.tools.<name>]` table with `approval_mode = "prompt"` per tool in the approval list below, in wiki order, same layout as the fizzy tool tables.
- `claude/.claude/HEADROOM.md` — under `## Claude`, a new `### TREK MCP server` section after `### Home MCP servers (email, fizzy)`: the `claude mcp add --scope user --transport http trek https://trips.vandelden.family/mcp` command, the rule that no Claude session may be running (a live session rewrites `~/.claude.json` and drops the change), and that login happens once through `/mcp` on TREK's consent screen. No header and no token. Under `## Codex`, a new `### TREK MCP login` section (named differently from the Claude one so markdownlint's MD024 duplicate-heading rule passes): `codex mcp login trek` once, scopes picked on the consent screen. One line per paragraph (playbook rule 26).

### Approval list (10 tools)

Deviation from the spec, on Etienne's instruction (2026-10-01): `intent.md` and `spec.md` say every TREK tool that deletes or removes something asks for approval. That is about 50 tools, too many prompts for daily use. Only these 10 ask; they destroy a whole trip, journey, collection or plan, or end other people's access, so a mistake is hard to undo. `intent.md`'s constraint was later updated to match; `spec.md` is superseded.

`delete_trip`, `bulk_delete_places`, `delete_journey`, `delete_collection`, `dissolve_vacay_plan`, `remove_trip_member`, `remove_collection_member`, `remove_journey_contributor`, `delete_trip_invite_link`, `delete_vacay_year`.

Every other TREK tool, including the other delete and remove tools, runs without asking. The names come from a summary of the TREK wiki pages MCP-Tools-and-Resources and MCP-Addon-Tools. Step 2 re-reads the raw wiki pages and corrects any name before the list is frozen in the test.

## Order of work

1. Write `test/codex_config_test.rb` with `test_trek_points_at_the_trek_url_with_no_bearer_token`. Run `ruby -Itest test/codex_config_test.rb`; watch it fail because `config.toml` has no `[mcp_servers.trek]` section (walking skeleton).
2. Re-read the raw wiki pages (the wiki git repo `https://github.com/mauriceboe/TREK.wiki.git`, cloned into the scratchpad) and confirm each of the 10 names exists exactly. Fix typos only; do not grow the list.
3. Add the remaining tests (see Proof). Run; watch them fail for the right reason.
4. Add the `[mcp_servers.trek]` block to `config.toml`. Run the test file; the URL and CLI tests pass.
5. Add the 10 tool tables. Run; all tests pass.
6. Write the two `HEADROOM.md` sections.
7. Lint: `markdownlint` on the touched files, `rubocop` and `ruby -c` on the test. Run the whole `test/*_test.rb` loop as CI does.
8. Commit in small steps (test + config; docs). Push.
9. Live check, by Etienne (needs a browser and, for Claude, no Claude session open): `codex mcp login trek`, then in Codex list trips and ask to delete a test trip — it must ask for approval (decline it). Run the HEADROOM.md Claude command from a plain shell, log in through `/mcp`, list trips. Then check each of the 10 names against Codex's live TREK tool list: a name the server lacks is renamed to its live equivalent or removed, in both the test constant and `config.toml`. Do not add tools; the list stays at 10 at most. Commit that reconciliation separately if anything changes.

## Risks

- OAuth login fails (Etienne's top risk): dynamic client registration off, or `APP_URL` wrong on CT111, breaks the consent redirect for both clients. Not fixable in this repo; the homelab-iac change `trek-app-url` owns it. If step 9 fails there, stop and report — do not fall back to the deprecated `trek_` token.
- Tool list drift: TREK renames one of the 10 tools, and Codex silently stops asking for it. The step 9 check catches it once; later drift is out of scope.
- Narrow approval: about 40 delete and remove tools (single places, days, reservations, budget items, notes) run without asking. Accepted by Etienne as the price of fewer prompts.
- Approval semantics, checked in the Codex source (`rust-v0.160.1`, `requires_mcp_tool_approval_for_mode`): `"prompt"` always asks, `"approve"` pre-approves and never asks, and the default `"auto"` asks for tools TREK marks `destructiveHint: true` (46 delete tools). The server default `"approve"` keeps the prompts to the 10 listed tools, as Etienne chose. The existing fizzy and email tables use `"approve"` and so do not ask. Codex writes exactly that value when the user picks "Always allow", so they are probably Etienne's own choices; any change there needs Etienne's say first. Step 9's delete-a-trip check proves the prompt for TREK.
- `codex mcp get --json` does not show per-tool approval, so the approval tests read the TOML text. A regex that misreads a table could pass wrongly; the tests anchor on `^[mcp_servers.trek.tools.<name>]` and read only up to the next `[`.
- Rejected: the static `trek_` token (deprecated, unrestricted); a `scopes` setting (scopes are chosen at consent); a `client_credentials` machine client (neither client can renew it); approving every write as fizzy does (intent says reads and other writes run freely); approving all ~50 delete and remove tools as the spec says (too many prompts).

## Proof

- Codex's config points `trek` at `https://trips.vandelden.family/mcp` with no bearer token or auth header → `test/codex_config_test.rb` `test_trek_points_at_the_trek_url_with_no_bearer_token`
- Codex accepts the config and shows the TREK URL → `test/codex_config_test.rb` `test_codex_accepts_the_config_and_shows_the_trek_url` (copies `config.toml` into a tmp `CODEX_HOME`, runs `codex mcp get trek --json`, asserts `transport.url`; skips when `codex` is missing)
- Deleting a trip asks for approval; so do the other 9 listed tools (narrowed from the spec's "every delete or remove tool", see Approval list) → `test/codex_config_test.rb` `test_every_listed_trek_tool_asks_for_approval`, plus step 9's manual delete-a-trip check
- After `codex mcp login trek`, Codex lists trips → manual, step 9 (needs Etienne's browser login)
- After following `HEADROOM.md`, Claude Code lists trips → manual, step 9 (needs no Claude session open)

Per changed file, the unit tests expected:

- `test/codex_config_test.rb`: `test_trek_points_at_the_trek_url_with_no_bearer_token`, `test_codex_accepts_the_config_and_shows_the_trek_url`, `test_codex_sends_no_credentials_to_trek` (reads the transport from `codex mcp get trek --json`), `test_trek_tools_run_without_asking_by_default`, `test_every_listed_trek_tool_asks_for_approval`, `test_no_other_trek_tool_asks_for_approval` (flags any table whose mode is not `"approve"`: `"prompt"`, `"auto"` and `"writes"` all ask), `test_trek_sets_no_scopes`.

Test setup: the approval list lives as a frozen constant in the test (the source of truth reviewed in step 2). The CLI test uses `Dir.mktmpdir` as `CODEX_HOME` with a copy of `config.toml`; it never touches `~/.codex`. No network.

## Out of scope

- TREK server config on CT111 (`APP_URL`, OAuth settings).
- Running `claude mcp add` from inside an agent session (it gets clobbered).
- Automatic detection of future TREK tool changes.
- Approval for non-removing writes, and for the delete and remove tools outside the 10.
