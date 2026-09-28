# Spec: Unwrap the existing dotfiles markdown

From `intent.md` (2026-09-25). Status: accepted.

## Requirements

1. **Unwrap the owned markdown.** Every tracked `.md` file in the dotfiles repository gets the `no-hardwrap` rule's unwrap fix, except the excluded files and symlinks. Each paragraph, list item and block quote ends up on one line.
2. **Exclusions stay as they are.** These files are not changed: `.clinerules/caveman.md`, `.windsurf/rules/caveman.md`, `.opencode/AGENTS.md`, `.github/copilot-instructions.md`, `claude/.claude/skills/intent/SKILL.md`, `claude/.claude/skills/rails-ui/SKILL.md`. Symlinked `.md` files are not edited; the files they point to are.
3. **Only line breaks change.** In every changed file, the sequence of words is the same as before. Only line breaks inside paragraphs, list items and block quotes, and the indentation or `> ` prefix of their continuation lines, are removed.
4. **Generated Codex agents follow their source.** `codex/.codex/agents/*.toml` is generated from `claude/.claude/agents/*.md` by `bin/generate-codex-agents`. When those agent files are unwrapped, the TOML files are regenerated in the same commit.
5. **Nothing else changes.** No file other than the unwrapped `.md` files, the regenerated agent TOML files, this change folder and the words cspell needs changes.

## Design decisions

- **One mechanical commit per area.** The unwrap is split into commits by directory: the playbook and root files, the skills, the agent files with their regenerated TOML, and the docs. Each commit is small enough to review, and a problem in one area can be reverted on its own.
- **No guard test.** Etienne chose a one-off unwrap on 2026-09-25. Later wraps only get the commit warning and the Claude edit warning from PR #160. So the acceptance criteria are checked with commands, and nothing new goes into `test/`.
- **The tool, not hand edits.** The fix is `markdownlint -c <package>/unwrap.json -r <package>/no-hardwrap.cjs --fix <files>`, run with the package in this worktree, so it works before `stow` has run on this machine.

## Integration points

- About 40 `.md` files under `agents.md`, `SKILLS-INDEX.md`, `claude/.claude/`, `codex/.codex/AGENTS.md`, `docs/`, `git/.config/git/worktree-tools/README.md`, `neovim/.config/nvim/README.md`.
- `bin/generate-codex-agents` and `codex/.codex/agents/*.toml`; the drift test `test/codex_agent_generation_test.rb`.
- Tests that read markdown files: `test/markdown_rule_mirror_test.rb`, `test/skill_parity_test.rb`.
- `project-dictionary.txt`, only if cspell rejects a word that the joined lines expose.

## Acceptance criteria

1. Running `no-hardwrap` over every tracked, non-symlinked `.md` file except the six excluded ones reports nothing.
2. The six excluded files are identical to `main`.
3. For every changed `.md` file, splitting the old and the new text on whitespace gives the same sequence of words.
4. `git diff --name-only main...HEAD` lists only `.md` files, `codex/.codex/agents/*.toml`, files in this change folder, and possibly `project-dictionary.txt`.
5. The full `test/*_test.rb` suite passes, including the Codex agent drift test.

---
Domain skills applied: dotfiles-maintenance (Codex agent generation, stow). No dependency change.
