# Plan: Tighten the autoMode block in settings.json

From `intent.md` (2026-11-03). Status: accepted.

## Design

### Domain terms

- **autoMode block**: the `autoMode` key of `claude/.claude/settings.json`, with an `environment` array of strings and a `soft_deny` array of strings. The auto-mode classifier reads it.
- **credential helper**: `git/.config/git/credential-1password`. It calls `op read` and holds no secret value.
- **credential-file rule**: the one custom `soft_deny` rule after `"$defaults"`.
- No `GLOSSARY.md` term applies, and no new glossary term is needed. These are Claude Code settings words, not domain terms of this repository.

### Diagrams

Not affected: the change edits strings in a JSON file. It has no objects, tables or flows.

### Signatures

Not affected: no Ruby class or method changes; the change edits JSON strings only.

### Complexity

Not affected: the classifier reads one `soft_deny` string less and one `environment` string more.

### Invariants

- `soft_deny[0]` is `"$defaults"`. Enforced by the edit; checked with `jq`.
- `soft_deny` has exactly two entries: `"$defaults"` and the credential-file rule. Checked with `jq`.
- No string in the autoMode block holds `kubectl` or `-n test`. Checked with `jq` and `grep`.
- No key outside `autoMode` changes. Checked by reading `git diff origin/main...HEAD`.
- The diff holds no `nedap` or `caren`. Checked with `grep`.

### Before

Line numbers in the main checkout's uncommitted copy of `claude/.claude/settings.json`. Commit one copies this block, so the worktree has the same line numbers after it.

- 355 `"autoMode": {`, 356 `"environment": [`, 357 `"### Org-wide"`.
- 362 `"**Secrets management**: None configured"`.
- 363 `"**Default / protected branches**: main (default); Rulesets: ..."`.
- 372 `"**Sensitive data locations & audiences**: git/.config/git/credential-1password, test/..._test.rb ... share only with audiences cleared at the [named+specifics] bar"`.
- 377 `"### User-specific"`, 378 Primary use, 379 Trusted repo, 380 Org-specific CLIs.
- 381 `"routine under eirvandelden/ prefix: git push/pull to this repo's own remote is routine"` (last `environment` entry).
- 383 `"soft_deny": [`, 384 `"$defaults"`, 385 the `Bash(rm -rf:*) in test/ fixtures ...` rule, 386 the `kubectl ... (-n test)` rule.

### After (the six edits of commit two, plus edits 7 and 8 from review)

All line numbers below are before-state lines. After the edits, the new `edit 6` line is 382, and the credential-file rule moves to line 386.

1. Line 385 becomes the credential-file rule, the intent's text verbatim. It loses its trailing comma, since it is now the last entry. Text in the block below, key `edit 1`.
2. Line 386 (the `kubectl` rule) goes.
3. Line 362 becomes the text of `edit 3`.
4. Line 372 becomes the text of `edit 4`. The audience clause stays.
5. Line 381 becomes the text of `edit 5`, and gains a trailing comma.
6. One new line, the text of `edit 6`, goes after line 381 as the last `environment` entry.

The exact strings, as JSON (the keys only label them; they do not go into `settings.json`):

```json
{
  "edit 1": "Deleting, truncating or overwriting (rm, git rm, git clean, git checkout --, git restore, mv, `>`) `git/.config/git/credential-1password` or `test/{git_credential_helper,secrets_loader,secrets_scope_menu}_test.rb` requires the user to name the exact file",
  "edit 3": "**Secrets management**: 1Password (`op`); the credential helper and its tests call `op read`",
  "edit 4": "**Sensitive data locations & audiences**: resolved 1Password values (output of `op read`), `.env` and `.env.*` files, `*.key` and `*.pem` files, and any unusual-named .gitignore'd path — share only with audiences cleared at the [named+specifics] bar. The credential helper (`git/.config/git/credential-1password`) and its tests are tracked code with no secret values, and are fine to commit and push",
  "edit 5": "**Routine pushes**: git push/pull to `origin` of this repo (github.com:eirvandelden/dotfiles.git) is routine; other `eirvandelden/*` repos follow playbook rule 19",
  "edit 7": "**Source control**: The trusted repo is eirvandelden/dotfiles and its remote (github.com:eirvandelden/dotfiles.git); other repos owned by the `eirvandelden` GitHub user are trusted for push and pull too (playbook rule 19). Dotfiles is public: only this repo's own work belongs here, never ported content from elsewhere",
  "edit 8": "**Trusted repo**: /Users/etienne.vandelden/Developer/dotfiles (github.com:eirvandelden/dotfiles.git), public — only this repo's own work is OK to push here; secrets/sensitive data never cleared by visibility. Other repos owned by `eirvandelden` are trusted remotes too",
  "edit 6": "**Branches and dotfiles**: `main` is protected by a ruleset and takes no direct push. Pushes to feature branches on `origin` are routine. Editing shell profiles inside this repo is routine. `stow` and `lefthook install` need an explicit user request (playbook rules 7, 12, 19)"
}
```

Line 363 stays as it is. No new string holds a double quote or a backslash, so none needs a JSON escape.

Resulting `soft_deny`:

```json
"soft_deny": [
  "$defaults",
  "Deleting, truncating or overwriting (rm, git rm, git clean, git checkout --, git restore, mv, `>`) `git/.config/git/credential-1password` or `test/{git_credential_helper,secrets_loader,secrets_scope_menu}_test.rb` requires the user to name the exact file"
]
```

### Alternatives

- **A. Smallest diff** (architect 1): edit lines in place and add no line. Edit 6 goes onto the end of the Org-specific CLIs line (380) and the routine line (381). Rejected: line 380 then holds three facts (tool provenance, shell profiles, stow/lefthook), and the branch facts spread over three lines.
- **B. One rule per labelled line** (architect 2): every behavioural rule becomes its own `**Routine — <topic>**` or `**Needs explicit user request — <topic>**` line, five new lines, and edit 1 writes the brace list out as four paths. Rejected: the label convention is not a Claude Code schema and nothing keeps it; edit 4 splits over two places; edit 1 departs from the intent's agreed text.
- **C. Chosen**: edits 1–5 in place, edit 6 as one new line. It keeps the intent's wording, adds one line, and keeps the branch and dotfile rules together.

## Design decisions

- Edit 1 uses the intent's brace form verbatim. The classifier is a model and reads brace expansion; the intent fixed this text.
- Edit 6 restates "`main` is protected by a ruleset" although line 363 says it too. The new line then reads whole, without a cross-reference.
- `claude auto-mode config` checks the worktree file in isolation with `CLAUDE_CONFIG_DIR`. `--settings <file>` does not work for this: it merges with the live `~/.claude/settings.json`, and the arrays concatenate (checked on 2026-11-03).
- Edits 1, 5, 7 and 8 depart from the intent's verbatim text after review, on Etienne's decisions of 2026-11-03: edit 1 adds `git rm` and `git restore`; edit 5 reads "is routine; other `eirvandelden/*` repos follow playbook rule 19"; edits 7 and 8 widen the `Source control` and `Trusted repo` lines to the other repos of the `eirvandelden` GitHub user, so the classifier sees no dotfiles-only trust. The Proof check counts them.
- `claude auto-mode critique` cannot run on the worktree file before merge. Under `CLAUDE_CONFIG_DIR` it fails with "Could not resolve authentication method" (checked on 2026-11-03). With `--settings` it sees the old rules too. The live file is the main checkout's copy, which the intent keeps untouched. So the critique criterion runs after merge, once Etienne has replaced the main checkout's uncommitted edit. This changes when that criterion is checked, not what it checks; the report raises it as a decision.

## Integration points

- `~/.claude/settings.json` is a stow symlink to the main checkout's `claude/.claude/settings.json`. Every Claude Code session reads it. The worktree file is not live until the branch merges and the main checkout updates.
- The main checkout holds the uncommitted autoMode edit. After the merge, `git pull` in the main checkout conflicts with it until Etienne discards it (`git -C ~/Developer/dotfiles checkout -- claude/.claude/settings.json`). That is Etienne's step, out of scope here.

## Files that change

- `claude/.claude/settings.json` — commit one adds the autoMode block as it stands in the main checkout; commit two applies the six edits above. Nothing else in the file changes.

## Order of work

No criterion needs a test (configuration, playbook rule 3). Work happens in `/Users/etienne.vandelden/Developer/dotfiles/.worktrees/tighten-auto-mode`; relative paths below start there. Spell that path out in full in every `git` command; the consent guard cannot expand `cd "$VAR"`.

`$S` below means one scratch directory: the session scratchpad, or a directory made once with `mktemp -d`. Shell state does not carry between tool calls, so write its full path into each command.

1. Check the base. `git -C /Users/etienne.vandelden/Developer/dotfiles rev-parse HEAD` and `git -C /Users/etienne.vandelden/Developer/dotfiles/.worktrees/tighten-auto-mode rev-parse origin/main` both print `a51f608f…`, or `git diff` between them shows no change to `claude/.claude/settings.json`.
2. Save the main checkout's diff: `git -C /Users/etienne.vandelden/Developer/dotfiles diff claude/.claude/settings.json > $S/main-before.diff`.
3. Check the diff holds no work reference: `test -z "$(grep -iE 'nedap|caren' $S/main-before.diff)"` exits 0.
4. Apply it: `git -C /Users/etienne.vandelden/Developer/dotfiles/.worktrees/tighten-auto-mode apply $S/main-before.diff`. Then `jq . claude/.claude/settings.json > /dev/null` exits 0.
5. Commit one: `Add the autoMode block to the Claude settings`. Only `claude/.claude/settings.json` is staged.
6. Save the expected strings: copy the JSON block under `### After` in this plan to `$S/expected.json`, and check `jq -e 'length == 7' $S/expected.json`.
7. Apply edits 1–6 with the Edit tool, exact strings from `$S/expected.json`.
8. Run every check in `## Proof` except the critique and the post-deliver `nedap|caren` check.
9. Re-read `git diff HEAD`; every hunk is one of the six edits.
10. Commit two: `Tighten the autoMode rules and environment`.
11. Confirm the main checkout is untouched: `git -C /Users/etienne.vandelden/Developer/dotfiles diff claude/.claude/settings.json | diff - $S/main-before.diff` prints nothing.

## Risks

- A trailing comma left on the old line 385 breaks the JSON and with it every Claude Code session after merge. `jq .` catches it before commit two.
- A mismatch between the main checkout and `origin/main` makes `git apply` fail. Step 1 checks the base; on a failure, stop and report, never hand-merge.
- The critique may raise new items for the new wording. Items 1–4 are the criterion; item 5 is decided in `intent.md` Decisions and may stay; a new item goes to a later change.
- Rejected: temporarily copying the worktree file over the main checkout to run the critique. It edits the live config of every session and breaks the intent's rule that the main checkout stays untouched.

## Proof

- `jq . claude/.claude/settings.json` parses → check: `jq . claude/.claude/settings.json > /dev/null` exits 0.
- All six edits are in place, exactly, and the replaced text is gone → check: `jq -e --slurpfile w $S/expected.json '$w[0] as $w | .autoMode as $a | ($a.soft_deny == ["$defaults", $w["edit 1"]]) and ($a.environment | length == 26) and ($a.environment[-1] == $w["edit 6"]) and ($a.environment[-2] == $w["edit 5"]) and any($a.environment[]; . == $w["edit 3"]) and any($a.environment[]; . == $w["edit 4"]) and any($a.environment[]; . == $w["edit 7"]) and any($a.environment[]; . == $w["edit 8"]) and all($a.environment[]; startswith("routine under") | not) and all($a.environment[]; . != "**Secrets management**: None configured")' claude/.claude/settings.json` prints `true` and exits 0. The same check on the before-state file prints `false` (checked on a scratch copy, 2026-11-03).
- `claude auto-mode config` shows the new text → check: `mkdir -p $S/cfg && cp claude/.claude/settings.json $S/cfg/settings.json && CLAUDE_CONFIG_DIR=$S/cfg claude auto-mode config | jq -e --slurpfile w $S/expected.json '$w[0] as $w | . as $c | any($c.soft_deny[]; . == $w["edit 1"]) and all($w["edit 3"], $w["edit 4"], $w["edit 5"], $w["edit 6"], $w["edit 7"], $w["edit 8"]; . as $s | any($c.environment[]; . == $s)) and all($c.environment[]; startswith("routine under") | not)'` prints `true` and exits 0. Without `CLAUDE_CONFIG_DIR`, against the live config, it prints `false` (checked 2026-11-03), which shows the isolation works.
- `soft_deny` still starts with `"$defaults"` → check: `jq -e '.autoMode.soft_deny[0] == "$defaults"' claude/.claude/settings.json`.
- `soft_deny` holds `"$defaults"` plus one custom rule, the credential-file rule → check: `jq -e '.autoMode.soft_deny | length == 2' claude/.claude/settings.json`; the six-edits check above proves the rule's exact text.
- The environment no longer mentions `kubectl` or `-n test` → check: `jq -e '[.autoMode[][] | select(test("kubectl|-n test"))] | length == 0' claude/.claude/settings.json` exits 0.
- `git diff origin/main...HEAD | grep -iE 'nedap|caren'` prints nothing → check: before `deliver`, `test -z "$(git -C /Users/etienne.vandelden/Developer/dotfiles/.worktrees/tighten-auto-mode diff origin/main...HEAD -- claude/.claude/settings.json | grep -iE 'nedap|caren')"` exits 0. `intent.md` and `plan.md` name those words, so the unscoped command matches them until `deliver` removes `docs/changes/tighten-auto-mode/`. After `deliver`, run the intent's exact command; it prints nothing.
- `claude auto-mode critique` no longer reports items 1 to 4 (item 5 may stay, by decision) → check, after merge and after Etienne discards the main checkout's uncommitted edit: `claude auto-mode critique` from any directory; read the output against the six issues in `intent.md`'s Problem. Before merge it cannot run on the worktree file (see `## Design decisions`).
- Invariant: no key outside `autoMode` changes, enforced by the edit scope → check: `git diff origin/main...HEAD` touches only lines inside the `autoMode` object.

Per changed file, the unit tests expected:
- `claude/.claude/settings.json`: none; configuration has no tests (playbook rule 3).

Test setup: none. The checks need `jq`, the `claude` CLI and a scratchpad directory.

## Out of scope

- New `soft_deny` rules for `bundle install`, deploys or `--force`; hooks enforce those.
- Any other key in `settings.json`, and the hooks.
- The main checkout's uncommitted edit; it stays as it is.
- Glossary changes.

---
Domain skills applied: dotfiles-maintenance (stow symlink, edit the source file), software-design (alternatives).

## Critique

### Round 1 (codex exec -p terra)

- The unscoped `git diff origin/main...HEAD | grep -iE 'nedap|caren'` matches `intent.md` and `plan.md`, which name those words → fixed (Proof scopes the pre-deliver check to `claude/.claude/settings.json` and runs the intent's exact command after `deliver` removes the change folder; no intent amendment needed)
- The critique criterion runs only after merge, so autonomous delivery cannot prove it first → fixed (no non-mutating authenticated pre-merge run exists: `CLAUDE_CONFIG_DIR` loses auth and `--settings` merges with the live file; `## Design decisions` records this and the report raises it as a `Decision needed:` line)
- Proof did not prove all six edits: edit 4 was missing and the rule check was loose → fixed (one `jq` check compares `soft_deny` exactly, all four environment strings, the entry count, and the absence of the replaced text; tested true on a scratch after-state and false on the before-state)
- Two absence checks passed by exiting 1 → fixed (both now exit 0 on success: a `jq -e` length check and a `test -z` wrapper)
- Line references mixed before and after positions → fixed (`### After` states that all numbers are before-state lines and names the after positions)
- `<scratchpad>` was never defined → fixed (`## Order of work` defines `$S` once and says to write its full path into each command)
- `### Signatures` had an extra `Not checked:` line → fixed (one `Not affected:` line)
