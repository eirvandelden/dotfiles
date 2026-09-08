# Skills Index

Topic-specific guidance that the core playbook (`agents.md`) deliberately does not repeat.

Claude Code loads these automatically by relevance and does not need this list. Any other agent
(Codex, ChatGPT, etc.) has no automatic loader: read the matching file below before starting work
that matches its trigger.

Two path forms for the same files. Inside the dotfiles repository, read the repo-local
`claude/.claude/skills/...` path. After stowing the `claude` package, the same files are installed
at `~/.claude/skills/...`.

## Design and architecture

- Object-oriented design in any language — class/method responsibilities, dependency injection,
  composition vs inheritance, avoiding anemic models:
  `claude/.claude/skills/object-oriented-design/SKILL.md`
- Rails domain modeling specifically — where logic and state transitions live in an ActiveRecord
  app: `claude/.claude/skills/rails-architecture/SKILL.md`
- REST endpoints, JSON responses, API authentication, pagination and versioning:
  `claude/.claude/skills/rails-api-design/SKILL.md`

## Writing code

- Ruby method style and formatting — method shape, naming, guard clauses, visibility, doc
  comments: `claude/.claude/skills/ruby-style/SKILL.md`
- Views, Hotwire/Stimulus, CSS, HTML, forms, i18n, accessibility, dialog and UX rules:
  `claude/.claude/skills/rails-ui/SKILL.md`
- Writing and reviewing tests, fixtures vs factories, Minitest and RSpec conventions:
  `claude/.claude/skills/rails-testing/SKILL.md`
- Adding, removing, or upgrading a dependency — gem sources, version constraints, Dependabot:
  `claude/.claude/skills/dependencies/SKILL.md`

## Working with git and pull requests

- Isolating a new-code task into its own git worktree instead of the main checkout:
  `claude/.claude/skills/worktree-first/SKILL.md`
- Syncing a branch with main — fetch, rebase, conflict resolution, force-with-lease push:
  `claude/.claude/skills/sync/SKILL.md`
- Reviewing a pull request, or implementing review feedback:
  `claude/.claude/skills/code-review/SKILL.md`

## Planning and setup

- Writing a plan for another agent, reviewing a plan critically, or executing a handed-over plan:
  `claude/.claude/skills/plan-handoff/SKILL.md`
- Setting up a new personal repository — repo context file, rv, lefthook, CI, Dependabot, deploy:
  `claude/.claude/skills/new-repo-setup/SKILL.md`
- Deployment, error tracking, performance monitoring:
  `claude/.claude/skills/rails-ops/SKILL.md`
- Working inside the dotfiles repository — stow, bootstrap, symlinks, machine setup, agent skill
  layout: `claude/.claude/skills/dotfiles-maintenance/SKILL.md`

## Not listed here

`handoff` and `review` are Claude-only slash commands that drive Herdr panes. They cannot be used
by an agent without Herdr, and they are never model-invoked.
