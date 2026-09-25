# Review: ghostty-shift-enter-newline-followup

## Round 1 — 2026-09-23T09:14Z — 5a77a583

No `REVIEW.md` or `REVIEW.local.md` at the repository root; used the default passes (Bugs, Security, Compliance). No uncommitted changes. cspell on the touched files: 0 issues.

Bugs: nothing found. `ghostty/.config/ghostty/config` is byte-identical to its state before 50a217e5 (PR #146); `git diff 50a217e5~1 HEAD -- ghostty/.config/ghostty/config` is empty. No other file in the repo still references the removed shift+enter keybind.

Security: nothing found.

Compliance (spec acceptance criteria):
- Ghostty config has no `13;2u` and matches pre-#146 → proven by the empty diff above.
- `~/.claude/keybindings.json` binds `alt+enter` to `chat:newline` under `Chat`, no `shift+enter` → confirmed by reading the file (outside the repo).
- herdr forwards alt+enter distinct from enter → evidence only in the commit message of 5a77a583 (`b'\r'` versus `b'\x1b\r'`); no transcript in the change folder. Accepted by the plan's Proof section as manual evidence.
- alt+enter inserts a newline live → claimed in the commit message; not checkable from the diff.
- Reasoning recorded → 5a77a583 names herdr 0.9.1 and links github.com/herdrdev/herdr/issues/1844.

- [ ] Nit: `~/.claude/keybindings.json` is a plain file, not part of the `claude` stow package, although `~/.claude/CLAUDE.md`, `PLAYBOOK.md` and `core-values.yml` are stowed from `claude/.claude/`. A fresh machine gets no alt+enter binding and newline input stops working there. The spec chose this on purpose; consider tracking it in a separate change. — `docs/changes/ghostty-shift-enter-newline-followup/spec.md:23` →
- [ ] Nit: The plan says a PR-body note should record the risk that a future herdr version changes alt-key handling. No PR exists yet to check; make sure the note is in the PR body when it is opened. — `docs/changes/ghostty-shift-enter-newline-followup/plan.md:61` →
- [ ] Nit: The raw-byte evidence exists only in the commit message; plan step 7 says to paste the transcript into the report. Adding it to the PR body keeps it visible to reviewers. — `docs/changes/ghostty-shift-enter-newline-followup/plan.md:56` →
