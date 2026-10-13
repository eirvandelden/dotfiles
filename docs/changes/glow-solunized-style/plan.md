# Plan: Glow uses the Solunized style

From `intent.md` (2026-10-13, amended). Status: accepted.

## Context

Glow 3.0.0 (`/opt/homebrew/bin/glow`) renders Markdown with its built-in `auto` style. The live config `~/Library/Preferences/glow/glow.yml` is a plain file that the dotfiles do not manage. It holds glow's generated comments plus `style: "auto"`, `mouse: false`, `pager: false`, `width: 80`, `all: false`. Ghostty swaps `solunized-light` and `solunized-dark` with the macOS appearance (`ghostty/.config/ghostty/config`). The solunized repository's `glow-style` change generates one ANSI-slot glamour style that follows that swap.

Glow facts from the plan-stage probes (glow 3.0.0, run under a pseudo-terminal, `script -q /dev/null glow … </dev/null`):

- `style:` resolves from every directory only as an absolute path. A relative path resolves against the current directory. `~/…` and `$HOME/…` pass glow's own check but fail in glamour (`error reading file: open ~/Library/…`). The `-s` flag behaves the same.
- `glow --config <file>` ignores the file's values. It proves nothing about the setup.
- Glow finds its default config through `$HOME`: with `HOME=<tmp>`, it reads `<tmp>/Library/Preferences/glow/glow.yml`.
- Glow blocks when stdin is not a terminal. Every scripted glow command here redirects `</dev/null`.

Source of the style: the solunized `glow-style` worktree, `/Users/etienne.vandelden/Developer/solunized/.worktrees/glow-style`. Its implementation is committed (`06d89bc Add Solunized glamour style for glow`, `d2e1a41 Document the glow target`). `dist/` is gitignored there, so the copy comes from a fresh `ruby generate_themes.rb` run on a clean, committed tree.

Repository facts the plan depends on:

- `install.sh` runs numbered scripts in `install/tasks/` through `run_task`, which refuses a script that is not executable. `50_stow_all.sh` is the last one. Each task sources `00_common.sh`, calls `task_bootstrap` and `determine_os`, and skips itself on the wrong OS (precedent: `24_configure_launchd_path.sh`). `determine_os` reads `uname -s`. Sourcing `install/utils.sh` and `packages.conf` has no side effects beyond `set -euo pipefail`.
- `install/utils.sh` `stow_configure` runs `stow --restow`, plus `--no-folding` for packages in `STOW_SHARED`.
- `test/stow_package_roots_test.rb` `#test_every_stowed_package_root_holds_only_dotfiles` fails for any non-dot entry at a package root. `glow/Library` is such an entry.
- No test covers `install/tasks/` today. Tests that run shell code stub commands on `PATH` (precedent: `test/secrets_loader_test.rb` stubs `op`).
- CI (`.github/workflows/dotfiles-tests.yml`) runs every `test/*_test.rb` on Ubuntu with Ruby 3.4. CI has no glow.
- Lint: lefthook runs `shellcheck -x -S warning` on `*.sh`, RuboCop on `*.rb`, yamllint on `*.yml`.
- Precedent for a committed generated theme: `zed/.config/zed/themes/solunized-theme.json`. No test checks it.

## Design decisions

- **The package holds only the style:** `glow/Library/Preferences/glow/solunized.json`, a byte copy of the generated `dist/glow/solunized.json`. No `glow.yml` in the package, no home path anywhere in the repository.
- **A new install task, `install/tasks/51_configure_glow_style.sh`,** run by `install.sh` right after `50_stow_all.sh`. It follows the task-script shape of `24_configure_launchd_path.sh`: bootstrap, `determine_os`, skip with a log line outside macOS. On macOS it sets `style:` in `$HOME/Library/Preferences/glow/glow.yml` to `"$HOME/Library/Preferences/glow/solunized.json"`, with `$HOME` expanded by the shell.
- **The edit is one `awk` pass, written back only on change.** `awk` replaces every line that starts with `style:` by `style: "<path>"`, and appends that line at the end when none matched. It reads the path from `ENVIRON`, not `-v`, so no escape processing touches it. The result goes to a `mktemp` file. When `cmp -s` says it differs from the config, `cat` writes it into the config, so a config that is a symlink or has its own mode keeps that identity; then the temp file goes. A missing config gets `mkdir -p` on its directory and a file holding only the `style:` line. Lines such as `# style name or JSON path (default "auto")` start with `#`, so they never match. Unchanged output means a second run writes nothing and logs that the style is already set.
- **The task skips with a warning when the stowed style is missing.** Pointing glow at a file that does not exist makes every `glow` call fail with `specified style does not exist`. After a normal `install.sh` run the file is there, because stow ran first.
- **`glow` also goes in `STOW_SHARED`, so stow links it file by file.** On a Mac without `~/Library/Preferences/glow`, stow would otherwise fold the whole directory into one symlink to the repository. The install step would then write `glow.yml` into the repository's `glow` package, as an untracked file. With `--no-folding`, stow makes a real directory and links only `solunized.json`. The `STOW_SHARED` comment in `packages.conf` grows one line: a package is shared too when something other than stow writes into its directory. This is the existing mechanism, used for a second reason; `stow_configure` does not change.
- **The stow root guard accepts `Library` for the `glow` package only.** `test/stow_package_roots_test.rb` gets `HOME_DIRECTORIES = { "glow" => [ "Library" ] }`: non-dot `$HOME` directories that a named package root may hold. The guard exists to keep files such as `README.md` out of `$HOME`. `Library` is a real macOS home directory, so `glow` targeting it is intended. Every other package and every other non-dot entry stays rejected. Written test-first; the existing tests stay unchanged.
- **The task's tests run the real script with a scratch `HOME` and a stubbed `uname`.** `test/glow_style_install_test.rb` puts a `uname` stub that prints `Darwin` (or `Linux`) first on `PATH`, so the macOS path runs in Ubuntu CI and the skip path runs on the Mac. Nothing needs glow, so no test skips itself.
- **One package test file, `test/glow_package_test.rb`,** in the style of `StowPackageRootsTest`: `REPO_ROOT`, plain `File` and `JSON` reads, `packages.conf` arrays read by sourcing it in bash.
- **Glow renders and byte identity are checks, not tests.** CI has neither glow nor the solunized repository. A self-skipping test is forbidden (playbook §7a).
- **No `README.md` change.** The README lists no stow packages per app.

## Integration points

- Glow 3.0.0 (Homebrew). Behaviour as probed above.
- The solunized `glow-style` change: source of `solunized.json`, generated by `ruby generate_themes.rb` in its worktree.
- Ghostty's `solunized-light`/`solunized-dark` palettes: the ANSI slots the style uses. Not edited.
- `install.sh`, `install/tasks/00_common.sh`, `install/utils.sh` (`determine_os`, `log`, `warn`, `require_cmd`, `stow_configure`). Only `install.sh` changes.
- `test/stow_package_roots_test.rb`: guard over every package root in `packages.conf`.
- The live `~/Library/Preferences/glow/glow.yml`: its `style:` line changes after merge, when the coordinator runs the step from the main checkout.

## Files that change

- `glow/Library/Preferences/glow/solunized.json` — new; byte copy of the solunized `dist/glow/solunized.json`.
- `install/tasks/51_configure_glow_style.sh` — new, executable; the macOS step described above. Header comment in the style of the other tasks: purpose, usage, idempotency, why the path is absolute.
- `install.sh` — `run_task "51_configure_glow_style.sh" "$root"` after `50_stow_all.sh`.
- `packages.conf` — `glow` in `STOW` between `github` and `herdr`; `glow` in `STOW_SHARED`, with the extra comment line.
- `test/glow_style_install_test.rb` — new; the install-step tests in Proof.
- `test/glow_package_test.rb` — new; the package tests in Proof.
- `test/stow_package_roots_test.rb` — `HOME_DIRECTORIES` with a comment saying why, used in `strays_in`; two new tests.

## Order of work

0. Precondition. In the solunized `glow-style` worktree, `git status --porcelain` is empty and `applications/glow/template.json.erb` is tracked. If not, stop and report it. Run `ruby generate_themes.rb` there. Confirm `dist/glow/solunized.json` exists. Note `git -C <that worktree> rev-parse HEAD` and `shasum -a 256 dist/glow/solunized.json`.
1. Write `test/glow_style_install_test.rb` with `test_an_existing_style_line_points_at_the_stowed_solunized_style`. Run `ruby -Itest test/glow_style_install_test.rb -n test_an_existing_style_line_points_at_the_stowed_solunized_style`. Watch it fail on the missing script.
2. Create `install/tasks/51_configure_glow_style.sh` (`chmod +x`) with the bootstrap, the macOS skip and the `awk` replace. Run step 1's command: green.
3. Add the other install-step tests one at a time, each run and watched fail before the code that makes it pass: no `style:` line, missing config, second run, not macOS, missing style.
4. Add `test_install_sh_runs_the_glow_step_after_stowing`. Watch it fail. Add the `run_task` line to `install.sh`. Green.
5. Write `test/glow_package_test.rb`. Run it. Watch every test fail.
6. `cp` the solunized `dist/glow/solunized.json` to `glow/Library/Preferences/glow/solunized.json`. Add `glow` to `STOW` and `STOW_SHARED`, and the comment line. Run the file: green.
7. Run `ruby -Itest test/stow_package_roots_test.rb`. Watch `test_every_stowed_package_root_holds_only_dotfiles` fail on `glow/Library`.
8. Add `test_an_allowed_home_directory_at_its_package_root_is_accepted` and `test_an_allowed_home_directory_at_another_package_root_is_rejected`. Watch the first fail. Add `HOME_DIRECTORIES` and use it in `strays_in`. Run the file: green.
9. Full suite, stopping at the first failing file and failing with it: `failed=0; for file in test/*_test.rb; do ruby -Itest "$file" || { failed=1; break; }; done; test "$failed" = 0`.
10. Linters on touched files: `shellcheck -x -S warning install/tasks/51_configure_glow_style.sh install.sh`, `bash -n packages.conf`, `rubocop test/glow_style_install_test.rb test/glow_package_test.rb test/stow_package_roots_test.rb`, `ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' glow/Library/Preferences/glow/solunized.json`.
11. Run the pre-merge checks in Proof and record their output for the delivery account.
12. Re-read the full diff (rule 21). Grep it for `nedap` and `caren`. Commit in small steps: the install task with its test and `install.sh`; the guard change; the package with its test and `packages.conf`. The commit that adds `solunized.json` names the solunized SHA and SHA-256 from step 0 in its body.

## Risks

- **The live `glow.yml` keeps glow's other values.** The step edits one line; a stale or hand-edited `width` stays. Intended: the dotfiles own only the style.
- **A home path with `"` or `\` breaks the YAML quoting.** macOS short user names cannot hold either. Not handled.
- **Re-copy drift.** If the solunized review changes the output, step 0 and step 6 run again, and the `cmp` check must pass on the new copy.
- **Stow on this Mac after merge.** `~/Library/Preferences/glow` exists as a real directory, so stow links `solunized.json` alone even without `--no-folding`. The plain `glow.yml` there stays untouched by stow; no trash step is needed.
- **Linux.** Stow links `~/Library/Preferences/glow/solunized.json` there too (accepted in intent). The install step skips.
- **Guard change.** The allowlist names one package and one directory. A future macOS package that targets `~/Library` needs its own entry.
- **`STOW_SHARED` reuse.** Its name speaks of a second repository. The comment line covers the second reason; if more such packages appear, a separate `STOW_NO_FOLDING` list may read better. Not worth a new list for one package.
- Rejected: a stowed `glow.yml` (needs a hardcoded home path in a public repository; the intent rejected it); `~` or `$HOME` in `style:` (glamour fails); a relative `style:` (resolves against the current directory); `GLOW_CONFIG_HOME` with a `.config/glow` package (changes the agreed layout, needs a shell change); a zsh alias `glow -s …` (moves the style out of `glow.yml`); `sed -i` for the edit (GNU and BSD flags differ); `mv` of the temp file over the config (replaces a symlinked config with a plain file); the edit as a function in `install/utils.sh` (the step is one task's logic, as in `24_configure_launchd_path.sh`); a Minitest test that shells out to glow (CI has no glow).

## Proof

- The `glow` package holds `Library/Preferences/glow/solunized.json`, byte-identical to `dist/glow/solunized.json` from the solunized `glow-style` branch's generator, and no `glow.yml` → `test/glow_package_test.rb` `GlowPackageTest#test_the_package_holds_a_valid_glamour_style`, `#test_the_package_holds_no_glow_yml`; plus check: `cmp /Users/etienne.vandelden/Developer/solunized/.worktrees/glow-style/dist/glow/solunized.json glow/Library/Preferences/glow/solunized.json` exits 0, after step 0.
- `packages.conf` lists `glow` in the `STOW` array → `test/glow_package_test.rb` `GlowPackageTest#test_packages_conf_stows_glow`.
- With a `glow.yml` of `style: "auto"` and `width: 80`, the install step leaves `width: 80` and sets `style:` to `<HOME>/Library/Preferences/glow/solunized.json`, with the real home directory spelled out → `test/glow_style_install_test.rb` `GlowStyleInstallTest#test_an_existing_style_line_points_at_the_stowed_solunized_style`.
- With a `glow.yml` that has no `style:` line, the install step adds one and keeps the other lines → `GlowStyleInstallTest#test_a_config_without_a_style_line_gets_one_and_keeps_its_other_lines`.
- With no `glow.yml`, the install step creates one that holds only the `style:` line → `GlowStyleInstallTest#test_a_missing_config_is_created_with_only_the_style_line`.
- Running the install step twice gives the same file as running it once → `GlowStyleInstallTest#test_a_second_run_leaves_the_config_unchanged`.
- `glow -s glow/Library/Preferences/glow/solunized.json README.md` renders without a style error, using only palette colours 0–15 → check: in the worktree, `root=$(git rev-parse --show-toplevel)`; `out=$(script -q /dev/null glow -s "$root/glow/Library/Preferences/glow/solunized.json" "$root/README.md" </dev/null)`. Pass when the command exits 0 (`script` passes on glow's exit status; a missing or unreadable style exits 1), `grep -ci error <<<"$out"` prints `0` (`README.md` holds no "error"), `grep -cE $'\e\[(3[0-7]|9[0-7]|38;5;([0-9]|1[0-5]))[;m]' <<<"$out"` prints more than `0`, and `grep -cE $'\e\[(38;5;(1[6-9]|[2-9][0-9]|[0-9]{3})|38;2;|48;)' <<<"$out"` prints `0`.
- With a scratch home directory that holds the stowed style and an installed `glow.yml`, plain `glow README.md` run from another directory picks up the Solunized style → check: `S` is a new directory under the session scratchpad. `mkdir -p "$S/Library/Preferences/glow"`; symlink `$S/Library/Preferences/glow/solunized.json` to the package file; write `$S/Library/Preferences/glow/glow.yml` holding `style: "auto"` and `width: 80`. Run `HOME="$S" "$root/install/tasks/51_configure_glow_style.sh"`. Then `grep '^style:' "$S/Library/Preferences/glow/glow.yml"` shows `$S` spelled out, and from `/`, `out=$(cd / && HOME="$S" script -q /dev/null glow "$root/README.md" </dev/null)` meets the four pass conditions above. Then run the same `out` with `HOME="$S"` and `glow -s auto` and confirm it differs, so the colours come from the Solunized style.
- In Ghostty with macOS in light mode, `glow -s <worktree style> README.md` shows headings, links and code in Solunized light colours on the cream background; after a switch to dark mode, Solunized dark colours on the blue-teal background → check: Etienne runs `glow -s <worktree>/glow/Library/Preferences/glow/solunized.json README.md` in Ghostty in both modes before he approves the merge. The pull request body gives that command with the worktree path spelled out.
- After merge, stow and the install step from the main checkout: `~/Library/Preferences/glow/solunized.json` is a symlink into the main dotfiles checkout, and plain `glow README.md` renders with the Solunized style → check, by the coordinator after Etienne merges, from `~/Developer/dotfiles` on an up-to-date `main`: `stow --no-folding -t "$HOME" glow` (the approved command plus the flag `install.sh` passes for a `STOW_SHARED` package; without it, a Mac with no `~/Library/Preferences/glow` would get a folded directory symlink and the next step would write `glow.yml` into the repository), then `./install/tasks/51_configure_glow_style.sh`, then `readlink ~/Library/Preferences/glow/solunized.json` points into `~/Developer/dotfiles/glow/`, `grep '^style:' ~/Library/Preferences/glow/glow.yml` shows the absolute path, and `script -q /dev/null glow README.md </dev/null` meets the four pass conditions. The delivery account lists these commands and their output.

Per changed file, the unit tests expected, named as behaviour:

- `test/glow_style_install_test.rb` (covers `install/tasks/51_configure_glow_style.sh`, `install.sh`): `test_an_existing_style_line_points_at_the_stowed_solunized_style` (file is `style: "auto"` and `width: 80`; afterwards `width: 80` stays and the style line is `style: "<scratch HOME>/Library/Preferences/glow/solunized.json"`), `test_a_config_without_a_style_line_gets_one_and_keeps_its_other_lines` (the original lines, comments included, stay in order; one `style:` line is added), `test_a_missing_config_is_created_with_only_the_style_line`, `test_a_second_run_leaves_the_config_unchanged` (bytes after two runs equal bytes after one), `test_the_step_leaves_the_config_alone_outside_macos` (`uname` stub prints `Linux`; an existing config is byte-identical and a missing one stays missing), `test_a_missing_stowed_style_leaves_the_config_alone` (exit 0, warning on stderr, config unchanged), `test_install_sh_runs_the_glow_step_after_stowing` (in `install.sh`, the `run_task "51_configure_glow_style.sh"` line comes after the `run_task "50_stow_all.sh"` line), `test_the_step_is_executable`.
- `test/glow_package_test.rb` (covers `glow/Library/Preferences/glow/solunized.json`, `packages.conf`): `test_the_package_holds_a_valid_glamour_style` (the JSON parses to a Hash with a `document` key), `test_the_package_holds_no_glow_yml`, `test_packages_conf_stows_glow`, `test_packages_conf_links_glow_file_by_file` (`STOW_SHARED` includes `glow`).
- `test/stow_package_roots_test.rb`: `test_an_allowed_home_directory_at_its_package_root_is_accepted` (fixture package `glow` with `[ ".config", "Library" ]` has no strays), `test_an_allowed_home_directory_at_another_package_root_is_rejected` (fixture package `other` with `[ "Library" ]` reports `other/Library`). The existing tests stay unchanged and green.

Test setup: `GlowStyleInstallTest` makes a `Dir.mktmpdir` per test holding a scratch `HOME` (with `Library/Preferences/glow/solunized.json` touched, except in the missing-style test) and a `bin` directory with an executable `uname` stub. It runs the real script with `Open3.capture3({ "HOME" => home, "PATH" => "#{bin}:#{ENV["PATH"]}" }, script)` and removes the directory in `teardown`. `GlowPackageTest` reads the real package files and sources `packages.conf` in bash. `StowPackageRootsTest` uses its existing `fixture_repository`. No other fakes. Nothing writes to the real `~/Library/Preferences/glow` before merge.

## Out of scope

- Generating or changing the style (the solunized repository owns it).
- Managing glow's other settings (`mouse`, `pager`, `width`, `all`).
- Linux glow config (`~/.config/glow/glow.yml`).
- Running `stow` or the install step on the live home directory before the pull request merges.
- Automatic sync of the copy with the solunized repository.
- Any change to `stow_configure` or other install tasks.

---
Domain skills applied: dotfiles-maintenance (stow layout, `packages.conf`, install tasks), rails-testing (Minitest conventions only; not a Rails app), ruby-style (test naming). No conflicts between them or with the playbook.

## Critique

### Round 1 (codex exec -p terra)

- The full-suite loop `ruby … || break` exits 0 after a failing test, because the loop returns `break`'s status. → fixed (step 9 records the failure in `failed` and ends with `test "$failed" = 0`)
- The post-merge proof runs plain `stow -t "$HOME" glow`, which bypasses the `--no-folding` that `install.sh` passes for a `STOW_SHARED` package; on a Mac without the directory the next step would write `glow.yml` into the repository. → fixed (the post-merge check runs `stow --no-folding -t "$HOME" glow`; the flag only keeps stow from folding the directory, so the approved action stays the same)
- The render checks count only `Error` and ignore glow's exit status, so a failing style could pass. → fixed (each check requires exit 0, which `script` passes on from glow, verified with a missing style exiting 1, and counts `error` case-insensitively; `README.md` holds no "error")
