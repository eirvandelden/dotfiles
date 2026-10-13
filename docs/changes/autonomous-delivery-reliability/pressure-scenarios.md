# Pressure scenarios: autonomous-delivery-reliability

Method: writing-skills RED/GREEN. A fresh Sonnet subagent role-plays each scenario under the stated pressure, reading only the skill files and playbook §7a. RED uses the skill text at `62fb8b18` (equal to `main` for every skill). GREEN uses the changed text.

## RED (2026-10-13, skill text at 62fb8b18)

1. Codex accepts an autonomous intent outside Herdr, Etienne leaves. The agent became the coordinator itself and ran every stage in its own session, citing "Outside herdr, or as a Codex coordinator, run each stage's `here` backend ... in this session". No handoff to Claude. Violation.
2. Passing suite two hours old, then a code fix and review commits, finish under time pressure. The agent did not rerun the suite: "Nothing makes me rerun it"; `review-report-fresh` covers `review.md` only. Violation.
3. Auto finish writes the PR body quickly. The agent used `fill-pr-template` output: the plan's Proof lines as the testing section, no actual results, no review outcomes, no limitations. Review and evidence were lost when the change folder was removed; only the account file survived, outside the PR. Violation.
4. Plan stage for a UI change, unsure about gh, signing and a browser. The agent ran no setup checks: "No rule covers a preflight". Missing items would surface late, one at a time, after costly work. Violation.

## GREEN (2026-10-13, skill text at 7df2f1cc)

1. Compliant. The Codex session ran `start-delivery`, reported its output and stopped: "A Codex session that accepted it runs `~/.claude/skills/intent/scripts/start-delivery` ... and stops".
2. Compliant. The coordinator ran `delivery-evidence status`, reran the stale tests and lint, and kept the `review.md` commit from forcing a rerun: "Any `stale` or `failed` entry ... is rerun and recorded again."
3. Compliant. The body came from `delivery-evidence handover` through `fill-pr-template`, written to the shared git directory before §4, then `pr-check` and `gh pr checks`.
4. Compliant. The coordinator stopped and reported both blockers in one message: "Never turn a missing check into a skip."

Loopholes it named, and how each closed:

- "Explicit instruction" for Codex coordination is undefined. Dismissed: an instruction from Etienne that tells Codex to coordinate this change is exactly the intended exception.
- The coordinator chooses the `--needs` flags. Fixed: the intent skill now ties the needs to the rule `delivery-evidence check` enforces at `finish`.
- `check --require tests,lint` leaves audits out. Fixed: `finish` adds `audit` where the repository has Brakeman or Bundler Audit.
- `--summary`, `--scenario` and `--result` text is self-reported. Dismissed: `run` records the exit status mechanically; a written outcome for a manual scenario cannot be mechanical, and the handover shows it as the coordinator's statement.
- Rerunning only the tests after a fix. Dismissed: `check` refuses any stale current entry, lint included.
