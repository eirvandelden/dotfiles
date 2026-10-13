# Evidence: agnostic-skills

## Plan step 4: a misplaced skill fails the suite

Recorded on 2026-10-13 at `7cfe131e`. Two probes went into the live repository: a real folder `claude/.claude/skills/probe/` with a `SKILL.md`, and a dangling link `claude/.claude/skills/gone -> ../../../agents/.agents/skills/gone`. `ruby -Itest test/skill_parity_test.rb` then exited 1:

```text
SkillParityTest#test_skill_names_match_on_both_sides [test/skill_parity_test.rb:105]:
  actual names include "gone" and "probe"; expected names do not
SkillParityTest#test_claude_skills_are_relative_links_into_the_agents_package [test/skill_parity_test.rb:45]:
claude/.claude/skills must only hold relative links.
Expected ["gone", "probe"] to be empty.

15 runs, 243 assertions, 2 failures, 0 errors, 0 skips
```

Both probes went to the Trash afterwards. The suite was green again: 15 runs, 0 failures.

## Review round 1: the skill-parity hook sees a pushed Claude link

Before the fix, `lefthook run pre-push --file claude/.claude/skills/sync --command skill-parity` printed `skill-parity (skip) no matching push files`. After it, the job runs: `✔️ skill-parity`. `test/skill_parity_hook_test.rb` holds both cases.
