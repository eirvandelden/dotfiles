---
name: new-repo-setup
description: Use when creating a new personal repository or bringing an existing one up to standard — agents.md symlinks, rv, lefthook, linters, CI, dependabot, deploy config.
---

# New Repo Setup (personal projects)

Checklist, in order. Reference repo for configs: `~/Developer/journal_administration`.

1. Agent instructions: `AGENTS.md` is a symlink to `~/Developer/dotfiles/agents.md` (absolute
   path — it exists on both macOS and SteamOS); `CLAUDE.md` is a symlink to `AGENTS.md`.
   Both symlinks are committed to the repository.
2. Ruby: `.ruby-version` present; `rv` is the version manager — never mise/asdf/rbenv/rvm.
3. Git hooks: symlink the default lefthook config from `~/Developer/dotfiles`, plus a
   repo-local `lefthook-local.yml` for repo-specific tasks. Never disable hooks to get a
   commit through.
4. Linters: copy rubocop and solargraph configuration from the reference repo.
5. CI: GitHub Actions workflow running linters and the full test suite on push, based on the
   reference repo's workflows. Pre-existing rubocop offenses go into `.rubocop_todo.yml` —
   except in files created in the current PR, which must be clean.
6. Dependabot: minimal config, all ecosystems, all update types, cooldown of 1 week.
7. Dependencies: Gemfile source `gem.coop`; UI apps load `mvpa-css` from GitHub
   (see agents.md §4a for the full dependency policy).
8. i18n: Dutch, English, and Italian locales from the start; no hardcoded user-facing strings.
9. Deploy (when the app deploys): Kamal, mirroring the reference repo's setup with names and
   URLs updated.
