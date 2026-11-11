# Delivery: Keep design internals out of the PR body

## Behaviour delivered

`fill-pr-template` fills the PR body from the Summary, the Why and the plan's Design subsections `### Domain terms` and `### Diagrams`. The body no longer holds Signatures, Complexity, Invariants, Alternatives, Proof lines or the file list. A template heading with nothing to fill keeps its own text. The `deliver` skill states the rule once. The `plan` and `finish` skills and playbook rule 5 point to it.

## Evidence

- Ran `fill-pr-template` on this change's own `intent.md` and `plan.md`: the body holds Summary and Implementation with Domain terms and Diagrams, and no Signatures, Invariants, Proof or file list.
- The tests were red before the fix (13 failures on the old script) and green after.

## Check results

- `test/fill_pr_template_test.rb` and `test/deliver_test.rb`: 44 runs, 0 failures.
- `bin/test` in the worker run: 111 of 112 files pass. `test/secrets_loader_test.rb` fails because it needs 1Password vault items. It touches no changed file.
- rubocop: clean on every touched Ruby file. Lefthook passed on every commit and push.
- Not run: `steep check` (no Steep setup was checked); Brakeman and Bundler Audit (no Rails app in this repository).

## Review outcome

Claude reviewer round 1: 0 Important, 0 Nit. No Codex round, as the intent records.
