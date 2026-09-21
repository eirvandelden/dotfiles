# Phase 2: the artifact chain — `intent`, `spec`, `plan`, `implement`

Part of the change on branch `ai-native-workflow`. Its documents are merged to `main` and live at `~/Developer/dotfiles/docs/changes/ai-native-workflow/` until the change finishes; read them there (read `intent.md`, `spec.md`, `plan.md`, `habits.md` first). Repository: `~/Developer/dotfiles`. Requires phase 1 merged. Work in a worktree, PR against `origin`.

## Context

Every change gets a folder in the application repository:

```
docs/changes/<slug>/
  intent.md   # Problem / Proposed outcome / Affected users and systems / Constraints / Open questions
  spec.md     # Requirements / Design decisions / Integration points / Flagged concerns
  plan.md     # Files that change / Order of work / Risks / Proof
```

`<slug>` is the current branch name with any `<prefix>/` removed (`ai/foo` → `foo`). Each file starts with a title line and a `Status: draft` or `Status: accepted` line. Files are committed on the feature branch and removed at the end of the change (phase 4). Skills derive the folder; nobody types the path.

Today plans go to `~/.claude/plans/<random>.md` (the `handoff` skill writes there), the `plan-handoff` skill describes writing/critiquing/executing a plan without saying where it lives, and playbook §7.17 says "present a plan" without a file. This phase replaces all three with the folder above. The skills are written once under `claude/.claude/skills/` and linked into Codex via the phase-1 mechanism.

Claude facts (verified 2026-09-18, `code.claude.com/docs/en/skills`): `SKILL.md` frontmatter supports `name`, `description`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `context: fork` + `agent`, `paths`, `arguments`. Plan mode: `--permission-mode plan` or `permissions.defaultMode: "plan"`. Codex: `/plan` toggles plan mode; no default setting; skills invoked as `$name`.

## Talk first

- None. Decisions are in `spec.md` §1–2. If a template wording question comes up, use the playbook's templates verbatim and note the question in the PR.

## Steps

1. **RED — slug and folder script.** `claude/.claude/skills/plan/scripts/change-folder` (Ruby, executable) prints `docs/changes/<slug>` for the current branch, exit 1 with a clear message on `main`/`master`/detached HEAD. Test `test/change_folder_test.rb` covers: plain branch, prefixed branch (`ai/x`, `feature/x`), main refuses, detached refuses. Run: fails, script missing. Then write it. Other skills call this script; do not duplicate the logic.

2. **`intent` skill** — `claude/.claude/skills/intent/SKILL.md` (+ `agents/openai.yaml`, Codex link per phase 1). Behaviour:
   - First asks for the GitHub issue (number or URL) if none was given; reads its title and body with `gh issue view` as input to the interview. When an issue exists, the branch — and therefore the folder — is named `<issue-number>-<issue-title-in-kebab-case>`, the same name GitHub's "Create a branch" button generates. Without an issue: a kebab-case task slug. Before writing anything, the skill checks where it is: in the main checkout, or on a branch whose name does not match, it invokes `worktree-first` with the derived name, which creates `.worktrees/<name>` off `origin/main`; the skill then continues inside that worktree. Already in the right worktree: it writes there. It never creates a branch or folder in the main checkout.
   - Interview technique borrowed from the superpowers-ruby `brainstorming` skill (`~/.claude/plugins/cache/superpowers-ruby/superpowers-ruby/7.5.0/skills/brainstorming/SKILL.md`, 13 KB — read it before writing this skill; the plugin is disabled in phase 5, so the technique must live here). Take over: one question at a time; multiple choice where possible; explore the problem before any solution; the "too simple to need this" anti-pattern section; the red-flags list that sends the agent back to the checklist; persist as you go (write the draft `intent.md` early and refine it, so a dropped session loses nothing). Leave out: the design/architecture exploration (that is `spec`), the hand-off to `writing-plans` (that is `plan`), and the visual companion. Record in the skill's header comment which sections were adapted, so a later re-sync against upstream is a diff, not archaeology.
   - Interview in the domain's words: what can users not do today, what does better look like, who and what systems are affected, constraints, success. Three to five questions, then write. A small change still gets an intent; three lines is valid.
   - Writes `<folder>/intent.md` from the playbook template with `Author:`, `Status: draft`, and `Type: feature|bugfix|refactor|chore` (asked, or inferred from the issue labels and confirmed). Creates the folder. Does not `git add` — the user or `implement` commits.
   - On the words "accepted" / "accept the intent": flips to `Status: accepted`.
   - Never proposes a solution inside the intent.

3. **`spec` skill** — reads `intent.md` (refuses if `Status: draft`), applies the domain skills that match (it names which ones it used at the bottom), writes `spec.md` with the four sections, a required `## Acceptance criteria` section (one concrete example per behaviour, in domain words, each destined to become exactly one acceptance test at the level the repo already uses), plus a `## Flagged concerns` list at the top when policies conflict. Refuses to flip to `Status: accepted` while a requirement has no example, and says which. `Status:` line same as intent.

4. **`plan` skill** — three roles, chosen by the request:
   - **write**: must run in plan mode. Claude: if not already in plan mode, the skill tells the session to enter it (`EnterPlanMode`) before reading code; Codex: says to run `/plan`. Reads intent + spec (refuses on draft) + codebase; writes `plan.md` with the four sections, where `## Proof` is structured: one line per acceptance criterion naming the test file and test name that proves it, then per changed file the unit tests expected, named as behaviour, then an optional short "Test setup" paragraph; `## Order of work` step 1 is always "write the acceptance test for criterion 1, run it, watch it fail"; asks the user at least one interrogation question ("what could break", "what did you reject") before offering acceptance; `Status: accepted` only on the user's word.
   - **critique**: the `plan-handoff` "critically review a plan" text, unchanged in substance — read the plan, read the code it touches, verify claims, propose better alternatives. Meant for a second model (`codex -p terra` or an Opus session).
   - Absorb the "write a plan for another agent" rules from `plan-handoff` (self-contained, no chat references, explicit out-of-scope, one file per phase when phased) into the write role.

5. **`implement` skill** — reads `plan.md`; refuses on `Status: draft`; works through the plan in the current worktree following the playbook: outer loop — write the next acceptance test from Proof, run it, confirm it fails for the expected reason; inner loop — for each unit test named under the file being changed: red, green, refactor, commit; a unit test the plan did not foresee is added to `plan.md` in the same commit; when reality departs from the plan otherwise, edits `plan.md` **in the same commit** as the code that departs. On `Type: bugfix`: writes the failing reproduction test first, commits it alone, appends `Reproduction: committed` to `plan.md` in that commit, then fixes without touching test files (the phase-3 hook enforces this; removing the line is the deliberate override). Ends with every test in Proof run and the output pasted. Absorbs `plan-handoff`'s "executing a handed-over plan" rules.

5a. **`implement split` — two agents.** Before the superpowers-ruby plugin is disabled (phase 5), read its `test-driven-development`, `subagent-driven-development` and `dispatching-parallel-agents` skills under `~/.claude/plugins/cache/superpowers-ruby/superpowers-ruby/7.5.0/skills/` and take over what fits; record the adapted sections in each agent file's header comment. Then:
   - `claude/.claude/agents/test-writer.md`: `tools: Read, Grep, Glob, Bash, Write, Edit`; `skills:` preload `rails-testing`; instructions: read `docs/changes/<slug>/spec.md` acceptance criteria and `plan.md` Proof only — never the production code beyond what a test needs to compile; write each acceptance test and each unit test file with the named cases; run them; every new test must fail for the reason the criterion implies (a passing new test is reported as a finding, not fixed); commit `Tests for <slug>`; report the list of tests and their failure messages. Writes only under test paths (`test/**`, `spec/**`, `*_test.rb`, `*_spec.rb`, `__tests__/**`, `*.test.*`) plus `plan.md` Proof lines.
   - `claude/.claude/agents/implementer.md`: `tools: Read, Grep, Glob, Bash, Write, Edit`; frontmatter `hooks:` with a `PreToolUse` entry on `Edit|Write|MultiEdit` running `~/.claude/hooks/test-guard.rb --always` (phase 3 step 9 adds that flag), so writes under test paths are denied regardless of `plan.md`; instructions: read `plan.md` and the failing tests; red/green/refactor on production code only, one unit test at a time, commit on green; a unit test it needs but may not write becomes a Proof line in `plan.md` and a line in its report; ends by running the full Proof list and pasting the output.
   - `implement` skill gains `arguments` (frontmatter): `split` / `single` for the agent mode, `handoff` to send the plan to a pane instead (step 7); `split` default rule: on when `spec.md` lists three or more acceptance criteria, unless the user says `single`. Sequence: `test-writer` → main session confirms the commit landed and the suite is red for the right reasons → `implementer` → main session runs the full suite, reads both reports, and if the implementer reported missing tests, runs `test-writer` again for those, then `implementer` again. Never both at once in the same worktree.
   - Codex: `bin/generate-codex-agents` (phase 3) produces `codex/.codex/agents/{test-writer,implementer}.toml`; Codex agents cannot carry a per-path hook, so the implementer's restriction there is the instruction plus the `review` compliance check — the generator writes that sentence into `developer_instructions` when it drops a hook it cannot translate. Say so in the `## Codex` section of the skill.
   - Test: `test/codex_agent_generation_test.rb` (phase 3) covers the two new agent files once they exist; no other test — the agents are markdown.
   - Ordering: `test-guard.rb` is written in phase 3. In this phase the `implementer` agent file references the hook, and the `implement` skill offers `split` only when `~/.claude/hooks/test-guard.rb` exists; phase 3 step 9 makes it exist. Until then the skill says "split mode needs the test guard from phase 3" and runs single-session.

6. **Retire `plan-handoff`.** `git rm -r claude/.claude/skills/plan-handoff`; update `SKILLS-INDEX.md` ("Planning and setup" entry → `intent`, `spec`, `plan`, `implement`). Grep the repo for `plan-handoff` and fix every reference (`handoff/SKILL.md` names it).

7. **Fold `handoff` into `implement`.** `implement handoff` does what `claude/.claude/skills/handoff/SKILL.md` does today, with the plan taken from `<folder>/plan.md` (via `change-folder`, must be `Status: accepted`; if absent, say "run `/plan` first"): call `~/.config/herdr/scripts/hand-off-plan.sh <absolute plan path>` from the repository's main checkout, tell the user which worker took it and where its report lands, and stop — the worker runs `implement` in its own worktree. Keep the "When the worker finishes" paragraph (the `Handoff done: <path>` message) in the `implement` skill. Then `git rm -r claude/.claude/skills/handoff` and its Codex link; grep the repo for `handoff` and fix references (`SKILLS-INDEX.md`, `WORKTREES.md`, herdr scripts' comments). Drop every mention of `~/.claude/plans/`. `hand-off-plan.sh` takes an absolute path today, so the script itself should not change — confirm by running `test/herdr_worker_scripts_test.rb`; if its worker prompt names the `handoff` skill, change that word to `implement`.

8. **Playbook §7.17.** Replace the rule text with: no code before an accepted `plan.md` in `docs/changes/<slug>/`, produced in plan mode from an accepted `intent.md` and `spec.md`; trivial tasks get a one-line intent and a one-line plan, not an exemption. Keep the rule number. Add one line to §5 pointing at the four skills.

8a. **`worktree-first` branch naming.** In `claude/.claude/skills/worktree-first/SKILL.md` Step 1, replace `branch="<kebab-case-task-slug>"` guidance with: when a GitHub issue is known, `branch="<issue-number>-<issue-title-in-kebab-case>"` exactly as GitHub's "Create a branch" would name it (`gh issue view <n> --json title` for the title; lowercase, non-alphanumerics to `-`, collapse repeats, trim); otherwise a kebab-case task slug. No prefix in either case. Add a `test/branch_name_test.rb` if the derivation becomes a script; if it stays prose in the skill, no test.

9. **`new-repo-setup`.** Step 1: mention that `docs/changes/` is reserved for change folders and must not be in `.gitignore`. Nothing else in this phase.

10. **Parity.** `test/skill_parity_test.rb` (phase 1) must stay green: each new skill needs its Codex symlink and `agents/openai.yaml`. `intent`, `spec`, `plan`, `implement` are model-invocable in both tools (no `disable-model-invocation`).

## Files

New: `claude/.claude/skills/{intent,spec,plan,implement}/SKILL.md` and `agents/openai.yaml`, `claude/.claude/agents/{test-writer,implementer}.md`, `claude/.claude/skills/plan/scripts/change-folder`, `test/change_folder_test.rb`, `codex/.codex/skills/{intent,spec,plan,implement}` (symlinks). Changed: `claude/.claude/skills/new-repo-setup/SKILL.md`, `agents.md` (§5, §7.17), `SKILLS-INDEX.md`. Removed: `claude/.claude/skills/plan-handoff/`, `claude/.claude/skills/handoff/` (and its Codex link).

## Verification

- `test/` green (`change_folder_test.rb`, `skill_parity_test.rb`, `herdr_worker_scripts_test.rb`).
- Dry run in a throwaway repo, both tools, fresh sessions: `/intent` → file with `Status: draft`; "accepted" → flipped; `/spec` refuses before that, writes after; `/plan` enters plan mode, asks a question, writes; `/implement` refuses on draft. In Codex the same with `$intent` etc.
- Grep: no `~/.claude/plans` and no `plan-handoff` left in the repo.
- **Etienne, by hand, after merge:** `stow -R --no-folding claude codex`. The intent, spec, plan and implement habits start when phase 4 merges.

## Out of scope

Review skills, `REVIEW.md` (phase 3). Deleting folders (phase 4). Plugin changes (phase 5). Migrating existing files in `~/.claude/plans/` — leave them; they are no longer written to. Codex plan-mode-by-default — not available.
