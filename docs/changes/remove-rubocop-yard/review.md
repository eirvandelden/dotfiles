## Round 1 — 2026-10-13T10:59:08Z — 2b5b8d78

- [x] Important: The fallback reports every valid `#:` signature as `Layout/LeadingCommentSpace` ("Missing space after #."). That cop comes from the inherited `rubocop-rails-omakase` config, and its `AllowRBSInlineAnnotation` defaults to `false`. With `rubocop -a`, which the lefthook pre-commit hook runs, RuboCop stops with "Infinite loop detected ... caused by Layout/LeadingCommentSpace -> Style/RbsInline/InvalidComment". Reproduced on `#: (Integer) -> String` above `def label(count) = count.to_s` in `lib/typed.rb` and on `#: Integer` above `attr_reader`. So the acceptance criterion "accepts a valid RBS 4 annotation" does not hold, and autocorrect is broken in any repository that uses the fallback. `# @rbs` lines are not affected. — `rubocop/.rubocop.yml:93` → fixed (Accept valid inline RBS signatures in the fallback RuboCop config)
- [x] Important: `test_fallback_accepts_valid_rbs_inline_signature` filters offenses to `Style/RbsInline/` only, so it passes while the fallback still reports the valid signature through `Layout/LeadingCommentSpace`. The test does not prove the criterion it is named for. It needs to assert no offense on the signature line from any cop, and to cover `-a` as well (the infinite loop goes to stderr, which `run_fallback` already fails on). — `test/rubocop_fallback_test.rb:95` → fixed (Accept valid inline RBS signatures in the fallback RuboCop config)
- [x] Nit: `test_no_rubocop_yard_reference_outside_change_folders` ignores the `git grep` exit status. A git error (status 128, for example a checkout without `.git`) prints nothing on stdout, so the test passes vacuously. Assert exit status 1 (no match) as well. — `test/rbs_inline_tooling_test.rb:96` → fixed (Fail the rubocop-yard grep test when git grep does not search)

Compliance (acceptance criteria from `intent.md`):

- No `rubocop-yard`, no `YARD/*` cop → `test_fallback_reports_no_yard_cop`, `test_fallback_config_does_not_load_rubocop_yard`.
- Malformed annotation reported → `test_fallback_reports_malformed_rbs_inline_type`, `test_fallback_reports_rbs_inline_comment_without_colon_prefix`. Valid RBS 4 annotation accepted → missing (see the Important findings above; the named test passes, but the criterion fails).
- `packages.conf` installs `rbs`, `steep`, `rubocop-rbs_inline`, lists no YARD gem → `test_packages_conf_installs_rbs_tooling`, `test_packages_conf_lists_no_yard_gems` (list only; transitive YARD gems accepted by Etienne).
- CI installs `rubocop-rbs_inline`, not `rubocop-yard`; fallback test passes → `test_ci_installs_rubocop_rbs_inline_not_rubocop_yard`; `test/rubocop_fallback_test.rb` 7/7 green locally with the plugin installed.
- Editors show Steep diagnostics next to Solargraph → `test_neovim_enables_steep_next_to_solargraph`, `test_neovim_steep_starts_only_with_a_steepfile`, `test_zed_runs_steep_next_to_solargraph`, `test_vscode_runs_global_steep`. Neovim headless loads `vim.lsp.config.steep` with `cmd = { "steep", "langserver" }`. The in-editor diagnostic stays a manual gate.
- Solargraph shows RBS for `String#upcase` → plan check run: Solargraph 0.58.1 prints `String`.
- `new-repo-setup` adds an inline Steepfile and `steep check` runs → `test_new_repo_setup_adds_inline_steepfile`. The skill's Steepfile, run in a scratch project, makes `steep check` report `Ruby::MethodBodyTypeMismatch` for `#: (Integer) -> String` on `def f(x) = x`.
- Personal rule is the same in both skills → `test_ruby_style_personal_rule_names_inline_rbs`, `test_rails_architecture_personal_rule_names_inline_rbs`, `test_rails_architecture_drops_personal_yard_method_docs`.
- Work YARD rules kept, with `@action` / `@route` → `test_rails_architecture_keeps_work_action_route_tags`, `test_ruby_style_keeps_work_yard_rule`.
- `git grep -i rubocop-yard` empty outside `docs/changes/` → `test_no_rubocop_yard_reference_outside_change_folders`.

Every test named in `plan.md` `## Proof` exists. No existing test was weakened, skipped or deleted: `run_fallback` gained a `path:` keyword with the old fixture as default.

Checks: `test/rubocop_fallback_test.rb` and `test/rbs_inline_tooling_test.rb` green; RuboCop, yamllint and markdownlint (no-hardwrap) clean on the changed files. In the full suite, `test/agent_worktree_test.rb` and `test/review_report_check_test.rb` error on `git` calls inside their temporary repositories (status 128, and a global `no-push-to-main` hook firing on a temporary `main`). This branch does not touch those files or the code they cover.

## Round 2 — 2026-10-13T10:47:16Z — 2b5b8d78 (codex)

No findings. `codex review --base origin/main` could not run the fallback RuboCop tests, because its sandbox blocked the RuboCop cache writes; they pass locally.

## Round 3 — 2026-10-13T11:13:17Z — a32fb3b1

- [ ] Important: Three `rbs_inline` fallback tests fail in CI. The fixtures use endless methods (`def label(count) = count.to_s`, Ruby 3.0+). RuboCop finds the target Ruby from a `.ruby-version` above the config file, not above the project. Locally `~/Developer/.ruby-version` is above the worktree, so the tests pass. In CI no ancestor of `rubocop/.rubocop.yml` has one, and the repo keeps it only at `ruby/.ruby-version`. RuboCop then parses as Ruby 2.7 and reports only `Lint/Syntax`. Reproduced: a copy of the config and test file outside any `.ruby-version` ancestor, run with `CI=true`, fails `test_fallback_reports_malformed_rbs_inline_type`, `test_fallback_reports_rbs_inline_comment_without_colon_prefix` and `test_fallback_accepts_valid_rbs_inline_signature` with `Expected ["Lint/Syntax", "Lint/Syntax"]`. `test_fallback_autocorrect_keeps_valid_rbs_inline_signature` then passes vacuously, because RuboCop does not correct a file that does not parse. A `.ruby-version` in the temporary project does not help. The plan's gate "the `rbs_inline` fallback tests pass in the pull request's CI run" therefore fails. — `test/rubocop_fallback_test.rb:47` →
- [ ] Nit: The valid-signature fixture covers only the `#:` form. Both skills also name `# @rbs`, and no test proves that the fallback accepts a valid `# @rbs` parameter annotation without an offense. — `test/rubocop_fallback_test.rb:46` →

Round 1 fixes checked:

- `Layout/LeadingCommentSpace` with `AllowRBSInlineAnnotation: true` holds. Valid `#:` lines on a method and on `attr_reader`, and `# @rbs` lines, give no offense from any cop, and `-a` leaves the file unchanged with empty stderr. Without the two config lines, the same fixture reports `Layout/LeadingCommentSpace` again.
- `test_fallback_accepts_valid_rbs_inline_signature` now asserts no offense from any cop, and the new `-a` test covers the autocorrect loop.
- `test_no_rubocop_yard_reference_outside_change_folders` now asserts `git grep` exit status 1.

Compliance (acceptance criteria from `intent.md`):

- No `rubocop-yard`, no `YARD/*` cop → `test_fallback_reports_no_yard_cop`, `test_fallback_config_does_not_load_rubocop_yard`.
- Malformed annotation reported, valid RBS 4 annotation accepted → `test_fallback_reports_malformed_rbs_inline_type`, `test_fallback_reports_rbs_inline_comment_without_colon_prefix`, `test_fallback_accepts_valid_rbs_inline_signature`, `test_fallback_autocorrect_keeps_valid_rbs_inline_signature`, `test_fallback_leaves_nodoc_comment_alone`. Green locally only; see the Important finding for CI.
- `packages.conf` installs `rbs`, `steep`, `rubocop-rbs_inline` and lists no YARD gem → `test_packages_conf_installs_rbs_tooling`, `test_packages_conf_lists_no_yard_gems` (list only; transitive YARD gems accepted by Etienne).
- CI installs `rubocop-rbs_inline`, not `rubocop-yard`, and `rubocop_fallback_test.rb` passes locally and in CI → `test_ci_installs_rubocop_rbs_inline_not_rubocop_yard`. The "passes in CI" half is missing: see the Important finding.
- Editors show Steep diagnostics next to Solargraph → `test_neovim_enables_steep_next_to_solargraph`, `test_neovim_steep_starts_only_with_a_steepfile`, `test_zed_runs_steep_next_to_solargraph`, `test_vscode_runs_global_steep`. The in-editor check stays a manual gate.
- Solargraph shows RBS for `String#upcase` → plan check (recorded in Round 1).
- `new-repo-setup` adds an inline Steepfile and `steep check` runs → `test_new_repo_setup_adds_inline_steepfile`, plus the Round 1 scratch `steep check`.
- Personal rule is the same in both skills → `test_ruby_style_personal_rule_names_inline_rbs`, `test_rails_architecture_personal_rule_names_inline_rbs`, `test_rails_architecture_drops_personal_yard_method_docs`.
- Work YARD rules kept, with `@action` / `@route` → `test_rails_architecture_keeps_work_action_route_tags`, `test_ruby_style_keeps_work_yard_rule`.
- `git grep -i rubocop-yard` empty outside `docs/changes/` → `test_no_rubocop_yard_reference_outside_change_folders`.

Every test named in `plan.md` `## Proof` exists. No existing test was weakened, skipped or deleted.

Checks: `test/rubocop_fallback_test.rb` (8 runs, 0 skips) and `test/rbs_inline_tooling_test.rb` (15 runs) green locally. RuboCop clean on both test files. yamllint clean on the changed YAML. The no-hardwrap markdownlint config is clean on the changed markdown. Default markdownlint reports MD031 at `new-repo-setup/SKILL.md:37`, which is the same on `origin/main`.
