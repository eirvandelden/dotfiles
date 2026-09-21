# Phase 1: one source for shared skills, Claude ↔ Codex

Part of the change in `docs/changes/ai-native-workflow/` (read `intent.md`, `spec.md`, `plan.md` first). Repository: `~/Developer/dotfiles`. Work in a worktree (`worktree-first` skill), PR against `origin`.

## Context

Claude skills live in `claude/.claude/skills/<name>/SKILL.md`; Codex skills in `codex/.codex/skills/<name>/` with `SKILL.md` and `agents/openai.yaml`. Today `handoff` and `review` exist as hand-typed copies on both sides and have drifted; Codex `worktree-first` has only an `openai.yaml` and no `SKILL.md` in the repo. `codex/.codex/HEADROOM.md` and `codex/.codex/WORKTREES.md` are also near-copies of the Claude files.

Later phases add seven skills that must exist on both sides. This phase builds the mechanism so they are written once. The repo already does this for the playbook: `claude/.claude/PLAYBOOK.md` and `codex/.codex/PLAYBOOK.md` are relative symlinks to `agents.md`, committed as symlinks, and stow links to them file by file (`STOW_SHARED` uses `--no-folding`).

Codex facts, verified against its docs on 2026-09-18 (`learn.chatgpt.com/docs/build-skills`): `SKILL.md` needs only `name` and `description` frontmatter; "Codex supports symlinked skill folders and follows the symlink target"; skill discovery lists `$HOME/.agents/skills`, and `~/.codex/skills` is **not** on the current list. Claude facts (`code.claude.com/docs/en/skills`): skills at `~/.claude/skills/<name>/SKILL.md`; symlinks supported.

## Talk first

- **Step 0 result.** If the installed Codex no longer reads `~/.codex/skills`, the `codex` stow package cannot deliver skills and a package targeting `~/.agents/skills` is needed. That is a new top-level stow package — playbook rule 12 — so stop and ask before creating it.

## Steps

0. **Verify the Codex skill path.** Check the installed version (`codex --version`), then confirm whether `~/.codex/skills/<existing skill>` is listed by Codex (start `codex`, list skills, or use `codex exec` with a prompt that names `$handoff`). Record the finding at the top of the PR description. If `~/.codex/skills` is not scanned: stop, report, ask (see Talk first).

1. **RED — parity test.** Add `test/skill_parity_test.rb` (Minitest, same style as `test/consent_guard_test.rb`; run with `ruby -Itest test/skill_parity_test.rb`). It asserts, against repo paths (never `~`):
   - Every directory under `codex/.codex/skills/` is a symlink whose target resolves to `claude/.claude/skills/<same name>`.
   - The set of skill names is identical on both sides, minus two explicit constants `CLAUDE_ONLY` and `CODEX_ONLY` (both empty to start; adding a name needs a reason in a comment above it).
   - A skill whose Claude frontmatter has `disable-model-invocation: true` has `allow_implicit_invocation: false` in its `agents/openai.yaml`, and vice versa.
   - `codex/.codex/WORKTREES.md` resolves to `claude/.claude/WORKTREES.md`. Run it; it fails because the Codex copies are real files. That is the gap.

2. **GREEN — convert existing skills.** For each of `handoff`, `review`, `worktree-first`:
   - Diff the Codex `SKILL.md` against the Claude one. Fold any Codex-only sentence into the Claude file under a short `## Codex` heading (the Codex `worktree-first` note about `allow_implicit_invocation: false` is the known case).
   - Move `codex/.codex/skills/<name>/agents/openai.yaml` to `claude/.claude/skills/<name>/agents/openai.yaml` (Claude ignores `agents/`).
   - Replace the directory `codex/.codex/skills/<name>` with a relative symlink to `../../../claude/.claude/skills/<name>` (`git rm -r` the old files, `ln -s`, `git add`).
   - Do `worktree-first` first: it has no Codex `SKILL.md`, so it is the smallest step. Run the test after each skill. One commit per skill.

3. **GREEN — shared docs.** Merge the Codex-specific paragraph of `codex/.codex/WORKTREES.md` into `claude/.claude/WORKTREES.md` under `## Codex`, then make the Codex file a symlink. `HEADROOM.md`: the two files differ in commands, not intent; make one file with `## Claude` and `## Codex` sections in `claude/.claude/HEADROOM.md` and link the Codex side to it. Update `codex/.codex/AGENTS.md` only if a path changes (it should not — `~/.codex/HEADROOM.md` still exists after stow).

4. **REFACTOR.** `SKILLS-INDEX.md`: replace the "Two path forms" paragraph with three — repo path, `~/.claude/skills/`, `~/.codex/skills/` — and delete the "Not listed here" claim that `handoff`/`review` are Claude-only (they run in both; both spawn a Claude pane via herdr). `claude/.claude/skills/dotfiles-maintenance/SKILL.md` "Agent skills" section: describe the one-source layout in three lines.

5. **Wire the test into lefthook.** `lefthook.yml` is the global fallback used by many repos; do not add a dotfiles-only command there. Instead add `test/skill_parity_test.rb` to whatever already runs the dotfiles tests (check `.github/workflows/` for the test job and `lefthook-local.yml`). If a CI workflow needs a new line, present the diff for approval before committing (playbook rule 13).

## Files

`test/skill_parity_test.rb` (new), `claude/.claude/skills/{handoff,review,worktree-first}/`, `codex/.codex/skills/{handoff,review,worktree-first}` (become symlinks), `claude/.claude/WORKTREES.md`, `claude/.claude/HEADROOM.md`, `codex/.codex/WORKTREES.md`, `codex/.codex/HEADROOM.md` (become symlinks), `SKILLS-INDEX.md`, `claude/.claude/skills/dotfiles-maintenance/SKILL.md`.

## Verification

- `ruby -Itest test/skill_parity_test.rb` green; whole `test/` green.
- `git ls-files -s codex/.codex/skills` shows mode `120000` for each skill entry.
- `cspell`, `shellcheck`, `yamllint` on touched files (lefthook pre-commit does this).
- **Etienne, by hand, after merge:** `stow -R --no-folding codex claude` from the dotfiles root (never the agent). Then in a fresh `codex` session confirm `$handoff` is listed, and in a fresh `claude` session confirm `/handoff` is listed. Report back if either is missing.

## Out of scope

New skills (phase 2+). Codex agents (phase 3). Deleting `plan-handoff` (phase 2). Changing what `handoff`/`review` do. Touching `~/.codex/skills/.system/`, `~/.codex/superpowers/`, or anything herdr wrote. Running `stow`.
