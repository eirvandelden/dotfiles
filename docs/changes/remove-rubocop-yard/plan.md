# Plan: Replace YARD tooling with inline RBS tooling

From `intent.md` (2026-10-13). Status: accepted.

## Context

Personal Ruby code moves from YARD method docs to inline RBS signatures (`#:` / `# @rbs`, upstream RBS 4 syntax). The dotfiles still load `rubocop-yard` in the fallback RuboCop config, install four YARD gems, and install `rubocop-yard` in CI. Nothing installs or wires up inline-RBS tooling. Two skills give conflicting personal documentation rules. This plan removes the YARD tooling, adds `rbs`, `steep` and `rubocop-rbs_inline`, wires Steep's language server into three editors next to Solargraph, and aligns the skills.

Facts checked while planning (2026-10-13):

- `rubocop-rbs_inline` 2.0.0 depends on `lint_roller ~> 1.1`, `rbs-inline >= 0` and `rubocop >= 1.72.1, < 2.0`, so it loads through `plugins:`. `rbs-inline` 0.14.0 depends on `rbs ~> 4.0`.
- Its cops live under `Style/RbsInline/*`. The `Style/RbsInline` department sets `Mode: opt_in` (only files with `# rbs_inline: enabled` are checked) and excludes `spec/**/*` and `test/**/*`. `Mode: opt_out` checks every file except those with `# rbs_inline: disabled`.
- `steep` 2.1.0 depends on `rbs ~> 4.2`. Steep 2.0 added inline RBS declarations, enabled per target with `check "<dir>", inline: true`. The language server command is `steep langserver`.
- The VS Code extension `soutaro.steep-vscode` starts only when the workspace has a `Steepfile`. With `steep.command` empty it runs `bin/steep` or `bundle exec steep`. With `steep.command` set, it appends `langserver` and its own options.
- Zed's Ruby extension supports a `steep` language server. It uses the Gemfile's `steep` through `bundle exec`, else `steep` from `PATH`.
- Solargraph 0.58.1 has no config key for RBS. It always loads core and standard library RBS from the `rbs` gem, and reads gem RBS from a project's `rbs_collection.yaml`. Its config keys are `include`, `exclude`, `require`, `domains`, `reporters`, `formatter`, `type_checker`, `require_paths`, `plugins` and `max_files`.
- Solargraph depends on `yard`, `yard-solargraph` and `yard-activesupport-concern` at runtime, in 0.58.1 and in the latest release, 0.61.0. A fresh `gem install solargraph` therefore still installs all three, whatever `packages.conf` lists.
- Solargraph 0.58.1 requires `rbs >= 3.6.1, <= 4.0.0.dev.4`; Solargraph 0.61.0 requires `rbs >= 3.10.4`. A fresh unpinned install gets 0.61.0, which shares `rbs` 4.2 with Steep. On a machine that keeps 0.58.1, RubyGems keeps both `rbs` versions and each tool activates its own.
- `rbs` 4.2, `steep` 2.1 and `rubocop-rbs_inline` 2.0 require Ruby 3.3 or later.
- The `dotfiles-tests` workflow runs on a push to `main` and on `pull_request` only. A push of the feature branch alone starts no CI run.
- This machine has `rbs` 4.2.0 and `solargraph` 0.58.1, but not `steep`, `rbs-inline` or `rubocop-rbs_inline`. Rule 8 forbids installing them. Neovim is 0.12.6.

## Design decisions

- Fallback RuboCop config, `rbs_inline` cops: set the `Style/RbsInline` department to `Mode: opt_out`. RBS 4 inline syntax and Steep's `inline: true` need no magic comment, so `opt_in` would skip every real file.
- Fallback RuboCop config, which cops: enable only the cops that check that an existing annotation is well formed: `InvalidComment`, `InvalidTypes`, `KeywordSeparator`, `ParametersSeparator`, `UnmatchedAnnotations`, `RedundantTypeAnnotation`, `MethodCommentSpacing`, `VariableCommentSpacing`, `EmbeddedRbsSpacing`, `RedundantAnnotationWithSkip`. Leave off the cops that demand annotations or enforce rbs-inline-prototype limits: `MissingTypeAnnotation`, `MissingDataClassAnnotation`, `MissingStructClassAnnotation`, `UntypedInstanceVariable`, `RequireRbsInlineComment`, `DataDefineWithBlock`, `StructNewWithBlock`, and the two alignment cops. Reason: the fallback lints every repository without its own config, including code that has no annotations yet. Intent asks the fallback to check inline annotations, not to require them.
- Keep the department's default `test/**` and `spec/**` exclude. Annotations in tests are rare, and the gem authors chose that default.
- Solargraph config: no key exists to switch RBS on, and core and standard library RBS already load. Add a short YAML comment that says so and points at `rbs_collection.yaml` for gem RBS. Gem RBS per project comes from the `new-repo-setup` step below.
- `new-repo-setup` gets a "Types" step: a `Steepfile` with one target that checks `app` and `lib` (or only `lib` for a non-Rails project) with `inline: true` and no `signature` line; `rbs collection init` and `rbs collection install`, committing `rbs_collection.yaml` and `rbs_collection.lock.yaml`; `.gem_rbs_collection/` in the repository's `.gitignore`. The step states that Steep and RBS 4 need Ruby 3.3 or later. The downloaded collection is generated `.rbs`, so it is never committed. Steep comes from the global install in `packages.conf`, not the Gemfile; adding a Gemfile entry would be a new dependency per repository (rule 11).
- Neovim: add `lsp/steep.lua` with `cmd = { "steep", "langserver" }`, `filetypes = { "ruby" }`, and a `root_dir` function that calls `on_dir` only when `vim.fs.root(bufnr, { "Steepfile" })` finds a root. A plain `root_markers` would still start Steep in a project without a `Steepfile`. Enable it in `lua/core/lsp.lua` next to `solargraph`.
- Zed: `languages.Ruby.language_servers` becomes `["solargraph", "steep"]`. Add `lsp.steep.binary` with `path: "steep"` and `arguments: ["langserver"]`, so Zed uses the global gem and does not install its own copy.
- VS Code: add `"steep.command": "steep"`, so the extension uses the global gem instead of `bundle exec steep`. The repository has no VS Code extension list, so there is no extension entry to add. The `soutaro.steep-vscode` extension is installed by hand (out of scope, rule 8).
- Skills: one personal rule in both skills. Personal: a one-line class summary comment, inline RBS signatures in RBS 4 syntax on methods, other comments only for a non-obvious "why", no YARD tags, no `@action` / `@route`. Work: unchanged YARD rules, with `@action` / `@route` labelled work-only. `rails-architecture/references/examples.md` labels the `@action` / `@route` example as work-only and adds a short personal example with a `#:` signature.
- Tests: static checks go in one new file, `test/rbs_inline_tooling_test.rb`, in the style of the other file-reading tests in `test/`. Behaviour of the fallback config goes in `test/rubocop_fallback_test.rb`, which already runs RuboCop against `rubocop/.rubocop.yml`.

## Integration points

- RuboCop plugin loading through `lint_roller` (`plugins:`).
- `install.sh` and the install scripts that read `RUBY_GEMS` in `packages.conf`.
- The `dotfiles-tests` GitHub Actions workflow on Ruby 3.4.
- Stow targets: `rubocop/.rubocop.yml`, `solargraph/.config/solargraph/config.yml`, `neovim/.config/nvim/`, `zed/.config/zed/settings.json`. The `vscode/` files are not stow-shaped; leave how they are linked unchanged.
- Codex reads the same skills through symlinks in `agents/.agents/skills`, so the skill edits reach both tools with no extra file.

## Files that change

- `test/rubocop_fallback_test.rb` — new behaviour tests for the YARD removal and the `rbs_inline` cops. Fixtures go under `lib/`, because the `Style/RbsInline` department excludes `test/**`.
- `test/rbs_inline_tooling_test.rb` — new static tests for packages, CI, editor wiring, Solargraph, skills and the `rubocop-yard` grep.
- `rubocop/.rubocop.yml` — remove `rubocop-yard` from `plugins:`, remove the `# Cops from YARD` heading and the six `YARD/*` entries; add `rubocop-rbs_inline` to `plugins:`, a `Style/RbsInline` department entry with `Mode: opt_out`, and a `# Cops from rbs_inline` section that enables the ten cops above.
- `packages.conf` — in `RUBY_GEMS`, remove `rubocop-yard`, `yard`, `yard-activesupport-concern`, `yard-solargraph`; add `rbs`, `rubocop-rbs_inline`, `steep` in alphabetical position.
- `.github/workflows/dotfiles-tests.yml` — in the gem install line, replace `rubocop-yard` with `rubocop-rbs_inline`. Approved in intent.
- `solargraph/.config/solargraph/config.yml` — the explanatory comment only.
- `neovim/.config/nvim/lsp/steep.lua` — new file.
- `neovim/.config/nvim/lua/core/lsp.lua` — add `"steep"` to `vim.lsp.enable`.
- `zed/.config/zed/settings.json` — `language_servers` and `lsp.steep`.
- `vscode/settings.json` — `"steep.command": "steep"`.
- `claude/.claude/skills/new-repo-setup/SKILL.md` — the Types step.
- `claude/.claude/skills/rails-architecture/SKILL.md` — the Documentation section.
- `claude/.claude/skills/rails-architecture/references/examples.md` — work-only label and a personal `#:` example.
- `claude/.claude/skills/ruby-style/SKILL.md` — the Documentation comments section.

## Order of work

1. Add `test_fallback_reports_no_yard_cop` to `test/rubocop_fallback_test.rb` and run it. It writes `lib/sample.rb` with a YARD tag that `YARD/MeaninglessTag` flags (an `@param` tag on a class) and asserts that no reported cop name starts with `YARD/`. Watch it fail on the current config, which still loads `rubocop-yard`.
2. Edit `rubocop/.rubocop.yml`: remove `rubocop-yard` and the YARD section. Run step 1 green.
3. Add the `rbs_inline` behaviour tests (see Proof). Locally they skip, because `rubocop-rbs_inline` is missing and RuboCop exits with status 2. Commit them with the config change from step 4.
4. Edit `rubocop/.rubocop.yml`: load `rubocop-rbs_inline`, set `Mode: opt_out`, enable the ten cops.
5. Add `test/rbs_inline_tooling_test.rb` with the packages and CI assertions; watch them fail. Edit `packages.conf` and `.github/workflows/dotfiles-tests.yml`; run green.
6. Add the Neovim, Zed and VS Code assertions; watch them fail. Add `lsp/steep.lua`, enable it, edit Zed and VS Code settings; run green. Run `nvim --headless -c 'lua print(vim.inspect(vim.lsp.config.steep.cmd))' -c q` to confirm Neovim loads the config.
7. Add the Solargraph comment. Run the Solargraph check from Proof.
8. Add the skill assertions; watch them fail. Edit `ruby-style`, `rails-architecture`, `examples.md`, `new-repo-setup`; run green.
9. Add the `git grep -i rubocop-yard` assertion; run green.
10. Run the full suite: `for file in test/*_test.rb; do ruby -Itest "$file" || break; done`. Run `markdownlint` on the changed markdown files, `yamllint` on the changed YAML, and RuboCop on the changed test files.
11. Push the branch. The `finish` skill opens the pull request later; this plan never does. The pull request's CI run is the first place where the `rbs_inline` tests run; they must pass there before merge. If CI shows that `rubocop-rbs_inline` rejects valid RBS 4 inline syntax, stop and ask Etienne (intent escalation).

Commit per step pair (test plus change), one logical change per commit.

## Risks

- `rubocop-rbs_inline` cannot run on this machine (rule 8), so the `rbs_inline` tests skip locally and run only in CI, where `skip_unless_ci` turns a load failure into a failure. The existing two fallback tests also skip locally once the config loads a plugin that is not installed. Branch pushes start no CI run, so the first real run is on the pull request that `finish` opens. Mitigation: that CI run must be green before merge; the implement report says the local run skipped them.
- Solargraph pulls in `yard`, `yard-solargraph` and `yard-activesupport-concern` as runtime dependencies. The acceptance criterion "a fresh install no longer installs `yard-activesupport-concern` or `yard-solargraph`" cannot hold while Solargraph stays, and replacing Solargraph is out of scope. This plan removes all four direct entries, and its tests check the `packages.conf` list, not the installed gem set. The gap goes to Etienne as an open decision.
- `rbs` version split: Solargraph 0.58.1 cannot load `rbs` 4.2. Mitigation: none needed in config; RubyGems activates `rbs` 3.10 for Solargraph 0.58.1 and `rbs` 4.2 for Steep, and a fresh install gets Solargraph 0.61.0, which accepts `rbs` 4.2. The Solargraph check in Proof runs under whichever Solargraph is installed.
- The new tools need Ruby 3.3 or later. Global gems install per Ruby version, so a repository pinned to an older Ruby already lacks the fallback's plugins unless they are installed for that Ruby; this change does not make that worse. The `new-repo-setup` Types step states the Ruby 3.3 minimum.
- `InvalidComment` may flag ordinary comments that start with `# :`, such as `# :nodoc:`. Mitigation: a test asserts that `# :nodoc:` gives no `Style/RbsInline` offense. If it fails in CI, drop `InvalidComment` from the enabled list and record why in the config comment.
- `rubocop-rbs_inline` is built on the `rbs-inline` 0.14 prototype and may reject RBS 4 syntax that Steep accepts. The intent's escalation rule applies: stop and ask.
- The editor acceptance criteria (Steep diagnostic and Solargraph completion in Neovim, Zed and VS Code) and `steep check` in a new repository need `steep` installed, and VS Code also needs the extension. Neither may be installed by the agent. These stay manual checks for Etienne after he installs from `packages.conf`.
- The Steep `inline: true` option is experimental in Steep 2.x. Its Steepfile syntax may change in a later release; the skill names the syntax for Steep 2.
- Rejected: `rubocop-on-rbs` (lints `.rbs` files, out of scope); enabling `MissingTypeAnnotation` in the fallback (would flag every unannotated method in every repository without its own config); a Gemfile `steep` entry per repository (rule 11); adding `.gem_rbs_collection/` to the global git ignore (outside the files intent names).

## Manual acceptance gates

These criteria have no automated proof on this machine, because the agent may not install `steep`, `rubocop-rbs_inline` or the VS Code extension (rule 8). The implement stage lists them as open in its report, and the change is not complete until they pass:

- The `rbs_inline` fallback tests pass in the pull request's CI run.
- Etienne installs from `packages.conf` (and `soutaro.steep-vscode` in VS Code), then runs the editor check and the `steep check` check from Proof.

## Out of scope

- Installing or uninstalling any gem or editor extension.
- Replacing Solargraph.
- `rubocop-on-rbs`.
- Adding a Steepfile, `rbs_collection.yaml` or annotations to existing repositories.
- Rewriting existing YARD comments in personal projects.
- Work YARD guidance beyond the work-only label on `@action` / `@route`.
- The VS Code `generateYard` keybinding and the `.yardoc` entries in `git/.config/git/ignore.global`.
- `rubocop-eirvandelden` (a separate repository).

## Proof

- RuboCop with the fallback config runs without `rubocop-yard` and reports no `YARD/*` cop → `test/rubocop_fallback_test.rb` `test_fallback_reports_no_yard_cop`, plus `test/rbs_inline_tooling_test.rb` `test_fallback_config_does_not_load_rubocop_yard`
- The fallback reports an offense for a malformed inline RBS annotation and accepts a valid RBS 4 annotation → `test/rubocop_fallback_test.rb` `test_fallback_reports_malformed_rbs_inline_type`, `test_fallback_reports_rbs_inline_comment_without_colon_prefix`, `test_fallback_accepts_valid_rbs_inline_signature`, `test_fallback_leaves_nodoc_comment_alone`
- A fresh install installs `rbs`, `steep`, `rubocop-rbs_inline` and none of the YARD gems → `test/rbs_inline_tooling_test.rb` `test_packages_conf_installs_rbs_tooling`, `test_packages_conf_lists_no_yard_gems` (proves the list only; Solargraph still installs `yard-solargraph` and `yard-activesupport-concern` transitively, see Risks)
- The `dotfiles-tests` workflow installs `rubocop-rbs_inline` and not `rubocop-yard`, and the fallback test passes → `test/rbs_inline_tooling_test.rb` `test_ci_installs_rubocop_rbs_inline_not_rubocop_yard`, plus the CI run of `test/rubocop_fallback_test.rb`
- Editors show a Steep diagnostic for a wrong `#:` type and Solargraph still completes → `test/rbs_inline_tooling_test.rb` `test_neovim_enables_steep_next_to_solargraph`, `test_neovim_steep_starts_only_with_a_steepfile`, `test_zed_runs_steep_next_to_solargraph`, `test_vscode_runs_global_steep`; then check: in a scratch project with a `Steepfile` (`check "lib", inline: true`), open `lib/a.rb` with `#: (Integer) -> String` above `def f(x) = x` in each editor, see the Steep type error, and see Solargraph completion on `"a".` (manual, after `steep` and the VS Code extension are installed)
- Solargraph shows RBS types for a standard library method → check: `ruby -e 'require "solargraph"; puts Solargraph::ApiMap.new.get_method_stack("String", "upcase").first.return_type'` prints `String`
- `new-repo-setup` adds a Steepfile with inline annotations, and `steep check` runs → `test/rbs_inline_tooling_test.rb` `test_new_repo_setup_adds_inline_steepfile`; then check: follow the step in a scratch repository and run `steep check` (manual, after `steep` is installed)
- Personal guidance is one rule in both skills → `test/rbs_inline_tooling_test.rb` `test_ruby_style_personal_rule_names_inline_rbs`, `test_rails_architecture_personal_rule_names_inline_rbs`, `test_rails_architecture_drops_personal_yard_method_docs`
- Work guidance keeps YARD, including `@action` / `@route` → `test/rbs_inline_tooling_test.rb` `test_rails_architecture_keeps_work_action_route_tags`, `test_ruby_style_keeps_work_yard_rule`
- `git grep -i rubocop-yard` returns nothing outside `docs/changes/` → `test/rbs_inline_tooling_test.rb` `test_no_rubocop_yard_reference_outside_change_folders`

Per changed file, the unit tests expected:

- `rubocop/.rubocop.yml`: `fallback reports no YARD cop`, `fallback reports a malformed #: type`, `fallback reports "# :" instead of "#:"`, `fallback accepts (Integer) -> String`, `fallback leaves # :nodoc: alone`, `config does not list rubocop-yard`.
- `packages.conf`: `RUBY_GEMS lists rbs, steep, rubocop-rbs_inline`, `RUBY_GEMS lists no YARD gem` (`test_packages_conf_lists_no_yard_gems`).
- `.github/workflows/dotfiles-tests.yml`: `gem install line names rubocop-rbs_inline and not rubocop-yard`.
- `neovim/.config/nvim/lsp/steep.lua`, `lua/core/lsp.lua`: `enable lists steep and solargraph`, `steep starts only under a Steepfile root`, `cmd is steep langserver`.
- `zed/.config/zed/settings.json`: `Ruby language_servers lists solargraph and steep`, `lsp.steep runs steep langserver`.
- `vscode/settings.json`: `steep.command is steep`.
- `claude/.claude/skills/*`: the skill assertions above.

Test setup: `test/rubocop_fallback_test.rb` reuses its temporary project and `run_fallback`, generalised to take a fixture path; new fixtures are small Ruby strings written under `lib/`. `test/rbs_inline_tooling_test.rb` reads files from the repository root and uses regular expressions on `zed/.config/zed/settings.json` and `vscode/settings.json`, which are JSON with comments and trailing commas. The acceptance criterion is a literal `git grep -i rubocop-yard` with no exception for test files, so no test file may hold that literal string. The tests build the gem name once, as `RUBOCOP_YARD = %w[rubocop yard].join("-")`, and use that constant in every assertion. The `git grep` test runs `git grep -i -l <RUBOCOP_YARD> -- ':!docs/changes'` from the repository root and asserts empty output.

---
Domain skills applied: dotfiles-maintenance, dependencies, ruby-style, rails-architecture, rails-testing.

## Critique

### Round 1 (codex exec -p terra)

- Solargraph installs `yard`, `yard-solargraph` and `yard-activesupport-concern` transitively, so removing the direct entries cannot meet the "no longer installs" criterion → fixed (verified against the 0.58.1 and 0.61.0 dependency lists; Context and Risks record the gap, the package test is renamed to check the list only, and the gap goes to Etienne as an open decision because replacing Solargraph is out of scope)
- Solargraph 0.58.1 cannot use `rbs` 4.2 while Steep 2.1 requires it, and the Solargraph comment changes nothing → fixed (Context and Risks record the version split, that RubyGems keeps both `rbs` versions, and that a fresh install gets Solargraph 0.61.0, which accepts `rbs` 4.2; the comment stays as documentation because intent asks for gem and standard library RBS and no config key exists)
- The global fallback and the setup skill set no Ruby version minimum, while the new tools need Ruby 3.3 or later → fixed (Risks explain that global gems are per Ruby version, so older-Ruby repositories already lack the fallback's plugins; the `new-repo-setup` Types step now states the Ruby 3.3 minimum)
- Several acceptance criteria lack executable proof: package tests read text, fallback tests skip locally, editor and new-repository checks fall to Etienne → fixed (new "Manual acceptance gates" section; Order of work and Risks now say that branch pushes start no CI run, so the pull request's CI run is the first real run and must be green before merge)
- The `extension.generateYard` VS Code keybinding still asks for YARD → dismissed: intent lists the `generateYard` keybinding as out of scope.
