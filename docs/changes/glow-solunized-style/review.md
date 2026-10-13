# Review: glow-solunized-style

## Round 1 — 2026-10-13T17:00Z — 759b05d8

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes apply (Bugs, Security, Compliance).

No Important findings.

- [x] Nit: `set_style` has no `trap` for the `mktemp` file. When `rewrite_style` or the `cat` write fails under `set -e`, the temp file stays behind in `$TMPDIR`. — `install/tasks/51_configure_glow_style.sh:51` → fixed (Remove the glow step's temp file when a write fails)
- [x] Nit: A config with CRLF line endings gets mixed endings. The `style:` line is rewritten without `\r`, and the other lines keep it. Glow's YAML parser accepts this, so it is cosmetic. — `install/tasks/51_configure_glow_style.sh:37` → dismissed: glow writes its config with LF endings, and the reviewer confirms glow's YAML parser accepts mixed endings; no reader sees a difference.
- [x] Nit: When the `50_stow_all.sh` line is missing from `install.sh`, `assert_operator(glow, :>, stow)` raises `ArgumentError` on `nil`. It does not fail with a clear message. Add `refute_nil(stow)` next to `refute_nil(glow)`. — `test/glow_style_install_test.rb:78` → fixed (Fail clearly when install.sh loses its stow step)

### Bugs

- Probed the install step with a scratch `HOME`. A config without a trailing newline gets one. A second run logs `style already set` and writes nothing. A missing stowed style warns and leaves the config alone.
- `determine_os` with the `Linux` stub on macOS falls back to `Unknown` and skips. With the `Darwin` stub on Ubuntu CI it takes the macOS branch without calling macOS-only tools.

### Security

- Nothing found. The style path reaches awk through `ENVIRON`, so awk applies no escape processing to it. The diff has no secrets. `nedap`/`caren` appear only in the plan's own grep instruction.

### Compliance

| Acceptance criterion | Proof |
| --- | --- |
| Package holds `solunized.json`, byte-identical to the generator output, and no `glow.yml` | `GlowPackageTest#test_the_package_holds_a_valid_glamour_style`, `#test_the_package_holds_no_glow_yml`; check: `cmp` against `solunized/.worktrees/glow-style/dist/glow/solunized.json` at `a27d632` exits 0; SHA-256 `bcdaebf1…665f` matches the commit body |
| `packages.conf` lists `glow` in `STOW` | `GlowPackageTest#test_packages_conf_stows_glow` (plus `#test_packages_conf_links_glow_file_by_file` for `STOW_SHARED`) |
| Existing `style: "auto"` + `width: 80` → absolute style path, `width: 80` kept | `GlowStyleInstallTest#test_an_existing_style_line_points_at_the_stowed_solunized_style` |
| No `style:` line → one added, other lines kept | `GlowStyleInstallTest#test_a_config_without_a_style_line_gets_one_and_keeps_its_other_lines` |
| No `glow.yml` → created with only the `style:` line | `GlowStyleInstallTest#test_a_missing_config_is_created_with_only_the_style_line` |
| Second run gives the same file | `GlowStyleInstallTest#test_a_second_run_leaves_the_config_unchanged` |
| `glow -s <package style> README.md` renders without a style error, palette 0–15 only | check, rerun by this review: exit 0, `error` count 0, 94 palette escapes, 0 escapes outside 0–15 |
| Scratch home + installed `glow.yml` → plain `glow` from `/` uses Solunized | check, rerun by this review: `style:` holds the scratch home spelled out; output equals the `-s` output above and differs from `-s auto` |
| Ghostty light and dark mode show Solunized colours | manual check by Etienne before merge; the PR body must give the command |
| After merge: stowed symlink into the main checkout, plain `glow` uses the style | post-merge check by the coordinator; not provable before merge |

- Every test named in the plan's `## Proof` exists. The plan's `test_the_step_leaves_the_config_alone_outside_macos` is split in two: that test covers an existing config, and `test_the_step_creates_no_config_outside_macos` covers a missing one. Both halves of the named behaviour are proven.
- Files changed match the plan's list. Nothing unplanned. Commits follow the plan's split.
- `test/stow_package_roots_test.rb`: the existing tests are unchanged. Only two tests and the `HOME_DIRECTORIES` allowlist are added.
- Checks run: the three changed test files pass (20 runs, 0 failures). `shellcheck -x -S warning` and `rubocop` on the touched files are clean. In the full suite, 43 of 45 files pass. `test/agent_worktree_test.rb` hangs (974s) and `test/review_report_check_test.rb` errors (`git commit --quiet -m advance main failed`, a fixture commit on `main`). This branch touches neither file. Both failures look environmental (global git hooks in fixture repositories), not caused by this change.

## Round 2 — 2026-10-13T16:40Z — 759b05d8 (codex)

No findings.

## Round 3 — 2026-10-13T17:31Z — 565cd9b9

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes apply (Bugs, Security, Compliance). This round covers the commits since round 1: `233b699b`, `03de13ab`, `3355db13`, `565cd9b9`.

No Important findings.

- [x] Nit: `test_a_failed_write_leaves_no_temp_file_behind` makes the write fail with `chmod 0444`. A process that runs as root ignores that mode, so the write succeeds and the test fails. GitHub's Ubuntu runner is not root, so CI passes today. — `test/glow_style_install_test.rb:76` → fixed (Escape the glow style path for YAML; make the failed-write test root-safe)

### Bugs

- The `EXIT` trap replaces no other trap: neither `00_common.sh` nor the helpers this task calls set one. Probed with a scratch `HOME` and `TMPDIR`: a first run sets the style and leaves the scratch `TMPDIR` empty. A second run logs `style already set` and also leaves it empty.
- `refute_nil(stow)` now fails with a clear message when the `50_stow_all.sh` line goes missing.

### Security

- Nothing found. The new commits add no input handling, secrets or work references.

### Compliance

- The acceptance-criteria table from round 1 still holds. `glow/` has not changed since `2dfa3fb7`, so the render and byte-identity checks from round 1 still apply.
- `233b699b` adds `require_relative "isolated_git"` to both new test files. That makes them comply with main's `IsolatedGitTest#test_every_test_file_requires_the_helper`.
- No existing test was weakened, skipped or deleted.
- Checks run: `glow_style_install_test.rb` (10 runs), `glow_package_test.rb` (4 runs) and `stow_package_roots_test.rb` (7 runs) pass. `shellcheck -x -S warning` and `rubocop` on the touched files are clean.
- Outside this branch: `test/isolated_git_test.rb` fails on `origin/main` (`31fbbd43`, the merge base). 18 test files that this branch does not touch lack the helper, for example `bi_test.rb` and `deliver_test.rb`. Neither glow test file is in that list. Under playbook rule 25 that fix belongs on its own branch.

## Round 4 — 2026-10-13T17:45Z — 565cd9b9 (codex)

- [x] Important: Escape the style path for YAML. If `$HOME` contains `"` or `\`, the step writes an invalid or misinterpreted quoted YAML value, so Glow cannot load its config. — `install/tasks/51_configure_glow_style.sh:37` → fixed (Escape the glow style path for YAML; make the failed-write test root-safe)

## Round 5 — 2026-10-13T17:55Z — b7f054ee

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes apply (Bugs, Security, Compliance). This round covers the commits since round 3: `01642586`, `b7f054ee`.

No findings.

### Bugs

- `yaml_escape` escapes `\` before `"`, so the backslash it adds before a quote is not doubled again. Probed with `h"o\me` under `/bin/bash` 3.2.57 and Homebrew bash 5.3.20 (where `patsub_replacement` is on): both write `h\"o\\me`. Ruby's YAML parser reads the result back as the original path.
- `test_a_failed_write_leaves_no_temp_file_behind` now puts a directory where `glow.yml` goes. macOS awk reads a directory as empty and exits 0, and gawk skips it with a warning, so on both the step fails at the `cat` write, after `mktemp`. A root process cannot write to a directory either, so the test holds under root.
- A second run with an escaped path still compares equal and writes nothing.

### Security

- Nothing found. The escape closes the YAML-injection path that round 4 raised. The path still reaches awk through `ENVIRON`. No secrets or work references in the new commits.

### Compliance

- The acceptance-criteria table from round 1 still holds. `glow/`, `packages.conf` and `install.sh` have not changed since round 3.
- Round 1, 3 and 4 findings are all closed. The plan's Risks entry on `"` and `\` in a home path ("Not handled") is now out of date; the change handles it.
- No existing test was weakened, skipped or deleted. The failed-write test changes how it forces the failure, not what it asserts.
- Checks run: `glow_style_install_test.rb` (11 runs), `glow_package_test.rb` (4 runs) and `stow_package_roots_test.rb` (7 runs) pass. `shellcheck -x -S warning` and `rubocop` on the touched files are clean.
- Outside this branch: `test/isolated_git_test.rb` still fails on `origin/main` (`31fbbd43`) with the same 18 files from round 3. Neither glow test file is in the list. The fix belongs on its own branch (playbook rule 25).

## Round 6 — 2026-10-13T18:00Z — b7f054ee (codex)

No findings.
