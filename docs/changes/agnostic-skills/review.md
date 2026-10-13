# Review: agnostic-skills

## Round 1 — 2026-10-13T08:59:18Z — 9d27c779

The repository has no `REVIEW.md` or `REVIEW.local.md`, so this round uses the reviewer's default Bugs, Security and Compliance passes. There are no uncommitted changes. Linters on the changed files are green: rubocop on the 5 Ruby files, yamllint on the 11 new `openai.yaml` files, and `shellcheck -x -S warning` on `start-review.sh`. The full suite has one error, and that error also occurs on `origin/main` (see the third nit).

- [ ] Important: The branch is 170 commits behind `origin/main`. Main has changed six files that this branch moves: `finish`, `implement`, `intent`, `review` and `worktree-first` `SKILL.md`, and `plan/scripts/auto-accept`. Main has also added `test/pull_request_flow_test.rb` with `SKILLS = File.join(REPO_ROOT, "claude/.claude/skills")`. The rebase (rule 20) must carry those edits into `agents/.agents/skills/<name>/`, where the move commit replaces each folder with a link. That gives a folder-versus-file conflict for each skill, so do not resolve one side blindly. After the rebase, run the step 9 grep and the full suite again, and repoint the new test constant. — `agents/.agents/skills/plan/scripts/auto-accept:1` →
- [ ] Important: The `skill-parity` pre-push glob no longer sees the Claude side. Each `claude/.claude/skills/<name>` is now a top-level link, and `claude/.claude/skills/**/*` does not match it. Evidence: `lefthook run pre-push --file claude/.claude/skills/sync --command skill-parity` prints `skill-parity (skip) no matching push files`, and the same command with `claude/.claude/skills/sync/SKILL.md` runs the test. A push that only adds, removes or retargets a Claude link skips the guard locally (only CI catches it). The plan's claim "Globs stay; both directories already match" no longer holds. — `lefthook-local.yml:64` →
- [ ] Important: The parity guard cannot see a dangling link or a plain file under `claude/.claude/skills/`. `skill_names` keeps only `File.directory?` entries, and that check follows links, so a dangling link is dropped. This happens when a skill is renamed or deleted in `agents/.agents/skills/` and its link stays behind. `misplaced_claude_skills` and `test_skill_names_match_on_both_sides` both pass in that case, and the restow then installs a dangling `~/.claude/skills/<name>`. The intent's "no dangling link" criterion forbids that. Evidence: in a fixture with a dangling `../../../agents/.agents/skills/gone` link and a `stray.md`, `skill_names` returns `[]`. — `test/skill_parity_test.rb:158` →
- [ ] Nit: Plan step 4 says "Record the output as evidence" for the `probe` folder run, and §7a requires recorded evidence. No commit message or change-folder file on the branch holds that output. — `docs/changes/agnostic-skills/plan.md:59` →
- [ ] Nit: Step 11 of `new-repo-setup` tells an agent in another repository to copy the repo-relative path `agents/.agents/skills/new-repo-setup/references/REVIEW.md`. That path does not exist there. The installed path `~/.claude/skills/...` or `~/.agents/skills/...` resolves. This problem existed before this branch, with the old `claude/.claude/skills/` path. The intent forbids content changes, so fix it on a separate branch. — `agents/.agents/skills/new-repo-setup/SKILL.md:39` →
- [ ] Nit: `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point` errors with `git commit --quiet -m advance main failed`. It errors the same way on an `origin/main` export, so this branch does not cause it. It probably comes from the global git hooks, which run in the fixture repository and block its commit on `main`. Rule 25 applies: fix it on a separate branch. — `test/review_report_check_test.rb:53` →

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
