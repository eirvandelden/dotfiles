# Plan: Blood Elf and Orc Grunt voices

From `intent.md` (2026-11-03). Status: accepted.

1. In `claude/.claude/agent-voice.yml`, delete the SCV and Thrall personas. Add `WarCraft Orc Grunt` and `WarCraft Blood Elf` where Thrall was.
2. In `test/agent_voice_test.rb`, update `PERSONAS` and the Thrall catchphrase test to name the Orc Grunt, and add a Blood Elf Thalassian test.

Proof: `ruby -Itest test/agent_voice_test.rb`, then `bin/test` and rubocop.
