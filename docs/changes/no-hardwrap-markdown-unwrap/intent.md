# Intent: Unwrap the existing dotfiles markdown

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore.

## Problem

PR #160 added playbook rule 26 (one line per paragraph, list item and block quote) and the `no-hardwrap` markdownlint rule. But almost all markdown in the dotfiles repository is still hardwrapped: the playbook, the skills, the agent files. Agents copy the style of the file they are editing, so they keep seeing the wrong style. Every commit that touches one of these files also gets a `no-hardwrap` warning.

## Proposed outcome

- Every markdown file that the dotfiles repository owns has its paragraphs, list items and block quotes on one line each.
- Running `no-hardwrap` over those files reports nothing.
- No word is lost or added; only line breaks inside paragraphs change.

## Affected users and systems

- Claude and Codex sessions that read the playbook, the skills and the agent files.
- About 40 markdown files in the dotfiles repository.

## Constraints

- Use the unwrap mode of the rule from PR #160 (`markdownlint -c ~/.config/markdownlint/unwrap.json -r ~/.config/markdownlint/no-hardwrap.cjs --fix`), not hand edits.
- Leave these files as they are (decided 2026-09-25):
  - the caveman-init output: `.clinerules/caveman.md`, `.windsurf/rules/caveman.md`, `.opencode/AGENTS.md`, `.github/copilot-instructions.md`;
  - the skills adapted from upstream plugins: `claude/.claude/skills/intent/SKILL.md`, `claude/.claude/skills/rails-ui/SKILL.md`.
- Symlinked `.md` files are not edited directly; their targets are.
- `docs/changes/ai-native-workflow/` is included.
- The dotfiles repository is public: no work references.

## Open questions

None.
