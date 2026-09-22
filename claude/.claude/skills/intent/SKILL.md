---
name: intent
description: Use when a request would change code — a bug, a feature, a refactor, a config change — before any code, spec, or plan exists. Interviews for the problem and proposed outcome, then writes docs/changes/<slug>/intent.md.
---

<!--
Interview technique adapted from the superpowers-ruby `brainstorming` skill
(~/.claude/plugins/cache/superpowers-ruby/superpowers-ruby/7.5.0/skills/brainstorming/SKILL.md,
2026-09 vendored version): one question at a time, multiple choice where possible, problem
before solution, the "too simple to need this" anti-pattern, the red-flags list, persist the
draft as you go. Left out: the design/architecture exploration (that is the `spec` skill), the
hand-off to `writing-plans` (that is the `plan` skill), and the visual companion. Re-sync against
upstream by diffing this file's interview section against that one.
-->

# Intent

Every change that touches code starts here — a bug, a feature, a refactor, a config change.
Personal or work, trivial or not. This skill interviews for the problem and the proposed
outcome, then writes `docs/changes/<slug>/intent.md`. It never proposes a solution; that is
`spec`'s job.

## Anti-pattern: "this one is too simple to need an intent"

Every change gets one. A three-line intent for a one-line fix is still an intent — write it, get
it accepted, move on. The changes that skip this step are exactly the ones where an unexamined
assumption costs the most: "fix the typo" turns out to touch three files because nobody asked
which typo.

## 1. Find the folder

- If a GitHub issue number or URL was given, or the user names one when asked, read it:
  `gh issue view <number> --json title,body,labels`. Its title and body seed the interview; its
  labels are a candidate for `Type:`, confirmed with the user rather than assumed.
- No issue: ask for one. If there truly is none, a kebab-case task slug stands in for it.
- Derive the branch/folder name the same way `worktree-first` does: with an issue,
  `<issue-number>-<issue-title-in-kebab-case>`, the name GitHub's "Create a branch" button
  would generate; without one, the kebab-case slug. No prefix either way.
- Check where this session already is:
  - Inside a linked worktree whose branch already matches that name: write here.
  - Anywhere else (the main checkout, or a worktree on a different branch): invoke
    `worktree-first` with the derived name before writing anything. It creates
    `.worktrees/<name>` off `origin/main` and this skill continues inside it.
- Never create the branch or the folder from the main checkout.

## 2. Interview

One question at a time; prefer multiple choice (use `AskUserQuestion` where available). Explore
the problem before any solution — if an answer describes a fix rather than a symptom, ask what a
user or system cannot do today instead. Three to five questions is typical:

1. What can someone not do today? (the problem, in the domain's words, not the fix)
2. What does better look like once this ships?
3. Who and what systems are affected?
4. What constrains the change (policy, compatibility, a deadline)?
5. What does success look like — how would you know it worked?

Batch independent multiple-choice questions (up to 4) only when none of them would change
another's answer; otherwise ask one at a time.

**Persist as you go**: write the draft `intent.md` as soon as the problem and outcome are clear
enough to state, then refine it as remaining questions are answered. A dropped session resumes
from the file, not from chat history.

## Red flags — stop and return to the interview

- About to write `intent.md` with no questions asked yet.
- The draft describes a solution ("add a background job") instead of a problem or outcome
  ("the export arrives by mail within a minute").
- Treating "sounds right" as "accepted" — only the literal word "accepted" flips the status.

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

## Open questions

<anything unresolved — or "None.">
```

Add a `Type: feature|bugfix|refactor|chore` line next to `Status:` — ask, or infer from the
issue's labels and confirm before writing it; a bugfix drives a stricter test rule later in
`implement`.

Create the folder (`mkdir -p`) if it does not exist. Write the file. Do not `git add` it — the
user or the `implement` skill commits.

## 4. Accept

On the words "accepted" or "accept the intent" (not "looks good", not "ok"): flip the `Status:`
line to `accepted`. Nothing else changes state.

## Codex

Same interview and template. Invoked as `$intent`. Use `gh issue view` the same way; there is no
`AskUserQuestion` tool, so number multiple-choice options in plain text instead.
