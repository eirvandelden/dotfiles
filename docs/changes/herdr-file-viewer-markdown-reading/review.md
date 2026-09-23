# Review: herdr-file-viewer-markdown-reading

No `REVIEW.md` or `REVIEW.local.md` at the repository root; passes and severity follow the default policy in `claude/.claude/skills/new-repo-setup/references/REVIEW.md`.

## Round 1 — 2026-09-23T09:50Z — 493df79d

Scope: `git diff origin/main...HEAD` (5 commits); working tree clean. `ruby -Itest test/stow_package_roots_test.rb`: 4 runs, 0 failures; every `test/*_test.rb` green. `rubocop test/stow_package_roots_test.rb`: no offenses. Key names in both READMEs checked against herdr-file-viewer 1.17.0 `src/input.rs` (`W`, `Z`, `v`, `w`, `f`, `p`, `{`/`}`, `]`/`[`, `c`, `e`, `L`, `y`, `i` all exist); `.worktrees/` is in `git/.config/git/ignore.global:191` as the README says.

Bugs: none found. Security: none found — config and prose only, the test shells out to `bash` with a fixed script and a quoted path argument.

Compliance, spec acceptance criteria against proof:

- Changed markdown opens rendered — hand-verified; not yet done (needs restow).
- `v` still reaches the diff — hand-verified; not yet done.
- Deleted file still shows a diff — hand-verified; not yet done.
- `prefix+shift+f` opens own tab, toggles without a second tab — hand-verified; not yet done.
- `prefix+f` still splits — hand-verified; not yet done.
- Cold-start reader reaches an agent's file with `W` — `herdr/.config/herdr/README.md`, present.
- Top-level README names viewer and link resolves — `README.md:243-250`, link resolves.
- Dot-only package passes — `test_a_package_of_only_dotfiles_is_accepted`.
- `README.md` at a root fails, naming the file and `~/README.md` — `test_a_readme_at_a_package_root_is_rejected`, partial (see Important 2).
- Check covers exactly `packages.conf` — `test_the_checked_packages_come_from_packages_conf`.
- After stowing, both symlinks exist and no `~/README.md` — not yet done; neither `~/.config/herdr/README.md` nor the plugin `config.toml` exists at the target today.

All four tests named in `plan.md` `## Proof` exist. No existing test weakened, skipped or deleted.

- [ ] Important: Six of the spec's acceptance criteria (the five viewer checks and the stow-result inspection) are still unexercised. The plan defers them until an approved restow of `herdr`, which has not happened: `~/.config/herdr/README.md` and `~/.config/herdr/plugins/config/herdr-file-viewer/config.toml` do not exist. The branch should not be called done until the restow is approved, `herdr server reload-config` is run, and each check is recorded. — `docs/changes/herdr-file-viewer-markdown-reading/plan.md:82` →
- [ ] Important: The spec promises the failure "names that file and the `~/README.md` it would become". The fixture test only asserts the stray list `["untidy/README.md"]`; the `-> ~/README.md` message is built only in the real-repository test, which passes, so that message is never exercised by any test. — `test/stow_package_roots_test.rb:23` →
- [ ] Nit: `Dir.children` never returns `.` or `..`, so `- [ ".", ".." ]` removes nothing. — `test/stow_package_roots_test.rb:53` →
- [ ] Nit: A package declared in `packages.conf` with no directory on disk is skipped silently (`next [] unless File.directory?`), so a misspelled package name passes the guard. Maybe intended; if so, a one-line reason would help. — `test/stow_package_roots_test.rb:51` →
- [ ] Nit: "worktrees created with `git worktree add` are invisible to it" reads as if the viewer cannot see them, but the next paragraph says `W` lists them. What is missing is a herdr workspace for them, not visibility to the viewer. — `herdr/.config/herdr/README.md:30` →
- [ ] Nit: The prose refers to `y` (copy path from a pin) and `i` (reveal ignored entries), but the "Keys worth knowing" table lists neither. — `herdr/.config/herdr/README.md:36` →
- [ ] Nit: `project-dictionary.txt` changes but is not in the plan's "Files that change" table. The words are legitimate (`Haije` from `intent.md`, `smarzban` from the install command, `hjkl`/`solunized` from existing lines of `config.toml` that cspell now scans), so this is a plan-accuracy note only. — `project-dictionary.txt:227` →
