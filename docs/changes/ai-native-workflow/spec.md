# Spec: AI-native workflow for personal and work development

From `intent.md` (2026-09-18). Decisions below were made in conversation on 2026-09-18 and are settled; the plan does not reopen them.

## 1. The artifact chain

### 1.1 Location and naming

```
docs/changes/<slug>/
  intent.md    # what and why — playbook template
  spec.md      # requirements + design decisions + acceptance criteria + flagged concerns
  plan.md      # files that change, order of work, risks, proof (the test list)
  review.md    # review rounds: findings, each fixed or dismissed with a reason
```

- Lives in the application repository, committed on the feature branch. Same layout for personal and work repositories.
- `<slug>` is the branch name without any prefix: branch `ai/claims-status` and branch `claims-status` both map to `docs/changes/claims-status/`. Skills derive the folder from the current branch; nobody types the path.
- Branch naming: when a GitHub issue is known, the branch is `<issue-number>-<issue-title-in-kebab-case>` — the name GitHub's "Create a branch" button generates (e.g. `7716-calendar-occurrence-range-fix`), so the issue number travels into the folder name. Without an issue, a kebab-case task slug. No prefix in either case; `worktree-first` and `intent` apply this.
- `docs/changes/` is reserved for these folders only. Other documentation stays where it is.
- Fixed filenames. A skill or hook can say "read `plan.md` in this branch's change folder" without searching.

### 1.2 Lifecycle

| Stage | Writes | Reads | Gate |
|---|---|---|---|
| Intent | `intent.md` | conversation | Etienne accepts; `Status: accepted` |
| Spec | `spec.md` | `intent.md` + skills | Etienne accepts |
| Plan | `plan.md` | `intent.md`, `spec.md`, codebase (plan mode) | Etienne accepts; optional second-model critique |
| Build | failing acceptance test first, then unit red/green/refactor per the plan's Proof; `plan.md` updated when reality departs | `plan.md` | every test named in Proof exists and passes; linters green |
| Review | `review.md` in the change folder, committed on the branch (see §4) | `REVIEW.md`, `plan.md`, `spec.md`, diff | Etienne reads findings; every finding fixed or dismissed with a reason; compliance pass confirms each acceptance criterion has its test |
| Finish | removes `docs/changes/<slug>/` | — | see §1.3 |

Each stage is a fresh session or a fresh context. No stage relies on chat history from the previous one. This is the same rule `plan-handoff` already states for plans.

### 1.3 Removal

The folder is deleted in its own commit, the last one before the change is handed on:

- **Personal**: after Etienne's review is complete and nothing is open. Then merge.
- **Work**: by the same `finish` skill (§2), which also fills the PR body and flags the PR for the team, before colleagues look. Team reviewers see the artifacts only through git history. Anyone who looks at the PR earlier sees them; that is accepted.

Kept permanently only as an ADR, and only at work, and only for changes that affect another application (API contracts, published events, shared schemas, anything another team consumes). The finishing skill asks "does this change affect another application?" and, on yes, distils `intent.md` + `spec.md` into an ADR at `docs/adr/NNNN-<slug>.md` in the work repository (Context / Decision / Consequences; numbered sequentially; the folder is created on first use) before deleting the folder.

Evals, metrics on artifact history, and the monitoring loop are out of scope.

### 1.4 Where tests come from

Tests are the spec made executable. Two documents, two altitudes; no separate test document.

- **`intent.md`** carries a `Type:` line — `feature`, `bugfix`, `refactor`, or `chore` — because a bugfix follows a stricter test rule (below).
- **`spec.md` → `## Acceptance criteria`** (required section). One concrete example per behaviour, in the domain's words, as a sentence a domain expert would agree with ("Paying empties the basket"; "A closed card is not reopened while its source is still visible"). Each criterion becomes exactly one acceptance test at the level the repository already uses (system, request, or feature test). A requirement that cannot be written as an example is not clear enough; the spec is not accepted until it can.
- **`plan.md` → `## Proof`** (structured). For each acceptance criterion: the test file and test name that proves it. For each file in "Files that change": the unit tests expected, named as behaviour ("`Basket#pay` clears the items", "refuses an unpaid order"). "Order of work" always starts with: write the acceptance test for the first criterion, run it, watch it fail — the walking skeleton. Test setup worth stating (fixtures, test data, boundaries that are faked) goes in a short "Test setup" paragraph inside Proof; if that paragraph grows long, the change is too big and is split.
- **Build**: outer loop — one failing acceptance test from Proof; inner loop — red/green/refactor per unit test named in Proof. A unit test the plan did not foresee is added to `plan.md` in the same commit. Done means the Proof list exists and passes, output pasted.
- **Split mode** (`implement split`, default off; on by default when the spec has three or more acceptance criteria): two agents, sequential, same worktree. `test-writer` reads only the acceptance criteria and Proof, writes the acceptance tests and the unit test files with their named cases, runs them, confirms each fails for the expected reason (a new test that passes is a finding), commits `Tests for <slug>`. `implementer` then makes them green with red/green/refactor on production code only; a `PreToolUse` hook on that agent denies every write under test paths, so "fix the code, not the test" is structural for every change type, not only bugfixes. A unit test the implementer needs but cannot write goes into Proof as a line and into its report; `test-writer` runs a second round. The main session runs the full suite and reads both reports. Not per-unit alternation — each hand-off is a fresh context; the inner loop stays inside one agent. Single-session TDD stays the default for small changes.
- **Bugfix rule** (`Type: bugfix`): the failing reproduction test is written and committed first; then the fix, without touching test files. The `implement` skill adds `Reproduction: committed` to `plan.md` after that commit, and a deterministic hook (§4) blocks agent edits to test files while that line is present — the playbook's "fix the code, not the test", enforced rather than advised.
- **Review**: the compliance pass checks that every acceptance criterion in `spec.md` has a test in the diff, every test named in Proof exists, and no existing test was weakened, skipped, or deleted.

## 2. Skills that produce and consume the chain

New skills, one source each, available in both Claude and Codex (§3):

| Skill | Does | Codex note |
|---|---|---|
| `intent` | Interview → `intent.md` from the playbook template; interview technique adapted from the superpowers-ruby `brainstorming` skill (one question at a time, multiple choice, problem before solution, persist the draft as you go); asks scope, users, constraints, success; writes `Status: draft`, flips to `accepted` on Etienne's word | same |
| `spec` | Reads `intent.md`, applies relevant domain skills, writes `spec.md` including `## Acceptance criteria` (one example per behaviour); flags conflicts it cannot resolve at the top; refuses acceptance while a requirement has no example | same |
| `plan` | Runs in plan mode; reads intent + spec + codebase; writes `plan.md` (files, order, risks, structured Proof mapping criteria to tests and files to unit tests); order of work starts with the first failing acceptance test; refuses to implement until accepted; absorbs today's `plan-handoff` "write" and "critique" roles | Codex plan mode; `codex -p terra` for critique |
| `implement` | Reads `plan.md`; outer loop one failing acceptance test, inner loop red/green/refactor per Proof; updates `plan.md` in the same commit when departing from it; on `Type: bugfix` commits the reproduction test first and marks `Reproduction: committed`; `split` mode (§1.4) hands tests to a `test-writer` agent and production code to an `implementer` agent that cannot write test paths; `handoff` mode sends the plan to a worker in a herdr pane instead of implementing here (absorbs today's `handoff`) | same; Codex agents restricted by sandbox, path rule by instruction; `handoff` spawns a Claude pane as today |
| `review` | One skill, two backends — default: the `reviewer` agent forked in-session; `review pane`: the same reviewer in a herdr pane (today's `/review`). Report-only: reads `REVIEW.md` + `plan.md` + `spec.md` + diff; compliance pass includes criterion→test coverage and no weakened tests; writes findings to `docs/changes/<slug>/review.md` (the only file it may write), one dated round per run, and commits it; never edits code | Claude: subagent; Codex: fresh session or Codex subagent if the docs confirm one exists |
| `finish` | One skill, scope from the remote. Both: confirms `review.md` is fresh and closed; deletes the folder; commits. Work only, before the delete: fills the repo PR template from `intent.md`/`plan.md` (Summary/Why ← intent; Implementation ← plan; Testing ← plan Proof); ADR for cross-application changes. Work only, after: pushes; puts the PR on the team's review project with Status "Needs Review"; requests reviewers. Assumes review already happened. Runs only on explicit command | same; board mechanism in a private after-push script |

Existing skills adapt:

- `handoff` is absorbed by `implement`: `implement handoff` sends the change folder's `plan.md` to a Sonnet worker in a herdr pane (`hand-off-plan.sh`), and that worker runs `implement` itself in its own worktree. Removed as a separate skill; `~/.claude/plans/` is no longer written to.
- `worktree-first`, `sync`, `code-review` (implementing review feedback), `dependencies`, `new-repo-setup`, `dotfiles-maintenance`, domain skills: unchanged in role.
- `plan-handoff` is absorbed by `plan` (write, critique) and `implement` (execute). Removed.
- `review` absorbs today's pane-only skill: the default runs the `reviewer` agent in-session (`context: fork`); `review pane` runs the same reviewer in a herdr pane via `start-review.sh`. Both append a round to `review.md` and commit it. One skill, two backends.

### 2.1 `REVIEW.md`

Repo root, playbook structure: passes (bugs / security / compliance with `spec.md` + `plan.md` + playbook), what "Important" means, nit cap, do-not-report paths. Template ships in dotfiles; `new-repo-setup` adds it to personal repos. Work repos get it via the stowed project-local package (same mechanism as `docs/for-agents.local.md`), never committed.

## 3. Claude ↔ Codex parity

Principle: **one source, thin adapters, a test that fails on drift.**

- Artifacts and `REVIEW.md` are markdown in the repo — parity for free.
- Each shared skill has one `SKILL.md` in the dotfiles. Both `~/.claude/skills/<name>/SKILL.md` and `~/.codex/skills/<name>/SKILL.md` resolve to it (symlink inside the repo, same trick as `PLAYBOOK.md → agents.md`). Codex gets `agents/openai.yaml` beside the link where needed.
- Consent guard stays one Ruby script. Claude calls it from `PreToolUse`; Codex calls it from its hook system, with the stdin/exit contract adapted in a small shim. Codex `rules/default.rules` is reduced to the hand-written prompt rules plus a short vetted allow-list.
- Report-only agents: Claude `.claude/agents/*.md`; Codex equivalent per its docs, or the same instructions as a skill run in a fresh session. Behaviour parity, not file parity.
- Hand-copied files today (`handoff`, `review`, `HEADROOM.md`, `WORKTREES.md`) become links or one file with tool-specific sections.
- Drift test: Minitest in `test/` asserting every shared skill resolves to the same file from both sides, every Claude hook has a Codex counterpart listed, and no Codex `allow` rule matches the consent guard's blocked patterns. Runs in lefthook pre-commit and CI.
- Codex-only by policy: `fizzy-sync` and the work integrations. Intake there ends in an `intent.md`, so a task can continue in either tool.

## 4. Review: local only

- No GitHub-side AI (no review action, no review app, no `claude -p` in CI). Credits come from the local CLIs.
- `review` writes `docs/changes/<slug>/review.md` and commits it on the branch — the same place as the other artifacts, deleted with them at the end. Each run appends a round: UTC timestamp, the commit reviewed, the findings by pass and severity. Findings are closed in the same file: `fixed (<commit>)` or `dismissed: <reason>`; the reviewer's only write permission is this one path. Identical for both tools and both scopes; the existing `/review` pane skill already prescribes a written review document and adopts this location.
- Freshness is defined in git terms, not mtime: the last commit that touched anything outside `docs/changes/<slug>/` must be no newer than the last commit that touched `review.md`, and the working tree must have no uncommitted changes outside the change folder.
- Deterministic backstop (playbook's hook + skill pattern): a lefthook pre-push command in the global `lefthook.yml` fails when the branch has a `docs/changes/<slug>/` folder and no review report newer than the last commit. Skippable only by the normal `--no-verify` route, which the consent guard already gates.
- Work repos additionally keep the `review-as-*` persona skills; they run before `finish`, as today.
- Test-file guard (§1.4 bugfix rule): a `PreToolUse` hook on file-editing tools, one Ruby script shared by both tools like the consent guard. It reads the current branch's `plan.md`; when that file contains `Reproduction: committed`, any edit or write to a test path (`test/**`, `spec/**`, `*_test.rb`, `*_spec.rb`, `__tests__/**`, `*.test.*`) is blocked with a message naming the rule. Removing the line from `plan.md` is the deliberate override, and the skill says so.

## 5. Plugins and always-loaded context

Disable (keep installed; one line to re-enable):

- Claude `settings.json` `enabledPlugins`: `agile@agile`, `caveman@caveman`, `superpowers-ruby@superpowers-ruby` → `false`.
- Codex `config.toml`: `[plugins."superpowers-ruby@superpowers-ruby"] enabled = false`.

Replace what they provided:

- Terseness: playbook rule 1 already states caveman-lite. Nothing else.
- Talk-before-code, TDD, verification: playbook §7.3, §7.17, §7.22 and the `plan` skill.
- superpowers domain skills worth keeping are copied into `claude/.claude/skills/` (linked to Codex): decided per skill during the phase; candidates are rails-guides, 37signals-style, the Hotwire set, ruby, sandi-metz-rules, brakeman, rails-upgrade, ruby-upgrade, systematic-debugging, compound. Each copy records its upstream path and version for re-sync.
- `cavecrew-investigator`/`-reviewer` behaviour: covered by `zubat` and the new review agent.

Target after this change: session start loads the playbook and its includes only (~19 KB), no per-subagent injection. Measured with `/audit-token` before and after.

### 5.1 Playbook edits

- §7.17 (plan first) points at the artifact chain and plan mode instead of "present a plan".
- §7.24 names the current model alias actually set in `settings.json`.
- New short section "Things agents get wrong here", maintained by the rule: same mistake twice → one line here. Kept under ten lines; anything older than three months without a repeat is removed.
- `WORKTREES.md`, `TOKENS.md`, `HEADROOM.md` reviewed for content that the new skills now carry; removed where duplicated.

## 6. Hygiene uncovered by the inventory (in scope because it blocks the above)

- Dangling stow symlinks in `~/.claude/skills/` and `~/.codex/skills/` from removed skills.
- Codex `config.toml` `[projects.*]` and `[hooks.state]` machine churn; `.gitignore` or `config.d` split so the committed file holds intent, not state.
- Orphaned `claude/.config/claude/settings.json`.
- Stray multi-MB log files at both repo roots.
- Work infrastructure text in the public repo (`autoMode.environment`, Codex allow rules). Moves to the private repo or is removed.
- Empty `docs/handoffs/_archive/` templates; stop appearing once superpowers hooks are off.

## 7. Habits

A `habits.md` next to this spec lists what Etienne changes, in adoption order, one habit per phase, with the cue that triggers it and the tooling that backs it. Written for a reader who has not seen this conversation.

## 8. Out of scope

- Evals suite, `agent-evals` workflow, metrics dashboards.
- Monitoring/closing-the-loop, Claude Security, Claude Tag.
- Any GitHub Actions or GitHub app running an AI agent.
- Proposal to the work team (may follow later as its own intent).
- Committing `CLAUDE.md`, `.claude/`, or `REVIEW.md` into work repositories.
- Uninstalling plugins or marketplaces.
- Changing Ruby/Node versions, version managers, or system tooling.

## Flagged concerns

- **Codex hook contract** must be verified against Codex docs before the guard shim is designed; if Codex hooks cannot block, the shim degrades to a `prompt` rule and the plan says so.
- **Codex subagents**: if Codex has no read-only agent definition, `review` runs as a skill in a fresh session; the report-only guarantee is then instruction, not tooling.
- **Stow `--no-folding`** links file by file; a new skill needs a re-stow, which Etienne runs by hand (never the agent).
- **Playbook rule 13**: the pre-push review check edits the global `lefthook.yml`, not CI; still presented for approval as it affects every repository.
