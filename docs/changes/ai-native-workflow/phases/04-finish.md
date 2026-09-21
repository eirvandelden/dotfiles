# Phase 4: `finish` — one skill closes a change in both scopes

Part of the change on branch `ai-native-workflow`. Its documents live in the worktree `~/Developer/dotfiles/.worktrees/ai-native-workflow/docs/changes/ai-native-workflow/` until the change finishes; read them there (read `intent.md`, `spec.md`, `plan.md`, `habits.md` first). Repository: `~/Developer/dotfiles`; employer-specific parts are in `~/Developer/dotfiles-work/.worktrees/ai-native-workflow/docs/changes/ai-native-workflow/work-specifics.md` and are executed there, in that repo's own worktree. Requires phase 3 merged.

## Context

The change folder is removed when the change is handed on (spec §1.3). Personal and work do the same core thing — confirm the review is fresh, delete `docs/changes/<slug>/`, commit — and differ only in what happens around it. One skill, `finish`, with the scope detected from the remote, not two skills.

- **Personal**: review fresh → delete → commit. Then Etienne merges.
- **Work**: review fresh → fill the PR template from the artifacts → ADR if the change affects another application → delete → commit → push → add the PR to the team's review project with Status "Needs Review" → request reviewers. Work PRs exist early; colleagues only look once the PR is on that board, so the artifacts vanish just before they would be seen. The skill **assumes review already happened** (the phase-3 freshness check proves it); it does not review again.

Public repo constraint: the skill must not know employer names, project numbers, or status field IDs. Everything employer-specific sits behind one optional script and one config file that the private dotfiles-work repo stows into place.

## Talk first

- **Reviewer list**: who `finish` requests by default at work, and whether it asks each time. Default if undecided: ask each time, offer the last-used list.
- **Dry run first**: the first real use on a work PR runs with `--dry-run` and Etienne executes the printed steps by hand once.

## Steps

1. **RED — PR body filler.** `claude/.claude/skills/finish/scripts/fill-pr-template` (Ruby). Input: template path, `intent.md`, `plan.md`. Output: the template with sections filled — a heading matching /summary|what/i gets the intent's Problem + Proposed outcome; /why|motivation/i gets the Problem; /implementation|how|details/i gets the plan's Files that change + Order of work; /test|verify/i gets the plan's Proof; unknown headings keep their template text; a template with no matching headings gets one `## Context` block prepended. Test `test/fill_pr_template_test.rb` with two fixture templates (a checkbox-style one and a plain one) and the no-template case. Run: fails. Write.

2. **RED — scope detection.** `claude/.claude/skills/finish/scripts/change-scope` (Ruby) prints `personal` when `git remote get-url origin` resolves to the user's own GitHub account, `work` when it matches an entry in `~/.claude/consent-guard-allowed-remotes.txt`, exit 1 otherwise ("unknown remote; finish refuses to guess"). Reuse the matching logic from `claude/.claude/hooks/consent-guard.rb` by extracting it into a small shared Ruby file both require — do not copy it. Test `test/change_scope_test.rb`: own remote, allowlisted remote, unknown remote, no remote. Run: fails. Write. Run `test/consent_guard_test.rb` to prove the extraction changed nothing.

3. **`finish` skill** (`disable-model-invocation: true`; runs only on explicit command; `--dry-run` prints every step and changes nothing). Steps, stopping at the first failure:
   - Preconditions, both scopes: `review-report-fresh` exits 0 (else: "run `/review` first"); `review.md` has no open finding without a later round (else list them: "close or dismiss these first"); working tree clean; scope resolved by `change-scope`.
   - **Work only**: a PR exists for the branch (`gh pr view --json number,url,isDraft`). Find the template (`.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`, or under `docs/`); run `fill-pr-template`; show the result; on confirmation `gh pr edit --body-file`.
   - **Work only**: ADR question — "Does this change affect another application: API contract, published event, shared schema, anything another team consumes?" On yes: write the ADR from `intent.md` + `spec.md` at the path pattern in `~/.claude/finish/adr-location` (`docs/adr/NNNN-<slug>.md`; numbered after the highest existing one; sections Context / Decision / Consequences), commit it `Add ADR NNNN: <title>`. On no: continue. If the file is absent: ask where.
   - **Both**: `git rm -r docs/changes/<slug>`; when `docs/changes/` is now empty, remove the directory too (git does not track empty directories, so this is a working-tree `rmdir`); commit `Remove change artifacts for <slug>`.
   - **Personal**: print the merge command and stop. No push unless asked.
   - **Work only**: `git push` (the consent guard governs the remote; `--force-with-lease` only if the branch was rebased in this run). If executable, run `~/.claude/finish/after-push <pr-number> <pr-url>` — the private repo's script that puts the PR on the review board and sets the status; absent script: print "no after-push script; set the review status by hand". Then `gh pr edit --add-reviewer` with the confirmed list. Print what it did and the PR URL. Never comments on the PR (playbook rule 6).

4. **Contract for the private files.** Document in the skill: `~/.claude/finish/after-push <pr-number> <pr-url>` (exit 0 = done, non-zero = print stderr and stop before requesting reviewers), `~/.claude/finish/adr-location` (one line, repo-relative path pattern), optional `~/.claude/finish/reviewers` (one handle per line). All supplied by dotfiles-work through its `claude` stow package (`STOW_SHARED`, file by file). The public skill only reads them. Paths are `~/.claude/...` on purpose — one location, both tools read it.

5. **Playbook and index.** `agents.md` §7.5 (PR workflow): "artifacts are removed by `finish`; never by hand". `SKILLS-INDEX.md`: add `finish`.

6. **Parity.** Codex link and `agents/openai.yaml` with `allow_implicit_invocation: false` (parity test enforces it).

## Files

New: `claude/.claude/skills/finish/` (+ `scripts/fill-pr-template`, `scripts/change-scope`), `test/fill_pr_template_test.rb`, `test/change_scope_test.rb`, a shared Ruby file for remote matching next to `consent-guard.rb`, Codex link. Changed: `claude/.claude/hooks/consent-guard.rb` (requires the shared file), `agents.md` §7.5, `SKILLS-INDEX.md`. In dotfiles-work (see work-specifics): `claude/.claude/finish/after-push`, `claude/.claude/finish/adr-location`, optional `claude/.claude/finish/reviewers`.

## Verification

- `test/` green, including `consent_guard_test.rb` after the extraction.
- Personal throwaway repo: `/finish` refuses without a fresh review, refuses with an open finding, deletes with a closed review, leaves one commit `Remove change artifacts for <slug>`, prints the merge command, pushes nothing.
- Work checkout, a real in-flight branch, `--dry-run`: printed steps match expectations; Etienne runs them by hand once; second time for real. Colleagues see a PR with a filled template and no `docs/changes/` in "Files changed".
- Codex: `$finish --dry-run` prints the same steps.
- **Etienne, by hand, after merge:** `stow -R --no-folding claude codex`; in dotfiles-work, restow its `claude` package. All six workflow habits in `habits.md` start now.

## Out of scope

Reviewing (phase 3). Posting PR comments — never. Merging. Changing the team's PR template. Choosing the ADR format beyond "one markdown file, title, context, decision, consequences".
