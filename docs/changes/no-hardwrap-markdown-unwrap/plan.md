# Plan: Unwrap the existing dotfiles markdown

From `intent.md` and `spec.md` (2026-09-28). Status: accepted.

Worktree `/Users/etienne.vandelden/Developer/dotfiles/.worktrees/no-hardwrap-markdown-unwrap`, branch `no-hardwrap-markdown-unwrap`, at `origin/main` `64200d2b`. Change folder `docs/changes/no-hardwrap-markdown-unwrap/`.

## Context

PR #160 added playbook rule 26 and the `no-hardwrap` markdownlint rule, with an unwrap mode for fixing. The markdown in the dotfiles repository is still hardwrapped, and agents copy that style. Phase 2 runs the unwrap mode once over the markdown the repository owns. Etienne decided on 2026-09-25 that there is no guard test afterwards.

## Files that change

39 files have findings today, after these six exclusions: the four caveman-init files, `claude/.claude/skills/intent/SKILL.md` and `claude/.claude/skills/rails-ui/SKILL.md`. Symlinked `.md` files are skipped (`git ls-files -s | awk '$1!="120000"'`).

- Root and config (9): `agents.md`, `SKILLS-INDEX.md`, `claude/.claude/{CLAUDE,HEADROOM,TOKENS,WORKTREES}.md`, `codex/.codex/AGENTS.md`, `git/.config/git/worktree-tools/README.md`, `neovim/.config/nvim/README.md`.
- Skills (23): `claude/.claude/skills/**/*.md` except the two excluded, references included.
- Agents (4): `claude/.claude/agents/{implementer,reviewer,test-writer,zubat}.md`, plus the regenerated `codex/.codex/agents/*.toml`.
- Docs (3): `docs/open-questions.md`, `docs/changes/ai-native-workflow/**`.
- `project-dictionary.txt` only if cspell rejects a newly joined line.

## Order of work

1. Walking skeleton, the proof for criterion 1: run the check command below over the target list and watch it report the 39 files. This is the failing acceptance check.
2. Build the target list once: tracked, non-symlinked `*.md`, minus the six exclusions and this change folder. Save it to the scratchpad; every later step uses it.
3. Unwrap by group, one commit each, running the word check (criterion 3) before every commit:
   1. root and config files: `Unwrap the playbook and root markdown`;
   2. skills: `Unwrap the skill files`;
   3. agents: run `bin/generate-codex-agents`, then commit the `.md` and `.toml` changes together: `Unwrap the agent files and regenerate the Codex agents`;
   4. docs: `Unwrap the docs`.

   The command is `markdownlint -c markdownlint/.config/markdownlint/unwrap.json -r markdownlint/.config/markdownlint/no-hardwrap.cjs --fix <files>`. It uses the package in the worktree, because `~/.config/markdownlint` is not stowed yet.
4. After each group, run cspell on the changed files. Add words to `project-dictionary.txt` only when a joined line exposes one, in the same commit.
5. Run the criteria 1–5 checks. Run the full `test/*_test.rb` suite, and read a few unwrapped files by eye: `agents.md` §7, one skill, one agent.
6. Commit the plan with the change folder, run `/review` (Etienne), then `/finish` (Etienne).

## Risks

- **The fix changes rendering.** Joining a line that starts with `-`, `+`, `1.`, `#` or `>` could turn text into a list or heading on re-parse. micromark parsed these as continuation text, so joining keeps them inline; the risk would come from a joined line starting a new block. Check: after the unwrap, the `no-hardwrap` rule finds no new list or heading. Also diff the block structure: count headings and list items per file before and after with a micromark token dump. They must match.
- **Frontmatter in skills and agents.** YAML front matter is not a paragraph, so it is untouched. Confirmed by the rule's front matter test from PR #160.
- **The Codex agent drift test** fails if the TOML files are not regenerated. Step 3c regenerates them in the same commit.
- **Diff size.** About 40 files, several hundred lines. Split by group so each commit reviews on its own.
- **Rejected:** hand edits (slow, error-prone), a guard test (Etienne declined).

## Decisions from planning (2026-09-28)

- The token-count structure check is enough. Any file whose heading, list-item or block-quote count changes is fixed by hand in that group's commit and listed in the PR body.
- A fresh worker in a herdr pane builds it (`implement handoff`). The worktree and branch above already exist, with the change folder committed: `cd` into that worktree and work there. Do not create a second worktree or branch.

## Out of scope

Excluded files, other repositories, and any change to the rule itself. If the unwrap shows a rule bug, stop and report it. Fix it in its own change.

## Proof

- 1 No findings left → command: `xargs markdownlint -c …/no-hardwrap.json -r …/no-hardwrap.cjs < targets.txt` exits 0 with no output.
- 2 Exclusions untouched → command: `git diff --quiet origin/main -- <six files>` exits 0.
- 3 Same words → command: for each changed `.md`, `diff <(git show origin/main:$f | tr -s ' \n\t' '\n\n\n') <(tr -s ' \n\t' '\n\n\n' < $f)` is empty.
- 4 Only expected files → command: `git diff --name-only origin/main...HEAD` matches `\.md$`, `^codex/\.codex/agents/.*\.toml$`, `^docs/changes/no-hardwrap-markdown-unwrap/` or `^project-dictionary\.txt$`, and nothing else.
- 5 Suite green → `for f in test/*_test.rb; do ruby -Itest "$f"; done`, 0 failures and 0 errors, including `test/codex_agent_generation_test.rb`.
- Extra structure check (risk above) → per file, the count of `atxHeading`, `setextHeading`, `listItemPrefix` and `blockQuote` tokens before and after is equal. This uses a scratchpad node script built on the `micromark-parse.mjs` that markdownlint 0.40 ships. The script is not committed.

No unit tests: no production code changes.
