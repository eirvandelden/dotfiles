---
name: intent
description: Use when a request would change code — a bug, a feature, a refactor, a config change — before any code or plan exists. Interviews until nothing is ambiguous about the problem, outcome, scope and acceptance criteria, then writes docs/changes/<slug>/intent.md.
arguments:
  - name: backend
    description: "(default) interview in this session, unchanged; \"handoff <slug-or-issue>\": start a fresh Opus pane below instead, rooted in a new worktree."
---

<!--
Interview technique adapted from the superpowers-ruby `brainstorming` skill
(~/.claude/plugins/cache/superpowers-ruby/superpowers-ruby/7.5.0/skills/brainstorming/SKILL.md,
2026-09 vendored version): one question at a time, multiple choice where possible, problem
before solution, the "too simple to need this" anti-pattern, the red-flags list, persist the
draft as you go. Left out: the design/architecture exploration (that is the `plan` skill), the
hand-off to `writing-plans` (that is the `plan` skill), and the visual companion. Re-sync against
upstream by diffing this file's interview section against that one.
-->

# Intent

Every change that touches code starts here — a bug, a feature, a refactor, a config change. Personal or work, trivial or not. This skill interviews for the problem, the proposed outcome, the scope boundaries and the acceptance criteria, then writes `docs/changes/<slug>/intent.md`. It never proposes a solution; that is `plan`'s job.

## Choosing a backend

- No argument: interview in the current session, unchanged — this is intent's usual path.
- `handoff <slug-or-issue>`: start a fresh Opus pane below instead, rooted in a new worktree; the interview happens there, not in this session.

## Pane backend

Resolve `<slug-or-issue>` into the final branch/folder slug the same way step 1 below does (an issue number or URL: `gh issue view <number> --json title,body,labels` for `<issue-number>-<issue-title-in-kebab-case>`; anything else: the kebab-case slug as-is). Then, from anywhere inside the repository:

```bash
~/.config/herdr/scripts/hand-off-plan.sh intent <slug>
```

The script creates `.worktrees/<slug>`, splits a pane below the caller, and starts a fresh Opus agent there, rooted in that worktree, told to invoke this skill for `docs/changes/<slug>` — there is no upstream artifact yet, so its interview is what creates `intent.md`. Tell the user which worker took it and where its report will land, then carry on: the interview that follows is that pane's own.

The pane writes `intent.md`, and once Etienne says "accepted" or "agreed", commits it alone, pushes the branch, writes a short report to the shared git directory, and sends one line back: `Intent ready: <path>`. It arrives as an ordinary message, possibly mid other work, and retries while the caller is busy — but the report is never lost, since the path was printed when the pane started. Read the file and tell the user what came back.

## Anti-pattern: "this one is too simple to need an intent"

Every change gets one. A three-line intent for a one-line fix is still an intent — write it, get it accepted, move on. The changes that skip this step are exactly the ones where an unexamined assumption costs the most: "fix the typo" turns out to touch three files because nobody asked which typo.

## 1. Find the folder

- If a GitHub issue number or URL was given, or the user names one when asked, read it: `gh issue view <number> --json title,body,labels`. Its title and body seed the interview; its labels are a candidate for `Type:`, confirmed with the user rather than assumed.
- No issue: ask for one. If there truly is none, a kebab-case task slug stands in for it.
- Derive the branch/folder name the same way `worktree-first` does: with an issue, `<issue-number>-<issue-title-in-kebab-case>`, the name GitHub's "Create a branch" button would generate; without one, the kebab-case slug. No prefix either way.
- Check where this session already is:
  - Inside a linked worktree whose branch already matches that name: write here.
  - Anywhere else (the main checkout, or a worktree on a different branch): invoke `worktree-first` in its no-pane mode (`--no-pane`) with the derived name before writing anything. It creates `.worktrees/<name>` off `origin/main`, opens no pane, and this skill continues inside it. The pane backend is the only intent path that opens a pane.
- Never create the branch or the folder from the main checkout.

## 2. Interview

One question at a time; prefer multiple choice (use `AskUserQuestion` where available). Explore the problem before any solution — if an answer describes a fix rather than a symptom, ask what a user or system cannot do today instead. There is no fixed question count: keep asking until every template section below can be filled without guessing. Cover:

1. What can someone not do today? (the problem, in the domain's words, not the fix)
2. What does better look like once this ships?
3. Who and what systems are affected?
4. What constrains the change (policy, compatibility, a deadline)? Where two constraints conflict, name the tradeoff and ask which side wins.
5. What is in scope?
6. What is explicitly out of scope?
7. What are the acceptance criteria — one concrete example per behaviour, in the domain's words, as a sentence a domain expert would agree with ("Paying empties the basket", not "calls Basket#pay")? A criterion that cannot be written as an example is not clear enough yet: ask for the example.

The interview ends when every template section can be filled without guessing. Until then, keep asking.

**Delivery mode.** Run `~/.claude/skills/finish/scripts/change-scope`. Offer autonomous delivery only when it prints `personal`; on `work`, or when it exits 1, skip this step and use the step-by-step flow. On `personal`, ask:

1. Which permissions will the change need? List gems or packages, system tools, migrations that drop or remove, and deploy files (playbook rules 8, 9, 11, 12, 13). Each one is approved now, or becomes a stop-and-ask later.
2. Autonomous delivery (playbook §7a: agents carry the change to a verified PR; you approve the intent and the merge) or step-by-step (you accept the plan too)?

Autonomous adds a `Delivery: autonomous` line next to `Status:` in `intent.md`, with the approved permissions under `## Constraints`.

Batch independent multiple-choice questions (up to 4) only when none of them would change another's answer; otherwise ask one at a time.

**Persist as you go**: write the draft `intent.md` as soon as the problem and outcome are clear enough to state, then refine it as remaining questions are answered. A dropped session resumes from the file, not from chat history.

## Red flags — stop and return to the interview

- About to write `intent.md` with no questions asked yet.
- About to write the file with no in-scope or out-of-scope question asked.
- The draft describes a solution ("add a background job") instead of a problem or outcome ("the export arrives by mail within a minute").
- Treating "sounds right" as "accepted" — only the words listed in step 4 flip the status.

## 3. Write `intent.md`

Template (playbook structure, `docs/changes/<slug>/intent.md`):

```markdown
# Intent: <title>

Author: <name>. Status: draft.

## Problem

<what can't happen today, in domain words>

## Proposed outcome

<what better looks like>

## Affected users and systems

<who and what>

## Constraints

<policy, compatibility, deadlines>

## In scope

<what the change must contain>

## Out of scope

<what it explicitly does not touch>

## Acceptance criteria

- <one concrete example per behaviour, in the domain's words>

## Flagged concerns

<constraints that conflict, with the tradeoff named and the side chosen — omit the section if there are none>

## Open questions

<anything unresolved — or "None.">
```

Add a `Type: feature|bugfix|refactor|chore` line next to `Status:` (and, for autonomous delivery, `Delivery: autonomous`) — ask, or infer from the issue's labels and confirm before writing it; a bugfix drives a stricter test rule later in `implement`.

Create the folder (`mkdir -p`) if it does not exist. Write the file.

## 4. Accept

Refuse to flip `Status:` to `accepted` while any of these holds, and name what is missing:

- `## Acceptance criteria` is missing or empty.
- `## Open questions` holds anything but "None.".
- A flagged concern names no chosen side.

Otherwise, on the words "accepted", "agreed", "accept the intent" or "agree the intent" (not "looks good", not "ok"): flip the `Status:` line to `accepted`, commit `intent.md` alone (`docs: intent for <slug>`), then push (`git push -u origin HEAD`).

- `intent.md` has `Delivery: autonomous`: do not chain to the plan stage by hand. Follow "Autonomous delivery" below.
- Otherwise, inside herdr (`HERDR_ENV` set), start the plan stage: `HERDR_PANE_ID=<coordinator> ~/.config/herdr/scripts/hand-off-plan.sh plan '<slug>'`, where `<coordinator>` is the pane id your starting prompt named if a stage pane started you, else your own `$HERDR_PANE_ID`. If that command fails, say so and do not retry — in a stage pane, in your report file, as your starting prompt says. Outside herdr, stop after the push.

## Autonomous delivery

Runs only when `intent.md` has `Delivery: autonomous`, which this skill writes only on a `personal` origin. This session is the coordinator. Etienne's "accepted" on the intent was the last approval before the PR, except the escalations below.

1. For each stage in order — `plan`, then `implement` — run `HERDR_PANE_ID=<own pane id> ~/.config/herdr/scripts/hand-off-plan.sh <stage> <slug> --auto`. Wait for that stage's `Plan ready:` or `Handoff done:` line, then read its report before starting the next stage.
2. A `Decision needed:` line in a report is an escalation (below). Settle it before the next stage.
3. Run the tests, the linters, Brakeman and Bundler Audit where the repository has them.
4. Exercise the behaviour as a human would, and record the evidence.
5. Review. Run `~/.config/herdr/scripts/start-review.sh` and `codex review --base <base>`. Transcribe the Codex output as its own round in `docs/changes/<slug>/review.md`, in the reviewer's format (see the `review` skill), and commit it alone, then push the branch (`git push -u origin HEAD`). Fix findings through `code-review`, then run both reviewers again, as the `review` skill's auto mode says. Repeat until a round of each reviewer leaves no open finding.
6. Follow `~/.claude/skills/finish/SKILL.md` in its auto mode.
7. Write the account — behaviour delivered, evidence, check results, review outcome, PR URL — to `<git-common-dir>/herdr/deliver-<slug>.md` and tell Etienne. Never merge.

A stage pane started by `hand-off-plan.sh intent` is still the coordinator: its starting prompt names another pane, but every stage gets this session's own pane id. That other pane receives only the account, as the single line `Delivery done: <account path>`, sent once the delivery ends; the account path also goes into the report file the starting prompt names.

Escalation: stop and ask Etienne one concrete question when a choice changes the agreed behaviour, a step needs a permission he has not approved, one problem fails three times, or a finding is still disputed after two rounds. A `Decision needed:` line in a stage report is how a pane raises one of these.

Outside herdr, or as a Codex coordinator, run each stage's `here` backend with the `auto` argument in sequence in this session instead of panes.

## Codex

Same interview and template. Invoked as `$intent`. Use `gh issue view` the same way; there is no `AskUserQuestion` tool, so number multiple-choice options in plain text instead. The default in-session interview is the only backend, since Codex has no herdr pane of its own; a Codex coordinator may still start a Claude intent pane through the same script, as `plan` and `implement` do today.
