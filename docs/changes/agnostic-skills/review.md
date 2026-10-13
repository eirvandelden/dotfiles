# Review: agnostic-skills

## Round 1 — 2026-10-13T08:59:18Z — 9d27c779

The repository has no `REVIEW.md` or `REVIEW.local.md`, so this round uses the reviewer's default Bugs, Security and Compliance passes. There are no uncommitted changes. Linters on the changed files are green: rubocop on the 5 Ruby files, yamllint on the 11 new `openai.yaml` files, and `shellcheck -x -S warning` on `start-review.sh`. The full suite has one error, and that error also occurs on `origin/main` (see the third nit).

- [x] Important: The branch is 170 commits behind `origin/main`. Main has changed six files that this branch moves: `finish`, `implement`, `intent`, `review` and `worktree-first` `SKILL.md`, and `plan/scripts/auto-accept`. Main has also added `test/pull_request_flow_test.rb` with `SKILLS = File.join(REPO_ROOT, "claude/.claude/skills")`. The rebase (rule 20) must carry those edits into `agents/.agents/skills/<name>/`, where the move commit replaces each folder with a link. That gives a folder-versus-file conflict for each skill, so do not resolve one side blindly. After the rebase, run the step 9 grep and the full suite again, and repoint the new test constant. — `agents/.agents/skills/plan/scripts/auto-accept:1` → fixed (test: read the finish skill from the agents package)
- [x] Important: The `skill-parity` pre-push glob no longer sees the Claude side. Each `claude/.claude/skills/<name>` is now a top-level link, and `claude/.claude/skills/**/*` does not match it. Evidence: `lefthook run pre-push --file claude/.claude/skills/sync --command skill-parity` prints `skill-parity (skip) no matching push files`, and the same command with `claude/.claude/skills/sync/SKILL.md` runs the test. A push that only adds, removes or retargets a Claude link skips the guard locally (only CI catches it). The plan's claim "Globs stay; both directories already match" no longer holds. — `lefthook-local.yml:64` → fixed (fix: run skill-parity when a push touches only a Claude skill link)
- [x] Important: The parity guard cannot see a dangling link or a plain file under `claude/.claude/skills/`. `skill_names` keeps only `File.directory?` entries, and that check follows links, so a dangling link is dropped. This happens when a skill is renamed or deleted in `agents/.agents/skills/` and its link stays behind. `misplaced_claude_skills` and `test_skill_names_match_on_both_sides` both pass in that case, and the restow then installs a dangling `~/.claude/skills/<name>`. The intent's "no dangling link" criterion forbids that. Evidence: in a fixture with a dangling `../../../agents/.agents/skills/gone` link and a `stray.md`, `skill_names` returns `[]`. — `test/skill_parity_test.rb:158` → fixed (test: report dangling links and stray files under claude skills)
- [x] Nit: Plan step 4 says "Record the output as evidence" for the `probe` folder run, and §7a requires recorded evidence. No commit message or change-folder file on the branch holds that output. — `docs/changes/agnostic-skills/plan.md:59` → fixed (docs: record the misplaced-skill probe for agnostic-skills)
- [x] Nit: Step 11 of `new-repo-setup` tells an agent in another repository to copy the repo-relative path `agents/.agents/skills/new-repo-setup/references/REVIEW.md`. That path does not exist there. The installed path `~/.claude/skills/...` or `~/.agents/skills/...` resolves. This problem existed before this branch, with the old `claude/.claude/skills/` path. The intent forbids content changes, so fix it on a separate branch. — `agents/.agents/skills/new-repo-setup/SKILL.md:39` → dismissed: pre-existing, and the intent forbids skill content changes; proposed as a separate branch (rule 21)
- [x] Nit: `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point` errors with `git commit --quiet -m advance main failed`. It errors the same way on an `origin/main` export, so this branch does not cause it. It probably comes from the global git hooks, which run in the fixture repository and block its commit on `main`. Rule 25 applies: fix it on a separate branch. — `test/review_report_check_test.rb:53` → dismissed: pre-existing on origin/main; fixed on its own branch under rule 25, intent awaiting acceptance

### Security

The diff adds no secrets, credentials or work references (`nedap`/`caren`: 0 added lines). No new command takes input from outside. The `require_relative` targets in `change-scope` and `auto-accept` resolve through the real file path to `claude/.claude/hooks/remote_matcher.rb`.

### Compliance

- `claude/.claude/skills/` holds no skill source; every folder lives in `agents/.agents/skills/` → `test_every_agents_skill_is_a_real_folder_with_a_skill_md`, `test_claude_skills_are_relative_links_into_the_agents_package` (gap: the third Important finding)
- A skill source added under `claude/.claude/skills/` fails the suite → `test_a_real_folder_under_claude_skills_is_reported`, `test_an_absolute_link_under_claude_skills_is_reported`; step 4 evidence missing (first nit)
- A new Claude session lists every skill → post-restow check, plan step 11; pending until after the merge
- Codex lists every skill, including `ruby-style` and `sync` → post-restow check; pending. The new `openai.yaml` files for the eleven skills are present (`test_every_agents_skill_has_an_openai_yaml`)
- `~/.claude/skills/finish/scripts/change-scope` prints `personal` → post-restow check; pending. `test/change_scope_test.rb` passes on the repository path
- `hand-off-plan.sh` and `start-review.sh` find their skill files → post-restow check; pending. `test/herdr_worker_scripts_test.rb` passes
- No dangling link after the restow → post-restow check; pending (see the third Important finding)
- The test suite and linters pass → linters green; one suite error that also occurs on `origin/main` (third nit)
- The four rule folders are gone → `test_unused_agent_rule_folders_are_gone`

Every test named in the plan's `## Proof` exists. No existing test was weakened, skipped or deleted: `CLAUDE_ONLY` was removed, which makes `test_skill_names_match_on_both_sides` stricter.

## Round 2 — 2026-10-13T08:40:00Z — 9d27c779 (codex)

Source: `codex review --base origin/main`, transcribed. Codex found no confirmed defects. It reports that the skill parity test passes and the diff has no whitespace errors.

No findings.

## Round 3 — 2026-10-13T11:17:50Z — f7c4267c

The repository has no `REVIEW.md` or `REVIEW.local.md`, so this round uses the reviewer's default passes. The branch is rebased: `origin/main` is an ancestor of `HEAD`, 0 commits behind. There are no uncommitted changes. Every rename except the five planned path edits is `R100`, so no edit from main got lost in the rebase. Linters are green: rubocop on the 7 changed Ruby files, yamllint on every `openai.yaml` and `lefthook-local.yml`, `shellcheck -x -S warning` on `start-review.sh`, and the no-hardwrap markdownlint rule on the changed Markdown. The full suite has one error, `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`. It is the same pre-existing error that round 1 dismissed under rule 25. No test skips. The step 9 grep returns only the expected hits.

No Important findings.

- [x] Nit: `test_a_pushed_claude_skill_link_runs_the_parity_job` checks only that the output lacks `skill-parity (skip)`. It also passes when the job does not exist. Evidence: `lefthook run pre-push --file claude/.claude/skills/sync --command no-such-job` prints `no job matching no-such-job found` and exits 0, and that output lacks `(skip)`. A rename or removal of the `skill-parity` job keeps both hook tests green. Assert a positive marker of the job run instead. — `test/skill_parity_hook_test.rb:19` → fixed (test: assert the skill-parity job ran, not only that it was not skipped)
- [x] Nit: The plan still names the move commit as `8087440d` with the subject `refactor: move skill sources into the agents package`. After the rebase, that commit is `e4f30374` with the subject `Move every skill source into the agents package`. It is the only commit on the branch without a conventional prefix. The plan's `LEFTHOOK_EXCLUDE=fixme` push rule now names a SHA that is not on the branch. — `docs/changes/agnostic-skills/plan.md:24` → fixed (docs: name the move commit by its real subject in the plan)
- [x] Nit: `consent-guard.rb` still finds `change-folder` through the Claude link (`../skills/plan/scripts/change-folder`), but `test-guard.rb` in the same folder now uses the agents source. Both paths resolve, so nothing breaks. The two hooks now use different path forms for one script. — `claude/.claude/hooks/consent-guard.rb:30` → fixed (refactor: find change-folder the way consent-guard does)

### Security (round 3)

The diff adds no secrets, credentials or work references. No new command takes input from outside. The new `skill_parity_hook_test.rb` runs only the repository's own lefthook job with a fixed file argument.

### Compliance (round 3)

- `claude/.claude/skills/` holds no skill source → `test_every_agents_skill_is_a_real_folder_with_a_skill_md`, `test_claude_skills_are_relative_links_into_the_agents_package`. `git ls-tree` shows only `120000` entries under `claude/.claude/skills/` and none under `agents/.agents/skills/`.
- A skill source added under `claude/.claude/skills/` fails the suite → `test_a_real_folder_under_claude_skills_is_reported`, `test_an_absolute_link_under_claude_skills_is_reported`, `test_a_dangling_link_under_claude_skills_is_reported`, `test_a_plain_file_under_claude_skills_is_reported`, plus the probe run in `evidence.md`.
- A new Claude session lists every skill → post-restow check (plan step 11); pending until after the merge.
- Codex lists every skill, including `ruby-style` and `sync` → post-restow check; pending. All eleven new `openai.yaml` files exist, and each short description is a shortened copy of the frontmatter description.
- `~/.claude/skills/finish/scripts/change-scope` prints `personal` → post-restow check; pending. `test/change_scope_test.rb` passes on the repository path.
- `hand-off-plan.sh` and `start-review.sh` find their skill files → post-restow check; pending. `test/herdr_worker_scripts_test.rb` passes.
- No dangling link after the restow → post-restow check; pending. Read of Stow 2.4.1 `stow_node` and `unstow_node` agrees with the plan's Risks trace: an existing real target folder is descended, and the old `~/.agents/skills/<name>` folder link is removed on `-D` and rebuilt as a folder of file links on `-S`.
- The test suite and linters pass → linters green; one pre-existing suite error (above).
- The four rule folders are gone → `test_unused_agent_rule_folders_are_gone`.

Every test named in the plan's `## Proof` exists. No existing test was weakened, skipped or deleted.

## Round 4 — 2026-10-13T11:20:00Z — f7c4267c (codex)

Source: `codex review --base origin/main`, transcribed. Codex found no actionable regression. It reports that the skill-source move and the Claude links resolve, and that the parity and related tests pass.

No findings.
