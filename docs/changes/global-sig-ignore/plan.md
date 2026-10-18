# Plan: Ignore generated signature folders globally

From `intent.md` (2026-10-18). Status: accepted.

## Context

Steep, `rbs collection` and rbs-inline write `sig/` and `.gem_rbs_collection/` into Ruby repositories. Signatures live inline as `#:` / `# @rbs` comments, so both folders are generated output. Today every repository ignores them by hand, and `new-repo-setup` step 12 tells the reader to add `.gem_rbs_collection/` to each `.gitignore`. This change moves both ignores into the global excludes file and updates two skills.

`git/.config/git/config` line 31 sets `excludesfile = ~/.config/git/ignore.global`. The source file is `git/.config/git/ignore.global`, already stow-linked. Both skills are shared: `claude/.claude/skills/new-repo-setup` and `claude/.claude/skills/ruby-style` are relative links to `agents/.agents/skills/<name>/`, so one edit reaches Claude and Codex.

## Design decisions

- Pattern form: `sig/` and `.gem_rbs_collection/`, unanchored, exactly as `intent.md` names them. An unanchored pattern also covers a gem in a subfolder of a monorepo. An anchored `/sig/` was rejected because it changes the agreed pattern and misses nested gems.
- Placement: a new block `## RBS generated signatures` in `ignore.global`, directly after the `## Environment normalization:` block of the Ruby section, with a one-line comment that names the gem exception (`!sig/` in the gem's own `.gitignore`).
- Gem CI recipe: three GitHub Actions steps in a fenced `yaml` block under step 12, each a `- run:` item, in this order.
  - `rm -rf sig && bundle exec rbs-inline --output=sig lib` — removing `sig/` first drops a stale file whose source no longer exists; rbs-inline does not delete files on its own. `bundle exec` because the gem adds `rbs-inline` as a development dependency in its own Gemfile.
  - `git add --intent-to-add sig/` — without it, `git diff` does not see a newly generated file that was never committed, so a missing file would pass.
  - `git diff --exit-code sig/` — fails the build when the committed copy differs.
- Test level: one new Minitest file. It runs real `git` in a temporary repository through the shipped global config, not a `-c` override, so it proves the `core.excludesfile` wiring too. Each git child gets `HOME=<tmp home>` and `GIT_CONFIG_GLOBAL=<REPO_ROOT>/git/.config/git/config`; the test copies `ignore.global` to `<tmp home>/.config/git/ignore.global`, which is where that config's `excludesfile = ~/.config/git/ignore.global` points. `test/isolated_git.rb` already sets `GIT_CONFIG_GLOBAL=/dev/null` for the test process; its header comment names a per-child `GIT_CONFIG_GLOBAL` as the supported override. The shipped config's `[include]` of `~/.config/git/work-remotes.config` is missing under the temporary home, and git ignores a missing include. The test never commits, so `gpgsign` and `hooksPath` do not run.
- Recipe test shape: the gem CI recipe is a fenced `yaml` block in step 12. The test extracts that block, parses it with `YAML.safe_load`, and asserts the ordered list of `run` commands, so prose that only names the commands does not pass.
- The existing `RbsInlineToolingTest#test_new_repo_setup_adds_inline_steepfile` asserts that the skill mentions `.gem_rbs_collection/`. The new step 12 wording still names it (as globally ignored), so that test stays unchanged. The new test adds the refusal of the per-repository instruction.

## Integration points

- Git's ignore precedence: a pattern in a repository's `.gitignore` overrides `core.excludesFile`, so `!sig/` in a gem's `.gitignore` re-includes the folder.
- Every git repository on the machine reads `ignore.global` through the global config. No stow run is needed: the file is already linked.
- CI (`.github/workflows/dotfiles-tests.yml`) runs every `test/*_test.rb` with `ruby -Itest`; the new file is picked up with no workflow change.
- Lefthook pre-commit runs RuboCop on `*.rb` and the no-hardwrap markdownlint rule on Markdown.

## Files that change

- `test/global_sig_ignore_test.rb` — new. Guards the ignore lines through `git check-ignore` and `git status` in a temporary repository, and guards the skill wording.
- `git/.config/git/ignore.global` — add the `## RBS generated signatures` block with `sig/` and `.gem_rbs_collection/`.
- `agents/.agents/skills/new-repo-setup/SKILL.md` — step 12: replace "and add `.gem_rbs_collection/` to the repo's `.gitignore`" with a sentence that the global excludes file ignores `sig/` and `.gem_rbs_collection/`, so the repository needs no ignore line of its own; state that `sig/` is generated and never committed; add the gem exception and its CI recipe.
- `agents/.agents/skills/ruby-style/SKILL.md` — `## Documentation comments`: one new list item: `sig/` is generated output and never committed, except in a gem that publishes its types, which commits a `sig/` generated from its inline comments.

## Order of work

1. Write `test/global_sig_ignore_test.rb` with the first acceptance test, `test_global_excludes_hide_sig_and_rbs_collection`. Run `ruby -Itest test/global_sig_ignore_test.rb -i test_global_excludes_hide_sig_and_rbs_collection`. Watch it fail because `ignore.global` has no `sig/` line.
2. Add the `## RBS generated signatures` block to `git/.config/git/ignore.global`. Run the test; it passes.
3. Add `test_gem_gitignore_reincludes_sig`. Run it. It passes at once, because git precedence does the work; this is a guard, not new behaviour. Confirm it fails when the gem's `.gitignore` line is removed from the test setup, then restore the line.
4. Add `test_new_repo_setup_drops_per_repo_rbs_collection_ignore` and `test_new_repo_setup_shows_gem_sig_ci_step`. Run them; watch both fail.
5. Rewrite step 12 in `agents/.agents/skills/new-repo-setup/SKILL.md`. Run the file's tests and `ruby -Itest test/rbs_inline_tooling_test.rb`; all pass.
6. Add `test_ruby_style_says_sig_is_generated_except_in_a_gem`. Run it; watch it fail.
7. Add the list item to `agents/.agents/skills/ruby-style/SKILL.md`. Run the test; it passes.
8. Run the full suite, stopping at the first failing file: `for file in test/*_test.rb; do ruby -Itest "$file" || break; done`. Minitest 6.0.6 has no fail-fast flag, so single-test runs use `-i <test name>` and the loop stops per file.
9. Run `rubocop test/global_sig_ignore_test.rb` and markdownlint with the no-hardwrap rule on both `SKILL.md` files. Fix every finding.
10. Verify by hand in a scratch repository under the scratchpad, with the same `HOME` and `GIT_CONFIG_GLOBAL` setup as the test: `git init`, `mkdir sig .gem_rbs_collection`, `touch sig/foo.rbs .gem_rbs_collection/x`, `git status --porcelain --untracked-files=all` shows neither; add `!sig/` to `.gitignore` and confirm `sig/foo.rbs` shows and `git add sig/foo.rbs` succeeds. Record the output as evidence.
11. Re-read the full diff. Commit in small steps: the ignore lines with their test, then each skill change with its tests.

## Risks

- An unanchored `sig/` hides any folder named `sig` in any repository, Ruby or not. `intent.md` records that no checkout under `~/Developer` tracks a `sig/` today. A tracked file stays tracked regardless of ignore rules, so nothing committed disappears; only new files in such a folder need `git add -f` or a `!sig/` line.
- The gem exception depends on the gem's `.gitignore` carrying `!sig/`. A gem without that line silently stops committing new signature files. The skill wording and the CI recipe make that visible: the CI step fails when `sig/` drifts.
- `/.config` in `ignore.global` already shows the file is broad and global; this change follows that style rather than reworking it.
- Rejected: a per-repository `.gitignore` line (the problem being solved), and an anchored `/sig/` (see Design decisions).

## Out of scope

- Any change in a gem repository, such as appkit: its `!sig/` line, its `rbs-inline` dependency and its CI job.
- Per-repository `.gitignore` files in other checkouts. An existing `.gem_rbs_collection/` line there stays.
- Steep, RBS or `rbs_collection.yaml` setup beyond the step 12 wording.
- Installing or upgrading `rbs`, `rbs-inline` or Steep.
- Any `stow` run.

## Proof

- In a repository with no ignore lines of its own, `sig/foo.rbs` and `.gem_rbs_collection/` do not show up as untracked → `test/global_sig_ignore_test.rb` `test_global_excludes_hide_sig_and_rbs_collection`
- In a gem repository whose `.gitignore` has `!sig/`, `sig/foo.rbs` shows up as untracked and can be committed → `test/global_sig_ignore_test.rb` `test_gem_gitignore_reincludes_sig`
- A new repository set up through `new-repo-setup` gets no `.gem_rbs_collection/` line in its `.gitignore` → `test/global_sig_ignore_test.rb` `test_new_repo_setup_drops_per_repo_rbs_collection_ignore`
- The `new-repo-setup` skill shows a gem's CI step: it runs `rbs-inline --output=sig lib`, and a stale committed `sig/` fails the build → `test/global_sig_ignore_test.rb` `test_new_repo_setup_shows_gem_sig_ci_step`
- The `ruby-style` skill says that `sig/` is generated, never committed, except in a gem that publishes its types → `test/global_sig_ignore_test.rb` `test_ruby_style_says_sig_is_generated_except_in_a_gem`

Per changed file, the unit tests expected:

- `git/.config/git/ignore.global`: `GlobalSigIgnoreTest#test_global_excludes_hide_sig_and_rbs_collection` (both `git check-ignore -q` exit 0, and `git status --porcelain --untracked-files=all` lists neither path), `#test_gem_gitignore_reincludes_sig` (`git status` lists `sig/foo.rbs`, `git add sig/foo.rbs` exits 0 and the file is in `git diff --cached --name-only`).
- `agents/.agents/skills/new-repo-setup/SKILL.md`: `#test_new_repo_setup_drops_per_repo_rbs_collection_ignore` (refutes "add `.gem_rbs_collection/` to the repo's `.gitignore`"; asserts step 12 says the global excludes file ignores `sig/` and `.gem_rbs_collection/`), `#test_new_repo_setup_shows_gem_sig_ci_step` (asserts `!sig/` in step 12; parses step 12's fenced `yaml` block and asserts its `run` commands are, in order, one containing `rbs-inline --output=sig lib`, then `git add --intent-to-add sig/`, then `git diff --exit-code sig/`). `RbsInlineToolingTest#test_new_repo_setup_adds_inline_steepfile` stays green unchanged.
- `agents/.agents/skills/ruby-style/SKILL.md`: `#test_ruby_style_says_sig_is_generated_except_in_a_gem` (the `## Documentation comments` section names `sig/`, "never committed" and the gem exception).

Test setup: `require_relative "isolated_git"`, `Dir.mktmpdir` per test holding a `home/` and a `repo/`. Copy `git/.config/git/ignore.global` to `home/.config/git/ignore.global`. Every git call runs through `Open3.capture2e({ "HOME" => home, "GIT_CONFIG_GLOBAL" => "<REPO_ROOT>/git/.config/git/config" }, "git", …, chdir: repo)`, starting with `git init -q`. Skill tests read files from `REPO_ROOT`, as `test/rbs_inline_tooling_test.rb` does. No fakes.

---
Domain skills applied: dotfiles-maintenance, new-repo-setup, ruby-style, rails-testing (Minitest conventions).

## Critique

### Round 1 (codex exec -p terra)

- The plan omits Minitest fail-fast flags, against the playbook's first-failure rule → fixed (single-test runs use `-i <test name>` and the suite loop stops at the first failing file; Minitest 6.0.6 has no `-f` flag, checked in its option parser)
- Testing through `git -c core.excludesFile=…` bypasses the shipped git config, so it cannot prove that normal git reads the global file → fixed (the test now sets `HOME` to a temporary home holding `.config/git/ignore.global` and `GIT_CONFIG_GLOBAL` to the shipped `git/.config/git/config`, with no `-c`)
- The recipe test only checks for command tokens anywhere in step 12, so prose would pass without a runnable recipe → fixed (the test parses step 12's fenced `yaml` block and asserts the ordered `run` commands)
