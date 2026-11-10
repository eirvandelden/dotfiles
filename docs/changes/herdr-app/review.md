# Review: herdr-app

## Round 1 — 2026-11-10T14:24Z — 6f1830eb

No `REVIEW.md` in the repository: the default passes ran (Bugs, Security, Compliance, Design). `bin/test`: 116 of 117 files green; `test/secrets_loader_test.rb` fails because the real 1Password CLI times out on authorization, unrelated to this diff. The new tests pass (24 and 10 runs). `shellcheck` and `rubocop` are clean on the touched files.

Compliance map, phase 1 acceptance criteria:

- Links resolve, MonoLisa, tones after delivery → manual check, pending (delivery step).
- Font edit reaches the window within 10 s → missing: no measurement recorded.
- Settings dialog edit shows as a repository diff → missing: no live check recorded.
- `git status` clean after a session → `test_atomic_write_leftovers_are_ignored` covers the tmp files only; live check missing.
- Fresh Mac installs and links → `test_brew_macos_lists_the_herdr_app_cask`, `test_stow_lists_herdr_app`, `test_stow_shared_lists_herdr_app`, `test_the_stow_task_links_herdr_app_file_by_file`; see the first finding.
- Fresh Steam Deck installs, second run downloads nothing → `test_a_fresh_install_places_the_app_and_the_launcher_link`, `test_a_second_run_downloads_nothing`; links: see the first finding.
- Steam Deck tones from the same `settings.json` → `test_sound_paths_resolve_under_home`.

Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or deleted.

- [ ] Important: On a fresh clone, `50_stow_all.sh` dies before it reaches `herdr-app`: `STOW` lists `bundler`, but the repository has no `bundler/` folder (this Mac has an ignored local one), and `stow_configure` dies on a missing package. So the criteria "on a fresh Mac / Steam Deck the installer … links both files" do not hold. `test_the_stow_task_links_herdr_app_file_by_file` hides it by creating an empty folder for every `STOW` entry. The bug predates this branch; per playbook rule 25 it needs its own fix branch first, then a rebase of this one, and the test should then run against the real package folders — `packages.conf:301`, `test/herdr_app_package_test.rb:106` → fixed (Run the herdr-app stow test against tracked package folders only)
- [ ] Important: Plan step 7 (sandbox live checks) was not attempted and nothing is recorded in the change folder. The implement report (`.git/herdr/implement-w1-pr3.md`) says no second window was started, and leaves two decisions open. The plan allows deferral only when a second window cannot start. These checks decide the design: if a settings save replaces the link, the intent's whole-folder fallback applies and this package layout is wrong. The 10 s font criterion is also unmeasured — `docs/changes/herdr-app/plan.md:163` → fixed (docs: plan matches the herdr-app task and records the live checks)
- [ ] Nit: The implementation departs from `plan.md` without a matching plan edit: `herdr_app_cleanup` with the global `HERDR_APP_STAGING` replaces the planned trap; `herdr_app_home`, `herdr_app_launcher` and `herdr_app_desktop_entry` are not in `### Signatures`; `test_a_tarball_with_a_symlinked_executable_installs_nothing` is not in `## Proof`. The implement skill asks for the plan edit in the same commit — `install/tasks/26_install_herdr_app.sh:35` → fixed (docs: plan matches the herdr-app task and records the live checks)
- [ ] Nit: The desktop entry writes `Exec=` with an unquoted path. The Desktop Entry spec needs quotes when the path holds a space or other reserved character, for example an `XDG_DATA_HOME` with a space — `install/tasks/26_install_herdr_app.sh:103` → fixed (Quote the herdr-app desktop entry's Exec path)

## Round 2 — 2026-11-10T20:07Z — 7078983c

No `REVIEW.md` in the repository: the default passes ran (Bugs, Security, Compliance, Design). The branch is rebased onto `main` with PR #273. `bin/test`: 107 of 108 files green; `test/secrets_loader_test.rb` fails 5 tests because they reach the real 1Password CLI (`"token" isn't an item in the "Private" vault`). The branch does not touch that test or `secrets/`, so it is not a finding here. The new tests pass (25 and 10 runs), as do `test/stow_package_roots_test.rb` and `test/repo_agents_file_test.rb`. `shellcheck` and `rubocop` are clean on the touched files; the two SC2016 infos in `install/utils.sh` (lines 324, 483) predate the branch.

All four round 1 findings hold as fixed: the stow test now builds only tracked package folders, the live checks are recorded in plan step 7, the plan's signatures match the task, and the desktop entry quotes and escapes its `Exec` path.

Compliance map, phase 1 acceptance criteria:

- Links resolve, MonoLisa, tones after delivery → manual check, pending (plan step 9).
- Font edit reaches the window within 10 s → live check recorded (9.3 s); see the nit.
- Settings dialog edit shows as a repository diff → live check recorded (`app.zoom_in` wrote through the link).
- `git status` clean after a session → live check recorded; `test_atomic_write_leftovers_are_ignored`.
- Fresh Mac installs and links → `test_brew_macos_lists_the_herdr_app_cask`, `test_stow_lists_herdr_app`, `test_stow_shared_lists_herdr_app`, `test_the_stow_task_links_herdr_app_file_by_file`; fresh-clone stow run recorded; cask install stays a manual check.
- Fresh Steam Deck installs, second run downloads nothing → `test_a_fresh_install_places_the_app_and_the_launcher_link`, `test_a_second_run_downloads_nothing`.
- Steam Deck tones from the same `settings.json` → `test_sound_paths_resolve_under_home`; playback stays a manual check.

Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or deleted. No avoided glossary word appears in the diff (`picker` and `palette` occur only as herdr-app's own action names in `keys.json`).

- [ ] Nit: `plan.md` still states the font criterion as "within a few seconds" in `## Proof` and `## Design decisions`, but the amended `intent.md` says 10 seconds. The recorded check also measured a `font_size` change through `herdr-app status`, not a `font` change through `herdr-app shot` as the Proof line asks. One sample at 9.3 s against a 10 s poll leaves little margin, so the delivery check in step 9 should time the font change itself — `docs/changes/herdr-app/plan.md:200` → fixed (docs: herdr-app plan states the 10 second font criterion)

## Round 3 — 2026-11-10T21:20Z — c9fada57

No `REVIEW.md` in the repository: the default passes ran (Bugs, Security, Compliance, Design). The only commit since round 2 is `c9fada57`, a `plan.md` edit. `bin/test`: 107 of 108 files green; `test/secrets_loader_test.rb` fails the same 5 tests as in round 2, because they reach the real 1Password CLI (`"token" isn't an item in the "Private" vault`). The branch does not touch that test or `secrets/`. The new tests pass (25 and 10 runs), as do `test/stow_package_roots_test.rb` (12) and `test/repo_agents_file_test.rb` (9). `shellcheck` and `rubocop` are clean on the touched files; `no-hardwrap` is clean on `intent.md` and `plan.md`.

The round 2 nit holds as fixed: `## Proof`, `## Design decisions` and `## Risks` now state the 10 second criterion from `intent.md`, and the Proof line names the `font_size` sample (9.3 s) and asks step 9 to time the `font` change itself three times.

A fresh read of `install/tasks/26_install_herdr_app.sh` found no new defect: every `die` inside a command substitution still stops the task under `set -e`; a URL or sha256 with a stray space or newline fails the digest check instead of installing; the EXIT trap is the only one in the task, and no helper in `00_common.sh` sets its own.

Compliance map, phase 1 acceptance criteria: unchanged from round 2. The links, MonoLisa, tone playback and the timed `font` change stay manual checks for plan step 9; the cask install on a fresh Mac and the Steam Deck run stay manual checks for Etienne.

No findings.
