# Spec: Codex stops asking for approval of routine commands

From `intent.md` (2026-10-02). Status: accepted.

## Flagged concerns

- Rule 6 (GitHub consent) and the new reviewer overlap. The `prompt` rules for `gh pr comment`, `gh pr review` and `gh issue comment` ask Etienne today. Whether such a `prompt` rule still reaches Etienne when `approvals_reviewer = "auto_review"` is on is not probed yet. The plan stage must probe it. If the reviewer replaces the prompt, the consent guard hook must block these three commands, because rule 6 keeps its meaning.
- Rule 19 (push only to owned remotes) has no hook-level equivalent for a push to a foreign remote. The consent guard enforces it in both tools, so the guard stays the hard stop. The reviewer is a second layer, not the first.
- The reviewer is a model. It can approve a command that the playbook reserves for Etienne. Only the hook and the `forbidden` rules are deterministic. This change does not move any reserved command from the guard to the reviewer.

## Requirements

1. `codex/.codex/config.toml` sets `approvals_reviewer = "auto_review"`.
2. `approval_policy` stays `on-request` and `sandbox_mode` stays `workspace-write`. Sandbox settings are not widened.
3. An escalated routine command runs without a prompt to Etienne. Routine means git writes, herdr pane calls and `gh` reads and PR writes that the playbook permits.
4. The commands that the playbook reserves for Etienne still stop. These are plain `git push --force`, pushes to remotes he does not own, `gh pr comment`, `gh pr review`, `gh issue comment`, deploys and destructive database commands.
5. When the reviewer denies a command, Codex returns the denial to the model. The model may use a safer alternative or ask Etienne in chat. Codex does not open an approval prompt for a denied command.
6. The `prompt` and `forbidden` rules in `rules/default.rules` stay. The existing `allow` rules stay too, because they still skip the prompt for commands that run inside the sandbox.
7. The change adds no work names, repositories or remotes, and adds no dependency.
8. A test pins the setting and the rule that goes with it, so a later edit cannot silently remove either.

## Design decisions

- Use the Codex feature `approvals_reviewer = "auto_review"`. A probe against codex 0.160.0 confirmed it. With it set and the sandbox blocking `git commit`, Codex reran the commit with `require_escalated` and the commit ran. No approval reached Etienne. Without the reviewer, the same escalation prompts.
- The open question on denial is settled by the text that Codex 0.160.0 ships for this mode. It says that after a rejection the model "can continue with a safer alternative" and must "ask for approval" from the user if the action stays blocked. So a denial is not a silent refusal and not an automatic prompt. The model decides.
- A direct probe of a denial was not possible. The model refused unsafe escalations itself before the reviewer saw them. The plan stage should re-check the denial path with a command the model does submit.
- Keep the guard hook as the deterministic layer. The reviewer only replaces the human click for commands that the guard and the rules let through.
- Do not add more `allow` rules. They do not help for escalated commands, which is the whole problem.
- Config only: one setting in `config.toml`, one test. No change to the hook, lefthook or the sandbox.

## Integration points

- `codex/.codex/config.toml`: the new setting beside `approval_policy`.
- `codex/.codex/rules/default.rules`: unchanged. Codex still appends rules there.
- `claude/.claude/hooks/consent-guard.rb`: unchanged, unless the plan-stage probe shows that the `gh` comment commands lose their prompt (see Flagged concerns).
- `test/guard_parity_test.rb`: the existing parity test is the model for the new test.
- Clients that read this file through the app-server: terminal `codex`, the ChatGPT desktop app, `codex exec`.

## Acceptance criteria

- Codex config selects the automatic reviewer for approvals.
- Codex config still asks for approval on request and still runs in the workspace-write sandbox.
- A commit that the sandbox blocks runs after an escalation, and Etienne sees no prompt.
- Plain `git push --force` is still refused by the consent guard.
- A push to a remote that Etienne does not own is still stopped.
- `gh pr comment`, `gh pr review` and `gh issue comment` still need Etienne's consent.
- When the reviewer denies a command, the model receives the denial and Etienne sees no approval prompt for it.
- Deploy commands and destructive database commands still need Etienne's consent.
- The committed Codex config and rules contain no work names, repositories or remotes.

---
Domain skills applied: None.
