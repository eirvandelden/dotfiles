# Phase 4: `finish-change` and `prepare-for-team`

Part of the change in `docs/changes/ai-native-workflow/` (read `intent.md`, `spec.md`, `plan.md`, `habits.md` first). Repository: `~/Developer/dotfiles`; employer-specific parts are in `~/Developer/dotfiles-work/docs/changes/ai-native-workflow/work-specifics.md` and are executed there, in that repo's own worktree. Requires phase 3 merged.

## Context

The change folder is removed when the change is handed on (spec §1.3):

- Personal: `finish-change`, after Etienne's review is complete. Then merge.
- Work: `prepare-for-team`, before the PR becomes visible to colleagues. Work PRs exist early; colleagues only look once the PR itself is on the team's review project with its Status field set to the review state. This skill **assumes review already happened** (the phase-3 freshness check proves it); it does not review again.

`prepare-for-team` also carries the intent into the PR body, because the files disappear: it fills the repository's PR template (playbook rule 5 — always the template) from `intent.md` and `plan.md`. Work-only: when the change affects another application, the artifacts are distilled into an ADR before deletion — the only artifact that survives (spec §1.3).

Public repo constraint: this skill must not know employer names, project numbers, or status field IDs. Everything employer-specific sits behind one optional script that the private dotfiles-work repo stows into place.

## Talk first

- ~~ADR location in work repos~~ — decided 2026-09-21: `docs/adr/NNNN-<slug>.md`, created on first use. No conversation needed.
- **Reviewer list**: who `prepare-for-team` requests by default, and whether it asks each time. Default if undecided: ask each time, offer the last-used list.
- **Dry run first**: the first real use of `prepare-for-team` on a work PR runs with `--dry-run` and Etienne executes the printed steps by hand once.

## Steps

1. **RED — PR body filler.** `claude/.claude/skills/prepare-for-team/scripts/fill-pr-template` (Ruby). Input: template path, `intent.md`, `plan.md`. Output: the template with sections filled — a heading matching /summary|what/i gets the intent's Problem + Proposed outcome; a heading matching /why|motivation/i gets the Problem; /implementation|how|details/i gets the plan's Files that change + Order of work; /test|verify/i gets the plan's Proof; unknown headings are left with their template text; a template with no matching headings gets one `## Context` block prepended. Test `test/fill_pr_template_test.rb` with two fixture templates (a checkbox-style one and a plain one) and the no-template case. Run: fails. Write.

2. **`finish-change` skill.** Steps it performs, in order, stopping at the first failure:
   - `review-report-fresh` exits 0 (else: "run `/review-branch` first").
   - Working tree clean.
   - Remote is a personal repository (owner from `git remote get-url origin` is the user's own; the consent guard's built-in owner check is the reference — reuse its logic, do not copy the string). On a work remote it says "use `/prepare-for-team`" and stops.
   - `git rm -r docs/changes/<slug>` and commit `Remove change artifacts for <slug>`.
   - Prints the merge command; does not merge, does not push unless asked.

3. **`prepare-for-team` skill** (`disable-model-invocation: true`; runs only on explicit command; supports `--dry-run` that prints every step and changes nothing). Steps:
   - Preconditions: `review-report-fresh` exits 0; working tree clean; a PR exists for the branch (`gh pr view --json number,url,isDraft,body`); on a personal remote it says "use `/finish-change`" and stops.
   - PR body: find the template (`.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`, or `docs/`); run `fill-pr-template`; show the result; on confirmation `gh pr edit --body-file`.
   - ADR question (work only): "Does this change affect another application — API contract, published event, shared schema, anything another team consumes?" On yes: write the ADR from `intent.md` + `spec.md` into the location named by the `adr-location` file (see step 4), numbering it after the highest existing one; on no: continue.
   - `git rm -r docs/changes/<slug>`, commit `Remove change artifacts for <slug>`.
   - `git push` (the consent guard governs the remote; `--force-with-lease` only if the branch was rebased in this run).
   - If executable, run `~/.claude/prepare-for-team/after-push <pr-number> <pr-url>`; this is where the private repo flips the review status and marks the PR ready. Absent script: print "no after-push script; set the review status by hand".
   - Request reviewers: `gh pr edit --add-reviewer` with the confirmed list.
   - Prints what it did and the PR URL. Never comments on the PR (playbook rule 6).

4. **Contract for the after-push script.** Document in the skill: path `~/.claude/prepare-for-team/after-push`, arguments, expected exit codes, and a `~/.claude/prepare-for-team/adr-location` file whose single line is the repo-relative ADR path pattern (`docs/adr/NNNN-<slug>.md` for the work repositories; absent file means "ask"). Both files are supplied by dotfiles-work through its `claude` stow package (`STOW_SHARED`, file by file). The public skill only reads them. Add the same contract note to `codex` via the phase-1 link (paths are `~/.claude/...` on purpose — one location, both tools read it).

5. **Habits and playbook.** `agents.md` §7.5 (PR workflow): add "artifacts are removed by `finish-change`/`prepare-for-team`; never by hand". `SKILLS-INDEX.md`: add both skills.

6. **Parity.** Both skills get Codex links and `openai.yaml` with `allow_implicit_invocation: false` for `prepare-for-team` (parity test enforces it).

## Files

New: `claude/.claude/skills/finish-change/`, `claude/.claude/skills/prepare-for-team/` (+ `scripts/fill-pr-template`), `test/fill_pr_template_test.rb`, Codex links. Changed: `agents.md` §7.5, `SKILLS-INDEX.md`. In dotfiles-work (see work-specifics): `claude/.claude/prepare-for-team/after-push`, `claude/.claude/prepare-for-team/adr-location`.

## Verification

- `test/` green.
- Personal throwaway repo: `/finish-change` refuses without a fresh report, deletes with one, leaves one commit `Remove change artifacts for <slug>`.
- Work checkout, a real in-flight branch, `--dry-run`: printed steps match expectations; Etienne runs them by hand once; second time for real. Colleagues see a PR with a filled template and no `docs/changes/` in "Files changed".
- Codex: `$finish-change --dry-run` prints the same steps.
- **Etienne, by hand, after merge:** `stow -R --no-folding claude codex`; in dotfiles-work, restow its `claude` package. Start habit 5.

## Out of scope

Reviewing (phase 3). Posting PR comments — never. Merging. Changing the team's PR template. Choosing the ADR format beyond "one markdown file, title, context, decision, consequences".
