# Skills Index

Topic-specific guidance that the core playbook (`agents.md`) deliberately does not repeat.

Sixteen skills are vendored from `lucianghinda/superpowers-ruby` 7.5.0 under its MIT licence; the licence text, and the CC BY-SA 4.0 notice for the Rails Guides inside `rails-guides/references/`, are in `VENDORED-LICENSES.md`. Each `SKILL.md` names its upstream path and the re-sync steps.

Claude Code loads these automatically by relevance and does not need this list. Any other agent (Codex, ChatGPT, etc.) has no automatic loader: read the matching file below before starting work that matches its trigger.

Three path forms for the same files. Inside the dotfiles repository, read the repo-local `claude/.claude/skills/...` path. After stowing the `claude` package, the same files are installed at `~/.claude/skills/...`. A skill shared with Codex also appears at `~/.agents/skills/...` after stowing the `agents` package — the path Codex actually reads.

## Design and architecture

- Object-oriented design in any language — class/method responsibilities, dependency injection, composition vs inheritance, avoiding anemic models: `claude/.claude/skills/object-oriented-design/SKILL.md`
- Rails domain modeling specifically — where logic and state transitions live in an ActiveRecord app: `claude/.claude/skills/rails-architecture/SKILL.md`
- REST endpoints, JSON responses, API authentication, pagination and versioning: `claude/.claude/skills/rails-api-design/SKILL.md`
- Rails coding patterns from 37signals' Fizzy codebase: `claude/.claude/skills/37signals-style/SKILL.md`
- Sandi Metz's four rules — class and method size, parameter count, one object per controller action: `claude/.claude/skills/sandi-metz-rules/SKILL.md`

## Writing code

- Ruby method style and formatting — method shape, naming, guard clauses, visibility, doc comments: `claude/.claude/skills/ruby-style/SKILL.md`
- Idiomatic modern Ruby — pattern matching, `Data.define`, error handling, memoization, performance idioms: `claude/.claude/skills/ruby/SKILL.md`
- The official Rails guides, for any Rails-specific topic: `claude/.claude/skills/rails-guides/SKILL.md`
- Views, Hotwire/Stimulus, CSS, HTML, forms, i18n, accessibility, dialog and UX rules: `claude/.claude/skills/rails-ui/SKILL.md`
- Hotwire forms — submission lifecycle, inline editing, validation errors, modal forms: `claude/.claude/skills/hwc-forms-validation/SKILL.md`
- Hotwire media — uploads, previews, playback, media libraries: `claude/.claude/skills/hwc-media-content/SKILL.md`
- Turbo navigation — frame pagination, tabs, lazy loading, filtering, cache and history: `claude/.claude/skills/hwc-navigation-content/SKILL.md`
- Turbo Streams over WebSocket or SSE, custom stream actions, live updates: `claude/.claude/skills/hwc-realtime-streaming/SKILL.md`
- Stimulus controller fundamentals — lifecycle, values, targets, outlets, action parameters: `claude/.claude/skills/hwc-stimulus-fundamentals/SKILL.md`
- Hotwire loading states, progress, optimistic UI, view transitions: `claude/.claude/skills/hwc-ux-feedback/SKILL.md`
- Writing and reviewing tests, fixtures vs factories, Minitest and RSpec conventions: `claude/.claude/skills/rails-testing/SKILL.md`
- Adding, removing, or upgrading a dependency — gem sources, version constraints, Dependabot: `claude/.claude/skills/dependencies/SKILL.md`
- Upgrading Rails, one major version at a time: `claude/.claude/skills/rails-upgrade/SKILL.md`
- Upgrading the Ruby interpreter of a Bundler or Rails app, including Ruby 4 risks: `claude/.claude/skills/ruby-upgrade/SKILL.md`
- Brakeman security scans — running, configuring, reducing false positives: `claude/.claude/skills/brakeman/SKILL.md`
- Finding the root cause of a bug or test failure before proposing a fix: `claude/.claude/skills/systematic-debugging/SKILL.md`
- Recording a just-verified fix as a searchable doc under `docs/solutions/`: `claude/.claude/skills/compound/SKILL.md`

## Working with git and pull requests

- Isolating a new-code task into its own git worktree instead of the main checkout: `claude/.claude/skills/worktree-first/SKILL.md`
- Copying a Rails app's SQLite development databases into a new worktree: `claude/.claude/skills/using-sqlite-worktrees/SKILL.md`
- Syncing a branch with main — fetch, rebase, conflict resolution, force-with-lease push: `claude/.claude/skills/sync/SKILL.md`
- Reviewing a pull request, or implementing review feedback: `claude/.claude/skills/code-review/SKILL.md`
- Report-only review of the current branch before pushing — a fresh reviewer in a herdr pane, or in-session with `here`; findings land in `docs/changes/<slug>/review.md`: `claude/.claude/skills/review/SKILL.md`. The review policy template (passes, what "Important" means, nit cap, do-not-report list) ships at `claude/.claude/skills/new-repo-setup/references/REVIEW.md`; `new-repo-setup` copies it to a personal repo's root as `REVIEW.md`.
- Closing a change once review is fresh — deletes `docs/changes/<slug>/`, fills the PR body, pushes, and creates or updates the PR, in both scopes; work also asks about an ADR and requests reviewers: `claude/.claude/skills/finish/SKILL.md`

## Mobile

- Hotwire Native apps — Swift and Kotlin shell work, path configuration, bridge components, the mobile validation matrix and build targeting: `claude/.claude/skills/hotwire-native/SKILL.md`
- iOS build, simulator and UI inspection through MobileBuildMCP tools (vendored): `claude/.claude/skills/mobilebuildmcp/SKILL.md`
- Auditing Android Intent handling and component exposure in manifests and source (vendored): `claude/.claude/skills/android-intent-security/SKILL.md`

The vendored mobile skills are pinned snapshots. `VENDORED-SKILLS.yml` records each upstream, tag, commit, licence and copied paths.

## Planning and setup

- Starting any change — interview for the problem, outcome, scope and acceptance criteria, write `docs/changes/<slug>/intent.md`: `claude/.claude/skills/intent/SKILL.md`
- Writing `plan.md` in plan mode, critiquing a plan, or executing a handed-over one: `claude/.claude/skills/plan/SKILL.md`
- Building an accepted plan — single session, split across a test-writer/implementer pair, or handed to a worker pane: `claude/.claude/skills/implement/SKILL.md`
- Setting up a new personal repository — repo context file, rv, lefthook, CI, Dependabot, deploy: `claude/.claude/skills/new-repo-setup/SKILL.md`
- Deployment, error tracking, performance monitoring: `claude/.claude/skills/rails-ops/SKILL.md`
- Working inside the dotfiles repository — stow, bootstrap, symlinks, machine setup, agent skill layout: `claude/.claude/skills/dotfiles-maintenance/SKILL.md`
