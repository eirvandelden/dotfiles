# Review: agent-shells-use-chnode-node

## Round 1 — 2026-10-16T13:59Z — b712ae55 (codex)

`codex review --base origin/main`. The rebase onto 73268db2 that followed changed no file in this branch's diff.

No findings.

## Round 2 — 2026-10-16T14:19Z — c72141f0 (claude reviewer)

Checks: every `test/*_test.rb` passes, `branch_guard_test.rb` included (its failure from before the rebase no longer happens). rubocop, `shellcheck -S warning -s bash paths.zsh`, and `zsh -n` on `paths.zsh` and `.zprofile` are clean. Every test named in `plan.md`'s Proof and its addendum exists. Each acceptance criterion in `intent.md` maps to a test: login, non-login and interactive order; inherited root in login and non-login shells; into a project and back; home default; `npm root -g`; project file wins; rv Ruby; unlocked shim; no-fixme for `references/` and for other files. No existing test is weakened. The `CHNODE_ROOT => nil` in `rv_ci_fallback_test.rb` isolates the environment and asserts nothing less.

- [ ] Important: `apply_default_node_version` overwrites the global `REPLY` and `reply` at every prompt. `_chnode_project_file` and `_chnode_wanted_node` set them, and no caller makes them local. In an interactive shell, `read` on one line followed by `echo $REPLY` on the next prints an empty string, because the precmd hook runs between the two. `select` is affected in the same way. A probe confirmed it: `REPLY=keep; apply_default_node_version; echo $REPLY` prints an empty value. Declare `local REPLY reply` in `apply_default_node_version`. Then the helpers write to its locals through zsh's dynamic scope. — `zsh/.config/zsh/paths.zsh:63` → fixed (Keep the shell's REPLY and reply in the node prompt hook)
- [ ] Nit: `read -r version` keeps a trailing carriage return. A `.node-version` with CRLF line endings gives `chnode: unknown Node.js: 20.11.1` and keeps the old node; a probe confirmed this. `chnode_auto` removed all trailing whitespace, so this is a regression for project files written on Windows. — `zsh/.config/zsh/paths.zsh:87` → fixed (Read a CRLF .node-version in the node prompt hook)
- [ ] Nit: Without `~/.node-version` and without an inherited root, `_chnode_wanted_node` fails and the hook returns early. A shell that leaves a project keeps the project's node. `chnode_auto` called `chnode_reset` in this case. — `zsh/.config/zsh/paths.zsh:94` → fixed (Reset the node after leaving a project with no default left)
- [ ] Nit: The glob `**/skills/*/references/**` also excludes first-party reference docs, not only vendored ones: `dotfiles-maintenance`, `new-repo-setup`, `object-oriented-design`, `rails-api-design`, `rails-architecture`, `rails-testing` and `rails-ui` (9 files). The comment "they are never edited here" is false for those files. The intent's In scope says "vendored", but its acceptance criterion says "a skill's `references/` doc". Either narrow the glob to the vendored skills or correct the comment. — `lefthook.yml:84` → fixed (Say which skill reference docs no-fixme skips)
- [ ] Nit: The assertion that `beautiful-mermaid` is a directory checks only a fixture that `write_node_root` creates. It proves nothing about the code under test. The `npm root -g` assertion on the line above is the real proof. — `test/node_path_order_test.rb:169` → fixed (Drop the node path test's self-made beautiful-mermaid check)

## Round 3 — 2026-10-16T14:23Z — 54d336a3 (codex)

`codex review --base origin/main`.

No findings.

## Round 4 — 2026-10-16T14:41Z — 54d336a3 (claude reviewer)

Checks: every `test/*_test.rb` passes. rubocop on the three changed test files, `shellcheck -S warning -s bash paths.zsh`, and `zsh -n` on `paths.zsh` and `.zprofile` are clean. Each Round 2 fix holds in the commit it names. 9cf37963 declares `local REPLY` and `local -a reply` in `apply_default_node_version`, and `test_the_prompt_hook_keeps_the_shells_reply_variables` proves it. 3d6684fd strips all whitespace from the version, and `test_a_project_node_version_with_crlf_line_endings_applies` proves it. 31543316 resets the node when no source is left, and `test_leaving_a_project_without_a_home_node_version_resets_the_node` proves it. b37bbf55 corrects the `lefthook.yml` comment. 54d336a3 removes the fixture-only assertion and its fixture. A probe with the real chnode 0.4.3 and the worktree's `paths.zsh` gives: Homebrew's node outside a project without `~/.node-version`, the project's node inside it, Homebrew's again after `cd ..`, and `REPLY` kept. Every test named in `plan.md`'s Proof and its addendum exists. Each acceptance criterion in `intent.md` maps to the test that Round 2 lists. No existing test is weakened, skipped or deleted.

- [ ] Nit: `_chnode_forget_applied_node` calls chnode's internal `chnode_reset`. The plan's design decision says "Only the public `chnode` command is used, never `chnode_use` or other internals." The public form is `chnode --reset` (or `chnode -r`). It does the same thing. — `zsh/.config/zsh/paths.zsh:98` → fixed (Reset the node through chnode's public --reset)

## Round 5 — 2026-10-16T19:10Z — 3cb21629 (codex)

`codex review --base origin/main`.

No findings.

## Round 6 — 2026-10-16T19:36Z — 3cb21629 (claude reviewer)

Checks: every `test/*_test.rb` passes. rubocop on the three changed test files, `shellcheck -S warning -s bash paths.zsh`, and `zsh -n` on `paths.zsh` and `.zprofile` are clean. The Round 4 fix holds: 3cb21629 calls `chnode --reset`, and the real chnode 0.4.3 dispatches `-r | --reset` to `chnode_reset`. A probe with the real chnode and the worktree's `paths.zsh` confirms that `chnode --reset` puts Homebrew's node back first. The test stub's `chnode` handles `--reset` in the same way. Every test named in `plan.md`'s Proof and its addendum exists. Each acceptance criterion in `intent.md` maps to the test that Round 2 lists. No existing test is weakened, skipped or deleted.

- [ ] Nit: An empty or whitespace-only project `.node-version` stops the walk. Then `_chnode_wanted_node` fails, and the hook resets the node to Homebrew's. This drops both the inherited root and `~/.node-version`. `chnode_auto` skipped such a file and walked on to the next `.node-version` up. A probe with the real chnode confirmed it: with an inherited `node-22.0.0`, `cd` into a directory with an empty `.node-version` gives Homebrew's node. Either skip an empty file in `_chnode_project_file`, or fall through to the inherited root and `~/.node-version` when the project file holds no version. — `zsh/.config/zsh/paths.zsh:65` → fixed (Skip an empty project .node-version in the node prompt hook)

## Round 7 — 2026-10-16T19:42Z — f6e8419d (codex)

`codex review --base origin/main`.

No findings.

## Round 8 — 2026-10-16T20:09Z — f6e8419d (claude reviewer)

Checks: every `test/*_test.rb` passes (67 files; `node_path_order_test.rb` has 20 runs). rubocop on the three changed test files, `shellcheck -S warning -s bash paths.zsh`, and `zsh -n` on `paths.zsh` and `.zprofile` are clean. The Round 6 fix holds: f6e8419d moves the version read into `_chnode_file_version`, and `_chnode_project_file` passes over a file that names no version. `test_an_empty_project_node_version_is_skipped` proves the fall-through to the inherited root and to `~/.node-version`. A probe with the real chnode 0.4.3 and the worktree's `paths.zsh` confirms three results. An empty file walks on to the parent's `.node-version`. A file with only a space and CRLF is skipped. An empty file with no project file above gives the inherited root, or `~/.node-version` without one. The whole branch diff was read again, and nothing new was found. Every test named in `plan.md`'s Proof and its addendum exists. Each acceptance criterion in `intent.md` maps to the test that Round 2 lists. No existing test is weakened, skipped or deleted.

No findings.

## Round 9 — 2026-10-16T20:17Z — d1501a32 (codex)

`codex review --base origin/main`, after CI failed on PR #214 and the change folder was restored.

No findings.

## Round 10 — 2026-10-17T05:50Z — d1501a32 (claude reviewer)

Checks: every `test/*_test.rb` passes; `node_path_order_test.rb` has 20 runs. rubocop on the three changed test files, `shellcheck -S warning -s bash paths.zsh`, and `zsh -n` on `paths.zsh` and `.zprofile` are clean. d1501a32 still proves the reset, independent of the machine. The test asserts that the project's node comes first inside the project. After `cd ../plain` it asserts that `CHNODE_ROOT` is empty and that no `PATH` entry is under `~/.nodes/`. It no longer names the node that follows, so `/usr/local/bin/node` from step 0 of `paths.zsh` on the Ubuntu runner cannot change the result. A mutation check confirms the test still has teeth: in a scratch copy with the `paths.zsh` from 3d6684fd (before the reset fix), the test fails, because `CHNODE_ROOT` stays on `node-20.11.1`. No other test in `node_path_order_test.rb` expects the stub Homebrew node in a non-login shell. The one test that names it runs as a login shell, where the path_helper stand-in puts it first. The whole branch diff was read again, and nothing new was found. Every test named in `plan.md`'s Proof and its addendum exists. Each acceptance criterion in `intent.md` maps to the test that Round 2 lists. No existing test is weakened, skipped or deleted; d1501a32 changes a test from this branch to a machine-independent form and keeps its proof.

No findings.
