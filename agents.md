# Etienne van Delden – Personal and Work Rails Playbook

Core rules only. Topic-specific guidance lives in skills — see §5.

## 0. How to Read This Playbook

Single source of truth for the rules that constrain almost every coding session, for humans and
agents alike. Read and apply every section before producing output.

Scope labels: **Personal** for personal projects, **Work** for professional projects,
**Both** for all of them. Where an item differs per scope, both are listed.

Influences: 37signals (Rails conventions, "everything is CRUD", Hotwire/Kamal/Solid stack),
thoughtbot (testing discipline, clean Ruby — [thoughtbot/guides](https://github.com/thoughtbot/guides)),
Sandi Metz (small classes, short methods, Tell Don't Ask, Dependency Injection, Law of Demeter).

## 1. Core Principles

Any language, not just Ruby/Rails — full principles and examples in the
`object-oriented-design` skill:

- Tell, Don't Ask; Dependency Injection; Composition over Inheritance; Law of Demeter.
- Business logic lives on the object that owns the data, never in a separate service/manager
  layer. **Never use service objects.**
- Model actions as resources ("everything is CRUD"), not bespoke procedures.

Rails/ActiveRecord — full detail in the `rails-architecture` skill:

- Rails convention/CRUD modeling. State transitions are nested resources, not custom controller
  actions.
- Orchestration goes, in order of preference: model method, concern, state record, inline
  ActiveJob, PORO for view-only presentation.
- Personal: prefer the Solid trifecta (Queue/Cache/Cable) over Redis/Sidekiq.

Refactor incrementally rather than rewriting — small steps, tests green, feature flags for risky
changes. Prefer intention-revealing names; short names are fine in hot paths.

## 2. Method Style and Formatting

Full rules — method shape, naming, guard clauses, visibility, doc comments — in the `ruby-style`
skill. Enforced mechanically by the `rubocop-eirvandelden` gem.

- Each method does exactly one thing; extract helper methods when it grows.
- `rescue => error`, never `rescue => e`. Never mutate a method's parameters.
- No `send`/metaprogramming to shortcut a proper interface.
- Target methods at 5 lines (under 10), classes under ~100 lines, at most 4 parameters, lines
  under ~120 characters.

## 3. Error Handling

- Raise errors freely when something goes wrong.
- Rescue at higher layers so users do not see raw exceptions.
- Return user friendly error pages.

## 4. Security Tooling

- Run Bundler Audit regularly and before pushes.
- Run Brakeman regularly and before pushes.
- Always use strong parameters in controllers.

## 4a. Dependencies and Versioning

Full policy — sources, constraint style, personal gems, Dependabot, upgrade steps — in the
`dependencies` skill.

- Ask before adding or removing any dependency (rule 11 in §7).
- Never skip major versions when upgrading (Rails 6 → 7 → 8, step by step).

## 5. Detailed Guidance

Topic-specific guidance — object-oriented design, Rails architecture, Ruby style, testing, UI,
API design, dependencies, ops, git workflow, code review, dotfiles — is not repeated here.

Claude Code loads those skills automatically by relevance. Any other agent has no loader and
should read the index, then the matching skill file: `SKILLS-INDEX.md`.

## 6. Open Questions

Undecided areas, to be settled per project: `docs/open-questions.md`.

## 7. AI Agent Workflow

The rules in sections 0–6 (plus the skills in §5) are the full ruleset. This section covers only
behaviors specific to how an AI agent should operate.

1. Keep output concise:
   - Brief and to the point; plans scannable but complete. Never add unsolicited verbosity,
     caveats, or filler.
   - Default to a `lite` caveman style: drop filler, hedging, and pleasantries; keep articles and
     full sentences; prefer short direct words; keep technical terms, code blocks, and error text
     exact. Pattern: `[thing] [action] [reason]. [next step].`
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
   - New code goes in its own git worktree under `.worktrees/`, never the main checkout and
     never a feature branch checked out in it — `worktree-first` skill, `WORKTREES.md`.
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
    - NEVER write or modify code before presenting a plan and receiving explicit approval. The
      plan says what will change and why, in enough detail for the user to evaluate it.
    - Trivial tasks included: state the intended change and wait for a go-ahead.
18. Commits:
    - Agents may create commits without asking first.
    - Each commit must be small and contain exactly one logical change. Split unrelated
      concerns into separate commits.
    - Still governed by rule 7 (never commit to `main`/`master`) and rule 21 (commit scope
      hygiene).
19. Pushes:
    - Agents may push without asking to repos owned by the `eirvandelden` GitHub user, and
      to any remote listed in `~/.claude/consent-guard-allowed-remotes.txt` (supplied by
      `dotfiles-work`; the same file the consent guard reads).
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
23. Test runs and output:
    - Run the narrowest thing first — one file or example — then the full suite once that is green.
    - Stop at the first failure instead of dumping output: `-f`/`--fail-fast` (Minitest, RSpec),
      `--bail` (Jest), `-x --tb=short` (pytest). `tail -20` is a fallback and needs
      `set -o pipefail`, or it reports `tail`'s exit status instead of the runner's.
    - NEVER re-run an identical failing command more than twice; change it — narrower scope, more
      diagnostics, a different flag. (Rule 14 caps the whole stuck problem at 3 attempts.)
24. Model selection:
    - Claude Code: Opus for planning and research, Sonnet for implementing. The `opusplan`
      alias does the switch automatically — Opus while in plan mode, Sonnet once execution
      starts — so `claude/.claude/settings.json` sets `"model": "opusplan[1m]"` and no manual
      switch is needed. Pick a plain `opus` or `sonnet` session only when a task is entirely
      research or entirely mechanical.
    - Codex: Terra for planning and research, Luna for implementing. Luna is the base default
      in `codex/.codex/config.toml`; start a planning session with `codex -p terra`, which
      layers `~/.codex/terra.config.toml` over that base.
    - Haiku belongs in subagents, never in the main session. Delegate to it for direct commands
      that need no interpretation — running a known command, listing files, a mechanical rename,
      a fixed-format lookup. Pass `model: "haiku"` on the individual Agent call rather than
      setting `CLAUDE_CODE_SUBAGENT_MODEL`, so only the mechanical calls drop down a tier.
    - Anything requiring judgement — reading a diff for correctness, choosing between designs,
      writing tests — stays on Opus or Sonnet.
