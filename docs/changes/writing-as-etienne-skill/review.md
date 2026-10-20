# Review: writing-as-etienne-skill

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the passes follow the reviewer defaults (`new-repo-setup/references/REVIEW.md`).

## Round 1 — 2026-10-19T15:21:19Z — fcb46d65

Checks: `skill_parity_test`, `skill_parity_hook_test`, `no_hardwrap_rule_test`, `markdown_rule_mirror_test` and `core_values_test` are green. Every test file up to `lefthook_local_hooks_test.rb` passed in the full serial run; the run was stopped there for time. `yamllint` and the no-hardwrap markdownlint rule pass on the touched files. Both skill paths resolve to the same `SKILL.md`.

Compliance: plan steps 1–5 are in the diff (step 5 edits `agents.md`, which `claude/.claude/PLAYBOOK.md` links to). Proof: "both paths resolve" is covered by `skill_parity_test`; "`SKILLS-INDEX.md` lists the skill" holds at `SKILLS-INDEX.md:48`; linters and tests are green as above. No existing test changed.

- [x] Important: `intent.md` promises "Codex loads it only on request", but `openai.yaml` sets no `policy.allow_implicit_invocation: false`, so Codex loads the skill implicitly. Plan step 2 chose this on purpose for the parity test, yet the accepted intent still states the opposite. Either update the intent's outcome and get it re-accepted, or make Codex request-only (for example through an `AGENT_INVOKED`-style exception in `test/skill_parity_test.rb`) — `agents/.agents/skills/writing-as-etienne/agents/openai.yaml:1` → fixed (Align writing-as-etienne intent with implicit loading)
- [x] Nit: The skill names a real colleague ("Hi Djurre 👋") and refers to "the reviewed colleague message" in a public repository. Use a neutral name, as the illustrative example already does with "Alex" — `agents/.agents/skills/writing-as-etienne/SKILL.md:14` → fixed (Use a fantasy name in the writing-as-etienne examples)

## Round 2 — 2026-10-20T07:46:00Z — 9b1bd994

Checks: `skill_parity_test`, `skill_parity_hook_test`, `no_hardwrap_rule_test`, `markdown_rule_mirror_test`, `core_values_test` and `artifact_chain_skills_test` are green. `yamllint` passes on `openai.yaml`. `markdownlint-cli2` did not run: the worktree has no `node_modules`; the no-hardwrap rule test covers the custom rule. Both skill paths resolve to the same `SKILL.md`. The branch is behind `origin/main` (PR #219), and `git merge-tree` shows a clean merge; main's new `intent_interview_depth_test` does not read change folders.

Compliance: both round 1 fixes hold. The intent now says Claude and Codex both load the skill by relevance, which matches plan step 2 and `openai.yaml`; the intent was re-accepted on 2026-10-20. No real colleague name remains in the skill; both examples use the fantasy name "Thalion". Plan steps 1–5 are in the diff, and nothing unplanned crept in. No existing test changed.

Bugs and security: no findings. The skill keeps the rule that drafting does not authorise sending, and it forbids invented facts.

No findings this round.
