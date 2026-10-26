# Intent: Clear wording in agent questions

Author: Etienne van Delden de la Haije. Status: accepted. Type: feature. Delivery: autonomous. Codex review: no.

## Problem

Etienne cannot tell who "I" and "you" refer to in the multiple-choice questions agents ask. The question speaks as the agent, but each option is something Etienne picks, so the pronouns change meaning from line to line. An option such as "I do this and you do that" leaves open who acts.

## Proposed outcome

Every question and option names its actor. Etienne reads an option and knows what Claude does, what he does, and what the result is. A hook stops a question that breaks the pronoun rule, so the rule survives a forgetful session.

## Affected users and systems

- Etienne, as the reader of agent questions.
- Claude Code sessions: the `AskUserQuestion` tool and its `PreToolUse` hook.
- Codex sessions: plain-text numbered options, covered by the shared playbook rule only.
- `claude/.claude/PLAYBOOK.md` §7, `claude/.claude/core-values.yml`, `claude/.claude/settings.json`, `claude/.claude/hooks/`.

## Constraints

- No permission beyond the repository is needed: no gems, no system tools, no deploy files.
- The playbook is the source of truth; `core-values.yml` mirrors the rule, and both change together.
- One line per paragraph and list item in markdown prose.
- Hooks are Ruby, with tests, like the existing hooks in `claude/.claude/hooks/`.
- The hook stays Claude-only. Codex has no `AskUserQuestion` tool.

## In scope

- A playbook §7 rule with five parts:
  - Name the actor. No "I" or "you" in a question or option label.
  - Write each option label as an order to Claude.
  - Each option description has "Claude does:", "You do:" and "Result:" lines.
  - Put the recommendation first, with one reason.
  - Use a preview with `[Claude]` and `[You]` tagged lines for single-select questions with side effects: push, delete, install, config and deploy decisions.
- The same rule in `core-values.yml`.
- A `PreToolUse` hook on `AskUserQuestion`, registered in `settings.json`, with tests.
- The hook checks the question text and the option labels only. It denies the call and tells Claude to rewrite.
- Default hook behaviour, stated rather than asked:
  - Match whole words, ignoring case: I, I'll, I'm, I've, me, my, you, you'll, your, yours.
  - Ignore text inside backticks.
  - Allow the call when the hook input is malformed or the hook errors. A broken hook never blocks Etienne.
- The same wording rules apply to Codex's numbered plain-text options, through the shared playbook.

## Out of scope

- One decision per question. Etienne did not choose it.
- The hook does not check the option template ("Claude does:", "You do:", "Result:"). The playbook rule covers it.
- The hook does not check option descriptions.
- A hook for Codex.
- Changing how any skill phrases its own questions. Skills pick up the rule through the playbook.
- Rewriting past questions or existing skill text.

## Acceptance criteria

- A question that says "Should I rebase the branch?" is denied, and Claude gets a message that names the banned word.
- An option label "I'll push first" is denied.
- An option label "Rebase onto main" with the description "Claude does: rebases. You do: nothing. Result: linear history." is allowed.
- A description that contains "You do: nothing" is allowed.
- A label with the command `git rebase` in backticks is allowed. A label that has "I" only inside backticks is allowed.
- A call whose input is malformed is allowed.
- A call to any tool other than `AskUserQuestion` is untouched.
- The playbook rule and the `core-values.yml` mirror say the same thing, and a session start injects the rule.

## Flagged concerns

None.

## Decisions

- No GitHub issue; the slug is `clear-ask-user-question-wording` — no issue exists.
- Add the enforcement hook — a rule alone can be forgotten, the hook cannot.
- Apply the wording rules to Codex through the shared playbook — parity goal, shared once.
- The hook checks the question and the labels only — descriptions need "You do:", and a scan there would cause false positives.
- The hook checks pronouns only, not the template — keeps the hook simple, the playbook covers the template.
- Previews are for single-select questions with side effects — previews only where they pay off.
- No extra permission is needed — the change stays inside the repository.
- Delivery is autonomous, without Codex review — two gates, fewer tokens.

## Open questions

None.
