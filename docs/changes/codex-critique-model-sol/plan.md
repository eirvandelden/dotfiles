# Plan: Codex critique and review use GPT Sol

From `intent.md` (2026-11-10). Status: accepted.

## Design

### Domain terms

- **Codex critique**: the second-model critique a Claude author runs on `plan.md` with the Codex CLI. The plan skill's `## Auto mode`, `## Critique` and `## Codex` sections and playbook §7a name it.
- **Codex critique command**: `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium`. It replaces `codex exec -p terra`. No new glossary term; `GLOSSARY.md` has no entry for critique or Terra.

### Diagrams

Not affected: the change touches markdown prose and one test file; no objects change.

### Signatures

`AutonomyContractTest` (`test/autonomy_contract_test.rb`) pins the text of autonomous delivery.

- New constant `CODEX_CRITIQUE = "codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium"`. It is the one place in the tests that names the critique model.
- `assert_critique_contract(section)`: asserts `CODEX_CRITIQUE` instead of `"codex exec -p terra"`.
- New `test_playbook_autonomy_names_the_codex_critique`: asserts `CODEX_CRITIQUE` in `autonomy_section` (§7a).

Not checked: the dotfiles repository has no Steepfile, and the change adds no method that needs a signature.

### Complexity

Not affected: two string lookups in a test; nothing runs at runtime.

### Invariants

- The plan skill's `## Auto mode` names `CODEX_CRITIQUE`, enforced by `assert_critique_contract` from `test_plan_auto_mode_runs_the_other_family_critique`.
- Playbook §7a names the same `CODEX_CRITIQUE`, enforced by the new `test_playbook_autonomy_names_the_codex_critique`. Both tests read one constant, so the two texts cannot name different commands without a red test.
- Rule 24 keeps `codex -p terra` for planning sessions. No test refutes `-p terra` across the whole playbook.

### Alternatives

- **A. Smallest diff** (four lines: plan skill line 137, §7a, speed-run, test string). Rejected: the plan skill would name Sol for the auto critique and Terra for the manual critique role (lines 146 and 160). It also leaves §7a unpinned.
- **B. Drift resistance, full** (A plus lines 146 and 160, a flags constant, §7a test, refutes of `-p terra` per section, a loop over `## Critique` and `## Codex`). Rejected in part: the refutes and the loop add tests for text that a grep check already proves; one positive assertion per pinned section already fails on a revert.
- **C. Chosen**: B's doc edits (six lines) and one constant asserted in the plan skill and §7a. A Codex profile file or a `codex-critique` script is out of scope (intent: "Any new Codex profile file").

## Design decisions

- Lines 146 (`## Critique`) and 160 (`## Codex`) of the plan skill change too. Both name `codex -p terra` as the model for the critique role. Intent's in-scope bullet says to replace `-p terra` "in the plan skill", and its first decision covers all Codex critiques. Line 146 becomes `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium`; line 160 becomes `codex -m gpt-6.1-sol -c model_reasoning_effort=medium`, because it names an interactive Codex session. Both `codex` and `codex exec` accept `-m` and `-c` (checked with `--help`).
- A new test pins §7a. Intent asks that §7a names the same command; a test keeps that true, at the cost of one short method.
- Intent's constraint says `gpt-6.1-sol` is the base `model` in `codex/.codex/config.toml`. That is not so: the base is `gpt-6-luna`. The ID is in `~/.codex/models_cache.json` with `medium` among its reasoning levels, so the decision holds. `config.toml` does not change.
- No conflict with intent's `## Decisions`.

## Integration points

- The Codex CLI (`codex exec`), at critique time in autonomous plan stages. `-m` sets the model; `-c model_reasoning_effort=medium` overrides the config key.
- `claude/.claude/PLAYBOOK.md` is a link to `agents/.agents/PLAYBOOK.md`; one edit covers both.
- `test/playbook.rb` (`Playbook.text`) feeds `PLAYBOOK` to the test.

## Files that change

- `test/autonomy_contract_test.rb` — add `CODEX_CRITIQUE`; use it in `assert_critique_contract`; add `test_playbook_autonomy_names_the_codex_critique`.
- `agents/.agents/skills/plan/SKILL.md` — line 137: `codex exec -p terra -s read-only -o <findings-file>` becomes `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium -s read-only -o <findings-file>`. Line 146: `codex -p terra` becomes `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium`. Line 160: `codex -p terra` becomes `codex -m gpt-6.1-sol -c model_reasoning_effort=medium`.
- `agents/.agents/PLAYBOOK.md` — §7a line 217: `codex exec -p terra` becomes `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium`.
- `agents/.agents/skills/speed-run/SKILL.md` — line 69: "latest available Claude Sonnet or GPT Terra" becomes "latest available Claude Sonnet or GPT Sol".

## Order of work

1. In `test/autonomy_contract_test.rb`, add `CODEX_CRITIQUE`, switch `assert_critique_contract` to it, and add `test_playbook_autonomy_names_the_codex_critique`. Run `bin/test test/autonomy_contract_test.rb`; watch both tests fail on the missing Sol command.
2. Edit plan skill line 137. Run the test file; `test_plan_auto_mode_runs_the_other_family_critique` passes.
3. Edit §7a in `agents/.agents/PLAYBOOK.md`. Run the test file; it is green.
4. Edit plan skill lines 146 and 160.
5. Edit speed-run line 69.
6. Run the grep checks in `## Proof`, then `bin/test`, then the lefthook linters (`rubocop` on the test file, `no-hardwrap` on the three markdown files).
7. Commit one logical change per commit: test and plan skill line 137 and §7a together (the contract), then lines 146 and 160, then speed-run.

## Risks

- A revert of step 1 alone would leave red tests on main; the commit grouping in step 7 keeps the test with the text it pins.
- `gpt-6.1-sol` may leave the models cache later; the critique would then fail. The plan skill already makes a failing critique CLI a `Decision needed:` blocker, so it fails loud.
- Rule 24 (`codex -p terra` for planning sessions) and `codex/.codex/terra.config.toml` stay; `test/codex_unlock_test.rb` uses `-p terra` as sample input and stays.
- Rejected: a refute of `-p terra` across the playbook, because rule 24 keeps it.

Out of scope: rule 24, `terra.config.toml`, any new Codex profile, the `claude -p` critique from a Codex author, the `Codex review: yes` reviewer path, `codex/.codex/config.toml`.

## Proof

- The plan skill tells a Claude author to critique with `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium` → `test/autonomy_contract_test.rb` `test_plan_auto_mode_runs_the_other_family_critique`
- Section 7a names the same command → `test/autonomy_contract_test.rb` `test_playbook_autonomy_names_the_codex_critique`
- `bin/test test/autonomy_contract_test.rb` passes and fails if the command goes back to `-p terra` → check: step 1's red run, then `bin/test test/autonomy_contract_test.rb` green
- `grep -rn "codex exec -p terra"` finds nothing outside `docs/changes` → check: `git grep -n "codex exec -p terra" -- ':!docs/changes'` prints nothing
- The speed-run reviewer line names GPT Sol, not GPT Terra → check: `git grep -n "GPT Terra" -- ':!docs/changes'` prints nothing and `git grep -n "GPT Sol" agents/.agents/skills/speed-run/SKILL.md` prints line 69
- Invariant: the plan skill's critique roles name no Terra profile, enforced by the text of lines 137, 146 and 160 → check: `git grep -n "terra" agents/.agents/skills/plan/SKILL.md` prints nothing
- Invariant: the plan skill and §7a name one critique command, enforced by `CODEX_CRITIQUE` → `test/autonomy_contract_test.rb` `test_plan_auto_mode_runs_the_other_family_critique` and `test_playbook_autonomy_names_the_codex_critique`

Per changed file, the unit tests expected:

- `test/autonomy_contract_test.rb`: `test_plan_auto_mode_runs_the_other_family_critique` (asserts `CODEX_CRITIQUE`), `test_playbook_autonomy_names_the_codex_critique`.
- Markdown files: no unit tests; the contract test and grep checks above cover them.

Test setup: none; the tests read the skill and playbook files from the worktree.

---
Domain skills applied: software-design (alternatives, connascence of meaning in one constant), glossary (no new terms), diagrams (not affected), ruby-style (constant and test naming).

## Critique

### Round 1 (Codex gpt-6.1-sol, medium)

No findings.
