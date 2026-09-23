# Plan: Read agent-written markdown without leaving the terminal

From `intent.md` and `spec.md` (2026-09-23). Status: accepted.
Change folder: `docs/changes/herdr-file-viewer-markdown-reading/`.
Branch and worktree: `herdr-file-viewer-markdown-reading`.

## Context

Reading a markdown file well currently means leaving Ghostty — an editor preview, a browser,
Obsidian, or Quick Look. The files being read are written by an agent, in a worktree, while its
pane is still open, and that makes the terminal the wrong place to read them today:

- An agent's file is always git-changed, and the viewer opens a changed file as a diff. A file it
  just created is no exception: `src/git.rs` diffs an untracked path against `/dev/null` with
  `--no-index`, so a brand-new file is a whole-file `+` diff that reads as plain source.
- Nothing is bound to the viewer's own-tab action, so a file can never take the whole terminal.
- Nothing in this repository mentions the viewer at all, so `W` — which re-roots it at another
  worktree and pre-selects the one with an active agent — is undiscoverable.

Outcome: markdown opens rendered with no keypress to get there, one key gives it the whole
terminal, and the repository explains how to reach an agent's worktree and read what it wrote.

herdr-file-viewer was updated 1.16.0 → 1.17.0 during planning. Every decision below was verified
against 1.17.0.

The setting does cover an agent's brand-new file. `src/view_policy.rs` decides the initial view
with `if fd.is_changed && (fd.is_deleted || changed_file_view == ChangedFileView::Diff)`, which
keys on one `is_changed` boolean and draws no tracked/untracked distinction. So `content` renders
an untracked markdown file, a deleted path stays diff-first, and `applicable_modes` keeps both
diff modes in the `v` cycle for any changed file. Three acceptance criteria, confirmed in the
source rather than assumed.

## Files that change

| Path | Change |
| --- | --- |
| `herdr/.config/herdr/plugins/config/herdr-file-viewer/config.toml` | New. `changed_file_view = "content"` so a changed or untracked markdown file opens rendered. |
| `herdr/.config/herdr/config.toml` | Append one `[[keys.command]]`: `prefix+shift+f` → `herdr-file-viewer.open-file-viewer-tab`. |
| `herdr/.config/herdr/README.md` | New. How to browse and read files in herdr, including `W`. |
| `README.md` | Pointer to the above, mirroring how the worktree section links `worktree-tools`. |
| `test/stow_package_roots_test.rb` | New. Guards that no file at a stow package root gets linked into `$HOME`. |

Not the package root for the README: stow maps a package's top-level entries to the target root
and `README.md` is not in `.stow-global-ignore`, so `herdr/README.md` would become `~/README.md`.
All three READMEs already in this repo sit at their stowed path.

## Order of work

The first four acceptance criteria are hand-verified, because the system under test is an
interactive TUI with no automated harness. So step 1 is the thin end-to-end slice rather than a
failing test — the walking skeleton is "open the viewer and read a rendered agent-written file".
The one testable requirement, the stow guard, does go red-first in step 5.

1. **Walking skeleton.** Create the plugin config with `changed_file_view = "content"`. Quit every
   open viewer pane first — the plugin config is read at launch only, there is no reload. Reopen
   with `prefix+f`, navigate to this worktree with `W`, open
   `docs/changes/herdr-file-viewer-markdown-reading/intent.md` — an untracked, agent-written
   markdown file, the exact failing case. It must render. Press `v` and confirm the diff is still
   one keypress away. Commit.
2. **Full width.** Append the `[[keys.command]]` block to `herdr/.config/herdr/config.toml`. Run
   `herdr server reload-config`. Press `prefix+shift+f`: the viewer fills the terminal in its own
   tab. Press again: it toggles off, with no second viewer tab left behind. Press `prefix+f` and
   confirm the split still works. Commit.
3. **Package README.** Write `herdr/.config/herdr/README.md`: summoning the viewer (split and
   tab), the keys that matter for reading (`Z`, `v`, `w`, `f`, `p`, `Tab`, `{`/`}`, `]`/`[`, `e`),
   reaching an agent's worktree with `W`, why `.worktrees/` is not in the tree, and the two
   settings this repo sets with their reasons. Commit.
4. **Pointer.** Add a short section to the top-level `README.md` linking
   `herdr/.config/herdr/README.md`, in the style of the existing worktree-tools link. Commit.
5. **Stow guard, red first.** Write `test/stow_package_roots_test.rb` against a tmpdir fixture, not
   the live repo — the invariant already holds everywhere, so a test that only reads the real repo
   would pass on its first run and prove nothing. Build a fixture package holding `README.md` at
   its root, assert the check rejects it, and watch that fail before the check exists. Then
   implement, go green, and add the assertion over the real repository last. Separate commit.
6. **Lint and verify.** `ruby -Itest test/stow_package_roots_test.rb`, then the whole suite:
   `for file in test/*_test.rb; do ruby -Itest "$file"; done`. `rubocop` on the new test file.
   `cspell` on every staged file. Re-read the full diff.

Stowing is not part of this. A restow of `herdr` is what makes the new files live, and the playbook
forbids running `stow` without explicit instruction — so ask at the end rather than doing it.

**Departure from the per-step verification above, recorded during step 1.** Steps 1 and 2 each say
to verify by hand straight after the edit. They cannot: both files only take effect once the
`herdr` package is stowed again, and that needs explicit instruction. So every hand-verified criterion moves to the end,
after an approved restow and `herdr server reload-config`, and the steps below commit on a written
and linted file rather than on a verified one.

## Risks

**A stale viewer makes step 1 look broken.** The plugin config is read only at viewer launch.
An already-open viewer pane keeps the old behaviour and the change looks like it did nothing.
Quit every viewer pane before reopening.

**A forgotten `reload-config` makes step 2 look broken.** The running herdr server does not reread
`config.toml` on its own, so the new key is inert until reloaded.

**cspell blocks the commit on new vocabulary.** `herdr` and `Herdr` are already in
`project-dictionary.txt`, but the README introduces words the dictionary has not seen. Run cspell
before committing and add the legitimate ones.

**Reviewing changed code gets one keypress worse.** `changed_file_view` is one switch over every
changed file, not only markdown, so a changed Ruby file opens as highlighted source and reaching
its diff costs a `v`. Accepted in the spec: reading prose is the frequent act.

**The guard duplicates eight lines.** `test/skill_parity_test.rb` has a `bash_array` helper that
sources `packages.conf` and prints an array — the right way to read the `STOW` list, since it
handles the comment lines inside the block that a regex would trip on. This is its second use, and
the rule of three says extract on the third. Duplicate now, extract later.

**Rejected: a custom launcher that opens the viewer rooted at the agent's worktree.** It would
re-implement the plugin's open-or-switch-or-toggle decision, which upstream delegates to the
viewer binary's `--launch-decision-tab`, and it would rot on every plugin release. Passing `--cwd`
to `herdr plugin pane open` is worse — the manifest's pane command is relative and herdr resolves
it against `--cwd`, failing with `plugin_pane_open_failed` or silently running another checkout's
binary. `W` is the answer here; making worktrees into herdr workspaces is briefed as separate work.

## Proof

Hand-verified in the viewer, each criterion exercised on a real agent-written file:

- A changed markdown file opens rendered, with headings and tables and no diff prefixes → step 1,
  on `docs/changes/herdr-file-viewer-markdown-reading/intent.md`.
- `v` on that file still reaches its diff → step 1.
- A deleted path still opens as a diff, because there is no content left to render → step 1.
- `prefix+shift+f` fills the terminal in its own tab, and toggles off without a duplicate tab →
  step 2.
- `prefix+f` still opens the split → step 2.

Verified by reading the repository:

- A reader can go from a cold start to reading an agent's file in a worktree, `W` included →
  `herdr/.config/herdr/README.md`.
- The top-level README names the viewer and its link resolves → `README.md`.

Automated:

- A file at a stow package root fails the suite → `test/stow_package_roots_test.rb`
  `test_a_readme_at_a_package_root_is_rejected`
- A package whose root holds only dot-prefixed entries passes →
  `test_a_package_of_only_dotfiles_is_accepted`
- The real repository holds the invariant → `test_every_stowed_package_root_holds_only_dotfiles`
- The set checked is the one `packages.conf` declares → `test_the_checked_packages_come_from_packages_conf`

Verified by inspecting the stow result, after an explicitly requested restow of `herdr`:

- `~/.config/herdr/README.md` and `~/.config/herdr/plugins/config/herdr-file-viewer/config.toml`
  are symlinks into this repository, and no `~/README.md` exists.

Per changed file, the unit tests expected:

- `test/stow_package_roots_test.rb`: the four tests above. The three config and documentation files
  carry no unit tests — they are configuration and prose, which the agile ruleset exempts, and
  their behaviour is the hand-verified list above.

Test setup: a tmpdir holding a fake repository root — a `packages.conf` declaring two packages, one
package directory containing only dot-prefixed entries and one containing `README.md` at its root.
No fixtures beyond that, and no faked boundaries: the check reads directories and shells out to
bash exactly as `skill_parity_test.rb` already does.

## Out of scope

- Rooting the viewer at the agent's worktree automatically. Briefed separately; `W` covers it here.
- `show_ignored`, `open_direction`, `baseline`, `tree_width`, `tree_max_cols`, and the renderer
  commands. All stay at their defaults, with reasons recorded in the spec.
- Running `stow`. Ask at the end.
- Extracting `bash_array` into a shared test helper.
