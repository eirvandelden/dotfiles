# Plan: Keep every skill in one tool-agnostic location

From `intent.md` (2026-10-09). Status: accepted.

## Context

Today every skill source lives in `claude/.claude/skills/<name>/` (37 folders). `agents/.agents/skills/` holds 26 relative symlinks back into the Claude package. Eleven skills have no link, so Codex cannot see them: dependencies, dotfiles-maintenance, new-repo-setup, object-oriented-design, rails-api-design, rails-architecture, rails-ops, rails-testing, rails-ui, ruby-style and sync.

Both `claude` and `agents` are in `STOW_SHARED` (`packages.conf`). `install/utils.sh` `stow_configure` stows them with `--restow --no-folding`, because dotfiles-work installs into the same `~/.claude/skills/` and `~/.agents/skills/` directories. On this machine `~/.claude/skills/<name>/` is a real directory of per-file links into `claude/.claude/skills/<name>/`. `~/.agents/skills/<name>` is one link to `agents/.agents/skills/<name>` (a package-side symlink is a leaf for stow, so it is linked whole).

`test/skill_parity_test.rb` is the drift guard. It runs in CI (`.github/workflows/dotfiles-tests.yml`, every `test/*_test.rb`) and in the pre-push hook `skill-parity` in `lefthook-local.yml`.

## Design decisions

- Reverse the link direction. Each source folder moves with `git mv` to `agents/.agents/skills/<name>/`. `claude/.claude/skills/<name>` becomes a relative symlink, `../../../agents/.agents/skills/<name>`. The `claude` package keeps owning `~/.claude/skills/<name>`, and `~/.claude/skills/` stays a real directory that several packages share.
- The link must be relative. GNU Stow 2.4.1 refuses an absolute package-side symlink (`source is an absolute symlink`, `Stow.pm` `stow_node`).
- No link for `agents/.agents/skills/` any more: every entry there is a real directory with a `SKILL.md`.
- Installed paths stay as they are. `~/.claude/skills/...` in skill bodies, `claude/.claude/agents/reviewer.md` and `codex/.codex/agents/reviewer.toml` keep resolving after the restow, and the intent forbids other content changes. Only repo-relative paths (`claude/.claude/skills/...`) change, to `agents/.agents/skills/...`.
- The one exception is the reviewer prompt in `herdr/.config/herdr/scripts/start-review.sh`. It tells the reviewer to run the repo-relative `claude/.claude/skills/plan/scripts/change-folder`, which exists only inside this repository. It changes to the installed `~/.claude/skills/plan/scripts/change-folder`, the same path `reviewer.md` uses. The old path stops naming a source after this change, so a path edit is due anyway.
- Codex policy file for the eleven skills: `agents/openai.yaml` with `interface.display_name` and `interface.short_description`, in the shape of `compound/agents/openai.yaml`. None of the eleven has `disable-model-invocation: true`, so none gets a `policy` block. The short description is a shortened copy of the skill's own frontmatter `description`, not new content.
- The parity test drops `CLAUDE_ONLY` (now empty by design) and keeps `CODEX_ONLY` and `AGENT_INVOKED` as they are.
- The "a source under `claude/.claude/skills/` fails the suite" criterion gets a fixture test as well as the live-repository assertion. The check moves into a small private helper that takes the two directories, so a `Dir.mktmpdir` fixture can prove it without touching the repository. This follows `test/stow_package_roots_test.rb`.
- Restow command after the merge: `stow --dir "$HOME/Developer/dotfiles" --target "$HOME" --restow --no-folding claude agents`, run from the main checkout. This is the intent's approved `stow -R -t "$HOME"` with the flags `stow_configure` uses for shared packages. Without `--no-folding` stow would fold differently from every other install run.

## Integration points

- GNU Stow 2.4.1 (`--restow --no-folding`) for `claude` and `agents`.
- dotfiles-work, which stows into `~/.claude/skills/` and `~/.agents/skills/`. Not changed.
- Claude Code reads `~/.claude/skills/<name>/SKILL.md`. Codex reads `~/.agents/skills/<name>/SKILL.md` and `agents/openai.yaml`.
- Scripts that resolve a skill file through the repository: `claude/.claude/hooks/test-guard.rb` and `git/.config/git/worktree-tools/review-report-fresh` (both through Ruby `__dir__`, which is a real path).
- herdr stage scripts: `hand-off-plan.sh` (prompts name skills, reads no skill file directly) and `start-review.sh` (prompt names `change-folder`).
- CI workflow and pre-push hook run the tests. Neither file changes (rule 13).

## Files that change

- `test/skill_parity_test.rb` — new invariants: every `agents/.agents/skills/<name>` is a real directory with `SKILL.md` and `agents/openai.yaml`; every `claude/.claude/skills/<name>` is a symlink whose `readlink` equals `../../../agents/.agents/skills/<name>`; names match on both sides; policy matches frontmatter; the repo-relative path guard also matches `agents/\.agents/skills/`. Header comment rewritten for the new direction. `CLAUDE_ONLY` removed.
- `claude/.claude/skills/<name>/` (37 folders) → `agents/.agents/skills/<name>/` by `git mv`; old `agents/.agents/skills/<name>` links (26) deleted first; `claude/.claude/skills/<name>` recreated as relative links (37).
- `agents/.agents/skills/{dependencies,dotfiles-maintenance,new-repo-setup,object-oriented-design,rails-api-design,rails-architecture,rails-ops,rails-testing,rails-ui,ruby-style,sync}/agents/openai.yaml` — new.
- `test/approval_word_test.rb`, `test/artifact_chain_skills_test.rb`, `test/auto_accept_test.rb`, `test/autonomy_contract_test.rb`, `test/change_folder_test.rb`, `test/change_scope_test.rb`, `test/fill_pr_template_test.rb`, `test/herdr_worker_scripts_test.rb`, `test/hotwire_native_skill_test.rb`, `test/mobile_testing_exception_test.rb`, `test/mobile_tooling_test.rb`, `test/vendored_skills_test.rb` — skill constants and literal paths point at `agents/.agents/skills`. `test_there_is_no_spec_skill_for_claude_or_codex` keeps both paths. `vendored_skills_test.rb` expects the new `SKILLS-INDEX.md` path form.
- `claude/.claude/hooks/test-guard.rb` — `CHANGE_FOLDER_SCRIPT` to `../../../agents/.agents/skills/plan/scripts/change-folder`.
- `git/.config/git/worktree-tools/review-report-fresh` — `CHANGE_FOLDER_SCRIPT` to `../../../../agents/.agents/skills/plan/scripts/change-folder`.
- `herdr/.config/herdr/scripts/start-review.sh` — comment and reviewer prompt name `~/.claude/skills/plan/scripts/change-folder`.
- `SKILLS-INDEX.md` — every `claude/.claude/skills/` path becomes `agents/.agents/skills/`; the "Three path forms" paragraph says the source is the `agents` package, installed at both `~/.agents/skills/` and `~/.claude/skills/`.
- `VENDORED-SKILLS.yml` (header comment) and `VENDORED-LICENSES.md` — snapshot folder paths.
- `agents.md` rule 20 — `sync` skill path. `claude/.claude/core-values.yml` does not mirror this line, so it does not change.
- `claude/.claude/WORKTREES.md` — the Codex paragraph: the skill lives in `agents/.agents/skills/worktree-first`, linked into `claude/.claude/skills/`.
- `agents/.agents/skills/dotfiles-maintenance/SKILL.md` "Agent skills" section — the new source and link direction, and that every skill is shared.
- `agents/.agents/skills/new-repo-setup/SKILL.md` step 11 — the `REVIEW.md` reference path.
- `lefthook-local.yml` `skill-parity.fail_text` — wording for the new direction. Globs stay; both directories already match.
- `.clinerules/`, `.cursor/`, `.opencode/`, `.windsurf/` — deleted (`git rm -r`).

## Order of work

1. Write the acceptance test: rewrite `test/skill_parity_test.rb` for the new layout. Run `ruby -Itest test/skill_parity_test.rb`. Watch it fail: `claude/.claude/skills/<name>` is not a symlink, and `agents/.agents/skills/<name>` is a symlink. Commit: `test: require the agents package to hold every skill source`.
2. Move the sources. Per skill: `git rm` the old agents link if it exists, `git mv claude/.claude/skills/<name> agents/.agents/skills/<name>`, `ln -s ../../../agents/.agents/skills/<name> claude/.claude/skills/<name>`, `git add` the link. Run the parity test: only the eleven missing `openai.yaml` files fail. Commit: `refactor: move skill sources into the agents package`.
3. Add the eleven `agents/openai.yaml` files. Parity test green. Commit: `feat: let Codex invoke every repository skill`.
4. Prove the guard by hand: `mkdir claude/.claude/skills/probe && touch claude/.claude/skills/probe/SKILL.md`, run the parity test, watch it fail on `probe`, then `trash claude/.claude/skills/probe`. Record the output as evidence.
5. Update the docs (`SKILLS-INDEX.md`, `VENDORED-*`, `agents.md`, `WORKTREES.md`, the two skill bodies, `lefthook-local.yml` fail text). In the same step change only the `SKILLS-INDEX.md` path expectation in `test/vendored_skills_test.rb` `test_skills_index_lists_every_new_mobile_skill`, first, and watch it fail before the index changes. Run `test/vendored_skills_test.rb`, `test/markdown_rule_mirror_test.rb`, `test/no_hardwrap_rule_test.rb`. Commit: `docs: name the agents package as the skill source`.
6. Repoint the other tests (list above, minus the assertion step 5 changed). Run each changed test file, then the full suite. Commit: `test: read skills from the agents package`.
7. Repoint `test-guard.rb`, `review-report-fresh` and `start-review.sh`. Run `test/test_guard_test.rb`, `test/review_report_check_test.rb`, `test/herdr_worker_scripts_test.rb`. Commit: `refactor: point scripts at the agents skill source`.
8. `git rm -r .clinerules .cursor .opencode .windsurf`. Commit: `chore: remove unused agent rule folders`.
9. `git grep -n 'claude/\.claude/skills/' -- ':!docs/changes'` returns only the parity test's own guard pattern, the `spec` absence test, and prose that names the link folder on purpose (`WORKTREES.md`, `dotfiles-maintenance`).
10. Full suite (`for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`), `yamllint` on the new YAML files, `shellcheck -x -S warning` on `start-review.sh`, `markdownlint` on changed Markdown, `rubocop` on changed Ruby. Re-read the full diff.
11. After Etienne merges (not before): from the main checkout run the restow command in Design decisions. Then run the post-restow checks in Proof. Give Etienne a `trash` command for any dangling link `find` reports; never remove one by hand.

## Risks

- Restow of a package-side symlink over an existing real directory. Traced in `Stow.pm` 2.4.1: on `-D`, `unstow_node` descends through the link (the package path is a directory to `-d`) and removes the per-file links it owns. On `-S`, an existing `~/.claude/skills/<name>/` directory gets per-file links through the package link; a missing one gets one link to `claude/.claude/skills/<name>`. Both resolve. Not yet exercised: step 11 is the first real run.
- Codex side changes shape. `~/.agents/skills/<name>` turns from one directory link into a real directory of per-file links (`--no-folding` on a real package directory). Codex has only read directory links on this machine so far. The "Codex lists every skill" check catches a loader that ignores file links.
- Between the merge and the restow, nothing breaks: the existing `~/.claude/skills/<name>/SKILL.md` links point at `claude/.claude/skills/<name>/SKILL.md`, which still resolves through the new package link. The eleven new Codex skills appear only after the restow.
- A skill whose files the dotfiles-work repo also provides under the same name would collide. None does today (work skills have distinct names).
- `git mv` of a folder onto a path where a link still exists fails. Step 2 removes the link first.
- Rejected: letting the `agents` package also ship `.claude/skills/<name>` links. It would make `agents` write into `~/.claude/`, which the `claude` package owns, for no gain.
- Rejected: one `claude/.claude/skills` link to `agents/.agents/skills`. `~/.claude/skills/` must stay a real shared directory.
- Rejected: rewriting `~/.claude/skills/...` references to `~/.agents/skills/...`. It is a content change the intent puts out of scope, and Claude reads only `~/.claude/skills/`.

## Out of scope

- dotfiles-work skills (code-style-*, review-as-*, fizzy-sync) and their repository.
- Any skill content change other than path references and the eleven Codex policy files.
- Plugin and marketplace skills, and `~/.claude/skills/synced`.
- `.github/workflows/` and any other deploy or CI configuration.
- The `lefthook.yml` `[[ ]]` bug and other unrelated fixes.

## Proof

- `claude/.claude/skills/` holds no skill source; each skill folder lives in `agents/.agents/skills/<name>/` → `test/skill_parity_test.rb` `test_every_agents_skill_is_a_real_folder_with_a_skill_md` and `test_claude_skills_are_relative_links_into_the_agents_package`
- A skill source added under `claude/.claude/skills/` makes the test suite fail → `test/skill_parity_test.rb` `test_a_real_folder_under_claude_skills_is_reported` (fixture), plus check: step 4 `probe` folder run
- After the restow, a new Claude session lists every repository skill → check: `claude -p "List the name of every skill available to you, one per line, nothing else"` contains every name in `ls agents/.agents/skills`, including `intent`, `finish` and `ruby-style`
- After the restow, Codex lists every repository skill → check: `codex exec -s read-only "List the name of every skill available to you, one per line, nothing else"` contains every name in `ls agents/.agents/skills`, including `ruby-style` and `sync`
- After the restow, `~/.claude/skills/finish/scripts/change-scope` prints `personal` → check: `cd ~/Developer/dotfiles && ~/.claude/skills/finish/scripts/change-scope`
- After the restow, `hand-off-plan.sh` and `start-review.sh` find their skill files → check: `test -x ~/.claude/skills/plan/scripts/change-folder && test -r ~/.claude/skills/plan/SKILL.md && test -r ~/.claude/skills/implement/SKILL.md && test -r ~/.claude/skills/review/SKILL.md`, then `ruby -Itest test/herdr_worker_scripts_test.rb` from the main checkout
- After the restow, no dangling link this change caused → check: `find ~/.claude/skills ~/.agents/skills -maxdepth 3 -type l ! -exec test -e {} \; -print` prints nothing that names a repository skill
- The repository test suite and linters pass → check: step 10 commands, and the pre-push hooks on `git push`
- The four rule folders are gone → `test/skill_parity_test.rb` `test_unused_agent_rule_folders_are_gone`

Per changed file, the unit tests expected:

- `test/skill_parity_test.rb`: `test_every_agents_skill_is_a_real_folder_with_a_skill_md`, `test_claude_skills_are_relative_links_into_the_agents_package`, `test_a_real_folder_under_claude_skills_is_reported`, `test_an_absolute_link_under_claude_skills_is_reported`, `test_skill_names_match_on_both_sides`, `test_every_agents_skill_has_an_openai_yaml`, `test_implicit_invocation_policy_matches_between_frontmatter_and_openai_yaml`, `test_codex_skills_directory_is_gone`, `test_codex_worktrees_doc_resolves_to_the_claude_one`, `test_packages_conf_lists_agents_in_stow_and_stow_shared`, `test_no_skill_or_agent_body_names_a_repo_relative_path_as_a_command`, `test_unused_agent_rule_folders_are_gone`.
- Other test files: no new tests; their existing tests stay green with the new paths.
- `test-guard.rb`, `review-report-fresh`, `start-review.sh`: covered by their existing tests (`test_guard_test.rb`, `review_report_check_test.rb`, `herdr_worker_scripts_test.rb`).

Test setup: the parity test reads the repository through `REPO_ROOT`, never `~`. The two fixture tests build `claude/.claude/skills/` and `agents/.agents/skills/` in a `Dir.mktmpdir` and call the private helper that lists sources outside the agents package.

---
Domain skills applied: dotfiles-maintenance, object-oriented-design (small helper for the fixture test).

## Critique

### Round 1 (codex exec -p terra)

- Step 5 repointed `test/vendored_skills_test.rb` to expect `agents/.agents/skills/...` in `SKILLS-INDEX.md` while the index changed only in step 7, so step 5's test and full-suite runs would fail → fixed (the docs step now runs before the test repoint, and the index assertion changes in that docs step, watched red first)
