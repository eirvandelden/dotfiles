# Intent: Merge the spec step into intent

Author: Etienne van Delden. Status: accepted. Type: refactor.

## Problem

Every change passes through four stages: intent, spec, plan, implement. The spec stage adds a separate interview, pane and acceptance round, but its content mostly repeats or extends the intent. Etienne does not feel the need for it. At the same time, intent asks too few questions: it does not pin down what the change must and must not contain, so the boundaries of the work stay implicit.

Separately, a bug: running intent in the current session inside herdr opens an empty pane below. Intent creates the change's worktree, and that worktree gets a pane of its own. Nothing ever starts in that pane, so Etienne has to close it by hand.

## Proposed outcome

The workflow is intent → plan → implement. The spec stage no longer exists.

Intent interviews deeper. There is no fixed question count: it keeps asking until no ambiguity is left about the problem, the outcome, the boundaries and the acceptance criteria. It records what is in scope, what is explicitly out of scope, concrete acceptance criteria in domain words, and flagged concerns where constraints conflict. It refuses "accepted" while the outcome has no acceptance criterion. Plan reads intent directly and owns what spec held beyond that: design decisions, integration points and domain-skill input.

## Affected users and systems

- Etienne, in every personal and work repository that uses this workflow.
- Claude and Codex agents that run the `intent`, `plan`, `implement`, `review` and `finish` skills.
- The herdr stage panes started by `hand-off-plan.sh`.
- Agents and hooks that read `spec.md` today: reviewer, test-writer, the test guard.

## Constraints

- Claude and Codex stay at parity (shared skills, adapters only where formats differ).
- Past change folders, such as `docs/changes/ai-native-workflow/`, stay untouched.
- Intent still states problems and outcomes, never solutions.

## In scope

- Intent absorbs scope boundaries, acceptance criteria and flagged concerns, and the refusal to accept without acceptance criteria.
- The intent pane stays on Opus.
- Plan absorbs design decisions, integration points and domain skills.
- Intent run in the current session no longer opens a pane. Other callers of worktree creation keep today's behaviour.
- The `spec` skill is deleted, for Claude and Codex both. No redirect stub remains.
- Every live reference to the spec stage is removed or redirected to intent.

## Out of scope

- Rewriting or migrating existing `spec.md` files in past change folders.
- Pane behaviour of plan, implement, or a plain worktree setup outside intent.

## Acceptance criteria

- An intent interview asks about what is in and out of scope before it writes the file.
- Intent refuses "accepted" while it has no acceptance criteria, and names what is missing.
- Invoking `spec` finds no skill.
- Running intent in the current session inside herdr creates the worktree and opens no new pane.
- Intent's `handoff` backend still opens exactly one pane, with the agent in it.
- An accepted intent hands off straight to plan; no spec pane starts.
- Plan refuses to start without an accepted intent, and never asks for a spec.
- The reviewer and test-writer read acceptance criteria from intent, not spec.
- No live skill, agent, hook, script or playbook rule names the spec stage.

## Open questions

None.
