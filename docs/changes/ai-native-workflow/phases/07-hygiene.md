# Phase 7: hygiene the inventory turned up

Part of the change on branch `ai-native-workflow`. Its documents are merged to `main` and live at `~/Developer/dotfiles/docs/changes/ai-native-workflow/` until the change finishes; read them there (read `intent.md`, `spec.md`, `plan.md` first). Repositories: `~/Developer/dotfiles` (items 1–6) and `~/Developer/dotfiles-work` (items in `work-specifics.md`). Items are independent: one worktree and PR per item, one logical change per commit. Mechanical items suit a Haiku worker; items marked **judgement** do not.

## Items

1. **Orphaned settings file.** `claude/.config/claude/settings.json` is not read by Claude Code (user settings live at `~/.claude/settings.json`; verified in `code.claude.com/docs/en/settings`). Check nothing in `install/` or `packages.conf` stows `claude/.config/`; then `git rm` it.

2. **Stray log at repo root.** `immich-go-serena-to-family-final.log` (1.4 MB) — `git rm`. Add `*.log` to the repo's `.gitignore` only if Etienne agrees (ask; one line).

3. **Codex machine state in a committed file** (**judgement**). `codex/.codex/config.toml` accumulates `[projects."<path>"] trust_level` entries and `[hooks.state]` hashes because Codex writes to the symlinked file. Investigate in the Codex config docs (`learn.chatgpt.com/docs/config-file/config-advanced`) whether trust and hook state can live in a separate layer (a project-level `.codex/config.toml`, a separate state file, or `codex exec --ignore-user-config` semantics). Report the options to Etienne with a recommendation before changing anything. Acceptable fallback: keep the entries but strip the dated `~/Documents/Codex/<date>/<slug>` scratch paths in a single commit and note the churn as known in `HEADROOM.md`.

4. **Work infrastructure text in the public repo** (**judgement**). `claude/.claude/settings.json` `autoMode.environment` and `autoMode.soft_deny` describe the employer's infrastructure. User-level settings are one file, so stow cannot split them. Move the text to a project-local `.claude/settings.local.json` delivered by the private repo's project-local stow packages into each work checkout (Claude reads `.claude/settings.local.json` at project scope, precedence above user settings — verified). The public file keeps only generic `autoMode` content. Coordinate with the work-specifics file: the private side adds the files, the public side removes the text, in that order.

5. **Lefthook hook shims regenerating gem paths.** `git/.config/git/hooks/{pre-commit,pre-push,post-merge,post-rewrite}` show as modified whenever Ruby or lefthook is bumped (hard-coded `rv` gem paths). Playbook rule 21 says never commit that churn. Investigate whether the shim can call `lefthook` via PATH or `rv ruby run -- lefthook` instead of an absolute gem path; `test/lefthook_pull_hooks_test.rb` covers the shims — extend it. **Judgement**; propose before changing.

6. **Empty handoff templates.** `docs/handoffs/_archive/*.md` with every section "to be enriched by LLM": `git rm` if tracked; otherwise list for Etienne. Phase 5 stops new ones appearing.

7. **Dangling stow symlinks in `$HOME`** — `~/.claude/skills/code-style-team/`, `~/.claude/skills/review-as-team/`, `~/.codex/skills/plan-my-day/`, and after phase 1 every remaining link under `~/.codex/skills/` (Codex does not read that directory). These are symlinks in `~`; playbook rule 12 forbids the agent deleting symlinks. Produce the exact `stow -D` / `rm` commands for Etienne, with the target each link points to, and stop.

8. **`~/.claude/plans/` leftovers.** Nine files, random names. Not written to after phase 2. List them with first lines for Etienne; suggest moving the still-relevant ones into their repo's `docs/changes/<slug>/plan.md` by hand. Do not delete.

## Verification

Per item: `test/` green; lint on touched files; for items 3–5 a written recommendation in the PR before any change. `git grep -n -i` for employer names in the public repo returns nothing after items 3 and 4.

## Out of scope

Anything herdr wrote in `~/.claude/hooks/` or `~/.codex/`. `~/.claude/plugins/`, `~/.codex/superpowers/`, sqlite state under `~/.codex/`. Running `stow`.

## Departures recorded by the executor (2026-10-01)

One branch, one commit per item, one PR, instead of one worktree per item. Etienne chose speed.

Item 1: done. Nothing in `install/` or `packages.conf` stows `claude/.config/`. The file is removed.

Item 2: the log is not tracked, so there is nothing to `git rm`. No `.gitignore` line is added. Etienne deletes the file from the main checkout by hand.

Item 4: already satisfied on the public side. The committed `claude/.claude/settings.json` has no `autoMode` key and a case-insensitive `git grep` for the employer names is empty. The text exists only in an uncommitted working tree. The private repository moves it to project-local files in parallel. No public change.

Item 5: done in #168 (`lefthook.yml` and its tests). This branch does not touch lefthook.

Item 6: done. `docs/handoffs/` is gitignored and Etienne deleted `_archive/` by hand.

Items 3, 7 and 8: report only. See the PR body. Nothing changes in `codex/.codex/config.toml`, `$HOME` or `~/.claude/plans/`.
