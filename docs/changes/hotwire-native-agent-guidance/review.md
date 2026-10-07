# Review: Hotwire Native agent guidance

## Round 1 — 2026-10-07T07:40:51Z — 6f774a05

- [ ] Important: Representative Claude and Codex sessions remain unverified (A1, A2, A15). The tests check guidance text, not whether either agent discovers the skill, selects the platform reference, preserves versions, or requests missing targets. Run the scratch-project sessions required by the plan and retain their outputs before claiming those criteria pass. — `docs/changes/hotwire-native-agent-guidance/plan.md:101` →
- [ ] Important: A13 and A17 lack acceptance evidence. The registered MCP server's build and simulator tool list remains pending installation. The supplied private denylist is unavailable, so the prescribed public-diff privacy audit cannot be completed. Keep both criteria pending until their respective outputs exist; the implementation report's partial search does not prove A17. — `docs/changes/hotwire-native-agent-guidance/plan.md:141` →
- [ ] Nit: The accepted plan still names the removed `spec` skill, cspell, and `project-dictionary.txt`, including an eight-file exception check. The implementation correctly follows current main, but the plan does not record those departures. Update its paths, validation commands, and Proof inventory to match the seven existing instruction files. — `docs/changes/hotwire-native-agent-guidance/plan.md:94` →

### Evidence and compliance

No root `REVIEW.md` or `REVIEW.local.md` exists. This round uses the repository's review policy template: Bugs, Security, Compliance.

Reviewed the committed diff against `origin/main`, plus the clean worktree. The coordinator fetched origin successfully and confirmed `origin/main` remains `58dab0a30c329094ec495632503f42a2326adeea`.

The four new test files, skill parity, and Codex agent generation pass together: 37 runs, 314 assertions, zero failures, errors, or skips. The coordinator's full suite exits successfully: 371 runs, 1429 assertions, zero failures, zero errors, and two skips. `git diff --check` and yamllint pass. The coordinator's Rubocop run with `--cache false` passes all four new test files with no offenses.

| Intent success criterion | Proof in this diff | Remaining evidence |
| --- | --- | --- |
| Both agents find mobile guidance and choose native UI, bridge, and regression validation | `hotwire_native_skill_test.rb` covers routing and validation rows; `skill_parity_test.rb` covers discovery layout | Representative agent sessions are missing, as reported above |
| Colleagues obtain application guidance from the shared repository alone | Outside this public repository implementation | Verify the separate application repository change |
| Simple wiring avoids invented tests; logic and security retain automated tests | `mobile_testing_exception_test.rb` covers seven instruction files; `hotwire_native_skill_test.rb` covers the matrix | No existing test is weakened, skipped, or deleted |
| Public guidance remains reusable and private setup stays private | The authored mobile files contain generic targets and commands | A17's supplied-denylist audit remains pending |
| Tooling builds and inspects the intended target without guesses | `mobile_tooling_test.rb` checks pinned version and telemetry parity; `hotwire_native_skill_test.rb` checks targeting instructions | Live MCP tool listing and representative targeting sessions remain pending |

Every automated test named in the Proof list exists. The removed `spec` skill explains the seven-file implementation but needs the plan correction above. A18's four resolved links are recorded in the implementation report. Snapshot licences and manifest entries exist. No additional actionable bug or security finding is established by this review.
