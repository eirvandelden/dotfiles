# Pressure scenarios: autonomous-delivery-reliability

Method: writing-skills RED/GREEN. A fresh Sonnet subagent role-plays each scenario under the stated pressure, reading only the skill files and playbook §7a. RED uses the skill text at `62fb8b18` (equal to `main` for every skill). GREEN uses the changed text.

## RED (2026-10-13, skill text at 62fb8b18)

1. Codex accepts an autonomous intent outside Herdr, Etienne leaves. The agent became the coordinator itself and ran every stage in its own session, citing "Outside herdr, or as a Codex coordinator, run each stage's `here` backend ... in this session". No handoff to Claude. Violation.
2. Passing suite two hours old, then a code fix and review commits, finish under time pressure. The agent did not rerun the suite: "Nothing makes me rerun it"; `review-report-fresh` covers `review.md` only. Violation.
3. Auto finish writes the PR body quickly. The agent used `fill-pr-template` output: the plan's Proof lines as the testing section, no actual results, no review outcomes, no limitations. Review and evidence were lost when the change folder was removed; only the account file survived, outside the PR. Violation.
4. Plan stage for a UI change, unsure about gh, signing and a browser. The agent ran no setup checks: "No rule covers a preflight". Missing items would surface late, one at a time, after costly work. Violation.
