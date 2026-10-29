# Intent: Drop headroom

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-29). Type: chore. Delivery: autonomous. Codex review: yes.

## Problem

The `headroom` command fails on every call: its uv venv symlinks to Homebrew's `python@3.13`, which the Python cleanup removed. Two Claude hooks run `headroom init hook ensure` at every session start and now fail each time. Headroom was never worth much here: in its only recorded window (2026-10-09 to 2026-10-12) it saved 43,600 tokens, about $0.004, all on Codex/OpenAI and none on Claude.

## Proposed outcome

Nothing in the dotfiles installs, calls or documents headroom. The MCP registration notes and the Codex daemon warning that live in the same files survive under a new name.

## Affected users and systems

- Etienne's Claude and Codex sessions, through `claude/.claude/settings.json`, `claude/.claude/CLAUDE.md` and `codex/.codex/AGENTS.md`.
- `packages.conf` (`UV_TOOLS`) and the `dotfiles-maintenance` skill.
- Four tests that read the headroom docs or name headroom.

## Constraints

- Removing a dependency needs approval (rule 11). Etienne approved it in this session: "lets drop it".
- `semble` shares the broken Python but is a separate decision. Its registration note stays in the renamed Claude doc.
- Etienne runs `uv tool uninstall headroom-ai` himself. The change does not touch system tooling (rule 8).
- Etienne also restows afterwards (`stow -R -t "$HOME"` for the `claude` and `codex` packages). The renamed docs leave dangling `~/.claude/HEADROOM.md` and `~/.codex/HEADROOM.md` links until then. The change never runs stow (rule 12).
- The main checkout has uncommitted edits to `claude/.claude/settings.json`. The worktree starts from `origin/main`, so the hook removal may conflict with them.
- No gem, migration or deploy permission is needed.

## In scope

- Remove `headroom-ai[all]` from `UV_TOOLS` in `packages.conf`.
- Remove both `headroom init hook ensure` hooks from `claude/.claude/settings.json`.
- Rename `claude/.claude/HEADROOM.md` to `claude/.claude/MCP.md`. Drop the Launch and Meta-commands sections and the headroom wording. Keep the semble, email, fizzy, homeassistant, journal and TREK registrations.
- Rename `codex/.codex/HEADROOM.md` to `codex/.codex/MCP.md`. Drop the headroom launch and meta-commands sections. Keep the daemon warning and the TREK login. Reword the paragraph about `headroom wrap codex`.
- Point `claude/.claude/CLAUDE.md`, `codex/.codex/AGENTS.md` and the `dotfiles-maintenance` skill at the new file names.
- Point `test/home_assistant_mcp_test.rb` and `test/journal_mcp_test.rb` at `MCP.md`, and rename their `headroom` helpers and test names.
- Rename the headroom wording in `test/codex_unlock_test.rb` and `test/codex_unlocked_shim_test.rb`. The shim `zsh/.config/zsh/unlocked-bin/codex` itself stays: it handles every `codex` call, not only headroom's.

## Out of scope

- `semble` (uninstall, reinstall or registration).
- Running `uv tool uninstall headroom-ai` and stow (Etienne does both).
- `~/.headroom` data and any other file outside the repository.
- Any change to the shim's behaviour.

## Acceptance criteria

- `git grep -i headroom` in the repository finds nothing, apart from the change folder's own documents before delivery.
- Starting Claude no longer runs a headroom hook.
- `packages.conf` installs `semble[mcp]` and no longer lists `headroom-ai[all]`.
- The Home Assistant and journal tests still pass: each finds its `claude mcp add` command and its unlock note in `claude/.claude/MCP.md`.
- A Codex session after `unlock` still runs with `--no-daemon` and the unlocked secrets, as `test/codex_unlock_test.rb` and `test/codex_unlocked_shim_test.rb` check.
- `codex/.codex/MCP.md` still warns never to start the background server from an unlocked session.
- The full test suite and the linters are green.

## Decisions

- Rename `claude/.claude/HEADROOM.md` to `MCP.md` instead of deleting it — two tests read the MCP registration notes in it, and the content is worth keeping.
- Rename `codex/.codex/HEADROOM.md` to `MCP.md` — the daemon warning and TREK login live there; Etienne chose "rename to MCP.md".
- Deliver autonomously — Etienne chose it; the change touches hooks and config but needs no extra permission.
- Review with Codex as well as Claude — Etienne chose "Add a Codex review".
- Drop headroom completely — "lets drop it", after the savings figures showed 43.6k tokens, $0.004 and no Claude usage.

## Open questions

None.
