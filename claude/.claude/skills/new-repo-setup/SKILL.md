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
3. Git hooks: no lefthook files needed in a new repo. Global `core.hooksPath` scripts
   automatically set `LEFTHOOK_CONFIG` to `~/Developer/dotfiles/lefthook.yml` when the repo has
   no own config — pre-commit, pre-push, and pull hooks fire everywhere with zero setup.
   Add a `lefthook-local.yml` only for repo-specific tasks on top of the defaults. A repo with
   its own `lefthook.yml` opts back into defaults with:
   `extends: ["${HOME}/Developer/dotfiles/lefthook.yml"]`.
   Never run `lefthook install` (restow `git` package to repair hook scripts if needed).
   Never disable hooks to get a commit through.
4. Linters: RuboCop rules come from the `rubocop-eirvandelden` gem — never copy the rules into
   the repo. Add to the `:development` group:
   `gem "rubocop-eirvandelden", github: "eirvandelden/rubocop-eirvandelden", require: false`
   Then name the layers the project needs in `.rubocop.yml`:

   ```yaml
   inherit_gem:
     rubocop-eirvandelden:
       - config/default.yml    # always
       - config/rails.yml      # a Rails app or engine
       - config/rspec.yml      # the tests are specs
       - config/capybara.yml   # the tests drive a browser (also add rubocop-capybara)
   ```

   The layers stack rather than inherit, so name every one that applies. A Rails app that
   leaves out `config/rails.yml` loses its Rails cops with no error at all, and naming only an
   extra drops everything in `config/default.yml`. Rails advice is separate because the cops
   asking for `assert_not` and `index_by` would autocorrect a plain Ruby project into methods it
   does not have. Copy solargraph configuration from the reference repo.
5. CI: GitHub Actions workflow running linters and the full test suite on push, based on the
   reference repo's workflows. Pre-existing rubocop offenses go into `.rubocop_todo.yml` —
   except in files created in the current PR, which must be clean.
6. Dependabot: minimal config, all ecosystems, all update types, cooldown of 1 week.
7. Dependencies: Gemfile source `gem.coop`; UI apps load `mvpa-css` from GitHub
   (see agents.md §4a for the full dependency policy).
8. i18n: Dutch, English, and Italian locales from the start; no hardcoded user-facing strings.
9. Deploy (when the app deploys): Kamal, mirroring the reference repo's setup with names and
   URLs updated.
