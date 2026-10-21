# Review: design-altitude-in-plans

## Round 1 — 2026-10-13T14:06Z — 216a28d7

Passes run: Bugs, Security, Compliance. Base: `origin/main` (merge base; the branch is 91 commits behind). No uncommitted changes. No `REVIEW.md` at the repository root, so the template defaults apply.

Suite: every test file the branch adds or changes passes (design_section, architect_agent, design_review_pass, diagrams_skill, fill_pr_template, glossary_skill, mermaid_show, ruby_signatures, skill_parity, approval_word, codex_agent_generation, rbs_inline_tooling). `test/herdr_worker_scripts_test.rb` (plan step 9) and `test/auto_accept_test.rb` did not finish within 8 minutes in this shell; not verified here.

Security: nothing found. Every subprocess gets an argument array, no shell; `GLOSSARY.local.md` is globally ignored.

Compliance, acceptance criteria to tests:

- Design section before files, with terms, class diagram, signature, complexity → `design_section_test.rb` (two tests)
- One `Not affected:` line per untouched subsection → `design_section_test.rb`
- Two or three alternatives, wait for agreement → `design_section_test.rb`
- Query-count claim names its test → `design_section_test.rb`
- Invariant names enforcement and test → `design_section_test.rb`
- Term survives `finish` in the glossary → `glossary_skill_test.rb`
- Avoided word gets the term and a question → `glossary_skill_test.rb`
- Before ERD from rails-erd, ask, fall back to `db/schema.rb` → `diagrams_skill_test.rb`
- Agent prints class/ER/sequence/state as text, image in Ghostty → `mermaid_show_test.rb` (stubbed) and `evidence.md`; fails in an agent shell, see the first finding
- Two or three architects; Codex gets the agent → `architect_agent_test.rb`
- Reviewer reports the four design findings → `design_review_pass_test.rb`
- Personal Ruby: class summary, inline RBS, no YARD → #201's `rbs_inline_tooling_test.rb`, `ruby_signatures_test.rb`
- `steep check` or "Not checked" → `ruby_signatures_test.rb`
- Codex loads the three skills and the template → `skill_parity_test.rb`

Findings:

- [x] Important: Text mode does not work from an agent shell, so the criterion "an agent prints a Mermaid … diagram as text in its own pane" is unmet. Agent shells resolve Homebrew's `node` (pulled in by `mermaid-cli`) first; `npm root -g` then points at `/opt/homebrew/lib/node_modules`, where `beautiful-mermaid` is not installed. Reproduced in this review: `mermaid-show c.mmd` prints the install hint and exits 1. `evidence.md` records the same result but no fix or decision follows. The skill still tells agents to "print diagrams as text in your own pane". — `claude/.claude/skills/diagrams/scripts/mermaid-ascii.mjs:8` → → fixed (PR #214 puts chnode's `node` first in agent shells; `mermaid-show` text mode re-checked, see evidence.md)
- [x] Important: `plan.md` has no `## Files that change` section and no `## Order of work` heading. The second Integration points bullet breaks off mid-line ("reads `## Files that change`, `## Order of work") and the step list follows as loose text; the damage dates from the first plan commit (3e5a05c1). Effects: `finish`'s `fill-pr-template` fills Implementation with `## Design` only, so the PR body loses the order of work; and the compliance check "every file the plan named changed as it said" cannot run. — `docs/changes/design-altitude-in-plans/plan.md:105` → fixed (docs: restore the plan's lost Files that change and Order of work sections)
- [x] Important: A test named in `## Proof` does not exist: `test/mermaid_show_test.rb` `test_image_mode_renders_a_png_and_shows_it_with_timg`. The file has `test_image_mode_calls_mmdc_then_timg`, which covers the behaviour under another name. — `docs/changes/design-altitude-in-plans/plan.md:161` → fixed (docs: restore the plan's lost Files that change and Order of work sections)
- [x] Important: The plan template and the architect output still ask for "a prose summary" per public method in `### Signatures`. The amended intent (2026-10-13, #201) drops that: a one-line summary per class, an inline RBS signature per method, other comments only for a non-obvious "why". Every new plan and architect proposal will ask for the comments the intent removed. Same text in `claude/.claude/agents/architect.md:42` and `codex/.codex/agents/architect.toml:35`. — `claude/.claude/skills/plan/SKILL.md:58` → fixed (Design templates ask for a class summary and a signature per method)
- [x] Nit: A missing `node` or `mmdc` ends in an uncaught `Errno::ENOENT` with a Ruby backtrace; a missing `timg` prints "timg could not show <png>". The skill promises "When a tool is missing, the script says which one". Rescue `Errno::ENOENT` around the spawns and name the tool. — `claude/.claude/skills/diagrams/scripts/mermaid-show:44` → fixed (mermaid-show: name a missing node, mmdc or timg with its install command)
- [x] Nit: `OPENING_FENCE` accepts no indentation, so a Mermaid fence inside a list item (up to three spaces, or list-indented) is never rendered. It also opens a fence on a line such as "```foo```", which CommonMark does not treat as a fence (a backtick info string cannot hold a backtick); every Mermaid fence after that line then stays source. — `claude/.claude/skills/diagrams/scripts/mermaid-show:17` → fixed (mermaid-show: render indented Mermaid fences and skip backtick lines that open no fence)

## Round 2 — 2026-10-20T19:03Z — 8f43feda

Passes run: Bugs, Security, Compliance. Base: `origin/main` (merge base 751c86c3; the branch is rebased and 0 commits behind). No uncommitted changes. No `REVIEW.md` at the repository root, so the template defaults apply.

Suite: all 80 test files pass (`for f in test/*_test.rb; do ruby -Itest "$f"; done`), `herdr_worker_scripts_test.rb` and `auto_accept_test.rb` included. `rubocop` is clean on `mermaid-show`, `fill-pr-template` and the nine new or changed test files; `node --check` is clean on `mermaid-ascii.mjs`; `shellcheck` is clean on `start-review.sh`.

Round 1 fixes re-checked: text mode now works from an agent shell (`node` resolves to `~/.nodes/node-25.9.0`; `mermaid-show a.mmd` prints the diagram and exits 0). Every test named in `## Proof` exists. The renumbered step in `approval_word_test.rb` and `pull_request_flow_test.rb` keeps its assertions; no test was weakened, skipped or deleted. Compliance mapping is unchanged from round 1.

Security: nothing found. Subprocesses still get argument arrays; `GLOSSARY.local.md` is globally ignored.

Findings:

- [x] Nit: `## Files that change` still names the pre-rebase layout: the new skills and the edited skills as `claude/.claude/skills/...`, and `agents/.agents/skills/{software-design,glossary,diagrams}` as "new relative symlinks". Commit 1c696bd4 flipped that: the real files live under `agents/.agents/skills/` and the Claude side holds the links. `fill-pr-template` copies this section into the PR body, so the pull request will name paths the diff does not touch. — `docs/changes/design-altitude-in-plans/plan.md:113` → fixed (docs: name the agents package paths in the plan and the tests for design-altitude-in-plans)
- [x] Nit: `beautiful-mermaid` 1.1.3 misreads an arrow written without spaces. `graph LR` with `A-->B` renders one box labelled `A--` and exits 0; `A --> B` renders two boxes and an arrow. Valid Mermaid thus prints a wrong diagram with no error. The Conventions list could ask for spaces around every arrow. — `agents/.agents/skills/diagrams/SKILL.md:22` → fixed (diagrams skill: ask for a space on each side of every arrow)
- [x] Nit: A tilde fence (`~~~mermaid`) stays source in `--markdown` and `.md` modes, because `flush` renders backtick fences only. GitHub renders such a fence as a diagram, and the skill promises "each Mermaid fence". — `agents/.agents/skills/diagrams/scripts/mermaid-show:161` → fixed (mermaid-show: render tilde Mermaid fences and report a parse error as one line naming the diagram)
- [x] Nit: A diagram the renderer cannot parse ends with the helper's full Node stack trace on stderr, because `text_for` raises with the whole of `stderr`. In `--markdown` mode one bad fence also aborts the whole document, so nothing is written. Report the `Error:` line only, naming the fence. — `agents/.agents/skills/diagrams/scripts/mermaid-show:50` → fixed (mermaid-show: render tilde Mermaid fences and report a parse error as one line naming the diagram)

## Round 3 — 2026-10-20T20:05Z — e51b8a0f

Passes run: Bugs, Security, Compliance. Base: `origin/main` (merge base 2319e720). Uncommitted: round 2's closed findings in this file only. No `REVIEW.md` at the repository root, so the template defaults apply. `origin/design-altitude-in-plans` still holds the pre-rebase intent and plan commits only, so a plain push is not a fast-forward.

Suite: all test files pass (`for f in test/*_test.rb; do ruby -Itest "$f"; done`, 0 failures). `rubocop` is clean on `mermaid-show` and the three changed test files.

Round 2 fixes re-checked by running the script with the real renderer: a `~~~mermaid` fence renders in `.md` and `--markdown` modes, also indented in a list item; a `~~~ruby` fence stays source; `nonsense here` exits 1 with `mermaid-show: diagram 1: Error: Invalid mermaid header: …` and no stack trace. `## Files that change` and the per-file unit test list now name the `agents/.agents/skills/` paths the diff touches. The diagrams skill asks for spaces around arrows. The new tests `test_markdown_mode_renders_a_tilde_fence` and `test_a_rejected_diagram_reports_the_error_line_and_names_the_fence_without_a_stack_trace` pass; the changed fixture in `test_markdown_mode_leaves_everything_but_mermaid_fences_alone` swaps a `~~~mermaid` fence for `~~~ruby`, which keeps the test's intent now that tilde Mermaid fences render.

Security: nothing found. The spawns still take argument arrays.

Not raised: `plan.md:108` (Integration points) still says new skills need "an `agents/.agents/skills/<name>` link". `fill-pr-template` does not copy that section and `deliver` removes the folder, so it reaches no reader after delivery.

Findings:

- [x] Nit: `error_line` keeps only a line that starts with "Error", else the first line. Node prints an uncaught `TypeError` or `RangeError` as a location line (`file:///…/mermaid-ascii.mjs:15`), the source line, a caret, then `TypeError: …`. A renderer crash of that kind therefore reports `diagram 1: file:///…/mermaid-ascii.mjs:15` and drops the message. Verified with `node` on a module that throws `TypeError`; no real diagram input reproduced it. Match `/\A\w*Error\b/` instead. — `agents/.agents/skills/diagrams/scripts/mermaid-show:63` → fixed (mermaid-show: keep the message of a Node crash that prints its location first)
- [x] Nit: The comment on `flush` still says "a Mermaid backtick fence becomes one :mermaid chunk". Since ff6d4d2b a tilde fence does too. — `agents/.agents/skills/diagrams/scripts/mermaid-show:167` → fixed (mermaid-show: keep the message of a Node crash that prints its location first)

## Round 4 — 2026-10-20T20:44Z — c59619b6

Passes run: Bugs, Security, Compliance. Base: `origin/main` after a fresh fetch (merge base 751c86c3; the branch is 38 commits behind, among them #223 lean-test-rule and #224 optional-codex-review). Uncommitted: round 3's closed findings in this file only. No `REVIEW.md` at the repository root, so the template defaults apply. `origin/design-altitude-in-plans` still holds the pre-rebase intent and plan commits only, so a plain push is not a fast-forward.

Suite: `test/mermaid_show_test.rb` passes (16 runs, 0 failures); `rubocop` is clean on `mermaid-show` and its test. Only c59619b6 changed since round 3, so the full suite was not re-run on this head.

Round 3 fixes re-checked: `error_line` now picks `TypeError: x is not a function` out of a real `node` crash whose stderr starts with the location line; the new test `test_a_crash_that_prints_its_location_first_still_reports_the_error_message` covers it. The `flush` comment names tilde fences.

Security: nothing found.

Findings:

- [x] Important: The branch no longer merges into `origin/main`. `git merge-tree --write-tree origin/main HEAD` reports a content conflict in `agents/.agents/skills/plan/SKILL.md`: #223 replaced the `## Proof` paragraph, the Mobile exception paragraph and the mobile check paragraph that this branch keeps as context under its new Design paragraphs. Rebase onto `origin/main` and keep both sides: main's lean test rule lines and `needs no test` / `→ check:` wording, and this branch's `## Design` template, Design gate step and design Proof paragraphs. Main's `test/test_rule_mirror_test.rb` refuses any "Mobile exception" phrase in that file, so taking the branch side fails it. Run the full suite after the rebase, then push with `--force-with-lease`. — `agents/.agents/skills/plan/SKILL.md:117` fixed (rebased onto origin/main; the plan skill conflict resolved in plan skill: design section, design gate and design proof lines, keeping main's lean test rule)

## Round 5 — 2026-10-21T07:15Z — 3a14a391

Passes run: Bugs, Security, Compliance. Base: `origin/main` after a fresh fetch (2319e720; the branch is rebased and 0 commits behind). `git merge-tree --write-tree origin/main HEAD` is clean. Uncommitted: round 4's closed finding in this file only. No `REVIEW.md` at the repository root, so the template defaults apply. `origin/design-altitude-in-plans` still holds the pre-rebase plan commit (6e2e8034) only, so a plain push is not a fast-forward.

Suite: all 80 test files pass (`for f in test/*_test.rb; do ruby -Itest "$f"; done`, 0 failures), `test_rule_mirror_test.rb` included. `rubocop` is clean on `mermaid-show`, `fill-pr-template` and the 11 changed test files; `node --check` is clean on `mermaid-ascii.mjs`; `shellcheck` is clean on `start-review.sh`. The three `claude/.claude/skills/` links resolve into the agents package.

Round 4 fix re-checked: `git range-diff` against the round 4 series shows only two commits changed in the rebase. In `plan/SKILL.md` the resolution keeps main's lean test rule (the `needs no test` / `→ check:` Proof wording and the four rule lines, no "Mobile exception") and this branch's design gate, `## Design` template and design Proof paragraphs; the steps renumber to 8, and the two step-number tests follow. In `implement/SKILL.md` only context changed: the branch's signature paragraph now sits above main's rule lines, and "its test first" matches main's "This pipeline still writes each test before its code". No other file refers to the plan skill's step numbers. No test was weakened, skipped or deleted. Compliance mapping is unchanged from round 1.

Security: nothing found.

Not raised: `## Files that change` lists the step 7 → 8 change in `test/approval_word_test.rb` but not the same one-line change in `test/pull_request_flow_test.rb`. The pull request's own file list shows it, so no reader is misled.

Findings:

No findings.
