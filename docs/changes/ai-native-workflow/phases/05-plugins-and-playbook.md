# Phase 5: disable process plugins, vendor domain skills, trim the playbook

Part of the change on branch `ai-native-workflow`. Its documents are merged to `main` and live at `~/Developer/dotfiles/docs/changes/ai-native-workflow/` until the change finishes; read them there (read `intent.md`, `spec.md`, `plan.md`, `habits.md` first). Repository: `~/Developer/dotfiles`. Requires phase 2 merged (the artifact skills replace what the plugins did). Work in a worktree, PR against `origin`.

## Context

Three plugins restate the playbook and load on every session start: `agile` (8.1 KB, also on every `SubagentStart`), `caveman` (5.2 KB), `superpowers-ruby` (10.1 KB `using-superpowers`, plus `PreCompact`/`PostCompact` hooks that write empty `docs/handoffs/` templates). Together with the playbook (15.4 KB) and its includes (2.9 KB) that is ~42 KB before the first prompt. Spec §5: disable all three (keep installed), keep `ruby-lsp`, `lua-lsp`, `claude-code-general`; copy the superpowers domain skills worth keeping into the dotfiles; terseness stays as playbook rule 1; talk-before-code and TDD stay as playbook §7.3/§7.17 and the `plan` skill.

Verified (2026-09-18): Claude `enabledPlugins` is `{"<plugin>@<marketplace>": true|false}`; `false` keeps it installed and stops its hooks and skills. Codex: `[plugins."<plugin>@<marketplace>"] enabled = false` — same semantics. No per-skill disable in either tool.

Current keys in `claude/.claude/settings.json`: `"caveman@caveman"`, `"agile@agile"`, `"superpowers-ruby@superpowers-ruby"`, `"ruby-lsp@claude-plugins-official"`, `"github@claude-plugins-official": false`. Codex: `[plugins."superpowers-ruby@superpowers-ruby"]`.

## Talk first

- **Which domain skills to vendor.** Present the list below with one line each on what it adds beyond the existing `rails-*`/`ruby-style` skills; Etienne picks. Candidates from `~/.claude/plugins/cache/` superpowers-ruby 7.5.0: `rails-guides`, `37signals-style`, `hwc-forms-validation`, `hwc-media-content`, `hwc-navigation-content`, `hwc-realtime-streaming`, `hwc-stimulus-fundamentals`, `hwc-ux-feedback`, `ruby`, `sandi-metz-rules`, `brakeman`, `rails-upgrade`, `ruby-upgrade`, `systematic-debugging`, `compound`. Default if undecided: `rails-guides`, `37signals-style`, `systematic-debugging`, `ruby-upgrade`, `rails-upgrade`; skip the rest.
- **Upstream licence.** Check the plugin repositories' licence files before copying; if a licence forbids redistribution in a public repo, that skill is not vendored — say so.
- **`settings.json` working-tree drift.** The committed `model` is `opusplan[1m]`; the working tree may hold something else. Ask which one is intended before touching the file; the playbook §7.24 text must match the committed value.

## Steps

1. **Baseline.** In a fresh session, run `/audit-token` and save its session-start figures into the PR description. Also `wc -c` on the always-loaded files. This is the "before".

2. **Disable, Claude.** `claude/.claude/settings.json` `enabledPlugins`: `"caveman@caveman": false`, `"agile@agile": false`, `"superpowers-ruby@superpowers-ruby": false`. Leave `extraKnownMarketplaces` untouched (re-enabling is one word). One commit.

3. **Disable, Codex.** `codex/.codex/config.toml`: `[plugins."superpowers-ruby@superpowers-ruby"] enabled = false`. One commit. Do not touch `[projects.*]` or `[hooks.state]` here (phase 7).

4. **Vendor chosen domain skills.** For each chosen skill: copy `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/<name>/` into `claude/.claude/skills/<name>/`; add a line directly under the frontmatter: `<!-- upstream: lucianghinda/superpowers-ruby@7.5.0 skills/<name> — re-sync by diffing -->`; remove any `${CLAUDE_PLUGIN_ROOT}` references or scripts that depend on the plugin layout (note what was dropped in the PR); Codex link + `openai.yaml` per phase 1. One commit per skill. `cspell` will flag vocabulary — add words to `project-dictionary.txt`, never a disable comment.

5. **Add the two agents that caveman provided.** Only if Etienne wants them: the read-only investigator is already `zubat`; a compressed-output reviewer is phase 3's `reviewer`. Default: nothing to add. Record the decision in the PR.

6. **Playbook edits** (`agents.md`):
   - §7.1: replace the caveman-lite sentence with the output style from spec §5: terseness (no filler, hedging, pleasantries) plus Simplified Technical English principles — sentences of at most 20 words, active voice, present tense, one instruction per sentence, one meaning per word, simple words, keep the articles. Two example pairs (before/after), no more. Add "no plugin enforces this; the rule is the rule". Do not paste the ASD-STE100 dictionary; the spec is licensed and a list that long costs context.
   - §7.24: name the model alias actually committed in `settings.json`; delete any claim about automatic switching that the docs do not back (the `opusplan` alias is not in public docs; describe observed behaviour or drop the sentence).
   - New section after §7, "Things agents get wrong here": the tuning rule (same mistake twice → one line; ten lines max; remove lines not repeated in three months). Seed it empty or with at most two lines Etienne dictates.
   - §5: add the vendored skills to the list and `SKILLS-INDEX.md`.
   - `WORKTREES.md`, `TOKENS.md`, `HEADROOM.md`: remove sentences now covered by skills (`TOKENS.md` "test and build output" already defers to rule 23 — check whether the file still earns its include).

7. **Clean what the hooks left.** `git rm` the empty templates under `docs/handoffs/_archive/` if tracked; if untracked, list them for Etienne to delete. Check `.gitignore` for `docs/handoffs/` and leave it.

8. **After.** Fresh session, `/audit-token` again; paste the figures next to the baseline. Target: playbook + includes only, no plugin injection, no per-subagent injection.

## Files

`claude/.claude/settings.json`, `codex/.codex/config.toml`, `claude/.claude/skills/<vendored>/`, Codex links, `agents.md`, `SKILLS-INDEX.md`, `claude/.claude/{WORKTREES,TOKENS,HEADROOM}.md`, `project-dictionary.txt`, `docs/handoffs/_archive/` (removal).

## Verification

- `test/skill_parity_test.rb` green (every vendored skill linked).
- Fresh Claude session: SessionStart output contains no AGILE/CAVEMAN/superpowers banner; `/audit-token` figures recorded. Fresh Codex session: superpowers skills not listed.
- `claude plugin list` (or the equivalent) still shows the three plugins installed.
- **Etienne, by hand, after merge:** `stow -R --no-folding claude codex`. Start the "mistake twice → one line" habit. Give it two weeks before judging whether anything is missed; re-enable with one word if so.

## Out of scope

Uninstalling plugins or marketplaces. `~/.codex/superpowers/`, `~/.claude/plugins/` contents. Codex `[projects.*]`/`[hooks.state]` churn (phase 7). Rewriting the playbook beyond the listed sections.
