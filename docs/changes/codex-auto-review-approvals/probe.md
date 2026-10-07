# Probe record: codex-auto-review-approvals

Run 2026-10-06 with codex-cli 0.160.1 (the plan named 0.160.0), `codex exec --json` in a scratch git repository outside this repository, with `-c 'approvals_reviewer="auto_review"'`. The live `~/.codex/config.toml` links to the main checkout, which does not have the new line yet, so the flag stands in for the committed setting. `codex exec` waits on stdin unless it is closed: run it with `</dev/null`. The JSON event stream has no approval or reviewer event type, so "no approval request" means that no command stalled and no event of that kind appeared.

## 1. Routine escalation: git commit

- Attempt 1, prompt "run git add && git commit": the model did not request escalation. The sandbox refused `.git/index.lock`. This confirms the sandbox problem in `intent.md`.
- Attempt 2, the prompt told the model to escalate: `git add` and `git commit` ran in `.git` with no approval request. The commit then failed on the 1Password SSH signer, which cannot sign headless. Not a reviewer effect.
- Attempt 3, the same with `-c commit.gpgsign=false`: the commit landed (`03b11be add b`), with no approval request in the event stream.
- Result: an escalated git write runs without asking Etienne. The reviewer's own approval is not visible in `codex exec` output.

## 2. Prompt rule: rm

- `rm scratch.txt` in the workspace ran at once, exit 0, no prompt and no approval event. The `prompt` rule did not stop it, or it did not reach the user.
- Etienne accepts either outcome for `rm` (decision 2026-10-05). Recorded only.

## 3. Guarded command: gh pr comment

Not run. Claude Code's auto-mode classifier denied the batch that held it, as an external write. Run it by hand: `codex exec ... "Run exactly: gh pr comment 1 --body hi"` in a scratch repository. Expect the consent guard refusal text. The unit tests cover the guard side: `test_github_comments_and_reviews_as_the_user_are_blocked` and `test_a_codex_payload_is_refused_with_the_same_message_as_a_claude_payload`.

## 4. Denial: write outside the workspace

Not run, for the same reason as probe 3 (it was in the denied batch). Run it by hand with a scratch file under `$HOME`. Expect a reviewer denial that returns to the model, and no approval request to Etienne.
