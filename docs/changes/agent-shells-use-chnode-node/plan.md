# Plan: Agent shells use chnode's node

From `intent.md` (2026-10-16). Status: accepted.

## Context

Every zsh reads `~/.zshenv`, which sources `zsh/.config/zsh/.zshenv`, which sources `zsh/.config/zsh/paths.zsh`. Step 5 of `paths.zsh` loads chnode and puts the selected node (`$CHNODE_ROOT/bin`) at the front of PATH. A login zsh then reads `/etc/zprofile`. On macOS that runs `path_helper`, which moves `/etc/paths` and `/etc/paths.d/*` to the front. `/etc/paths.d/homebrew` holds `/opt/homebrew/bin`, so Homebrew's node (26.x, pulled in by mermaid-cli) moves ahead of chnode's node. `zsh/.config/zsh/.zprofile` runs next and restores rv's Ruby paths and the unlocked codex shim, but not chnode's node.

Observed on 2026-10-16 on this Mac, in `/tmp`:

- `env -i … zsh -c 'command -v node'` → `~/.nodes/node-25.9.0/bin/node` (correct).
- `env -i … zsh -lc` and `zsh -lic` → `/opt/homebrew/bin/node`; `/opt/homebrew/bin` is at PATH index 15, `~/.nodes/node-25.9.0/bin` at 16.
- `zsh -c` that inherits `CHNODE_ROOT` and a PATH with `/opt/homebrew/bin` first → chnode's node first. Real `chnode.sh` runs `chnode_reload` when sourced: with `CHNODE_ROOT` set, it removes `$CHNODE_ROOT/bin` and prepends it again. So the non-login inherited case already works; only login shells lose the order.
- A scratch copy of `.zprofile` with the block below, in a temporary HOME, gives chnode's node at index 1, rv's Ruby at 3–4 and `/opt/homebrew/bin` behind both, in both `zsh -c` and `zsh -lc`. `npm root -g` gives `~/.nodes/node-25.9.0/lib/node_modules`, which holds `beautiful-mermaid`.

## Design decisions

- Fix the login path only, in `.zprofile`, with the same shape as its existing `UNLOCKED_BIN` block: when `CHNODE_ROOT` is set and `$CHNODE_ROOT/bin/node` is executable, `path=("$CHNODE_ROOT/bin" "${path[@]}")`. `.zshenv` sets `typeset -gU path`, so the prepend moves the entry to the front and leaves no duplicate.
- Order inside `.zprofile`: rv block, then the new chnode block, then the `UNLOCKED_BIN` block. The result is shim, node, Ruby, …, Homebrew — the same order `paths.zsh` gives a non-login shell (steps 4, 5, 6).
- No logic change in `paths.zsh`. The intent says an inherited `CHNODE_ROOT` skips the default-version step and so never gets back in front. That early return is real, but `chnode.sh`'s own `chnode_reload` already moves the inherited root to the front when sourced (verified above). The new test locks that behaviour in with a stub that mirrors chnode 0.4.3. Only the step 5 comment in `paths.zsh` changes, to say `.zprofile` restores the order after `path_helper`.
- The chnode guard uses `CHNODE_ROOT` only, not a chnode function. On Linux or SteamOS without chnode, `CHNODE_ROOT` is empty and the block does nothing (out-of-scope machines keep the existing guard).
- "Inherits `CHNODE_ROOT`" keeps chnode's own rule: `chnode_auto` walks up from the working directory, so a `.node-version` in the directory or an ancestor (including `~/.node-version` for any directory under HOME) picks that file's version. The inherited version stays only when no such file is found. This is today's behaviour, and it keeps the constraint that a project's `.node-version` wins. The acceptance test for the inherited case therefore runs in a directory with no `.node-version` in its ancestry.
- No `stow -R`. The change adds no file to the `zsh` package, and the live links in `~/.config/zsh` point at the main checkout, not at this worktree. Live verification uses a temporary HOME whose `.zshenv` and `.config/zsh` link to this worktree (see Order of work, step 6). The approved stow permission stays unused.
- New tests use their own chnode stub, faithful to chnode 0.4.3 (`chnode_reload` on source, `chnode_use` replaces the old root in place, `chnode_auto` resets only after it set a version itself). The stub in `test/rv_ci_fallback_test.rb` resets whenever no file is found and has no reload, so it cannot model an inherited `CHNODE_ROOT`. That stub stays unchanged.

## Integration points

- macOS `/etc/zprofile` → `/usr/libexec/path_helper -s`, and `/etc/paths.d/homebrew` (system files, read only).
- chnode 0.4.3 at `$HOMEBREW_PREFIX/opt/chnode/share/chnode/{chnode.sh,auto.sh}`.
- rv's `rv shell env zsh` in `.zprofile` (prints an `export PATH=…` with Ruby first).
- `unlock` and `zsh/.config/zsh/unlocked-bin/codex` (`UNLOCKED_BIN`).
- Consumers: the Claude Code Bash tool (its shell snapshot comes from a login shell, so it refreshes only in a new session), Codex `zsh -lc`, Ghostty and herdr login shells, lefthook-local's `verify-node-version` and `verify-node-path` pre-push checks.
- CI: `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb` on Ubuntu with zsh; there is no path_helper there, so tests simulate it.

## Files that change

- `zsh/.config/zsh/.zprofile` — new block between the rv block and the `UNLOCKED_BIN` block that puts `$CHNODE_ROOT/bin` first; header comment names node next to Ruby.
- `zsh/.config/zsh/paths.zsh` — comment only: step 5 says `.zprofile` puts the node back after `path_helper` in login shells.
- `test/node_path_order_test.rb` — new Minitest file with the acceptance tests below and its own stubs.

## Order of work

1. Write `test/node_path_order_test.rb` with the fixtures (Test setup below) and `test_a_login_shell_puts_chnodes_node_ahead_of_homebrews_after_path_helper`. Run `ruby -Itest test/node_path_order_test.rb -n test_a_login_shell_puts_chnodes_node_ahead_of_homebrews_after_path_helper`. Watch it fail: `command -v node` is the fake Homebrew node.
2. Add the chnode block to `.zprofile`. Run the same test; it passes.
3. Add the other acceptance tests one at a time, running each with `-n`: non-login, interactive login, inherited root (login and non-login), npm/npx and `npm root -g`, project `.node-version`, rv Ruby order, unlocked shim. These guard behaviour the fix must keep; each must pass. If one fails, fix `.zprofile`, not the test.
4. Update the `.zprofile` header comment and the `paths.zsh` step 5 comment.
5. Run the whole file, then every test file as CI does: `set -o pipefail; for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`. Run linters on touched files: `rubocop test/node_path_order_test.rb`, `ruby -c test/node_path_order_test.rb`, `shellcheck -S warning -s bash zsh/.config/zsh/paths.zsh` (`.zprofile` has no `.zsh` extension, so lefthook does not lint it; also run `zsh -n zsh/.config/zsh/.zprofile`).
6. Live check on this Mac with the real path_helper, without stow. Build a temporary HOME `$T` with symlinks: `$T/.zshenv` → `<worktree>/zsh/.zshenv`, `$T/.config/zsh` → `<worktree>/zsh/.config/zsh`, and `$T/.nodes`, `$T/.node-version`, `$T/.local`, `$T/.ruby-version` → the same names in the real HOME. From `/tmp`, run each with `env -i HOME=$T USER=$USER PATH=/usr/bin:/bin`:
   - Set `D=$(cat $T/.node-version)` first; never hard-code a version.
   - `zsh -lc 'command -v node npm npx; ls -d "$(npm root -g)/beautiful-mermaid"'` → `$T/.nodes/node-$D/bin/…` and `…/node-$D/lib/node_modules/beautiful-mermaid`. The `ls` runs inside the same `env -i … zsh -lc`, so it uses the temporary HOME.
   - `zsh -c 'command -v node'` → chnode's node.
   - `printf 'command -v node\nexit\n' | script -q /dev/null env -i HOME=$T USER=$USER TERM=xterm PATH=/usr/bin:/bin zsh -il` → chnode's node (a real pty, so the precmd hook fires). Repeat with `zsh -i` for a non-login interactive shell, as some herdr panes and editors start.
   - With `I` an installed version other than `$D`: `CHNODE_ROOT=$T/.nodes/node-$I PATH=/opt/homebrew/bin:$T/.nodes/node-$I/bin:/usr/bin:/bin zsh -lc 'command -v node'`, run from `/tmp` → node-`$I`. Use `$T/.nodes`, not the real HOME path, or `chnode_reload` drops the root as unknown.
   - `P=$(mktemp -d)`; write to `$P/.node-version` an installed version other than `$D` (from `ls $T/.nodes`); from `$P`, `zsh -lc 'command -v node'` → that version.
   - `zsh -lc 'command -v ruby'` → `~/.local/share/rv/rubies/ruby-<~/.ruby-version>/bin/ruby`.
   - `UNLOCKED_BIN=<worktree>/zsh/.config/zsh/unlocked-bin zsh -lc 'command -v codex'` → the shim.
   - `zsh -lc 'mmdc --version'` still prints a version (mermaid-cli uses `#!/opt/homebrew/opt/node/bin/node`, so it keeps Homebrew's node).
   - Record the output as evidence. The Claude Code Bash tool keeps its old snapshot until a new session starts after merge; say so in the delivery report rather than claim it.
7. Re-read the full diff (playbook rule 21) and commit: one commit for the test plus `.zprofile` fix, one for comments if they are separate.

## Risks

- Global npm binaries in chnode's node now beat Homebrew binaries of the same name in login shells (for example `markdownlint`). Non-login shells already behave this way, so login shells only catch up.
- Node's bin is ahead of rv's Ruby. A global npm package that ships a `ruby` or `gem` binary would shadow rv. Non-login shells already have this order; the Ruby acceptance test guards `ruby`.
- An inherited `CHNODE_ROOT` outside `$CHNODE_NODES_DIR` (for example a different HOME) is dropped by `chnode_reload`, and the default version applies. Existing chnode behaviour, not changed.
- Interactive terminals: `-i` without a pty does not fire precmd; the acceptance test calls `apply_default_node_version` itself to stand in for the first prompt, in both a login and a non-login interactive shell, and the live check uses `script` for a real pty.
- `mermaid-show` from the diagrams skill is not installed on this Mac on 2026-10-16 (not in PATH or any skill folder). Its criterion is proved through `npm root -g` and the presence of `beautiful-mermaid` there.
- Rejected: calling `chnode_reload` from `.zprofile`. It works with real chnode but also rebuilds `CHNODE_NODES` and depends on chnode internals; the explicit prepend matches the existing `UNLOCKED_BIN` pattern.
- Rejected: dropping the `CHNODE_ROOT` early return in `apply_default_node_version`. It would replace an inherited version with `~/.node-version` outside any project and break the inherited criterion.
- Rejected: changing `/etc/paths.d/homebrew` or unlinking Homebrew's node — system files and out of scope.

## Out of scope

- Removing, unlinking or upgrading Homebrew's node or mermaid-cli.
- Installing node versions or changing `~/.node-version`.
- bash, fish and other shells.
- Linux and SteamOS behaviour and tests.
- Changing the shared chnode stub in `test/rv_ci_fallback_test.rb`.
- Running `stow`.

## Proof

- Login, non-interactive zsh: first `node` is chnode's default → `test/node_path_order_test.rb` `test_a_login_shell_puts_chnodes_node_ahead_of_homebrews_after_path_helper`
- Non-login, non-interactive zsh: first `node` is chnode's default → `test/node_path_order_test.rb` `test_a_non_login_shell_puts_chnodes_node_first`
- Interactive terminal shell: first `node` is chnode's default → `test/node_path_order_test.rb` `test_interactive_login_and_non_login_shells_keep_chnodes_node_first_after_the_prompt_hook`
- Inherited `CHNODE_ROOT`: first `node` is that version → `test/node_path_order_test.rb` `test_an_inherited_chnode_root_stays_ahead_of_homebrews_node`
- `npm root -g` points under `~/.nodes/node-<version>/` → `test/node_path_order_test.rb` `test_npm_and_npx_come_from_chnodes_node_in_a_login_shell`
- A project's `.node-version` wins → `test/node_path_order_test.rb` `test_a_project_node_version_wins_in_a_login_shell`
- `ruby` resolves to rv's Ruby before Homebrew's → `test/node_path_order_test.rb` `test_rvs_ruby_stays_ahead_of_homebrews_ruby_in_a_login_shell`
- After `unlock`, `codex` resolves to the shim first → `test/node_path_order_test.rb` `test_the_unlocked_codex_shim_stays_first_in_a_login_shell`

Per changed file, the unit tests expected:

- `zsh/.config/zsh/.zprofile`: covered by the acceptance tests above; plus `test_zprofile_leaves_path_alone_without_chnode_root` (no `CHNODE_ROOT` → fake Homebrew node stays first, the Linux guard).
- `zsh/.config/zsh/paths.zsh`: comment only, no new test.
- Existing tests that must stay green: `test/secrets_loader_test.rb` (`.zprofile` shim tests), `test/rv_ci_fallback_test.rb` (paths.zsh node tests).

Test setup: each test gets a `Dir.mktmpdir` with `home/` (as HOME) holding `.node-version` (`24.14.0`) and `.nodes/node-24.14.0/bin/` and `.nodes/node-22.21.1/bin/` with stub `node`, `npm` (prints `<its root>/lib/node_modules` for `root -g`) and `npx`, and an empty `lib/node_modules/beautiful-mermaid/` directory under each node root, which the npm test asserts exists under `npm root -g`; `homebrew/` (as `HOMEBREW_PREFIX`) with `bin/` holding stub `node`, `npm`, `npx`, `ruby` and an `rv` stub, and `opt/chnode/share/chnode/` holding the faithful chnode stub; `rubies/bin/ruby` for rv. The `rv` stub answers `shell init zsh` with a `_rv_autoload_hook` function plus a PATH prepend of `rubies/bin`, and `shell env zsh` with `export PATH='<rubies/bin>:'"$PATH"`. Each shell runs `zsh -f -c` (`-f -i -c` for the interactive case) with `unsetenv_others: true` and PATH `homebrew/bin:/usr/bin:/bin`, from a working directory outside `home/` (so no ancestor `.node-version`) unless the test needs one. The login script is: `typeset -gU path`, source `paths.zsh`, `path=("$HOMEBREW_PREFIX/bin" "${path[@]}")` to stand in for path_helper, source `.zprofile`, then the probe. The non-login script stops before the path_helper line. Assert on exact paths from `command -v`.

---
Domain skills applied: dotfiles-maintenance (stow and symlink rules), rails-testing (Minitest conventions, one behaviour per test name).

## Critique

### Round 1 (codex exec -p terra)

- The inherited-root test narrows the criterion; real chnode lets `~/.node-version` replace an inherited root under HOME, so keep a valid inherited root unless a project-local `.node-version` exists, and test both cases → dismissed: that changes `chnode_auto` behaviour, which `intent.md` says stays, and it would make a shell's node depend on its parent instead of its directory; it goes to the coordinator as a decision, and the plan keeps chnode's rule.
- Interactive coverage misses a non-login interactive terminal; add a pty check for `zsh -i` as well as `zsh -il` → fixed (the interactive acceptance test now covers login and non-login, and step 6 repeats the pty check with `zsh -i`)
- The `beautiful-mermaid` live check runs `npm root -g` in a normal shell, not the temporary-HOME shell; also fixture the package in the automated test → fixed (the `ls` runs inside the same `env -i … zsh -lc`, and the test setup adds `lib/node_modules/beautiful-mermaid/` under each stub node root)
- The project-version live check uses a `/tmp/np` that is never created and hard-codes versions → fixed (step 6 uses `mktemp -d` and derives versions from `$T/.node-version` and `ls $T/.nodes`)
