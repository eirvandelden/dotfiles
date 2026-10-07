# Spec: Autonomous delivery for personal projects

From `intent.md` (2026-10-01). Status: accepted.

## Flagged concerns

- Playbook rule 17 says an accepted `plan.md` needs Etienne's literal word "accepted". Autonomous mode replaces that word with the two-model critique below, for personal repos only. Work repos keep rule 17 unchanged. Rule 17 and its `core-values.yml` mirror need a personal-scope carve-out.
- Etienne's escalation answers listed only "stuck after 3 attempts" and "review disagreement". The intent also returns material behaviour changes and permission needs to him. This spec keeps all four, because the intent is the accepted source and the permission rules (8, 9, 11, 12, 13) stay in force. Etienne confirmed all four on 2026-10-01.
- Playbook rule 6 forbids posting GitHub comments as Etienne without approval. Opening the PR is allowed (rule 5). Replying to human reviewers on it stays forbidden.
- Autonomy must not weaken checks. A hook cannot prove "no weakened test", so the independent review round is the control.

## Requirements

1. **Scope test.** Autonomy applies only when `origin` matches `RemoteMatcher.personal?` (GitHub owner `eirvandelden`). Any other remote, or no remote, uses the current approval flow.
2. **Scope conversation.** The coordinator interviews Etienne about what to build, how a human uses it and what success looks like. It writes this as `intent.md`. Etienne's literal "accepted" on that intent is the only human gate before delivery.
3. **Single coordinator.** One coordinator pane drives intent, spec, plan, implement, review, fix and PR. It runs each stage skill in an `auto` mode. Stage panes do work. They never wait for Etienne's approval.
4. **Auto mode.** In `auto` mode the spec and plan skills skip the "accepted" prompt. They flip `Status: accepted` only after the critique rule (5) passes. They still commit and push each artifact alone, as today.
5. **Cross-model critique.** Before `spec.md` and before `plan.md` become accepted, the other model family's local CLI critiques them (Claude critiques Codex-written work and the reverse). Findings are fixed or dismissed with a written reason in the artifact.
6. **Independent review.** Before the PR, the `reviewer` agent and a Codex CLI review each review the diff. Findings loop to fixed or dismissed-with-reason. Review disagreement that survives two rounds goes to Etienne.
7. **Checks stay strict.** The coordinator runs tests, linters, Brakeman and Bundler Audit. It never edits a linter config, skips a test or adds a disable comment to pass. Pre-push `review.md` freshness is still enforced.
8. **Verified behaviour.** The coordinator exercises the delivered behaviour as a human would (rule 22) and records the evidence.
9. **Escalation.** The coordinator stops and asks Etienne, with one concrete decision, on: a choice that materially changes the agreed behaviour; a permission need from rules 8, 9, 11, 12, 13; three failed attempts at one problem; review disagreement after two rounds. It lists known permission needs during the scope conversation.
10. **Final handoff.** The coordinator opens a PR on `origin` with the repo template and sends Etienne a short account: delivered behaviour, evidence, check results, review outcome. Etienne's approval of the merge is the second and last gate. Agents never merge. Deployment is out of scope.
11. **Both CLIs.** Claude and Codex guidance state the same autonomy boundaries. Shared text lives once, with adapters only where formats differ.
12. **Public-safe.** No employer name, internal source or credential enters the changed files. The `RemoteMatcher` allowlist file stays outside the repo.

## Design decisions

- **Personal test reuses `RemoteMatcher`.** It exists, is tested and already fails closed for work remotes. A marker file adds setup for no gain.
- **Coordinator over chained panes.** One agent holds the state, so escalation and retries happen in one place. The `hand-off-plan.sh` chain keeps working for work repos.
- **Critique replaces acceptance, not the artifact.** The documents still exist and are committed. Etienne can read them but no longer has to.
- **Two review sources.** Claude and Codex differ in blind spots. A shared-model review would repeat its own errors.
- **Autonomy is a mode of existing skills.** No new stage skill, no new pipeline. This keeps one source of truth per stage.
- **First trial repo left open.** Chosen after this spec lands. Provisional repo: `journal_administration`. The change itself is picked with Etienne at trial time.

## Integration points

- `claude/.claude/PLAYBOOK.md`, `AGENTS.md`, `agents.md` and `codex/.codex/PLAYBOOK.md`: rule 17 carve-out, new autonomy section.
- `claude/.claude/core-values.yml` and the `core-values.rb` hook: mirror the carve-out.
- Skills `intent`, `spec`, `plan`, `implement`, `review`, `code-review`, `finish`: `auto` mode and the critique step.
- `~/.config/herdr/scripts/hand-off-plan.sh` and `start-review.sh`: coordinator launch.
- `claude/.claude/hooks/remote_matcher.rb`, `consent-guard.rb`, `test-guard.rb`: personal test and unchanged consent rules.
- `codex/.codex` config and skills path (`~/.agents/skills`): Codex parity and the Codex critique and review calls.
- `journal_administration`: first end-to-end trial.

## Acceptance criteria

- Starting a change in a repo whose `origin` is `github.com/eirvandelden/…` offers autonomous delivery.
- Starting a change in a repo with any other `origin` runs the current approval flow and still requires "accepted" on the spec and plan.
- Saying "accepted" on the intent starts delivery with no further approval prompt before the PR.
- Auto mode marks `spec.md` accepted only after a Codex or Claude critique round, and the critique findings are recorded in it.
- Auto mode marks `plan.md` accepted only after the same critique round.
- A diff reaches the PR only after the reviewer agent and the Codex review each leave no open finding.
- A failing test is fixed in the production code, and the PR diff contains no skipped test or linter disable comment.
- A change that alters the agreed behaviour makes the coordinator stop and ask Etienne one concrete question.
- A needed new gem makes the coordinator stop and ask for approval, with the reason.
- Three failed attempts at one problem send Etienne a blocker report with a decision to make.
- A review finding still disputed after two rounds goes to Etienne instead of being dismissed.
- The finished PR comes with a short account of the behaviour and its evidence, and the coordinator does not merge it.
- Claude and Codex guidance both state the same autonomy boundaries.
- The changed files contain no employer name or credential.

---
Domain skills applied: None (workflow and tooling change; `dotfiles-maintenance` conventions followed).
