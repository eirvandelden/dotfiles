# Intent: Stop agents hardwrapping markdown

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore.

## Problem

Claude and Codex keep writing markdown with each paragraph split over many lines at about 80–100 characters. Etienne wants one line per paragraph so the renderer or editor does the wrapping. Three things cause it:

- The rule lives only in Claude's project memory for the dotfiles repository. Codex never sees it, and Claude does not see it in any other repository.
- Almost all markdown in the dotfiles repository (the playbook, the skills, the intent/spec/plan templates) is itself hardwrapped. Agents copy the style of the file they are editing.
- Nothing tells an agent when it hardwraps. The installed markdownlint (0.48) has no configuration, so its default line-length rule (MD013, 80 characters) reports every unwrapped paragraph as an error. Linting pushes agents toward wrapping.

## Proposed outcome

- Every agent, in every repository, knows the rule: markdown prose is one line per paragraph.
- The rule survives context compaction in Claude sessions.
- The markdown in the dotfiles repository follows the rule, so it no longer shows agents the wrong style.
- Linting markdown no longer reports long paragraph lines as errors.
- When a hardwrapped paragraph is written, the agent is told at once, when it edits the file, and again when it commits. The commit still goes through.

## Affected users and systems

- Claude Code and Codex sessions, in every repository.
- The shared playbook (`agents.md`) and `core-values.yml`.
- Markdown files in the dotfiles repository.
- markdownlint, globally.
- The shared lefthook pre-commit config (`lefthook.yml`), used by every repository.
- Claude Code hooks (`settings.json`).
- The `no-hardwrap-markdown` memory file, which becomes redundant.

## Constraints

- Commit check warns only; it never blocks a commit.
- Unwrapping the existing markdown is a separate pull request from the rule and tooling.
- No new dependencies without approval. markdownlint-cli is already installed.
- A new stow package for the markdownlint config needs Etienne's explicit go-ahead (playbook rule 12).
- The dotfiles repository is public: no work references.
- Lists, tables, code blocks, headings, block quotes and front matter keep their own line structure; only paragraph prose is joined.

## Open questions

None. The commit check goes in the dotfiles `lefthook.yml`. That file is already the default lefthook config for every repository without its own (`new-repo-setup` skill, step 3), so the check reaches every repository the same way the other default hooks do.
