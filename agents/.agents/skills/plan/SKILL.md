---
name: plan
description: Use when a request would change code — a bug, a feature, a refactor, a config change — before any code exists. Interviews one question at a time, writes docs/changes/<slug>/plan.md (intent sections, design, proof), critically reviews an existing plan, or absorbs a plan another agent should execute.
arguments:
  - name: backend
    description: "(default) interview and plan in this session; \"pane\": start a fresh Opus pane below via hand-off-plan, rooted in a new worktree; \"here\": work in this session; \"here auto\": draft and critique without Etienne on a personal autonomous change."
---

# Plan

Every change that touches code starts here — a bug, a feature, a refactor, a config change. Personal or work, trivial or not. Three roles. Do only the one asked for.

## Write

One document per change: `docs/changes/<slug>/plan.md`. Its header holds `Status`, `Type`, `Delivery` and `Codex review`. Its first sections hold the intent: problem, outcome, scope and acceptance criteria. The design and the proof follow. The plan's signatures, invariants, alternatives, proof and file list stay in `plan.md`; the PR body never holds them. See the `deliver` skill, "PR body".

### Anti-pattern: "this one is too simple to need a plan"

Every change gets one. A one-line plan for a one-line fix is still a plan — write it, get it accepted, move on. The changes that skip this step are exactly the ones where an unexamined assumption costs the most: "fix the typo" turns out to touch three files because nobody asked which typo.

### Choosing a backend

- No argument: work in this session. The interview and the draft run in plan mode.
- `pane`, or from a coordinator that must stay free: pane backend, below.
- `here`, or `HERDR_ENV`, `HC_TERMINAL_ID` and `REX_SESSION` unset: work in this session. Outside herdr, herdr-app and Rex this is the only option — say so in one line before starting, so the pane behaviour isn't silently missed.

### Pane backend

```bash
~/.agents/bin/hand-off-plan plan <slug>
```

Run it from anywhere inside the repository. The script creates `.worktrees/<slug>` if it does not exist yet, opens a pane below the caller as a new row, and starts a fresh Opus agent there in plan mode (`--permission-mode plan`), rooted in that worktree, told to invoke this skill's `here` backend for `docs/changes/<slug>` — there is no `plan.md` yet, so its interview is what creates it. Tell the user which worker took the plan stage and where its report will land, then carry on: the interview that follows is that pane's own.

`<slug>` must equal the branch name — the naming rule forbids a prefixed branch, and the script only reuses an existing `.worktrees/<slug>` when it is already checked out on that branch, refusing otherwise.

The pane interviews, drafts `plan.md`, and once the plan is accepted commits it through `commit-plan`, pushes the branch (on a work repository `commit-plan` commits nothing and the pane pushes nothing), writes a short report to the shared git directory, and sends one line back: `Plan ready: <path>`. It arrives as an ordinary message, possibly mid other work, and retries while the caller is busy — but the report is never lost, since the path was printed when the pane started. In herdr-app it arrives inside an `<hc from=…>` tag, as `<hc from="t61 …">Plan ready: <path></hc>`: the line inside the tag is the report line. Read the file and tell the user what came back.

### `here` backend

Claude runs this in plan mode: this is where the repository gets read and the approach gets decided, so nothing is edited until the user accepts. Not already in plan mode: call `EnterPlanMode` before reading code (Codex: there is no plan mode, so the literal word is the gate). Plan mode may allow writing only its own plan file. The draft then lives in that file, under `~/.claude/plans/`, until approval; a dropped session resumes from there, not from `plan.md`. Codex and auto mode write `plan.md` as a draft straight away.

#### 1. Find the folder

- If a GitHub issue number or URL was given, or the user names one when asked, read it: `gh issue view <number> --json title,body,labels`. Its title and body seed the interview; its labels are a candidate for `Type:`, confirmed with the user rather than assumed. An issue may be written intent-shaped: problem, outcome, scope, acceptance criteria.
- No issue: ask for one. If there truly is none, a kebab-case task slug stands in for it.
- Derive the branch/folder name the same way `worktree-first` does: with an issue, `<issue-number>-<issue-title-in-kebab-case>`, the name GitHub's "Create a branch" button would generate; without one, the kebab-case slug. No prefix either way.
- Check where this session already is:
  - Inside a linked worktree whose branch already matches that name: write here.
  - Anywhere else (the main checkout, or a worktree on a different branch): invoke `worktree-first` in its no-pane mode (`--no-pane`) with the derived name before writing anything. It creates `.worktrees/<name>` off `origin/main`, opens no pane, and this skill continues inside it. The pane backend is the only plan path that opens a pane.
- Never create the branch or the folder from the main checkout.

#### 2. Interview

The interview is the `brainstorming` skill: one question at a time, problem before solution, approaches with trade-offs, the design presented in sections. This skill adds the rules below. It never proposes a solution before the problem is clear.

**Explore first.** Before the first interview question, `Type:` included, read what the repository already answers: the issue, the files the request names or implies, nearby docs, `git log --oneline -20` on those paths, and the current behaviour (run it when that is cheap and safe). State what you found as premises the user can correct. Ask only what the repository cannot answer.

**Scope check.** Before refining details, flag a request that bundles independent changes. Two changes are independent when either one could ship and be useful without the other. Propose the split, one plan per change, each with its own slug and worktree. Continue the interview with the first change only.

**Depth by type.** Settle `Type:` early: from the issue labels, confirmed with the user, or asked. `bugfix` and `chore` with a clear cause ask 1–3 questions and default the rest; state those defaults in the draft. `feature` and `refactor` cover the seven topics and the full **Probe** list below. A bug fix whose cause or scope is unclear is not clear: probe it like a feature.

One question at a time; prefer multiple choice (use `AskUserQuestion` where available). Explore the problem before any solution — if an answer describes a fix rather than a symptom, ask what a user or system cannot do today instead. For `feature` and `refactor` there is no fixed question count: keep asking until every template section below can be filled without guessing. Cover:

1. What can someone not do today? (the problem, in the domain's words, not the fix)
2. What does better look like once this ships?
3. Who and what systems are affected?
4. What constrains the change (policy, compatibility, a deadline)? Where two constraints conflict, name the tradeoff and ask which side wins.
5. What is in scope?
6. What is explicitly out of scope?
7. What are the acceptance criteria — one concrete example per behaviour, in the domain's words, as a sentence a domain expert would agree with ("Paying empties the basket", not "calls Basket#pay")? A criterion that cannot be written as an example is not clear enough yet: ask for the example.

**Probe.** For `feature` and `refactor`, go beyond the seven topics until each of these is answered or ruled out:

- Current behaviour today.
- Edge cases: empty, one, many, boundary values, concurrent use.
- Failure modes: a dependency that is missing, slow, refused or wrong.
- Existing patterns in the repository to follow or to break.
- One "what happens when X" question per acceptance criterion.
- Compatibility with existing data, config and callers.

**Record decisions.** Each time the user picks between options or overrides a default, add a line to `## Decisions` in the draft right away, as `- <decision, in the user's words or close to them> — <one-line rationale>`. A default you chose without asking is not a decision: it stays in the section it affects. Never invent a rationale: when the user gave no reason, ask for it in the same turn, and write "no reason given" if they decline.

The interview ends when every template section can be filled without guessing. Until then, keep asking.

**Glossary.** Read the repository glossary (`glossary` skill) before the first question. When a word in the request is one a term lists under `Avoid:`, name the glossary term and ask which one Etienne means. Note each new term he agrees; write it to the glossary when the plan is accepted.

**Delivery mode.** Run `~/.claude/skills/finish/scripts/change-scope`. Offer autonomous delivery only when it prints `personal`; on `work`, or when it exits 1, skip this step and use the step-by-step flow. On `personal`, ask:

1. Which permissions will the change need? List gems or packages, system tools, migrations that drop or remove, and deploy files (playbook rules 8, 9, 11, 12, 13). Each one is approved now, or becomes a stop-and-ask later.
2. Autonomous delivery (playbook §7a: agents carry the change to a verified PR; you accept the plan after its critique closes, and you approve the merge) or step-by-step (you accept the plan, then follow each stage)?
3. Only when autonomous is chosen: also review with Codex? Ask "Also review with Codex?" (default: no). Codex adds a second reviewer and costs extra tokens.

Autonomous adds `Delivery: autonomous` in the same paragraph as `Status:` in `plan.md`. Put it on the status line or immediately below, without a blank line. When autonomous is chosen, add `Codex review: yes` or `Codex review: no` the same way; the question applies only to autonomous delivery, so step-by-step plans carry no such field. Record approved permissions under `## Constraints`.

Header fields are `Author:`, `Status:`, `Type:`, `Delivery:` and `Codex review:`. Start each line at column zero; separate inline fields with a period and a space. An accepted status is `accepted` or `accepted (YYYY-MM-DD)`. Delivery is `autonomous` or `step-by-step`. Codex review is `yes` or `no`; a missing field means `no`. Conflicting Status or Delivery values refuse acceptance.

Batch independent multiple-choice questions (up to 4) only when none of them would change another's answer; otherwise ask one at a time.

**Persist as you go**: write the draft as soon as the problem and outcome are clear enough to state, then refine it as remaining questions are answered. A dropped session resumes from the file, not from chat history.

#### 3. Red flags — stop and return to the interview

- About to write the plan with no questions asked yet.
- About to write it with no in-scope or out-of-scope question asked.
- The intent sections describe a solution ("add a background job") instead of a problem or outcome ("the export arrives by mail within a minute").
- Treating "sounds right" as "accepted" — only the acceptance in step 7 flips the status.

#### 4. Design gate

Read the codebase enough to know which files change and in what order. Apply the domain skills that match the work (Rails architecture, API design, UI, dependencies, and so on). Flag conflicts they raise against each other or against the playbook in the plan, rather than silently picking a side. Also check every design decision and step against `## Decisions`. A conflict is never resolved silently: outside auto mode, name it in `## Design decisions` and raise it with the user before acceptance.

Before any file-level text, open the design discussion. Read the `software-design`, `glossary` and `diagrams` skills. Check every word of the intent sections against the glossary and ask about any avoided word. Generate the "before" picture of the touched objects yourself. Run two or three `architect` agents (the architects) in parallel, each with one different design goal, and give each the before picture. Show the design (domain terms, diagrams, signatures, complexity, invariants) and the two or three alternatives. Say why you reject all but one. Claude shows the alternatives with `AskUserQuestion` previews. Codex shows them as a numbered list with one fenced block each. Then stop and wait. The design moves on only on the user's literal word "agreed" or "accepted". Challenges and questions do not move it on. Write the agreed design into `## Design` of `plan.md`.

#### 5. Write `plan.md`

```markdown
# Plan: <title>

Author: <name>. Status: draft. Type: <feature|bugfix|refactor|chore>. Delivery: <step-by-step|autonomous>.

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

## Decisions

<each explicit user decision, in their words or close to them, with a one-line rationale — or "None.">

- <decision> — <one-line rationale>

## Open questions

<anything unresolved — or "None.">

## Design

### Domain terms

<terms from the glossary, and new ones>

### Diagrams

<Mermaid class diagram of the touched objects; ER, sequence or state diagram where they apply>

### Signatures

<each touched class with its one-line summary, then its public methods, each with an inline RBS comment (`#:`), as `ruby-style` says>

Checked by: steep check

### Complexity

<cost of each new path; queries per request>

### Invariants

<what must always hold, where it is enforced>

### Alternatives

<two or three designs; why all but one are rejected>

## Design decisions

<choices made and why, only where the interview left them open — and any conflict with `## Decisions`>

## Integration points

<other systems, APIs, or code this touches>

## Files that change

<path — what changes and why>

## Order of work

1. Write the acceptance test for the first acceptance criterion, run it, watch it fail.
2. <next step>
...

## Risks

<what could break, what was rejected and why>

## Proof

- <acceptance criterion> → `<test file>` `<test name>`
- Query count: <claim, for example "the board page runs three queries"> → `<test file>` `<test name>`
- Invariant: <statement>, enforced by <where> → `<test file>` `<test name>`
...

Per changed file, the unit tests expected, named as behaviour:
- `<file>`: `<Thing#does_this>`, `<refuses that>`, ...

Test setup: <fixtures, test data, faked boundaries — short; if this paragraph grows long,
the change is too big and should be split>

---
Domain skills applied: <list, or "None">.
```

`## Design` follows the intent sections and comes before `## Design decisions`. A subsection the change does not touch is one line: `Not affected: <why>.` A config tweak therefore shows six short lines. `### Signatures` ends with `Checked by: steep check`, or with `Not checked: <project> declined Steep and rbs_rails.` when the project declined. Signatures are inline RBS `#:` method type signatures above each `def`, never `sig/*.rbs` files.

Each design claim gets a Proof line after the acceptance criteria. A complexity claim about queries gets a `Query count:` line that names a query-count test. An invariant gets an `Invariant:` line that names where it is enforced and the test that proves it. `implement` builds these lines like any criterion.

`## Proof` is structured, not prose: one line per acceptance criterion naming the test file and test name that proves it, or, for a criterion that needs no test, the check that proves it, then per changed file the unit tests expected. Step 1 of `## Order of work` is the first failing acceptance test, run, watched fail — the walking skeleton — unless no criterion needs a test.

- Every code change has tests. Configuration has no tests.
- A new feature has an integration test that proves it works and keeps working. It also has unit tests of its public methods and classes.
- Test public methods and classes only. Private methods never get tests of their own.
- Tests may follow the code. A bug fix is the exception: its regression test comes first and fails before the fix.

A criterion that needs no test, such as a configuration change, has no test to name. Its Proof line names the check instead: `- <criterion> → check: <exact command or manual step>`. `## Order of work` then starts with the change, and the check runs after it.

Add a `Type: feature|bugfix|refactor|chore` field to the header (and, for autonomous delivery, `Delivery: autonomous` and `Codex review: yes|no`) — ask, or infer from the issue's labels and confirm before writing it; a bugfix drives a stricter test rule later in `implement`.

Create the folder (`mkdir -p`) if it does not exist. Self-contained, no chat references: a plan is the only context its executor gets, whether that is this same session later, a fresh worker pane, or another agent entirely. State context, concrete steps, files, verification, and an explicit out-of-scope list — nothing assumes the reader was in this conversation. Phased plans: one file per phase, each stating which decisions need a conversation with the user before that phase starts.

#### 6. Interrogate

Before offering acceptance, ask the user at least one interrogation question — "what could break", "what did you reject", "what's riskiest" — so the plan gets challenged before it is frozen. For anything non-trivial, offer a second-model critique (below) before acceptance.

#### 7. Accept

**Self-review.** Before the read-back, scan the draft for placeholders (`<...>`, "TBD", "TODO"), contradictions between sections, scope (more than one independent change) and ambiguous wording (an acceptance criterion with no concrete example). Fix what you find.

**Read-back.** Present the intent sections section by section, in template order, and correct each section the user disputes, updating the draft. For `bugfix` and `chore`, send one message that lists every section in order. For `feature` and `refactor`, confirm each section, or a small group of short sections, before moving on. The read-back is not counted as an interview question.

Refuse to accept while any of these holds, and name what is missing:

- `## Acceptance criteria` is missing or empty.
- `## Open questions` holds anything but "None.".
- A flagged concern names no chosen side.

The gate depends on the session:

- Claude, interactive: approving `ExitPlanMode` counts as "accepted", for a plan that is not autonomous only.
- Codex, or a pane where `ExitPlanMode` has no approver: the user's literal word "accepted" or "agreed", or "accept the plan" or "agree the plan" (not "looks good", not "ok").
- Autonomous delivery: Etienne types the literal word after the critique has closed, never `ExitPlanMode`. See "Interactive autonomous plan" and "Auto mode".

**Interactive autonomous plan.** When the interview picks `Delivery: autonomous` in an interactive Claude session, plan mode cannot run the critique. Claude leaves plan mode, and does not treat the `ExitPlanMode` approval as acceptance for this plan. It writes `plan.md` with `Status: draft`, then runs steps 1 to 3 of "Auto mode": the critique with the other model family, every finding closed, the result under `## Critique`. It shows the plan and the closed critique. Only the typed word "accepted" or "agreed" flips `Status` to accepted, and `commit-plan` then commits it. The statusline shows "interviewing" until `plan.md` exists, because the draft lives under `~/.claude/plans/` before that.

On acceptance, write `<folder>/plan.md` with `Status: accepted (<date>)` and run `~/.claude/skills/plan/scripts/commit-plan`: it commits `plan.md` (`docs: plan for <slug>`) and nothing else; for an autonomous plan it refuses an open or missing critique. Then write the agreed terms into the glossary as the `glossary` skill says; a personal repository gets its own commit (`docs: glossary terms for <slug>`). Then push (`git push -u origin HEAD`), except on a work repository: `commit-plan` commits nothing there, the branch holds no commit yet, and a push would create an empty branch on the work origin.

Inside Rex (`REX_SESSION` set, `HERDR_ENV` and `HC_TERMINAL_ID` unset), record this block for the delivery step: write `$REX_BLOCK` to `<git-common-dir>/rex/plan-pane-<slug>` (create the directory); block ids never repeat, so it needs no terminal id.

Inside herdr (`HERDR_ENV` set), record this pane for the delivery step. Run `herdr pane current` and write the `pane_id` field, then the `terminal_id` field, one per line, to `<git-common-dir>/herdr/plan-pane-<slug>` (create the directory). The delivery step reads it to keep this pane open when it closes the idle stage panes, and the terminal id tells this pane from a later pane that reuses its id.

Inside herdr-app (`HC_TERMINAL_ID` set, `HERDR_ENV` unset), record this terminal for the delivery step: write `$HC_TERMINAL_ID` to `<git-common-dir>/herdr-app/plan-pane-<slug>` (create the directory). The delivery step keeps the pane of that terminal open when it closes the idle stage panes.

- `plan.md` has `Delivery: autonomous`: do not chain to the implement stage by hand. Follow `references/autonomous-delivery.md`.
- Otherwise, inside herdr, herdr-app or Rex (`HERDR_ENV`, `HC_TERMINAL_ID` or `REX_SESSION` set), start the implement stage, in its own fresh pane: `COORDINATOR=<coordinator> ~/.agents/bin/hand-off-plan implement '<slug>'`, where `<coordinator>` is the pane or terminal id your starting prompt named if a stage pane started you, else your own `$HERDR_PANE_ID` (`$HC_TERMINAL_ID` in herdr-app, `$REX_BLOCK` in Rex; herdr wins over herdr-app, and herdr-app over Rex). If that command fails, say so and do not retry — in a stage pane, in your report file, as your starting prompt says. Outside the three tools, stop after the push.

Either way, writing a plan is not permission for *this session* to implement it — deliver the plan and stop; the implementing, if it happens, happens in that other pane.

## Auto mode

Plan mode does not apply: never call `EnterPlanMode` (Codex: never ask for `/plan`), because nobody is there to approve `ExitPlanMode`. This overrides the `here` backend's plan-mode step.

Only valid for a plan that records, or is about to record, `Delivery: autonomous`; otherwise refuse and say why. Invoked as the `auto` argument of the `here` backend, normally by `hand-off-plan plan <slug> --auto`, or from "Interactive autonomous plan" after the interview picks autonomous delivery. It never asks Etienne anything, never accepts the plan and never starts the next stage. A choice that would change the agreed behaviour, or a step that contradicts one of the `## Decisions`, becomes a `Decision needed:` line in the report, not a guess.

1. Write `plan.md` as usual, with `Status: draft`. The architects still run, but nobody waits at the design gate.
2. Run the critique with the other model family's local CLI. A Claude author uses Codex: `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium -s read-only -o <findings-file> "<prompt>" < /dev/null`. Closing stdin keeps an inherited prompt stream out of the critique. A Codex author uses Claude: `claude -p --model opus --permission-mode plan "<prompt>"`. The prompt asks it to read `plan.md`, `## Design` included, and the code it names, and to list disagreements with reasons. The critique covers the design section.
3. Record the result in `plan.md` under `## Critique`, as `### Round 1 (<critic>)` with one finding per list item, written `- <finding> → fixed (<what changed>)` or `- <finding> → dismissed: <reason>`. The closure is the text after the line's last arrow, so a reason or subject may not contain `→`. Indented sub-bullets may explain a closed finding. A round with nothing to raise holds the single line `No findings.`. Any other line under `## Critique` — a paragraph, a quote, a fence — leaves the critique open, and `commit-plan` refuses it. `## Critique` is the last thing in the file, after any footer, and appears once: a later round goes in it as a further `### Round` heading. Fix the plan for every `fixed` item.
4. Stop with `Status: draft` and report. Etienne reads the plan and the closed critique, then types "accepted". The accepting session runs `commit-plan`, which refuses until every finding is closed, and pushes. The `## Proof` structure still applies.

A critique CLI that fails or is missing is a blocker: put it in the report as a `Decision needed:` line. Never skip the critique.

## Critique

Read the plan, then read the actual code it touches. Be critical: does the approach hold? Can it be done better? Verify the plan's claims against the code — a file it says exists, a pattern it says is already used, a test level it assumes. Check the plan against its `## Decisions` too, and report any step that contradicts one. Report disagreements with reasons and propose the better alternative. Meant for a second model: `codex exec -m gpt-6.1-sol -c model_reasoning_effort=medium` reviewing a Claude-written plan, or an Opus session reviewing one Sonnet wrote.

## Execute a handed-over plan

- Read the project's `AGENTS.md` fully first, following links — the shared playbook already applies from the user config.
- Execute only the assigned phase or scope — nothing beyond it, no handing the work onward.
- An approved plan means: stop asking what to do next; work through it.
- When the plan no longer matches reality (main moved, a file it names is gone), rebase, re-verify the plan against the current code, and report the difference instead of improvising.
- Done = all tests green, all linters green, self-reviewed diff (playbook §7).

This role exists for a plan handed over outside the artifact chain (a plan pasted in, or one without a `docs/changes/<slug>/` folder). A plan that does live in that folder is executed by the `implement` skill instead, which reads `plan.md`'s structured `## Proof` directly.

## Codex

Same three roles, same plan template and design gate. Explore first, the scope check, the probe list and the read-back apply unchanged; read files with Codex's own tools. Codex has no plan mode, so the literal word "accepted" or "agreed" is the gate. `here` is the only backend, since Codex has no herdr pane of its own; a Codex coordinator may still start a Claude plan pane through the same script, as `implement` does today. Invoked as `$plan`. Use `gh issue view` the same way; there is no `AskUserQuestion` tool, so number multiple-choice options in plain text instead. `critique` role is what `codex -m gpt-6.1-sol -c model_reasoning_effort=medium` is for. In auto mode a Codex author runs the critique with Claude: `claude -p --model opus --permission-mode plan "<prompt>"`.
