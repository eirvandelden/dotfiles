# Review: fun-agent-voice

## Round 1 — 2026-10-20 07:52Z — 402fb4d5 (codex)

- [ ] Important: Persona data is not validated in `load_data`; `personas: []` or a persona without `catchphrases` makes `pick` raise `ZeroDivisionError` or `print_voice` raise `NoMethodError`, exiting 1 with a traceback instead of the documented warning and exit 0 — `claude/.claude/hooks/agent-voice.rb:19` → fixed (Make agent-voice fail closed on bad cwd, bad session id and bad persona data)

## Round 2 — 2026-10-20 07:57Z — 402fb4d5 (claude)

- [ ] Important: A nonexistent or unreadable `cwd` counts as personal. `git rev-parse` fails, so `inside_git?` is false and the hook gives a persona. This breaks the fail-closed rule for any session whose cwd git cannot read. Reproduced with `{"cwd":"/nonexistent"}` — `claude/.claude/hooks/agent-voice.rb:45` → fixed (Make agent-voice fail closed on bad cwd, bad session id and bad persona data)
- [ ] Nit: A non-string `session_id` (for example `5`) raises `TypeError` in `Zlib.crc32` and exits 1, against the "always exit 0" design. Same class as round 1 but a different input — `claude/.claude/hooks/agent-voice.rb:52` → fixed (Make agent-voice fail closed on bad cwd, bad session id and bad persona data)
- [ ] Nit: Compliance: all 22 tests exist and pass, every acceptance criterion and `## Proof` test is present, nothing weakened. The plan's step 8 live `claude -p` and `codex exec` evidence is not in the change folder — `docs/changes/fun-agent-voice/plan.md:1` → dismissed: the live claude and codex evidence sits in the implement report and goes into the PR description; deliver removes this folder.


## Round 3 — 2026-10-20 08:02Z — ae322094 (codex)

No findings.

## Round 4 — 2026-10-20 08:10Z — ae322094 (claude)

Closures checked: rounds 1 and 2 hold (bad persona data, nonexistent cwd and non-string session_id all exit 0 with no output; 25 tests green, rubocop clean). The round 2 compliance dismissal stands.

- [ ] Nit: Hook input that parses as JSON but is not an object (`[]`, `5`) or has a non-string `cwd` (`{"cwd":5}`) raises `TypeError` and exits 1, against the "always exit 0" design. Same class as rounds 1 and 2 — `claude/.claude/hooks/agent-voice.rb:70` → fixed (Exit quietly on hook input that is not a JSON object or has a bad cwd)


## Round 5 — 2026-10-20 08:13Z — 79b358ff (codex)

No findings.

## Round 6 — 2026-10-20 08:14Z — 79b358ff (claude)

Closures checked: the round 4 nit holds (`[]`, `5`, `{"cwd":5}`, `/nonexistent` and unparsable input all exit 0 with no persona; tests and rubocop green). All earlier closures stand.

No findings.


## Round 7 — 2026-10-20 09:20Z — 25be16df (codex)

No findings.


## Round 8 — 2026-10-20 09:40Z — 25be16df (claude)

No findings.

Checked: catchphrase counts within the new cap of 8 (Peon 7, Deekin 6, minion 5); Thrall line removed; plan and test cap agree; new tests present; 29 tests green.
