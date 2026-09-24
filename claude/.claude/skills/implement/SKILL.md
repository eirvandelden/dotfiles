---
name: implement
description: Use once plan.md is accepted — builds it through the acceptance test then red/green/refactor per its Proof list, in single, split, or handoff mode.
arguments:
  - name: mode
    description: "single (default for small plans), split (two agents, default when spec.md has 3+ acceptance criteria), or handoff (send the plan to a worker pane instead of building here)."
---

# Implement

Builds an accepted `plan.md`. Refuses to start on anything not `Status: accepted` — say which
file and why.

## 1. Read

Run `~/.claude/skills/plan/scripts/change-folder` for the folder path. Read
`<folder>/intent.md` (for `Type:`), `<folder>/spec.md` (for acceptance criteria) and
`<folder>/plan.md` (for `## Proof`). Refuse if `plan.md` is not `Status: accepted`.

## 2. Pick a mode

- No `mode` argument: `single`, unless `spec.md` lists three or more acceptance criteria, in
  which case default to `split`. The user can always say `single` to override.
- `handoff`: skip building here entirely — see §5.
- `split` needs `~/.claude/hooks/test-guard.rb` to exist (phase 3 wires it up). If it is not
  there yet, say "split mode needs the test guard from phase 3" and fall back to `single`.

## 3. Single-session build

Outer loop, once per acceptance criterion in `## Proof`: write the failing acceptance test,
run it, confirm it fails for the reason the criterion implies — a test green on first run is
broken.

Inner loop, per unit test named under the file being changed: red, green, refactor, commit on
green.

A unit test the plan did not foresee: add it to `plan.md`'s Proof in the same commit as the code
that needed it. Anywhere else reality departs from the plan: edit `plan.md` in the same commit
as the departing code, never after.

**`Type: bugfix`** (from `intent.md`): write the failing reproduction test first, commit it
alone, then append `Reproduction: committed` to `plan.md` in that same commit. Only then fix —
without touching any test file. A hook enforces this once phase 3 lands (`§4` of the spec);
until then it is this instruction. Removing the `Reproduction: committed` line from `plan.md` is
the deliberate, visible way to override it — never just edit the test.

Done: every test named in `## Proof` exists, passes, and its output is pasted; linters clean on
every touched file.

## 4. Split mode (two agents)

Same worktree, sequential, never both at once:

1. `test-writer` agent: reads only `spec.md`'s acceptance criteria and `plan.md`'s `## Proof` —
   never production code beyond what a test needs to compile. Writes every acceptance test and
   every named unit test, runs them, confirms each fails for the reason its criterion implies (a
   new test that passes is reported as a finding, not silently fixed). Commits `Tests for
   <slug>`.
2. Confirm here: the commit landed, the suite is red, and it is red for the right reasons.
3. `implementer` agent: reads `plan.md` and the failing tests. Red/green/refactor on production
   code only, one unit test at a time, commit on green. A `PreToolUse` hook denies its writes
   under test paths regardless of what it thinks it needs. A unit test it needs but cannot write
   becomes a line in `plan.md`'s Proof and a line in its report.
4. Run the full suite here and read both reports. If the implementer's report lists tests it
   needed but couldn't write, run `test-writer` again for those, then `implementer` again.

Not per-unit alternation — each hand-off is a fresh context; the inner loop stays inside the one
agent running it.

## 5. Handoff mode

Send `plan.md` to a fresh Sonnet worker in a herdr pane instead of building here:

1. `plan.md` must be `Status: accepted`; if it is not, or the folder does not exist yet, say
   "run `/plan` first" and stop.
2. From the repository's main checkout (not a worktree — the worker branches off cleanly from
   there), passing the change's branch name as the worktree name so the worker starts already
   inside it. The `intent` skill already created `.worktrees/<slug>` on that branch, so read the
   branch off it rather than assuming it matches the slug (a branch named `fix/foo` gives a slug
   of `foo`):
   ```bash
   branch=$(git -C .worktrees/<slug> rev-parse --abbrev-ref HEAD 2>/dev/null || echo <slug>)
   ~/.config/herdr/scripts/hand-off-plan.sh <absolute path to plan.md> "$branch"
   ```
3. Tell the user which worker took it (the name the script printed) and where its report will
   land. The work is now theirs: do not start on it, and do not check up on it unless asked.

### When the worker finishes

The worker writes what it did, and anything it could not finish, to a Markdown file inside the
repository's shared git directory, then sends one line: `Handoff done: <path>`. It arrives as an
ordinary message, possibly mid other work, and retries while this session is busy — but the
report is never lost either way, since the script printed the path when it started.

Read the file and tell the user what came back. Do not pick up the leftovers unless asked.
Reports pile up in that directory over time; nothing prunes it — that is the user's to clear.

## Codex

Same modes. `handoff` still spawns a Claude pane, as today — Codex has no herdr worker of its
own. `split` mode's `implementer` restriction comes from the generated `codex/.codex/agents/`
TOML plus its `developer_instructions` sentence (phase 3), not a per-path hook — Codex agents
cannot carry one.
