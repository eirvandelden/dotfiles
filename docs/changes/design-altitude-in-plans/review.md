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

- [ ] Important: Text mode does not work from an agent shell, so the criterion "an agent prints a Mermaid … diagram as text in its own pane" is unmet. Agent shells resolve Homebrew's `node` (pulled in by `mermaid-cli`) first; `npm root -g` then points at `/opt/homebrew/lib/node_modules`, where `beautiful-mermaid` is not installed. Reproduced in this review: `mermaid-show c.mmd` prints the install hint and exits 1. `evidence.md` records the same result but no fix or decision follows. The skill still tells agents to "print diagrams as text in your own pane". — `claude/.claude/skills/diagrams/scripts/mermaid-ascii.mjs:8` →
- [x] Important: `plan.md` has no `## Files that change` section and no `## Order of work` heading. The second Integration points bullet breaks off mid-line ("reads `## Files that change`, `## Order of work") and the step list follows as loose text; the damage dates from the first plan commit (3e5a05c1). Effects: `finish`'s `fill-pr-template` fills Implementation with `## Design` only, so the PR body loses the order of work; and the compliance check "every file the plan named changed as it said" cannot run. — `docs/changes/design-altitude-in-plans/plan.md:105` → fixed (docs: restore the plan's lost Files that change and Order of work sections)
- [x] Important: A test named in `## Proof` does not exist: `test/mermaid_show_test.rb` `test_image_mode_renders_a_png_and_shows_it_with_timg`. The file has `test_image_mode_calls_mmdc_then_timg`, which covers the behaviour under another name. — `docs/changes/design-altitude-in-plans/plan.md:161` → fixed (docs: restore the plan's lost Files that change and Order of work sections)
- [x] Important: The plan template and the architect output still ask for "a prose summary" per public method in `### Signatures`. The amended intent (2026-10-13, #201) drops that: a one-line summary per class, an inline RBS signature per method, other comments only for a non-obvious "why". Every new plan and architect proposal will ask for the comments the intent removed. Same text in `claude/.claude/agents/architect.md:42` and `codex/.codex/agents/architect.toml:35`. — `claude/.claude/skills/plan/SKILL.md:58` → fixed (Design templates ask for a class summary and a signature per method)
- [x] Nit: A missing `node` or `mmdc` ends in an uncaught `Errno::ENOENT` with a Ruby backtrace; a missing `timg` prints "timg could not show <png>". The skill promises "When a tool is missing, the script says which one". Rescue `Errno::ENOENT` around the spawns and name the tool. — `claude/.claude/skills/diagrams/scripts/mermaid-show:44` → fixed (mermaid-show: name a missing node, mmdc or timg with its install command)
- [x] Nit: `OPENING_FENCE` accepts no indentation, so a Mermaid fence inside a list item (up to three spaces, or list-indented) is never rendered. It also opens a fence on a line such as "```foo```", which CommonMark does not treat as a fence (a backtick info string cannot hold a backtick); every Mermaid fence after that line then stays source. — `claude/.claude/skills/diagrams/scripts/mermaid-show:17` → fixed (mermaid-show: render indented Mermaid fences and skip backtick lines that open no fence)
