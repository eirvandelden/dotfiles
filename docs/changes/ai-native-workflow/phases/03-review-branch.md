# Phase 3: `REVIEW.md`, the report-only reviewer, and the freshness check

Part of the change in `docs/changes/ai-native-workflow/` (read `intent.md`, `spec.md`, `plan.md`, `habits.md` first). Repository: `~/Developer/dotfiles`. Requires phases 1 and 2 merged. Work in a worktree, PR against `origin`.

## Context

Review runs locally, from the CLIs, never in GitHub (spec §4). A report-only agent reads the repo's `REVIEW.md`, the change folder's `plan.md` and `spec.md`, and the diff, and writes findings to a file outside the tracked tree. A deterministic pre-push check refuses to push a branch that has a change folder but no review report newer than its last commit — the playbook's "skill makes violations rare, hook makes them impossible" pairing.

Existing pieces: `claude/.claude/skills/review/SKILL.md` starts an Opus reviewer in a herdr pane via `herdr/.config/herdr/scripts/start-review.sh`, which writes its report under `$(git rev-parse --git-common-dir)/herdr/`. `claude/.claude/skills/code-review/SKILL.md` is for *implementing* review feedback and stays as is. `claude/.claude/agents/zubat.md` is the existing read-only locator agent and shows the agent file format in use.

Verified facts (2026-09-18). Claude agents (`code.claude.com/docs/en/sub-agents`): frontmatter `name`, `description`, `tools`, `model`, `permissionMode`, `skills`, `isolation`; user agents in `~/.claude/agents/`. Claude skills can run in a subagent with `context: fork` and `agent: <name>`. Codex agents (`learn.chatgpt.com/docs/agent-configuration/subagents`): TOML files in `~/.codex/agents/`, required `name`, `description`, `developer_instructions`; optional `model`, `model_reasoning_effort`, `sandbox_mode = "read-only"`. Multi-agent is on by default.

## Talk first

- **`lefthook.yml` change.** It is the global fallback for every repository without its own config. Present the pre-push command diff and its failure message to Etienne before merging.
- **Keep or retire the herdr `review` skill.** After `review-branch` works in-session, decide together whether the pane version stays as an alternative. Default if undecided: keep, rename its description to say "in a separate pane".

## Steps

1. **`REVIEW.md` template.** `claude/.claude/skills/new-repo-setup/references/REVIEW.md`, the playbook structure: `## Passes` (Bugs / Security / Compliance — compliance means the diff matches `plan.md`, behaviour matches `spec.md`, code follows the playbook and the repo's `AGENTS.md`), `## What Important means here`, `## Cap the nits` (five, rest as a count), `## Do not report` (generated files, anything a linter already enforces). Add a `new-repo-setup` checklist step: copy it to the repo root. Work repos: see the dotfiles-work phase file — there it is `REVIEW.local.md`, stowed; the reviewer looks for `REVIEW.md` then `REVIEW.local.md`.

2. **RED — freshness check.** `git/.config/git/worktree-tools/review-report-fresh` (Ruby, executable; the directory already holds `worktree-remove`). Contract: exit 0 when the current branch has no `docs/changes/<slug>/` in `HEAD`; exit 0 when a report `<git-common-dir>/reviews/<slug>-*.md` exists with mtime ≥ the `HEAD` commit time; otherwise exit 1 with: which slug, when the last commit was, when the newest report was (or "none"), and the exact command to run (`/review-branch`). Test `test/review_report_check_test.rb` with a temp git repo for the four cases. Run: fails. Write the script. Uses `claude/.claude/skills/plan/scripts/change-folder` for the slug — do not re-derive it.

3. **Reviewer agent, Claude.** `claude/.claude/agents/reviewer.md`: `tools: Read, Grep, Glob, Bash` restricted in the body to `git diff`, `git log`, `git show`, and the project's test and lint commands; `model:` per playbook rule 24 (judgement → not haiku). Instructions: read `REVIEW.md` (or `REVIEW.local.md`), `docs/changes/<slug>/{spec,plan}.md`, the diff against the base branch plus uncommitted changes; run the three passes — the compliance pass explicitly lists each acceptance criterion from `spec.md` with the test in the diff that proves it (or "missing"), checks every test named in the plan's Proof exists, and flags any existing test that was weakened, skipped, or deleted as Important; rank Important before Nit; cap nits; write the report to `<git-common-dir>/reviews/<slug>-<UTC timestamp>.md`; **do not edit any tracked file**; end by printing the report path.

4. **RED — Codex agent generated from the Claude one.** `bin/generate-codex-agents` (Ruby): for each `claude/.claude/agents/<name>.md`, write `codex/.codex/agents/<name>.toml` with `name`, `description` from frontmatter, `developer_instructions` = the markdown body, `sandbox_mode = "read-only"` when the Claude `tools` list contains no `Edit`/`Write`. Test `test/codex_agent_generation_test.rb`: generated output for a fixture; and an assertion that every committed `codex/.codex/agents/*.toml` equals what the generator produces now (drift). Run: fails. Write generator; generate `reviewer.toml` and `zubat.toml`; commit both. Add the drift assertion to `test/skill_parity_test.rb` or keep it here — one place only.

5. **`review-branch` skill.** `claude/.claude/skills/review-branch/SKILL.md`, Claude frontmatter `context: fork`, `agent: reviewer`; body: what to review (branch vs base plus working tree), where the report goes, and "summarise findings worst first; do not fix anything until the user says so". `## Codex` section: spawn the `reviewer` agent (multi-agent tools) or, if spawning is unavailable in the session, run the same instructions in a fresh `codex` session; the report path contract is identical. Codex link + `openai.yaml` per phase 1.

6. **Pre-push wiring.** In `lefthook.yml` `pre-push.commands`, add `review-report-fresh` with `tags: review` and `run: ~/.config/git/worktree-tools/review-report-fresh`, `fail_text` pointing at `/review-branch`. Approval first (Talk first). Bypass is `--no-verify`, which the consent guard already gates.

7. **Adapt `start-review.sh` / `review` skill.** Make the pane reviewer read the same inputs (`REVIEW.md`, change folder) and write to `<git-common-dir>/reviews/` with the same name pattern, so one report location satisfies the check. Run `test/herdr_worker_scripts_test.rb`.

8. **Playbook.** §7.16 (code review workflow): add "before pushing for others, run `review-branch`; the pre-push check enforces a fresh report". `SKILLS-INDEX.md`: add `review-branch`; note `REVIEW.md` template location.

9. **RED — test-file guard for bugfixes.** `claude/.claude/hooks/test-guard.rb`, next to `consent-guard.rb`, same stdin contract: reads the hook JSON, takes `tool_input.file_path` (Claude `Edit`/`Write`; for Codex the field name comes from the phase-6 probe), resolves the current branch's change folder with `change-folder`, and when that folder's `plan.md` contains a line `Reproduction: committed`, exits 2 for any path matching `test/**`, `spec/**`, `*_test.rb`, `*_spec.rb`, `__tests__/**`, `*.test.*` with the message: "Bugfix in progress: the reproduction test is committed; fix the code, not the tests. Remove `Reproduction: committed` from plan.md to override on purpose." Exit 0 in every other case, including no change folder and no `plan.md`. Test `test/test_guard_test.rb` with a temp git repo: no folder → allow; folder without the line → allow; line present + test path → block with that message; line present + non-test path → allow. Run: fails. Write. Wire in `claude/.claude/settings.json` `PreToolUse` with `matcher: "Edit|Write|MultiEdit"`. Codex wiring is phase 6 (same probe that finds the shell tool name finds the edit tool name).

## Files

New: `claude/.claude/skills/new-repo-setup/references/REVIEW.md`, `git/.config/git/worktree-tools/review-report-fresh`, `test/review_report_check_test.rb`, `claude/.claude/hooks/test-guard.rb`, `test/test_guard_test.rb`, `claude/.claude/agents/reviewer.md`, `bin/generate-codex-agents`, `test/codex_agent_generation_test.rb`, `codex/.codex/agents/{reviewer,zubat}.toml`, `claude/.claude/skills/review-branch/` (+ Codex link). Changed: `lefthook.yml`, `claude/.claude/settings.json` (one `PreToolUse` entry), `herdr/.config/herdr/scripts/start-review.sh`, `claude/.claude/skills/review/SKILL.md`, `claude/.claude/skills/new-repo-setup/SKILL.md`, `agents.md` §7.16, `SKILLS-INDEX.md`.

## Verification

- `test/` green, including the two new tests and `herdr_worker_scripts_test.rb`.
- Throwaway repo with a change folder and a commit: `git push` fails with the message; run `/review-branch`; report appears under `.git/reviews/`; `git push` passes. Same via Codex `$review-branch`. Then amend a file, commit, `git push` fails again.
- Reviewer never modified a tracked file: `git status` clean apart from its report location.
- Test guard: in a throwaway repo with `Reproduction: committed` in the branch's `plan.md`, an `Edit` of `test/foo_test.rb` is refused with the message and an `Edit` of `app/foo.rb` goes through; remove the line, the test edit goes through.
- **Etienne, by hand, after merge:** `stow -R --no-folding claude codex git`. Start habit 3.

## Out of scope

Deleting change folders (phase 4). Work `REVIEW.local.md` content (dotfiles-work phase file). Any GitHub Action or app. Tuning `REVIEW.md` per repo — that is habit 4's job over time.
