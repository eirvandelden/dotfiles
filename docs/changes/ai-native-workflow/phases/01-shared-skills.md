# Phase 1: one source for shared skills, Claude ↔ Codex

Part of the change on branch `ai-native-workflow`. Its documents are merged to `main` and live at `~/Developer/dotfiles/docs/changes/ai-native-workflow/` until the change finishes; read them there (read `intent.md`, `spec.md`, `plan.md` first). Repository: `~/Developer/dotfiles`. Work in a worktree (`worktree-first` skill), PR against `origin`.

## Context

Claude skills live in `claude/.claude/skills/<name>/SKILL.md` and are stowed to `~/.claude/skills/`. Codex skills were kept in `codex/.codex/skills/<name>/` with `SKILL.md` and `agents/openai.yaml`, stowed to `~/.codex/skills/`. Today `handoff` and `review` exist as hand-typed copies on both sides and have drifted; Codex `worktree-first` has only an `openai.yaml` and no `SKILL.md` in the repo. `codex/.codex/HEADROOM.md` and `codex/.codex/WORKTREES.md` are also near-copies of the Claude files.

**Codex does not read `~/.codex/skills/`.** Verified 2026-09-21 on `codex-cli 0.154.0` and against `learn.chatgpt.com/docs/build-skills`: Codex scans `$CWD/.agents/skills`, `$CWD/../.agents/skills`, `$REPO_ROOT/.agents/skills`, `$HOME/.agents/skills`, `/etc/codex/skills` and bundled skills; there is no config key to add a directory. `~/.agents/skills/` already exists and holds one entry, `superpowers -> ~/.codex/superpowers/skills`, which is why plugin skills kept working while the three hand-written skills were invisible. A fresh `codex exec` confirmed: no skill named `worktree-first`, `handoff` or `review` is registered. "Codex supports symlinked skill folders and follows the symlink target."

Decision, given by Etienne on 2026-09-21 (playbook rule 12 satisfied): create a new stow package **`agents`** that delivers Codex skills to `~/.agents/skills/<name>`. `codex/.codex/skills/` goes away. The same package name is used in dotfiles-work for its Codex-only skill.

Later phases add six skills that must exist on both sides. This phase builds the mechanism so they are written once. The repo already does this for the playbook: `claude/.claude/PLAYBOOK.md` and `codex/.codex/PLAYBOOK.md` are relative symlinks to `agents.md`, committed as symlinks, and stow links to them file by file (`STOW_SHARED` uses `--no-folding`).

## Talk first

- None. The skill-path question is decided (above). If Codex turns out not to follow a symlinked *folder* whose target is under another stow package, stop and report; do not work around it with copies.

## Steps

0. **Confirm the scan path once more, cheaply.** `codex --version`; then from `~`, `codex exec --sandbox read-only --skip-git-repo-check '$worktree-first Do not use tools. Was a skill injected by that $ mention? If yes, quote its H1 verbatim.'` Expected before this phase: "injected: no" (the file sits under `~/.codex/skills/`, which Codex does not scan). Paste the answer into the PR description. Do **not** ask Codex whether a skill "is registered": skills with `allow_implicit_invocation: false` are hidden from the model's list by design and it answers "no" even when they work. Only the `$name` injection test or the loader's `total_skills=` debug count (`RUST_LOG=debug`, strip colour codes; hidden skills are not counted) tells the truth.

1. **RED — parity test.** Add `test/skill_parity_test.rb` (Minitest, same style as `test/consent_guard_test.rb`; run with `ruby -Itest test/skill_parity_test.rb`). It asserts, against repo paths (never `~`):
   - `agents/.agents/skills/` exists and every directory under it is a symlink whose target resolves to `claude/.claude/skills/<same name>`.
   - `codex/.codex/skills/` does not exist.
   - The set of skill names under `agents/.agents/skills/` equals the set under `claude/.claude/skills/`, minus two explicit constants `CLAUDE_ONLY` and `CODEX_ONLY` (both empty to start; adding a name needs a reason in a comment above it).
   - A skill whose Claude frontmatter has `disable-model-invocation: true` has `allow_implicit_invocation: false` in `claude/.claude/skills/<name>/agents/openai.yaml`, and vice versa.
   - `codex/.codex/WORKTREES.md` resolves to `claude/.claude/WORKTREES.md`.
   - `packages.conf` lists `agents` in both `STOW` and `STOW_SHARED`.
   Run it; it fails on every count. That is the gap.

2. **GREEN — the `agents` package and the three existing skills.** For each of `worktree-first`, `handoff`, `review` (`handoff` is absorbed into `implement` in phase 2 and `review` is rewritten in phase 3; converting them here still proves the mechanism on real files):
   - Diff the Codex `SKILL.md` against the Claude one. Fold any Codex-only sentence into the Claude file under a short `## Codex` heading (the Codex `worktree-first` note about `allow_implicit_invocation: false` is the known case).
   - Move `codex/.codex/skills/<name>/agents/openai.yaml` to `claude/.claude/skills/<name>/agents/openai.yaml` (Claude ignores `agents/`).
   - Create `agents/.agents/skills/<name>` as a relative symlink to `../../../claude/.claude/skills/<name>` (`ln -s`, `git add`); `git rm -r codex/.codex/skills/<name>`.
   - Do `worktree-first` first: it has no Codex `SKILL.md`, so it is the smallest step. Run the test after each skill. One commit per skill.
   Then add `agents` to `STOW` (alphabetically, after `1password`) and to `STOW_SHARED` in `packages.conf`; check `install/tasks/50_stow_all.sh` needs no change (it iterates the arrays). Confirm `codex/.codex/skills/` is gone. One commit.

3. **GREEN — shared docs.** Merge the Codex-specific paragraph of `codex/.codex/WORKTREES.md` into `claude/.claude/WORKTREES.md` under `## Codex`, then make the Codex file a symlink. `HEADROOM.md`: the two files differ in commands, not intent; make one file with `## Claude` and `## Codex` sections in `claude/.claude/HEADROOM.md` and link the Codex side to it. `codex/.codex/WORKTREES.md` names the old skill path (`codex/.codex/skills/worktree-first/`); the merged text names `agents/.agents/skills/`. Update `codex/.codex/AGENTS.md` only if a path changes (it should not — `~/.codex/HEADROOM.md` still exists after stow).

4. **REFACTOR.** `SKILLS-INDEX.md`: replace the "Two path forms" paragraph with three — repo path, `~/.claude/skills/`, `~/.agents/skills/` — and delete the "Not listed here" claim that `handoff`/`review` are Claude-only (they run in both; both spawn a Claude pane via herdr). `claude/.claude/skills/dotfiles-maintenance/SKILL.md` "Agent skills" section: describe the one-source layout in three lines, naming `agents/.agents/skills/` and stating that `~/.codex/skills/` is not read by Codex. `README.md` package list if it has one.

5. **Wire the test into lefthook.** `lefthook.yml` is the global fallback used by many repos; do not add a dotfiles-only command there. Instead add `test/skill_parity_test.rb` to whatever already runs the dotfiles tests (check `.github/workflows/` for the test job and `lefthook-local.yml`). If a CI workflow needs a new line, present the diff for approval before committing (playbook rule 13).

## Files

New: `agents/.agents/skills/{worktree-first,handoff,review}` (symlinks), `test/skill_parity_test.rb`. Changed: `claude/.claude/skills/{handoff,review,worktree-first}/` (+ `agents/openai.yaml` each), `claude/.claude/WORKTREES.md`, `claude/.claude/HEADROOM.md`, `codex/.codex/WORKTREES.md`, `codex/.codex/HEADROOM.md` (become symlinks), `packages.conf`, `SKILLS-INDEX.md`, `claude/.claude/skills/dotfiles-maintenance/SKILL.md`. Removed: `codex/.codex/skills/`.

## Verification

- `ruby -Itest test/skill_parity_test.rb` green; whole `test/` green.
- `git ls-files -s agents/.agents/skills` shows mode `120000` for each entry; `git ls-files codex/.codex/skills` prints nothing.
- `cspell`, `shellcheck`, `yamllint` on touched files (lefthook pre-commit does this).
- **Etienne, by hand, after merge:** from the dotfiles root, every call with `-t "$HOME"` (stow's default target is the parent directory, `~/Developer`): `stow -t "$HOME" -R --no-folding codex`, `stow -t "$HOME" --no-folding agents`, `stow -t "$HOME" -R --no-folding claude`. Stow cannot remove the old `~/.codex/skills/{handoff,review,worktree-first}` directories because their file links point at paths that no longer exist; remove those three directories by hand (they hold only dangling links). Then from `~`: `codex exec --sandbox read-only --skip-git-repo-check '$worktree-first Do not use tools. Was a skill injected by that $ mention? If yes, quote its H1 verbatim.'` must answer "injected: yes" and `# Worktree First`. In a fresh `claude` session confirm `/handoff` is listed. Report back if either is missing. Known until phase 2: `$handoff` in Codex resolves to the superpowers-ruby plugin's skill of the same name, not ours. The dotfiles-work half (its own `agents` package for `fizzy-sync`) is in `~/Developer/dotfiles-work/docs/changes/ai-native-workflow/work-specifics.md`, "Phase 1".

## Out of scope

New skills (phase 2+). Codex agents (phase 3). Deleting `plan-handoff` (phase 2). Changing what `handoff`/`review` do. `~/.agents/skills/superpowers` (owned by the superpowers plugin; phase 5 decides its fate). Touching `~/.codex/skills/.system/`, `~/.codex/superpowers/`, or anything herdr wrote. Running `stow`.
