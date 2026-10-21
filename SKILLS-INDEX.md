# Skills Index

Topic-specific guidance that the core playbook (`agents.md`) deliberately does not repeat.

Sixteen skills are vendored from `lucianghinda/superpowers-ruby` 7.5.0 under its MIT licence; the licence text, and the CC BY-SA 4.0 notice for the Rails Guides inside `rails-guides/references/`, are in `VENDORED-LICENSES.md`. Each `SKILL.md` names its upstream path and the re-sync steps.

Claude Code loads these automatically by relevance and does not need this list. Any other agent (Codex, ChatGPT, etc.) has no automatic loader: read the matching file below before starting work that matches its trigger.

Three path forms for the same files. Inside the dotfiles repository, read the repo-local `agents/.agents/skills/...` path, the source of every skill. After stowing the `agents` package, the files are installed at `~/.agents/skills/...`, the path Codex actually reads. After stowing the `claude` package, the same files are also installed at `~/.claude/skills/...`, through links in `claude/.claude/skills/`.

## Design and architecture

- Designing a change before building it — the plan's Design section: deep modules, messages first, CRC cards, connascence, SOLID without service objects: `agents/.agents/skills/software-design/SKILL.md`
- Mermaid diagrams — class, ER, sequence and state conventions, the "before" ERD from rails-erd or `db/schema.rb`, terminal rendering with `mermaid-show`: `agents/.agents/skills/diagrams/SKILL.md`
- The domain glossary — agreed terms and words to avoid in `GLOSSARY.md` (personal) or `GLOSSARY.local.md` (work), and when a decision earns an ADR: `agents/.agents/skills/glossary/SKILL.md`
- Object-oriented design in any language — class/method responsibilities, dependency injection, composition vs inheritance, avoiding anemic models: `agents/.agents/skills/object-oriented-design/SKILL.md`
- Rails domain modeling specifically — where logic and state transitions live in an ActiveRecord app: `agents/.agents/skills/rails-architecture/SKILL.md`
- REST endpoints, JSON responses, API authentication, pagination and versioning: `agents/.agents/skills/rails-api-design/SKILL.md`
- Rails coding patterns from 37signals' Fizzy codebase: `agents/.agents/skills/37signals-style/SKILL.md`
- Sandi Metz's four rules — class and method size, parameter count, one object per controller action: `agents/.agents/skills/sandi-metz-rules/SKILL.md`

## Writing code

- Ruby method style and formatting — method shape, naming, guard clauses, visibility, doc comments and inline RBS signatures: `agents/.agents/skills/ruby-style/SKILL.md`
- Idiomatic modern Ruby — pattern matching, `Data.define`, error handling, memoization, performance idioms: `agents/.agents/skills/ruby/SKILL.md`
- The official Rails guides, for any Rails-specific topic: `agents/.agents/skills/rails-guides/SKILL.md`
- Views, Hotwire/Stimulus, CSS, HTML, forms, i18n, accessibility, dialog and UX rules: `agents/.agents/skills/rails-ui/SKILL.md`
- Hotwire forms — submission lifecycle, inline editing, validation errors, modal forms: `agents/.agents/skills/hwc-forms-validation/SKILL.md`
- Hotwire media — uploads, previews, playback, media libraries: `agents/.agents/skills/hwc-media-content/SKILL.md`
- Turbo navigation — frame pagination, tabs, lazy loading, filtering, cache and history: `agents/.agents/skills/hwc-navigation-content/SKILL.md`
- Turbo Streams over WebSocket or SSE, custom stream actions, live updates: `agents/.agents/skills/hwc-realtime-streaming/SKILL.md`
- Stimulus controller fundamentals — lifecycle, values, targets, outlets, action parameters: `agents/.agents/skills/hwc-stimulus-fundamentals/SKILL.md`
- Hotwire loading states, progress, optimistic UI, view transitions: `agents/.agents/skills/hwc-ux-feedback/SKILL.md`
- Writing and reviewing tests, fixtures vs factories, Minitest and RSpec conventions: `agents/.agents/skills/rails-testing/SKILL.md`
- Adding, removing, or upgrading a dependency — gem sources, version constraints, Dependabot: `agents/.agents/skills/dependencies/SKILL.md`
- Upgrading Rails, one major version at a time: `agents/.agents/skills/rails-upgrade/SKILL.md`
- Upgrading the Ruby interpreter of a Bundler or Rails app, including Ruby 4 risks: `agents/.agents/skills/ruby-upgrade/SKILL.md`
- Brakeman security scans — running, configuring, reducing false positives: `agents/.agents/skills/brakeman/SKILL.md`
- Finding the root cause of a bug or test failure before proposing a fix: `agents/.agents/skills/systematic-debugging/SKILL.md`
- Recording a just-verified fix as a searchable doc under `docs/solutions/`: `agents/.agents/skills/compound/SKILL.md`

## Working with git and pull requests

- Isolating a new-code task into its own git worktree instead of the main checkout: `agents/.agents/skills/worktree-first/SKILL.md`
- Copying a Rails app's SQLite development databases into a new worktree: `agents/.agents/skills/using-sqlite-worktrees/SKILL.md`
- Syncing a branch with main — fetch, rebase, conflict resolution, force-with-lease push: `agents/.agents/skills/sync/SKILL.md`
- Reviewing a pull request, or implementing review feedback: `agents/.agents/skills/code-review/SKILL.md`
- Review of the current branch before pushing — a fresh reviewer in a herdr pane, or in-session with `here`; findings land in `docs/changes/<slug>/review.md`, and a clean review hands over to delivery: `agents/.agents/skills/review/SKILL.md`. The review policy template (passes, what "Important" means, nit cap, do-not-report list) ships at `agents/.agents/skills/new-repo-setup/references/REVIEW.md`; `new-repo-setup` copies it to a personal repo's root as `REVIEW.md`.
- Ending a change once review is closed — removes `docs/changes/<slug>/`, fills the PR body, pushes, opens a draft PR and a gh-dash pane; runs on its own after a clean review: `agents/.agents/skills/deliver/SKILL.md`
- Shipping the draft PR (`/finish`) — marks it ready, waits for green CI and merges; work also sets the review board status and requests reviewers: `agents/.agents/skills/finish/SKILL.md`
- Drafting a message in Etienne's voice, where he has allowed it — greeting, context first, warm tone, unfinished work stated; drafting never authorises sending: `agents/.agents/skills/writing-as-etienne/SKILL.md`

## Mobile

- Hotwire Native apps — Swift and Kotlin shell work, path configuration, bridge components, the mobile validation matrix and build targeting: `agents/.agents/skills/hotwire-native/SKILL.md`
- iOS build, simulator and UI inspection through MobileBuildMCP tools (vendored): `agents/.agents/skills/mobilebuildmcp/SKILL.md`
- Auditing Android Intent handling and component exposure in manifests and source (vendored): `agents/.agents/skills/android-intent-security/SKILL.md`

The vendored mobile skills are pinned snapshots. `VENDORED-SKILLS.yml` records each upstream, tag, commit, licence and copied paths.

## Planning and setup

- Starting any change — interview for the problem, outcome, scope and acceptance criteria, write `docs/changes/<slug>/intent.md`: `agents/.agents/skills/intent/SKILL.md`
- Writing `plan.md` in plan mode, critiquing a plan, or executing a handed-over one: `agents/.agents/skills/plan/SKILL.md`
- Building an accepted plan — single session, split across a test-writer/implementer pair, or handed to a worker pane: `agents/.agents/skills/implement/SKILL.md`
- Setting up a new personal repository — repo context file, rv, lefthook, CI, Dependabot, deploy: `agents/.agents/skills/new-repo-setup/SKILL.md`
- Deployment, error tracking, performance monitoring: `agents/.agents/skills/rails-ops/SKILL.md`
- Working inside the dotfiles repository — stow, bootstrap, symlinks, machine setup, agent skill layout: `agents/.agents/skills/dotfiles-maintenance/SKILL.md`
