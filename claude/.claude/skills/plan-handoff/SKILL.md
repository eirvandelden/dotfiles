---
name: plan-handoff
description: Use when asked to write a plan for another agent, critically review an existing plan, or execute a handed-over plan.
---

# Plan Handoff (multi-agent workflow)

Three roles. Do only the one asked for.

## Writing a plan for another agent

- The plan is the only context the executor gets: make it self-contained, no references back
  to this chat.
- Structure: context (why), concrete steps, files involved, verification steps, and an explicit
  out-of-scope list.
- Phased plans: one file per phase named `nn-phase-slug.md` when the repo has a `docs/plans`
  convention; each phase states which decisions need a conversation with the user before work
  starts.
- When the plan should apply to several apps, keep it app-agnostic.
- Writing a plan is not permission to implement it or hand it off — deliver the plan and stop.

## Critically reviewing a plan

- Read the plan, then read the actual code it touches. Be very critical: does the approach
  hold? Can we do better?
- Verify the plan's claims against the code. Report disagreements with reasons and propose
  the better alternative.

## Executing a handed-over plan

- Read the applicable `agents.md` fully first, following links.
- Execute only the assigned phase or scope — nothing beyond it, no handing work onward.
- An approved plan means: stop asking what to do next; work through it.
- When the plan no longer matches reality (e.g. main moved), rebase, re-verify the plan against
  the current code, and report differences instead of improvising.
- Done = all tests green, all linters green, self-reviewed diff (playbook §7).
