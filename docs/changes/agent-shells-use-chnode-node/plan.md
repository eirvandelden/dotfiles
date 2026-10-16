# Plan: Agent shells use chnode's node

From `intent.md` (2026-10-16). Status: accepted.

## Context

Every zsh reads `~/.zshenv`, which sources `zsh/.config/zsh/.zshenv`, which sources `zsh/.config/zsh/paths.zsh`. Step 5 of `paths.zsh` sources chnode 0.4.3 (`chnode.sh` and `auto.sh`), defines `apply_default_node_version`, runs it once and registers it as a `chpwd` hook. `zsh/.config/zsh/environment.zsh` also adds it to `precmd_functions` in interactive shells.

Today `apply_default_node_version` calls `chnode_auto`, which walks up from `$PWD` and selects the version in the nearest `.node-version`, including `~/.node-version` for any directory under HOME. Only when no file is found and `CHNODE_ROOT` is empty does it read `~/.node-version` itself.

A login zsh then reads `/etc/zprofile`. On macOS that runs `path_helper`, which moves `/etc/paths` and `/etc/paths.d/*` to the front. `/etc/paths.d/homebrew` holds `/opt/homebrew/bin`, so Homebrew's node (26.x, pulled in by mermaid-cli) moves ahead of chnode's node. `zsh/.config/zsh/.zprofile` runs next and restores rv's Ruby paths and the unlocked codex shim, but not chnode's node.

Observed on 2026-10-16 on this Mac, in `/tmp`:

- `env -i … zsh -c 'command -v node'` → `~/.nodes/node-25.9.0/bin/node` (correct).
- `env -i … zsh -lc` and `zsh -lic` → `/opt/homebrew/bin/node`; `/opt/homebrew/bin` is at PATH index 15, `~/.nodes/node-25.9.0/bin` at 16.
- Real `chnode.sh` runs `chnode_reload` when sourced: with `CHNODE_ROOT` set and inside `$CHNODE_NODES_DIR`, it removes `$CHNODE_ROOT/bin` and prepends it again. With a root outside that directory, it unsets `CHNODE_ROOT`.
- A scratch copy of `.zprofile` with a `$CHNODE_ROOT/bin` prepend, in a temporary HOME, gives chnode's node at index 1, rv's Ruby at 3–4 and `/opt/homebrew/bin` behind both, in `zsh -c` and `zsh -lc`. `npm root -g` gives `~/.nodes/node-25.9.0/lib/node_modules`, which holds `beautiful-mermaid`.
- `~/.nodes` holds both `node-22.17.0` and `node-22.21.1`; `chnode 22` is ambiguous (chnode picks the last substring match).
- `Dir.mktmpdir` on macOS gives `/var/folders/…`, but zsh's `$PWD` there is `/private/var/folders/…`. A string compare of `$PWD/.node-version` with `$HOME/.node-version` fails; `[[ a -ef b ]]` (same file) succeeds.

`intent.md` records Etienne's rule of 2026-10-16: an inherited `CHNODE_ROOT` beats `~/.node-version`. A project-local `.node-version` (any `.node-version` that is not the same file as `~/.node-version`) beats both. This replaces `chnode_auto`'s rule in these dotfiles.

## Design decisions

- Two separate fixes. `paths.zsh` decides which node a shell selects. `.zprofile` puts the selected node back in front after `path_helper`.
- Version source, in order, computed by `apply_default_node_version` on every call:
  1. Project: the nearest `.node-version` from `$PWD` upward, to `/`, that is not the same file as `~/.node-version` (`-ef`, not a string compare, because of the `/private` paths above). Directories above HOME count, as in chnode.
  2. Inherited: the `CHNODE_ROOT` that the shell had right after `chnode.sh` was sourced. `chnode_reload` has already validated it at that point, so an invalid root is gone and falls to step 3.
  3. Default: the version in `~/.node-version`, `v` prefix stripped, as today.
- Capture the inherited root once, in a non-exported global (`_inherited_chnode_root`), right after `source …/chnode.sh`. Not exported: a child shell gets the parent's current `CHNODE_ROOT`, which becomes the child's own inherited root. So a child keeps its parent's node, as the intent asks.
- Select the inherited root by its exact directory name, `chnode "${root##*/}"` (for example `chnode node-22.21.1`). chnode's matcher takes an exact name first, so `node-22.17.0` and `node-22.21.1` cannot be confused. Only the public `chnode` command is used, never `chnode_use` or other internals.
- Skip redundant work, as `chnode_auto` does with `CHNODE_AUTO_VERSION`: remember the last applied source and value in a non-exported global (`_applied_node_source`, for example `project:20.11.1`, `inherited:/…/node-22.21.1`, `default:24.14.0`). When the new source equals it, return without calling `chnode`. Record it before calling `chnode`, so an unknown version prints chnode's error once, not at every prompt. A manual `chnode 18` therefore stays until the directory's version source changes, as today.
- The project walker sets a variable (`REPLY`-style global) instead of printing to a command substitution, so the per-prompt hook forks no subshell. Walk with `${dir%/*}`, not zsh `:h`, so `shellcheck -s bash` on `paths.zsh` stays clean.
- Stop sourcing `auto.sh`. Nothing calls `chnode_auto` any more. The step 5 guard stays on `chnode.sh` only, so Linux and SteamOS without chnode keep the existing no-op.
- Keep the name `apply_default_node_version`. `environment.zsh` (precmd) and `test/rv_ci_fallback_test.rb` (chpwd hook name) refer to it; renaming adds churn without behaviour.
- `.zprofile`: new block, between the rv block and the `UNLOCKED_BIN` block, in the same shape as the `UNLOCKED_BIN` block: when `CHNODE_ROOT` is set and `$CHNODE_ROOT/bin/node` is executable, `path=("$CHNODE_ROOT/bin" "${path[@]}")`. `.zshenv` sets `typeset -gU path`, so the prepend moves the entry and leaves no duplicate. The result is shim, node, Ruby, …, Homebrew, the order `paths.zsh` gives a non-login shell.
- No `stow -R`. The change adds no file to the `zsh` package, and the live links in `~/.config/zsh` point at the main checkout, not at this worktree. Live verification uses a temporary HOME whose links point at this worktree (Order of work, step 7). The approved stow permission stays unused.
- New tests use their own chnode stub, faithful to chnode 0.4.3: `chnode_reload` on source (drops a root outside `CHNODE_NODES_DIR`), `chnode_reset`, `chnode_use` (replaces the old root in place), `chnode_match` (exact name first, else last substring match) and `chnode`. No `auto.sh` function is needed. The stub in `test/rv_ci_fallback_test.rb` has only `chnode` by exact version and no reload; it stays unchanged, and the new code calls it only with plain versions in those tests.

## Integration points

- macOS `/etc/zprofile` → `/usr/libexec/path_helper -s`, and `/etc/paths.d/homebrew` (system files, read only).
- chnode 0.4.3 at `$HOMEBREW_PREFIX/opt/chnode/share/chnode/chnode.sh` (`auto.sh` no longer sourced).
- `environment.zsh`'s precmd registration of `apply_default_node_version` (unchanged; it now runs the new rule at every prompt).
- rv's `rv shell env zsh` in `.zprofile` (prints an `export PATH=…` with Ruby first).
- `unlock` and `zsh/.config/zsh/unlocked-bin/codex` (`UNLOCKED_BIN`).
- Consumers: the Claude Code Bash tool (its shell snapshot comes from a login shell, so it refreshes only in a new session), Codex `zsh -lc`, Ghostty and herdr login shells, lefthook-local's `verify-node-version` and `verify-node-path` pre-push checks.
- CI: `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb` on Ubuntu with zsh; there is no path_helper or chnode there, so tests simulate both.

## Files that change

- `zsh/.config/zsh/paths.zsh` — step 5: capture `_inherited_chnode_root` after sourcing `chnode.sh`; stop sourcing `auto.sh`; add the project-file walker; rewrite `apply_default_node_version` for the project → inherited → default order with the applied-source cache; update the step 5 comment (rule, and that `.zprofile` restores the order after `path_helper`).
- `zsh/.config/zsh/.zprofile` — new chnode block between the rv block and the `UNLOCKED_BIN` block; header comment names node next to Ruby.
- `test/node_path_order_test.rb` — new Minitest file with the acceptance and unit tests below and its own stubs.

## Order of work

1. Write `test/node_path_order_test.rb` with the fixtures (Test setup below) and `test_a_login_shell_puts_chnodes_node_ahead_of_homebrews_after_path_helper`. Run `ruby -Itest test/node_path_order_test.rb -n test_a_login_shell_puts_chnodes_node_ahead_of_homebrews_after_path_helper`. Watch it fail: `command -v node` is the fake Homebrew node.
2. Add the chnode block to `.zprofile`. Run the same test; it passes.
3. Add `test_an_inherited_chnode_root_beats_the_home_node_version_in_login_and_non_login_shells`. Run it with `-n`; watch it fail (the shell gets 24, not 22).
4. Change `paths.zsh` step 5: capture the inherited root, add the walker, rewrite `apply_default_node_version`, drop `auto.sh`. Run the test; it passes. Run `ruby -Itest test/rv_ci_fallback_test.rb`; it stays green.
5. Add the remaining tests one at a time, running each with `-n`: leaving a project returns to the inherited root, home default without an inherited root, project file wins, home file through a symlinked path, manual choice kept, invalid inherited root, non-login, interactive, npm/npx, rv Ruby order, unlocked shim, no `CHNODE_ROOT` guard. Each must pass after its own code change, or already pass because it guards kept behaviour. If one fails, fix the production file, not the test.
6. Update the `.zprofile` header comment and the `paths.zsh` step 5 comment. Run the whole file, then every test file as CI does: `set -o pipefail; for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`. Run linters on touched files: `rubocop test/node_path_order_test.rb`, `ruby -c test/node_path_order_test.rb`, `shellcheck -S warning -s bash zsh/.config/zsh/paths.zsh`, `zsh -n zsh/.config/zsh/paths.zsh`, `zsh -n zsh/.config/zsh/.zprofile` (`.zprofile` has no `.zsh` extension, so lefthook does not lint it).
7. Live check on this Mac with the real path_helper and real chnode, without stow. Build a temporary HOME `$T`. `$T/.zshenv` is a plain file, not a link to `zsh/.zshenv`, holding three lines: `export ZDOTDIR="$HOME/.config/zsh"`, `export ZDOTDIR_LOADED=1`, `source "$ZDOTDIR/.zshenv"`. This skips the `launchctl setenv ZDOTDIR` block in `zsh/.zshenv`, which would point GUI apps at the temporary HOME (a system change no rule approves); `zsh/.zshenv` does not change in this plan. Run `/bin/launchctl getenv ZDOTDIR` before and after the checks; the value must stay the same. Add symlinks: `$T/.config/zsh` → `<worktree>/zsh/.config/zsh`, and `$T/.nodes`, `$T/.node-version`, `$T/.local`, `$T/.ruby-version` → the same names in the real HOME. Run each with `env -i HOME=$T USER=$USER PATH=/usr/bin:/bin`, from `$T` (under HOME, so `~/.node-version` is an ancestor) unless stated:
   - Set `D=$(cat $T/.node-version)` and pick `I` and `J`, two installed versions other than `$D`, as full directory names from `ls $T/.nodes`. Never hard-code a version.
   - `zsh -lc 'command -v node npm npx; ls -d "$(npm root -g)/beautiful-mermaid"'` → `$T/.nodes/node-$D/bin/…` and `…/node-$D/lib/node_modules/beautiful-mermaid`.
   - `zsh -c 'command -v node'` → `node-$D`.
   - `printf 'command -v node\nexit\n' | script -q /dev/null env -i HOME=$T USER=$USER TERM=xterm PATH=/usr/bin:/bin zsh -il` → `node-$D` (a real pty, so precmd fires). Repeat with `zsh -i`.
   - Inherited: `CHNODE_ROOT=$T/.nodes/$I PATH=/opt/homebrew/bin:$T/.nodes/$I/bin:/usr/bin:/bin zsh -lc 'command -v node'` → `$I`, not `node-$D`. Repeat with `zsh -c`. Use `$T/.nodes`, not the real HOME path, or `chnode_reload` drops the root as unknown.
   - Project and back: `P=$T/project; mkdir "$P"`; write `${J#node-}` to `$P/.node-version`. With the same inherited root, `zsh -lc 'cd '"$P"'; command -v node; cd ..; command -v node'` → `$J`, then `$I`.
   - Project outside HOME: `Q=$(mktemp -d)` with `${J#node-}` in `$Q/.node-version`; from `$Q`, `zsh -lc 'command -v node'` → `$J`.
   - `zsh -lc 'command -v ruby'` → `~/.local/share/rv/rubies/ruby-<~/.ruby-version>/bin/ruby`.
   - `UNLOCKED_BIN=<worktree>/zsh/.config/zsh/unlocked-bin zsh -lc 'command -v codex'` → the shim.
   - `zsh -lc 'mmdc --version'` still prints a version (mermaid-cli uses `#!/opt/homebrew/opt/node/bin/node`, so it keeps Homebrew's node).
   - Remove `$Q` and `$T` with `trash` afterwards (`$P` is inside `$T`). Record the output as evidence. The Claude Code Bash tool keeps its old snapshot until a new session starts after merge; say so in the delivery report rather than claim it.
8. Re-read the full diff (playbook rule 21) and commit in small steps: the `.zprofile` fix with its first test; the `paths.zsh` rule change with its tests; comments if separate.

## Risks

- Behaviour change, chosen by Etienne: under HOME, a shell started from a parent with a `CHNODE_ROOT` keeps that node, even when `~/.node-version` names another. A herdr server or editor started from an old shell passes its old node on; after a change to `~/.node-version`, such children keep the old version until their parent restarts.
- A child started inside a project (parent on the project's version) keeps that project's version after it leaves the project, because that is its inherited root. Intended by the rule.
- A manual `chnode X` stays until the directory's version source changes, as today. The applied-source cache is what keeps it; without the cache the precmd hook would undo it at the next prompt.
- `-ef` compares inodes. A copy of `~/.node-version` elsewhere (not a link) counts as a project file. Correct by the rule.
- Global npm binaries in chnode's node now beat Homebrew binaries of the same name in login shells (for example `markdownlint`). Non-login shells already behave this way.
- Node's bin is ahead of rv's Ruby. A global npm package that ships a `ruby` or `gem` binary would shadow rv. Non-login shells already have this order; the Ruby acceptance test guards `ruby`.
- Interactive terminals: `-i` without a pty does not fire precmd; the acceptance test calls `apply_default_node_version` itself to stand in for the first prompt, and the live check uses `script` for a real pty.
- `mermaid-show` from the diagrams skill is not installed on this Mac on 2026-10-16. Its criterion is proved through `npm root -g` and the presence of `beautiful-mermaid` there.
- Rejected: keeping `chnode_auto` and patching around it (for example a different `CHNODE_AUTO_VERSION_FILENAME`). It cannot skip one specific file, and it resets the node whenever it finds nothing, which would drop the inherited root.
- Rejected: calling `chnode_reload` from `.zprofile`. It rebuilds `CHNODE_NODES` and depends on chnode internals; the explicit prepend matches the existing `UNLOCKED_BIN` pattern.
- Rejected: exporting the inherited root under a new name. A child would then keep its grandparent's node instead of its parent's current one.
- Rejected: changing `/etc/paths.d/homebrew` or unlinking Homebrew's node — system files and out of scope.

## Out of scope

- Removing, unlinking or upgrading Homebrew's node or mermaid-cli.
- Installing node versions or changing `~/.node-version`.
- bash, fish and other shells.
- Linux and SteamOS behaviour and tests.
- Changing `environment.zsh` or the shared chnode stub in `test/rv_ci_fallback_test.rb`.
- Running `stow`.

## Proof

- Login, non-interactive zsh: first `node` is chnode's default → `test/node_path_order_test.rb` `test_a_login_shell_puts_chnodes_node_ahead_of_homebrews_after_path_helper`
- Non-login, non-interactive zsh: first `node` is chnode's default → `test/node_path_order_test.rb` `test_a_non_login_shell_puts_chnodes_node_first`
- Interactive terminal shell: first `node` is chnode's default → `test/node_path_order_test.rb` `test_interactive_login_and_non_login_shells_keep_chnodes_node_first_after_the_prompt_hook`
- Inherited `CHNODE_ROOT` 22 beats `~/.node-version` 24 under HOME, login and non-login → `test/node_path_order_test.rb` `test_an_inherited_chnode_root_beats_the_home_node_version_in_login_and_non_login_shells`
- Into a project with 20, then back: 20, then 22 → `test/node_path_order_test.rb` `test_leaving_a_project_returns_to_the_inherited_node`
- No inherited root, under HOME, no project file: 24 → `test/node_path_order_test.rb` `test_without_an_inherited_root_the_home_node_version_applies`
- `npm root -g` points under `~/.nodes/node-<version>/` → `test/node_path_order_test.rb` `test_npm_and_npx_come_from_chnodes_node_in_a_login_shell`
- A project's `.node-version` wins → `test/node_path_order_test.rb` `test_a_project_node_version_wins_in_a_login_shell`
- `ruby` resolves to rv's Ruby before Homebrew's → `test/node_path_order_test.rb` `test_rvs_ruby_stays_ahead_of_homebrews_ruby_in_a_login_shell`
- After `unlock`, `codex` resolves to the shim first → `test/node_path_order_test.rb` `test_the_unlocked_codex_shim_stays_first_in_a_login_shell`

Per changed file, the unit tests expected:

- `zsh/.config/zsh/.zprofile`: `test_zprofile_leaves_path_alone_without_chnode_root` (no `CHNODE_ROOT` → fake Homebrew node stays first, the Linux guard).
- `zsh/.config/zsh/paths.zsh`: `test_the_home_node_version_reached_through_a_symlinked_path_is_not_a_project_file` (HOME given as a symlink to the real directory; inherited root still wins), `test_a_project_node_version_above_home_counts` (working directory outside HOME with an ancestor `.node-version` beats the inherited root), `test_an_inherited_root_outside_the_nodes_dir_falls_back_to_the_home_node_version`, `test_a_manual_chnode_choice_survives_the_next_prompt_hook` (call `chnode`, then `apply_default_node_version` → still the manual node), `test_inherited_root_is_selected_by_exact_directory_name` (`node-22.17.0` and `node-22.21.1` both installed, inherited `node-22.17.0` → `node-22.17.0`).
- Existing tests that must stay green: `test/secrets_loader_test.rb` (`.zprofile` shim tests), `test/rv_ci_fallback_test.rb` (paths.zsh node tests and the chpwd hook name).

Test setup: each test gets a `Dir.mktmpdir` with `home/` (as HOME) holding `.node-version` (`24.14.0`), `project/.node-version` (`20.11.1`), `plain/` (no file), and `.nodes/node-{24.14.0,22.21.1,22.17.0,20.11.1}/bin/` with stub `node`, `npm` (prints `<its root>/lib/node_modules` for `root -g`) and `npx`, plus an empty `lib/node_modules/beautiful-mermaid/` under each node root; `homebrew/` (as `HOMEBREW_PREFIX`) with `bin/` holding stub `node`, `npm`, `npx`, `ruby` and an `rv` stub, and `opt/chnode/share/chnode/chnode.sh` holding the faithful chnode stub (no `auto.sh`); `rubies/bin/ruby` for rv. The `rv` stub answers `shell init zsh` with a `_rv_autoload_hook` function plus a PATH prepend of `rubies/bin`, and `shell env zsh` with `export PATH='<rubies/bin>:'"$PATH"`. Each shell runs `zsh -f -c` (`-f -i -c` for the interactive case) with `unsetenv_others: true` and PATH `homebrew/bin:/usr/bin:/bin`, from `home/plain/` unless the test needs another directory. An inherited root is passed as `CHNODE_ROOT=<home>/.nodes/node-22.21.1` with that `bin` also on the starting PATH behind `homebrew/bin`. The login script is: `typeset -gU path`, source `paths.zsh`, `path=("$HOMEBREW_PREFIX/bin" "${path[@]}")` to stand in for path_helper, source `.zprofile`, then the probe. The non-login script stops before the path_helper line. Assert on exact paths from `command -v`.

---
Domain skills applied: dotfiles-maintenance (stow and symlink rules), rails-testing (Minitest conventions, one behaviour per test name).

## Critique

### Round 1 (codex exec -p terra)

- The inherited-root test narrows the criterion; real chnode lets `~/.node-version` replace an inherited root under HOME, so keep a valid inherited root unless a project-local `.node-version` exists, and test both cases → fixed (first dismissed as a change to chnode's rule; Etienne chose this rule on 2026-10-16, `intent.md` records it, and the plan now implements and tests it)
- Interactive coverage misses a non-login interactive terminal; add a pty check for `zsh -i` as well as `zsh -il` → fixed (the interactive acceptance test covers login and non-login, and step 7 repeats the pty check with `zsh -i`)
- The `beautiful-mermaid` live check runs `npm root -g` in a normal shell, not the temporary-HOME shell; also fixture the package in the automated test → fixed (the `ls` runs inside the same `env -i … zsh -lc`, and the test setup adds `lib/node_modules/beautiful-mermaid/` under each stub node root)
- The project-version live check uses a `/tmp/np` that is never created and hard-codes versions → fixed (step 7 creates its directories and derives versions from `$T/.node-version` and `ls $T/.nodes`)

### Round 2 (codex exec -p terra)

- The live check's temporary HOME runs `zsh/.zshenv`, whose macOS block calls `launchctl setenv ZDOTDIR` with the temporary path, a system change no rule approves; set `ZDOTDIR` to the worktree and keep the real HOME instead → fixed (step 7 now writes a plain `$T/.zshenv` that sets `ZDOTDIR` and sources the worktree's `.config/zsh/.zshenv`, so `launchctl` never runs, and checks `launchctl getenv ZDOTDIR` before and after)
  - The proposed alternative does not work as given: the worktree's `.config/zsh/.zshenv` sets `ZDOTDIR="$HOME/.config/zsh"`, so with the real HOME it would load the main checkout's `paths.zsh` and `.zprofile`, not the worktree's.

## Addendum: no-fixme hook (coordinator, 2026-10-16)

Etienne asked for this fix in this branch after the pre-push `no-fixme` hook refused the push. After the rebase past PR #208, lefthook's `{push_files}` is the diff against the old remote tip. It lists old `claude/.claude/skills/<name>/references/…` paths, which still resolve through the new `claude/.claude/skills/<name>` symlinks into `agents/.agents/skills/`. Two vendored docs there (`37signals-style/references/development-philosophy.md`, `rails-guides/references/command_line.md`) name the fix-me marker in upstream prose.

- Design: add `exclude: ["**/skills/*/references/**"]` to `no-fixme` in both `pre-commit` and `pre-push` in `lefthook.yml`. lefthook filters the file template before `run`, so the glob covers both the `agents/` and the `claude/` paths. Vendored docs are never edited here, so a fix-me marker in them is never ours to fix. `no-nocommit` stays unchanged: no vendored doc names the no-commit marker.
- Rejected: grepping only the branch's own diff from the merge-base. It changes what `{push_files}` means for one command and does not help the pre-commit hook when a new snapshot is vendored.
- Files: `lefthook.yml`; new `test/lefthook_no_fixme_test.rb`.
- Order: write the test, watch the references case fail, add the exclude, watch it pass. Then push this branch. The test runs `lefthook run <hook> --tag fixme` in a temporary repo with this `lefthook.yml` and a bare origin: the marked file is staged for pre-commit, and committed but not pushed for pre-push. `--file` bypasses `exclude:`, and `--command` exits 1 when the excluded job skips, so the test uses neither.

Proof:

- A skill `references/` doc with the fix-me marker passes `no-fixme` → `test/lefthook_no_fixme_test.rb` `test_pre_push_no_fixme_skips_a_skill_reference_doc`, `test_pre_commit_no_fixme_skips_a_skill_reference_doc`
- Any other file with the fix-me marker is still refused → `test/lefthook_no_fixme_test.rb` `test_pre_push_no_fixme_still_refuses_another_file`, `test_pre_commit_no_fixme_still_refuses_another_file`
