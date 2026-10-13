# Plan: Glow uses the Solunized style

From `intent.md` (2026-10-13). Status: accepted.

## Context

Glow 3.0.0 (`/opt/homebrew/bin/glow`) renders Markdown with its built-in `auto` style. The live config `~/Library/Preferences/glow/glow.yml` is a plain file that the dotfiles do not manage. It holds `style: "auto"`, `mouse: false`, `pager: false`, `width: 80`, `all: false`. Ghostty swaps `solunized-light` and `solunized-dark` with the macOS appearance (`ghostty/.config/ghostty/config`, `theme = dark:"solunized-dark",light:"solunized-light"`). The solunized repository's `glow-style` change generates one ANSI-slot glamour style, `dist/glow/solunized.json`, that follows that palette swap.

Planning probes on 2026-10-13, glow 3.0.0, run under a pseudo-terminal (`script -q /dev/null glow … </dev/null`):

- `style:` in `glow.yml` works only as an absolute path. A relative path resolves against the current directory (`Error: specified style does not exist: probe.json` from `/`). A `~/…`, `$HOME/…` or `${HOME}/…` path passes glow's own existence check but fails in glamour: `Error: unable to create renderer: glamour: error reading file: open ~/Library/Preferences/glow/solunized.json: no such file or directory`. The `-s` flag behaves the same.
- `glow --config <file>` does not apply the file's values. With `--config` pointing at a file with `style: "pink"` and `width: 20`, glow renders the default dark style at width 80. A missing style file in that config gives no error. `GLOW_CONFIG_HOME=<dir>` does apply `<dir>/glow.yml`.
- Glow finds its default config through `$HOME`: with `HOME=<tmp>`, it reads `<tmp>/Library/Preferences/glow/glow.yml`.
- Glow blocks when stdin is not a terminal and stays open. Every scripted glow command here redirects `</dev/null`.
- The source file does not exist yet. The solunized `glow-style` worktree (`/Users/etienne.vandelden/Developer/solunized/.worktrees/glow-style`) holds an accepted plan but no implementation, and `dist/` is gitignored there. Its plan fixes the output path: `ruby generate_themes.rb` writes `dist/glow/solunized.json`.

Repository facts the plan depends on:

- `test/stow_package_roots_test.rb` `#test_every_stowed_package_root_holds_only_dotfiles` fails for any non-dot entry at a package root. `glow/Library` is such an entry.
- CI (`.github/workflows/dotfiles-tests.yml`) runs every `test/*_test.rb` on Ubuntu with Ruby 3.4 and Minitest. CI has no glow.
- `install/utils.sh` `stow_configure` runs `stow --dir <repo> --target "$HOME" --restow <package>` for each `STOW` entry. `glow` does not need `STOW_SHARED`.
- yamllint (`yamllint/.config/yamllint/config`) extends `default`, so YAML files start with `---`.
- Precedent for a committed generated theme: `zed/.config/zed/themes/solunized-theme.json`. No test checks it.

## Design decisions

- **`style:` is an absolute path: `/Users/etienne.vandelden/Library/Preferences/glow/solunized.json`.** It is the only form glow 3.0.0 resolves from every directory (probes above). The path is where stow links the package's `solunized.json`. It names this Mac's home directory. A Mac with another home directory needs an edit; see Risks and the decision line in the report.
- **The style file sits beside `glow.yml`:** `glow/Library/Preferences/glow/solunized.json`. Stow links both files into `~/Library/Preferences/glow/`. The name stays `solunized.json`, as generated.
- **`glow.yml` keeps the live file's comments and values**, adds a leading `---` for yamllint, and changes only `style:`.
- **The stow root guard accepts `Library` for the `glow` package only.** `test/stow_package_roots_test.rb` gets a per-package allowlist, `HOME_DIRECTORIES = { "glow" => [ "Library" ] }`, of non-dot `$HOME` directories a named package root may hold. The guard exists to stop files such as `README.md` from landing in `$HOME`; `Library` is a real macOS home directory, so `glow` targeting it is intended. Every other package, and every other non-dot entry, stays rejected. This is a deliberate change to a guard, written test-first, not a weakened test.
- **One new test file, `test/glow_package_test.rb`,** in the style of the existing tests: a `Minitest::Test` with `REPO_ROOT`, plain `File`/`YAML`/`JSON` reads, `packages.conf` read by sourcing it in bash (same helper shape as `StowPackageRootsTest#bash_array`). It needs no glow, so it runs in CI without a skip.
- **Glow renders are checks, not Minitest tests.** CI has no glow, and a test that skips itself without glow is a skipped test (playbook §7a). The checks in Proof run on the Mac before the pull request.
- **Byte identity with the solunized output is a check (`cmp`), not a test.** The source lives in another repository, which CI does not have.
- **Pre-merge proof uses `-s <package style>` and a temporary `HOME`, not `--config`.** `--config` ignores the file's values, so acceptance criteria 3–5 as written cannot show the Solunized style. The plan keeps criterion 3's `--config` command as a literal check, and adds two real ones:
  - The style itself: `glow -s "$PWD/glow/Library/Preferences/glow/solunized.json" README.md`. This also is the command Etienne runs in Ghostty for the light and dark checks before he approves the merge.
  - The config wiring: a scratch `HOME` whose `Library/Preferences/glow` holds `glow.yml` from the package with `style:` rewritten to the scratch path, and a symlink to the package's `solunized.json`. This proves glow reads the package's `glow.yml` and loads an absolute style path from any directory. It does not prove the committed home path; criterion 7 after merge does.
- **No `README.md` change.** The README lists no stow packages per app; nothing there goes stale.

## Integration points

- Glow 3.0.0 (Homebrew). Behaviour as probed above.
- The solunized repository's `glow-style` change: source of `solunized.json`. Generated by `ruby generate_themes.rb` in `/Users/etienne.vandelden/Developer/solunized/.worktrees/glow-style`, output `dist/glow/solunized.json`.
- Ghostty's `solunized-light`/`solunized-dark` palettes: the ANSI slots the style uses. Not edited.
- `install/tasks/50_stow_all.sh` and `install/utils.sh` `stow_configure`: link every `STOW` entry into `$HOME`. Not edited.
- `test/stow_package_roots_test.rb`: guard over every package root in `packages.conf`.
- The live `~/Library/Preferences/glow/glow.yml`: replaced by a stow link after merge, by Etienne's post-merge commands.

## Files that change

- `test/stow_package_roots_test.rb` — new tests `test_an_allowed_home_directory_at_its_package_root_is_accepted` and `test_an_allowed_home_directory_at_another_package_root_is_rejected`; `strays_in` skips an entry only when `HOME_DIRECTORIES` lists it for that package. A comment on the constant says why.
- `test/glow_package_test.rb` — new; the package tests in Proof.
- `glow/Library/Preferences/glow/glow.yml` — new; the live values plus the absolute `style:` path.
- `glow/Library/Preferences/glow/solunized.json` — new; a byte copy of the solunized `dist/glow/solunized.json`.
- `packages.conf` — `glow` in the `STOW` array, in alphabetical position between `git`/`github` and `herdr`.

## Order of work

0. Precondition: `/Users/etienne.vandelden/Developer/solunized/.worktrees/glow-style/applications/glow/template.json.erb` is committed there, and that worktree's `git status --porcelain` is empty. If not, stop and report that the solunized `glow-style` implementation has not landed. Then run `ruby generate_themes.rb` in that worktree, confirm `dist/glow/solunized.json` exists, and note `git -C <that worktree> rev-parse HEAD` and `shasum -a 256 dist/glow/solunized.json`.
1. Write `test/glow_package_test.rb` with `test_the_package_holds_glow_yml_with_the_live_values`. Run `ruby -Itest test/glow_package_test.rb -n test_the_package_holds_glow_yml_with_the_live_values`. Watch it fail on the missing file.
2. Create `glow/Library/Preferences/glow/glow.yml` with `---`, the live comments, `style: "/Users/etienne.vandelden/Library/Preferences/glow/solunized.json"`, `mouse: false`, `pager: false`, `width: 80`, `all: false`. Run step 1's command: green.
3. Add the remaining `GlowPackageTest` tests (Proof). Run the file. Watch the style, JSON and `packages.conf` tests fail.
4. `cp` the solunized `dist/glow/solunized.json` to `glow/Library/Preferences/glow/solunized.json`. Add `glow` to `STOW`. Run the file: green. The commit that adds the copy names the solunized commit SHA and the SHA-256 from step 0 in its message body.
5. Run `ruby -Itest test/stow_package_roots_test.rb`. Watch `test_every_stowed_package_root_holds_only_dotfiles` fail on `glow/Library`.
6. Add `test_an_allowed_home_directory_at_its_package_root_is_accepted` and `test_an_allowed_home_directory_at_another_package_root_is_rejected`. Run them; watch the first fail. Add `HOME_DIRECTORIES` and use it in `strays_in`. Run the file: green, including the README rejection tests.
7. Run the full suite: `for file in test/*_test.rb; do ruby -Itest "$file" || break; done`.
8. Run the linters on touched files: `yamllint glow/Library/Preferences/glow/glow.yml`, `rubocop test/glow_package_test.rb test/stow_package_roots_test.rb`, `ruby -e 'require "json"; JSON.parse(File.read(ARGV[0]))' glow/Library/Preferences/glow/solunized.json`.
9. Run the checks in Proof and record their output for the delivery account.
10. Re-read the full diff (playbook rule 21). Commit in small steps: the guard change; then the package, its test and `packages.conf`.

## Risks

- **The solunized output does not exist yet.** Implementation cannot start until the solunized `glow-style` change is implemented. If its review later changes the output, the copy needs a re-run of step 4 and the `cmp` check.
- **The absolute path ties `glow.yml` to one home directory.** On a Mac whose home is not `/Users/etienne.vandelden`, glow fails with `specified style does not exist`. The repository is public; the path holds a user name but no work reference (grep the diff for `nedap` and `caren` before committing).
- **Criteria 3–5 name `--config`, which glow 3.0.0 ignores.** The `--config` check passes but proves nothing about the style. The `-s` and scratch-`HOME` checks carry the real proof.
- **Stow folding.** After merge, Etienne trashes only `~/Library/Preferences/glow/glow.yml`, not the directory. The directory stays, so stow links the two files one by one and `glow.yml` becomes a symlink, as criterion 7 requires. If the directory were gone, stow would link the whole `glow` directory instead; glow would still work, but `glow.yml` itself would not be a symlink.
- **Linux.** Stow links `~/Library` there too (accepted in intent). Glow on Linux ignores it.
- **Guard change.** The allowlist names one package and one directory. A future macOS package that targets `~/Library` needs its own entry; a stray `README.md` still fails everywhere.
- Rejected: `~` or `$HOME` in `style:` (glamour fails on both); a relative `style:` (resolves against the current directory); `GLOW_CONFIG_HOME` with a `.config/glow` package (changes the agreed package layout and needs a shell-config change); a zsh alias `glow -s …` (moves the style out of `glow.yml`, against intent); a Minitest test that shells out to glow (CI has no glow; a self-skipping test is forbidden); generating `glow.yml` at install time from a template (new install machinery, out of scope).

## Proof

- The `glow` package holds `Library/Preferences/glow/glow.yml` with `mouse: false`, `pager: false`, `width: 80`, `all: false`, and a `style:` that names the Solunized style → `test/glow_package_test.rb` `GlowPackageTest#test_the_package_holds_glow_yml_with_the_live_values`, `#test_the_style_is_an_absolute_path_to_the_stowed_solunized_json`.
- The package's `solunized.json` is byte-identical to `dist/glow/solunized.json` from the solunized `glow-style` branch's generator → check: `cmp /Users/etienne.vandelden/Developer/solunized/.worktrees/glow-style/dist/glow/solunized.json glow/Library/Preferences/glow/solunized.json` exits 0, run after `ruby generate_themes.rb` in that worktree; plus `GlowPackageTest#test_the_package_holds_a_valid_glamour_style`.
- `glow --config glow/Library/Preferences/glow/glow.yml README.md`, from the repository root and from another directory, renders without a style error → check: set `root=$(git rev-parse --show-toplevel)` in the worktree. From `$root`, `script -q /dev/null glow --config glow/Library/Preferences/glow/glow.yml README.md </dev/null | grep -c Error` prints `0`; then from `/`, the same with `"$root/glow/Library/Preferences/glow/glow.yml"` and `"$root/README.md"`. Plus the real wiring check: build a scratch `HOME` (`$S`, under the session scratchpad) with `$S/Library/Preferences/glow/glow.yml` copied from the package with `style:` set to `$S/Library/Preferences/glow/solunized.json`, and `$S/Library/Preferences/glow/solunized.json` a symlink to the package file. From `$root` and from `/`, capture `out=$(HOME="$S" script -q /dev/null glow "$root/README.md" </dev/null)`. Pass when `grep -c Error <<<"$out"` prints `0`, `grep -cE $'\e\[(3[0-7]|9[0-7]|38;5;([0-9]|1[0-5]))[;m]' <<<"$out"` prints more than `0`, and `grep -cE $'\e\[(38;5;(1[6-9]|[2-9][0-9]|[0-9]{3})|38;2;|48;)' <<<"$out"` prints `0`.
- In Ghostty with macOS in light mode, the style shows headings, links and code in Solunized light colours on the cream background → check: from `$root`, capture `out=$(script -q /dev/null glow -s "$root/glow/Library/Preferences/glow/solunized.json" README.md </dev/null)` and apply the same three pass conditions as the wiring check; then Etienne runs `glow -s <worktree>/glow/Library/Preferences/glow/solunized.json README.md` in Ghostty in light mode before he approves the merge. The pull request body lists that command.
- After a switch to dark mode, the same command, with no config change, shows them in Solunized dark colours on the blue-teal background → check: Etienne runs the same command in Ghostty in dark mode before he approves the merge.
- `packages.conf` lists `glow` in the `STOW` array → `test/glow_package_test.rb` `GlowPackageTest#test_packages_conf_stows_glow`.
- After merge, trash and stow from the main checkout: plain `glow README.md` renders with the Solunized style, and `~/Library/Preferences/glow/glow.yml` is a symlink into the main dotfiles checkout → check, by Etienne after merge, from `~/Developer/dotfiles`: `trash ~/Library/Preferences/glow/glow.yml`, then `stow -t "$HOME" glow`, then `readlink ~/Library/Preferences/glow/glow.yml` points into `~/Developer/dotfiles/glow/`, then `glow README.md` in Ghostty shows the Solunized colours. The delivery account lists these commands.

Per changed file, the unit tests expected, named as behaviour:

- `test/glow_package_test.rb` (covers `glow/Library/Preferences/glow/glow.yml`, `glow/Library/Preferences/glow/solunized.json`, `packages.conf`): `test_the_package_holds_glow_yml_with_the_live_values` (YAML loads; `mouse`, `pager`, `all` are `false`; `width` is `80`), `test_the_style_is_an_absolute_path_to_the_stowed_solunized_json` (`style` equals `/Users/etienne.vandelden/Library/Preferences/glow/solunized.json`, and `glow/Library/Preferences/glow/solunized.json` exists in the package), `test_the_package_holds_a_valid_glamour_style` (the JSON parses to a Hash with a `document` key), `test_packages_conf_stows_glow` (`STOW` sourced from `packages.conf` includes `glow`).
- `test/stow_package_roots_test.rb`: `test_an_allowed_home_directory_at_its_package_root_is_accepted` (fixture package `glow` with `[ ".config", "Library" ]` has no strays), `test_an_allowed_home_directory_at_another_package_root_is_rejected` (fixture package `other` with `[ "Library" ]` reports `other/Library`); the existing `test_a_readme_at_a_package_root_is_rejected` and `test_every_stowed_package_root_holds_only_dotfiles` stay unchanged and green.

Test setup: no fixtures beyond `StowPackageRootsTest#fixture_repository`, which already exists. `GlowPackageTest` reads the real package files and `packages.conf`. No fakes. Glow checks use a scratch directory under the session scratchpad; nothing writes to the real `~/Library/Preferences/glow` before merge.

## Out of scope

- Generating or changing the style (the solunized repository owns it).
- Linux glow config (`~/.config/glow/glow.yml`).
- Running `stow`, or trashing the live `glow.yml`, before the pull request merges.
- Automatic sync of the copy with the solunized repository.
- A home-directory-independent `style:` path; glow 3.0.0 offers none.

---
Domain skills applied: dotfiles-maintenance (stow layout, `packages.conf`), rails-testing (Minitest conventions only; not a Rails app), ruby-style (test naming). Conflict flagged: the intent's `--config` verification commands against glow 3.0.0's behaviour (see Design decisions).

## Critique

### Round 1 (codex exec -p terra)

- The guard permits `Library` for every package, but only `glow` needs it; scope the allowlist per package and test rejection for another package. → fixed (`HOME_DIRECTORIES` is keyed by package; a new test rejects `Library` in another package)
- The style test accepts any `/Users/<name>/` path, so a wrong user name passes; assert the exact planned path. → fixed (the test asserts `/Users/etienne.vandelden/Library/Preferences/glow/solunized.json`)
- The copy comes from an ignored, unpinned generator output, so `cmp` trusts local state; record the source commit and digest. → fixed (step 0 requires a clean, committed solunized worktree and records its HEAD SHA and the SHA-256; the copy commit names both)
- The proof commands are not reproducible: `$PWD_ROOT` is undefined, one glow command has no pseudo-terminal, and the SGR `grep` only lists codes. → fixed (Proof defines `root`, runs every glow check through `script`, and states explicit pass conditions as `grep -c` counts)
