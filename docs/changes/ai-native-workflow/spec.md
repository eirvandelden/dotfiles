# Spec: AI-native workflow for personal and work development

From `intent.md` (2026-09-18). Decisions below were made in conversation on 2026-09-18 and are settled; the plan does not reopen them.

## 1. The artifact chain

### 1.1 Location and naming

```
docs/changes/<slug>/
  intent.md    # what and why — playbook template
  spec.md      # requirements + design decisions + flagged concerns
  plan.md      # files that change, order of work, risks, proof
```

- Lives in the application repository, committed on the feature branch. Same layout for personal and work repositories.
- `<slug>` is the branch name without any prefix: branch `ai/claims-status` and branch `claims-status` both map to `docs/changes/claims-status/`. Skills derive the folder from the current branch; nobody types the path.
- `docs/changes/` is reserved for these folders only. Other documentation stays where it is.
- Fixed filenames. A skill or hook can say "read `plan.md` in this branch's change folder" without searching.

### 1.2 Lifecycle

| Stage | Writes | Reads | Gate |
|---|---|---|---|
| Intent | `intent.md` | conversation | Etienne accepts; `Status: accepted` |
| Spec | `spec.md` | `intent.md` + skills | Etienne accepts |
| Plan | `plan.md` | `intent.md`, `spec.md`, codebase (plan mode) | Etienne accepts; optional second-model critique |
| Build | code + tests; `plan.md` updated when reality departs | `plan.md` | tests + linters green |
| Review | review report (outside the repo, see §4) | `REVIEW.md`, `plan.md`, `spec.md`, diff | Etienne reads findings |
| Finish | removes `docs/changes/<slug>/` | — | see §1.3 |

Each stage is a fresh session or a fresh context. No stage relies on chat history from the previous one. This is the same rule `plan-handoff` already states for plans.

### 1.3 Removal

The folder is deleted in its own commit, the last one before the change is handed on:

- **Personal**: after Etienne's review is complete and nothing is open. Then merge.
- **Work**: by the `prepare-for-team` skill (§5), before the PR is flagged for the team. Team reviewers see the artifacts only through git history. Anyone who looks at the PR earlier sees them; that is accepted.

Kept permanently only as an ADR, and only at work, and only for changes that affect another application (API contracts, published events, shared schemas, anything another team consumes). The finishing skill asks "does this change affect another application?" and, on yes, distils `intent.md` + `spec.md` into an ADR in the work repo's existing ADR location (or proposes one if none exists) before deleting the folder.

Evals, metrics on artifact history, and the monitoring loop are out of scope.

## 2. Skills that produce and consume the chain

New skills, one source each, available in both Claude and Codex (§3):

| Skill | Does | Codex note |
|---|---|---|
| `intent` | Interview → `intent.md` from the playbook template; asks scope, users, constraints, success; writes `Status: draft`, flips to `accepted` on Etienne's word | same |
| `spec` | Reads `intent.md`, applies relevant domain skills, writes `spec.md`; flags conflicts it cannot resolve at the top | same |
| `plan` | Runs in plan mode; reads intent + spec + codebase; writes `plan.md` (files, order, risks, proof); refuses to implement until accepted; absorbs today's `plan-handoff` "write" and "critique" roles | Codex plan mode; `codex -p terra` for critique |
| `implement` | Reads `plan.md`, works through it in the worktree, TDD per playbook, updates `plan.md` in the same commit when departing from it | same |
| `review-branch` | Report-only: reads `REVIEW.md` + `plan.md` + `spec.md` + diff; writes findings to `.git/<agent>/review-<slug>.md`; never edits code | Claude: subagent; Codex: fresh session or Codex subagent if the docs confirm one exists |
| `finish-change` | Personal: confirms review report exists and is newer than the last code commit; deletes the folder; commits | same |
| `prepare-for-team` | Work: assumes review already happened (no re-review); fills the repo PR template from `intent.md`/`plan.md` (Summary/Why ← intent; Implementation ← plan; Testing ← plan Proof); deletes the folder; commits; pushes; sets PR status to the team's review state; requests reviewers. Runs only on explicit command | same; status mechanism read from `fizzy-sync` |

Existing skills adapt:

- `handoff` reads `plan.md` from the change folder instead of `~/.claude/plans/`.
- `worktree-first`, `sync`, `code-review` (implementing review feedback), `dependencies`, `new-repo-setup`, `dotfiles-maintenance`, domain skills: unchanged in role.
- `plan-handoff` is absorbed by `plan` (write, critique) and `implement` (execute). Removed.
- `review` (herdr pane) becomes the Claude adapter for `review-branch` or is removed if the subagent covers it — decided during the phase, not before.

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
- `review-branch` produces a report outside the tracked tree. Identical for both tools and both scopes.
- Deterministic backstop (playbook's hook + skill pattern): a lefthook pre-push command in the global `lefthook.yml` fails when the branch has a `docs/changes/<slug>/` folder and no review report newer than the last commit. Skippable only by the normal `--no-verify` route, which the consent guard already gates.
- Work repos additionally keep the `review-as-*` persona skills; they run before `prepare-for-team`, as today.

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
- **Codex subagents**: if Codex has no read-only agent definition, `review-branch` runs as a skill in a fresh session; the report-only guarantee is then instruction, not tooling.
- **Stow `--no-folding`** links file by file; a new skill needs a re-stow, which Etienne runs by hand (never the agent).
- **Playbook rule 13**: the pre-push review check edits the global `lefthook.yml`, not CI; still presented for approval as it affects every repository.
