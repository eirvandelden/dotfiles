# Skills Index

Topic-specific guidance that the core playbook (`agents.md`) deliberately does not repeat.

Claude Code loads these automatically by relevance and does not need this list. Any other agent
(Codex, ChatGPT, etc.) has no automatic loader: read the matching file below before starting work
that matches its trigger.

Three path forms for the same files. Inside the dotfiles repository, read the repo-local
`claude/.claude/skills/...` path. After stowing the `claude` package, the same files are installed
at `~/.claude/skills/...`. A skill shared with Codex also appears at `~/.agents/skills/...` after
stowing the `agents` package — the path Codex actually reads.

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
- Report-only review of the current branch before pushing — a fresh reviewer in a herdr pane, or
  in-session with `here`; findings land in `docs/changes/<slug>/review.md`:
  `claude/.claude/skills/review/SKILL.md`. The review policy template (passes, what "Important"
  means, nit cap, do-not-report list) ships at
  `claude/.claude/skills/new-repo-setup/references/REVIEW.md`; `new-repo-setup` copies it to a
  personal repo's root as `REVIEW.md`.
- Closing a change once review is fresh — deletes `docs/changes/<slug>/`, fills the PR body,
  pushes, and creates or updates the PR, in both scopes; work also asks about an ADR and
  requests reviewers: `claude/.claude/skills/finish/SKILL.md`

## Planning and setup

- Starting any change — interview for the problem and proposed outcome, write
  `docs/changes/<slug>/intent.md`: `claude/.claude/skills/intent/SKILL.md`
- Turning an accepted intent into requirements and testable acceptance criteria:
  `claude/.claude/skills/spec/SKILL.md`
- Writing `plan.md` in plan mode, critiquing a plan, or executing a handed-over one:
  `claude/.claude/skills/plan/SKILL.md`
- Building an accepted plan — single session, split across a test-writer/implementer pair, or
  handed to a worker pane: `claude/.claude/skills/implement/SKILL.md`
- Setting up a new personal repository — repo context file, rv, lefthook, CI, Dependabot, deploy:
  `claude/.claude/skills/new-repo-setup/SKILL.md`
- Deployment, error tracking, performance monitoring:
  `claude/.claude/skills/rails-ops/SKILL.md`
- Working inside the dotfiles repository — stow, bootstrap, symlinks, machine setup, agent skill
  layout: `claude/.claude/skills/dotfiles-maintenance/SKILL.md`
