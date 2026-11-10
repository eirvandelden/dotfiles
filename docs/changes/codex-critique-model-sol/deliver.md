# Delivery account: codex-critique-model-sol

## Behaviour delivered

- A Claude author runs the Codex plan critique with `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium`. The plan skill (auto mode, `## Critique`, `## Codex`) and playbook §7a say so.
- The speed-run reviewer line names GPT Sol instead of GPT Terra.
- `test/autonomy_contract_test.rb` pins the command through one constant, `CODEX_CRITIQUE`, and has a new test for playbook §7a.

## Evidence

- The new tests failed before the text edits and passed after.
- `bin/test test/autonomy_contract_test.rb`: 39 runs, 0 failures.
- `git grep "codex exec -p terra"` and `git grep "GPT Terra"` outside `docs/changes`: no output.
- `codex exec --help` confirms `-m` and `-c`. `~/.codex/models_cache.json` lists `gpt-6.1-sol` with `medium`.

## Check results

- rubocop, no-hardwrap: green in the pre-commit and pre-push hooks.
- Full `bin/test`: 104 of 105 files pass. `test/secrets_loader_test.rb` fails 5 tests because the real `op` runs instead of the test stub in the agent session. It fails the same way on the main checkout. This change touches no secrets file. A separate look is still open under playbook rule 25.
- Brakeman and Bundler Audit: not applicable, the repository has no Gemfile for them.

## Review outcome

- Claude reviewer, round 1: no findings. No Codex review, as `intent.md` records.
