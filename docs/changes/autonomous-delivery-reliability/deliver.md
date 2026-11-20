# Delivery account: autonomous-delivery-reliability

## Behaviour delivered

- Claude coordinates personal autonomous delivery. A Codex session hands it over with `intent/scripts/start-delivery`, inside herdr (the `hand-off-plan` deliver stage opens a pane below) or outside it (a background `claude --bg` session).
- `intent/scripts/delivery-preflight` reports every setup item together as pass, missing or n/a, with a `Blockers:` summary.
- `finish/scripts/delivery-evidence` ties each check to the content it verified. A code change makes it stale. A commit that touches only the change folder does not.
- `deliver` refuses on missing, failed or stale evidence for an accepted autonomous intent, builds the draft PR body from the handover, and runs `pr-check` after the push.
- `fill-pr-template` takes the handover as an optional fourth argument.
- The playbook §7a and the `intent`, `plan`, `review`, `implement` and `deliver` skills describe the flow.

## Evidence

- Full suite minus `test/rubocop_fallback_test.rb`: 129 files, 0 failed, at the delivered revision. That file fails 16 of 16 on `main` too, because the `rubocop` binary prints gem warnings on stderr.
- Lint: RuboCop on 19 Ruby files, shellcheck on `hand-off-plan.sh`, markdownlint on 8 Markdown files. All clean.
- Manual exercises on fixtures, each recorded with `delivery-evidence`: preflight, `start-delivery` with a fake `claude`, one real `claude --bg` smoke start (id printed, stopped and removed), the evidence run, stale and handover cycle, and `fill-pr-template` with a handover.
- Pressure scenarios: RED all four violated, GREEN all four compliant.
- Brakeman and Bundler Audit do not apply: the repository has no `Gemfile.lock`.

## Review

- Round 1 (Claude) and round 2 (Codex): every finding fixed.
- Round 3 (Claude): two nits, one fixed, one dismissed with a reason.
- Round 4 (Claude): no findings.

## Notes

- The branch was rebased onto a moved `main`, where skills now live under `agents/.agents/skills/`. The evidence gate and handover moved into the `deliver` script (plan design decision 6).
