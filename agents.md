# Etienne van Delden – Personal and Work Rails Playbook

Snapshot: core rules only. Detailed Rails/OOP/testing/UI/API/ops/dotfiles guidance lives in
skills — see §5 "Detailed Guidance".

## 0. How to Read This Playbook

This document is the single source of truth for the rules that must constrain almost every coding
session — for humans and AI agents alike. Read and apply every section before producing output.

- Personal: applies to personal projects.
- Work: applies to professional and Nedap projects.
- Both: applies to all projects.
- If an item differs per scope, both are listed.

Deeper, topic-specific guidance (object-oriented design, Rails architecture, testing, UI, API
design, ops, dotfiles maintenance, code review) is not repeated here — it lives in skills. Claude
Code loads those
automatically by relevance. Any other agent (Codex, ChatGPT, etc.) should read the matching file
in §5 before starting work that matches its trigger — the file exists and is meant to be opened
manually when there's no automatic skill loader.

Influences: 37signals (Rails conventions, "everything is CRUD", Hotwire/Kamal/Solid stack),
thoughtbot (testing discipline, clean Ruby — [thoughtbot/guides](https://github.com/thoughtbot/guides)),
Sandi Metz (small classes, short methods, Tell Don't Ask, Dependency Injection, Law of Demeter).

## 1. Core Principles

These apply in any language, not just Ruby/Rails — full principles and examples in the
`object-oriented-design` skill:

- Tell, Don't Ask; Dependency Injection; Composition over Inheritance; Law of Demeter.
- Default to rich objects: business logic lives on the object that owns the data, not in a
  separate service/manager layer. **Never use service objects.**
- Model actions as resources ("everything is CRUD") rather than bespoke, ad hoc procedures.

Rails/ActiveRecord-specific (full detail in `rails-architecture` skill):

- Use Rails convention/CRUD modeling. Model state transitions as nested resources, not custom
  controller actions.
- If something needs orchestration in a Rails app, prefer (in order) a model method, a concern, a
  state record, an inline ActiveJob, or a PORO for view-only presentation.
- Personal projects: prefer the Solid trifecta (Solid Queue/Cache/Cable) over Redis/Sidekiq/etc.

General engineering practice:

- Prefer incremental refactoring over rewrites — small steps, tests green, feature flags for risky
  changes.
- Prefer intention-revealing names; short names are fine in hot paths, longer names in less-used
  code.

## 2. Method Style and Formatting

- Each method does exactly one thing; if it starts doing more, extract helper methods.
- Bang methods (`!`) are unsafe (mutate the receiver or behave more dangerously) — there should
  normally be a safe non-bang variant.
- Predicate methods (`?`) must always return a boolean and never mutate or have side effects.
- Personal projects: prefer guard clause style (`return x if y`) over `if/else/end` when the line
  fits within 120 characters.
- A guard clause is followed by a blank line. No one-line method definitions, and no inline
  variable assignment inside a guard condition.
- `rescue => error`, never `rescue => e`.
- Never mutate a method's parameters — work on a copy (`dup`) when a transformation is needed.
- Keep existing methods' visibility when refactoring; new helper methods default to `private`.
- Add parentheses when a compound condition reads ambiguously.
- No `send`/metaprogramming to shortcut a proper interface.
- Documentation comments: work projects use YARD — short docs on classes always, on methods only
  when complex, never on private methods, no giant `@example` blocks. Personal projects: no doc
  comments unless a non-obvious "why" needs recording.
- Max line length ~120 characters. Keep classes under ~100 lines. Target methods at 5 lines, keep
  under 10. Pass no more than 4 parameters (hash options count as one). Blank lines between
  methods. Group related private methods together. Use explicit `private`/`protected` sections.
  Avoid abbreviations unless universal (`id`, `url`, `api`).
- Examples (guard clause, etc.): `rails-architecture` skill, `references/examples.md`.

## 3. Error Handling

- Raise errors freely when something goes wrong.
- Rescue at higher layers so users do not see raw exceptions.
- Return user friendly error pages.

## 4. Security Tooling

- Run Bundler Audit regularly and before pushes.
- Run Brakeman regularly and before pushes.
- Always use strong parameters in controllers.

## 4a. Dependencies and Versioning

- Ask before adding or removing any dependency (rule 11 in §7).
- Personal: Gemfile source is `gem.coop`, not rubygems.org.
- Do not pin gem versions by default; let them update. When a constraint is needed, use
  major.minor (`~> 9.3`) and no upper bound. Add an upper bound only when something actually
  breaks.
- Personal gems (mvpa.css etc.): reference from GitHub without a version restriction
  (`gem "mvpa-css", github: "eirvandelden/mvpa.css"`); version by git SHA, no semver tags.
- Dependabot: minimal config, all ecosystems, all update types, cooldown of 1 week.
- Node: use yarn, not npm. Prefer a gem over adding a JavaScript dependency.
- Upgrades: never skip major versions (Rails 6 → 7 → 8, step by step). Fix deprecation
  warnings as part of the work instead of leaving them.

## 5. Detailed Guidance

Claude Code loads these skills automatically by relevance. Any other agent (Codex, ChatGPT, etc.):
read the matching file below before proceeding when the task at hand matches. Inside this repo,
read the repo-local `claude/.claude/skills/...` path; after stowing the `claude` package, the same
files are installed at `~/.claude/skills/...`.

Read first:

- Object-oriented design in any language — class/method responsibilities, DI, composition vs
  inheritance, avoiding anemic models:
  `claude/.claude/skills/object-oriented-design/SKILL.md`
- Rails domain modeling specifically — where logic/state transitions live in an ActiveRecord app:
  `claude/.claude/skills/rails-architecture/SKILL.md`
- Writing/reviewing tests, fixtures vs factories, Minitest/RSpec conventions:
  `claude/.claude/skills/rails-testing/SKILL.md`
- Views, Hotwire/Stimulus, CSS, HTML, forms, i18n, accessibility, dialog/UX rules:
  `claude/.claude/skills/rails-ui/SKILL.md`
- REST endpoints, JSON responses, API auth, pagination/versioning:
  `claude/.claude/skills/rails-api-design/SKILL.md`
- Deployment, error tracking, performance monitoring:
  `claude/.claude/skills/rails-ops/SKILL.md`
- Reviewing a PR / implementing review feedback:
  `claude/.claude/skills/code-review/SKILL.md`
- Working inside the dotfiles repo (stow, bootstrap, symlinks, machine setup):
  `claude/.claude/skills/dotfiles-maintenance/SKILL.md`
- Syncing a branch with main — fetch, rebase, conflict resolution, force-with-lease push:
  `claude/.claude/skills/sync/SKILL.md`
- Setting up a new personal repo (symlinks, rv, lefthook, CI, dependabot, deploy):
  `claude/.claude/skills/new-repo-setup/SKILL.md`
- Writing a plan for another agent, reviewing a plan critically, or executing a handed-over plan:
  `claude/.claude/skills/plan-handoff/SKILL.md`
- Isolating new-code tasks into their own git worktree instead of the main checkout:
  `claude/.claude/skills/worktree-first/SKILL.md`

## 5a. Codex Skills Setup

Codex skills are stowed as part of the `codex` package. Custom skills live under `codex/.codex/skills/`.
Codex's bundled `.system/` skills are gitignored (Codex-owned, managed separately).

When adding new skills: create directory under `codex/.codex/skills/<skill-name>/` with SKILL.md and
optionally `agents/openai.yaml`. Stow handles the rest on next install.

Read Codex-specific setup details in `codex/.codex/HEADROOM.md`.

## 6. Open Questions

These areas are intentionally left open and should be decided per project.

- Front end performance budget: LCP, bundle size, Lighthouse targets.
- Authentication: web stays session-based, API stays Bearer token; external providers (Auth0 etc.)
  only when required.
- Continuous integration and delivery: GitHub Actions vs GitLab CI vs other options.
- Front end documentation: Storybook, zeroheight, or rely on code and tests.
- Onboarding: identify common blockers that prevent a new developer from opening a pull request
  within about one hour.
- Linting stack: finalise a modern HTML, CSS, and JavaScript linting setup that works without
  bundlers.
- Architecture direction: monoliths vs extracting services later.

## 7. AI Agent Workflow

The rules in sections 0–6 (plus the skills in §5) are the full ruleset. This section covers only
behaviors specific to how an AI agent should operate.

1. Keep output concise:
   - Responses brief and to the point; plans scannable but complete.
   - Never add unsolicited verbosity, caveats, or filler text.
   - Use a `lite` caveman communication style by default:
     - Drop filler, hedging, and pleasantries.
     - Keep articles and full sentences. Fragments are allowed only when they are clearly better.
     - Prefer short, direct words (`fix` over "implement a solution for", `big` over `extensive`).
     - Keep technical terms exact. Leave code blocks unchanged. Quote errors exactly.
     - Prefer the pattern: `[thing] [action] [reason]. [next step].`
     - Target tone: professional, tight, and direct.
2. Lint all generated code before finishing:
   - Run linters on every file touched.
   - Fix all issues before considering the task done.
   - NEVER add linter disable comments.
3. Test-driven development:
   - Write the test first; never generate code without a corresponding test.
   - Run tests after every change and fix failures before finishing.
   - A task is only done when all tests are green, all linters are green, and you have
     re-read your own diff and adjusted.
4. Ask for clarification when the playbook does not cover something.
5. Pull request workflow:
   - Always target `origin` (personal fork) over upstream.
   - If the target repository is ambiguous, ask before proceeding.
   - Never create PRs to an upstream project without explicit instruction.
   - Always use the repo's PR template for the PR body (check `.github/PULL_REQUEST_TEMPLATE.md`
     or similar). Mandatory on work repos; use on personal repos too if one exists.
6. GitHub identity and consent:
   - NEVER post, publish, submit, or reply to a GitHub comment as Etienne without explicit
     instruction for that exact message.
   - This includes issue comments, pull request comments, review comments, and replies.
   - Do not infer permission from approval to open a PR, push code, request review, or perform
     any other GitHub action.
   - If GitHub communication is needed, draft the proposed text in chat first and wait for
     explicit approval before posting it.
7. Branch protection:
   - NEVER commit directly to `main` or `master`.
   - Always create a feature branch; merge via pull request.
   - New code goes in its own git worktree under `.worktrees/`, not the main checkout —
     `worktree-first` skill. Never `git checkout -b`/`git switch -c` a feature branch in the
     main checkout as a substitute; the main checkout stays on whatever branch it's already on.
8. Hands off system tooling:
   - NEVER install, uninstall, upgrade, or switch Ruby versions, version managers, or other
     system-level tools without explicit instruction.
   - The Ruby version manager is `rv`. Do not assume or use any other version manager (mise, asdf,
     rbenv, rvm, chruby, etc.).
   - Do not run commands that modify the system environment (e.g. `brew uninstall`, `rm` on
     toolchain paths, `mise use`, `asdf install`, etc.) unless the user explicitly asks for it.
   - If a Ruby version or tool appears to be missing or broken, report the problem and ask
     for instructions. Do not attempt to fix it autonomously.
   - This rule extends to all language runtimes, package managers, and system dependencies —
     not just Ruby.
9. Database safety:
   - NEVER run destructive database commands (`db:drop`, `db:reset`, `db:schema:load`,
     `db:migrate:down` on unknown migrations) without explicit instruction.
   - NEVER write migrations that drop tables or remove columns without explicit instruction.
   - NEVER run `db:migrate` against a production database.
   - Prefer `db:migrate:status` to check migration state before running migrations.
10. Secrets and credentials:
    - NEVER read, print, log, or output the contents of `.env`, `.env.*`,
      `credentials.yml.enc`, `master.key`, or any file likely containing secrets.
    - NEVER commit files containing secrets. If creating `.env` files, use placeholder values.
    - NEVER hardcode secrets, API keys, tokens, or passwords in source code.
      Use `Rails.application.credentials` or environment variables.
    - If a secret is accidentally printed in output, warn immediately to rotate it.
11. Dependency management:
    - NEVER add or remove gems, npm packages, or other dependencies without asking for approval
      first. The request must explain why the dependency is needed and what it does.
    - NEVER run `bundle update` (all gems) without explicit instruction. Prefer
      `bundle update <specific-gem>`.
12. Symlinks and dotfiles:
    - NEVER overwrite, delete, or modify symlinks directly. When editing dotfiles, always edit
      the source file in `~/Developer/dotfiles/<package>/`, never the symlinked target in `~/`
      or `~/.config/`.
    - NEVER run `stow` or `stow -R` without explicit instruction.
    - NEVER create new stow packages (top-level directories in the dotfiles repo) without
      explicit instruction.
    - Full dotfiles environment/bootstrap detail: `dotfiles-maintenance` skill.
13. Deployment and infrastructure:
    - NEVER run deploy commands (`kamal deploy`, `kamal app exec`, `cap deploy`, etc.)
      without explicit approval.
    - NEVER modify deployment configuration (`deploy.yml`, `deploy.rb`, `Dockerfile`,
      `docker-compose.yml`, `.github/workflows/`, `.gitlab-ci.yml`) without explicit approval.
    - Treat `config/environments/production.rb` as a high-risk file. Always ask before
      modifying it.
14. Error recovery:
    - If a change breaks tests, fix what you introduced rather than modifying the test to pass.
    - NEVER delete or skip failing tests to make a suite pass.
    - If stuck after 3 failed attempts at the same problem, stop and explain the situation
      rather than continuing to make speculative changes.
15. Project scope awareness:
    - Before starting work, identify whether this is a personal or work project. The rules
      differ (Minitest vs. RSpec, fixtures vs. FactoryBot, i18n vs. gettext, etc.).
    - NEVER copy code, configuration, or credentials between personal and work projects.
16. Code review workflow:
    - When asked to review work: first look for an `agents.md` file in the project root;
      if none exists, fall back to `~/Developer/dotfiles/agents.md`. Combine the rules found
      there with any existing review criteria rather than replacing them.
    - Full apply-fixes / re-review workflow: `code-review` skill.
17. Plan before implementing:
    - NEVER start writing or modifying code without first presenting a plan to the user
      and receiving explicit approval to proceed.
    - The plan must describe what will be changed and why, at a level of detail sufficient
      for the user to evaluate it.
    - If a task seems trivial (e.g. a single-character typo fix), still state the intended
      change and wait for a go-ahead before touching files.
18. Commits:
    - Agents may create commits without asking first.
    - Each commit must be small and contain exactly one logical change. Split unrelated
      concerns into separate commits.
    - Still governed by rule 7 (never commit to `main`/`master`) and rule 21 (commit scope
      hygiene).
19. Pushes:
    - Agents may push without asking to repos owned by the `eirvandelden` GitHub user, and
      to `nedap/caren3` and `nedap/ons-client`.
    - Pushing to any other remote or repository requires explicit permission first.
    - Force-push rules (rule 20: `--force-with-lease` only, never plain `--force`) still
      apply regardless of target repo.
20. Branch sync (rebase workflow):
    - When starting work on an existing branch and before any approved push or PR update,
      fetch the latest main and rebase the feature branch on top of it. Rebase, never merge
      main into the branch.
    - Stacked branches: rebase onto the explicitly named base branch and target the PR at it.
    - Resolve each conflicted file on its own merits; never blindly discard one side.
    - After a rebase, push with `--force-with-lease` only. NEVER use plain `--force`.
    - Full workflow: `sync` skill (`claude/.claude/skills/sync/SKILL.md`).
21. Commit scope hygiene:
    - Before committing, re-read the full diff. Every hunk must be required by the task.
      Revert unrelated changes: whitespace, quote style, comments, renamed test strings,
      lint configs, `.github/` files.
    - NEVER commit personal or machine-local setup files (`.pumadev`, local `database.yml`,
      local `.rubocop.yml` tweaks, editor configs). If such a file is already tracked and
      shows up as modified, leave it out of the commit and mention it.
    - Orthogonal improvements discovered while working: propose them for a separate
      branch/PR. Never bundle them into the current one.
22. Verify, don't assume:
    - Verify claims by exercising the change (run the command, hit the endpoint, load the
      page) before reporting done — "should work" is not verified.
    - Never invent data, names, or content. When real data is needed, ask for it or read it
      from the source.
    - Don't assume CLI flags or API behaviour from memory — check the documentation.
    - Conductor: before editing, verify the working directory is the assigned workspace
      (`pwd`), not another checkout of the same repository.
    - When re-checking an earlier fix, confirm it holds in the originally failing scenario
      before closing the loop.
23. Test output hygiene:
    - Run the narrowest thing first: a single test file or example, then the full suite only
      once that is green.
    - Trim verbose suite output instead of dumping it whole: pipe through `tail` or use the
      runner's fail-fast flag.
    - NEVER re-run an identical failing command more than twice. Change it instead — narrower
      scope, more diagnostics, a different flag.

Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the), filler (just/really/basically), pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: [thing] [action] [reason]. [next step].
- Not: "Sure! I'd be happy to help you with that."
- Yes: "Bug in auth middleware. Fix:"

Switch level: /caveman lite|full|ultra|wenyan
Stop: "stop caveman" or "normal mode"

Auto-Clarity: drop caveman for security warnings, irreversible actions, user confused. Resume after.

Boundaries: code/commits/PRs written normal.
