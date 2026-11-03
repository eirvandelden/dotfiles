# Review: Blood Elf and Orc Grunt voices

## Round 1 — 2026-11-03 12:14 UTC — 4131f1e9

Criteria: no `REVIEW.md` or `REVIEW.local.md` at the repository root, so the reviewer defaults apply.

Checks: `ruby -Itest test/agent_voice_test.rb` passes (30 runs, 0 failures). `bin/test` fails only `test/herdr_config_test.rb` (expects `delivery = "terminal"`, finds `"system"`); that comes from `8363835d` on `main`, not from this branch, and belongs on its own branch under rule 25. `rubocop` does not start here (`cannot load such file -- rubocop-rbs_inline`), so the Ruby lint result is unknown. `yamllint` exits 0 with one warning, listed below.

Compliance: removal of SCV and Thrall and the two new names are proven by the persona-list test (`test/agent_voice_test.rb:125` against `PERSONAS`). The Thalassian requirement is proven by `test_the_blood_elf_speaks_thalassian`. The plan's two steps match the diff, and nothing unplanned changed. No existing test was weakened. Security and Design: nothing found; the diff adds no public Ruby method and no glossary `Avoid:` word.

- [x] Nit: The Blood Elf `tone` line is 174 characters; `yamllint` warns `line too long (174 > 120 characters)`, and the file on `main` had no warning. — `claude/.claude/agent-voice.yml:32` → fixed (Address review round 1 for the Blood Elf and Orc Grunt voices): tone shortened; yamllint exits 0
- [x] Nit: "Shindu falah nah." differs from the in-game Blood Elf line "Shindu fallah na" ("Our enemies will fall"). — `claude/.claude/agent-voice.yml:35` → fixed (Address review round 1 for the Blood Elf and Orc Grunt voices): removed the phrase; sources disagree on its spelling and meaning
- [x] Nit: Two catchphrases have no English gloss, so the agent does not know what they mean when it improvises with them. The tone also ties the gloss rule to array order ("the first three phrases"), which breaks when the list is reordered. — `claude/.claude/agent-voice.yml:32` → fixed (Address review round 1 for the Blood Elf and Orc Grunt voices): removed the unglossed phrases; the tone now glosses every phrase, with no order rule
- [x] Nit: The Orc Peon and the StarCraft Marine tones both call the character a "grunt", which is now also a persona name; one word, two meanings. — `claude/.claude/agent-voice.yml:18`, `claude/.claude/agent-voice.yml:38` → fixed (Address review round 1 for the Blood Elf and Orc Grunt voices): Peon tone says worker, Marine tone says soldier
- [x] Nit: The renamed test refutes "What is thy bidding?" for the Grunt, a line it never had; the assertion guarded a Thrall regression and now proves nothing about the Grunt. — `test/agent_voice_test.rb:140` → fixed (Address review round 1 for the Blood Elf and Orc Grunt voices): the Grunt test now refutes the Peon line "Work, work."

## Round 2 — 2026-11-03 12:28 UTC — 01518b96

Criteria: no `REVIEW.md` or `REVIEW.local.md` at the repository root, so the reviewer defaults apply.

Checks: `ruby -Itest test/agent_voice_test.rb` passes (30 runs, 0 failures). `bin/test` fails only `test/herdr_config_test.rb`, the same pre-existing `main` failure from round 1; this branch does not touch herdr. `yamllint claude/.claude/agent-voice.yml` exits 0 with no warning. `rubocop` still does not start here (`cannot load such file -- rubocop-rbs_inline`), so the Ruby lint result is unknown.

Compliance: every round 1 fix is in `01518b96` and holds. SCV and Thrall have no reference left outside the change folder (`git grep`). The persona-list test proves the removals and the two new names; `test_the_blood_elf_speaks_thalassian` proves the Thalassian requirement. The three Blood Elf glosses match their usual translations. Security and Design: nothing found; no public Ruby method and no glossary `Avoid:` word in the diff.

Nothing found.
