# Review: herdr-app-look

## Round 1 — 2026-11-11 13:51 UTC — cdac6d68

Checks: `bin/test test/herdr_app_look_test.rb test/herdr_app_package_test.rb test/isolated_git_test.rb` green (56 runs, 0 skips; the drift test ran against the solunized origin/main export). `rubocop` on both test files: no offenses. `markdownlint` is not on PATH in this shell, so the `no-hardwrap` hook skips; the runbook and glossary were read by hand and hold one line per paragraph. `test/secrets_loader_test.rb` was not run (out of this branch).

Compliance (phase 4 acceptance criteria):

- The sidebar with the spaces list and the agents list sits on the right → `test_the_sidebar_is_the_last_child_of_the_root`, `test_the_sidebar_keeps_the_spaces_and_agents_lists`; sandbox shot recorded.
- Colors match Ghostty's solunized colors in light and dark → `test_the_herdr_app_themes_match_ghosttys_solunized_colors`, `test_the_themes_match_the_solunized_dist`, `test_the_root_theme_is_the_personal_pair`; sandbox pixel samples recorded (light #fffbf1 / #eeeae0, dark #012b38 / #0d3b4a).
- Blue on a personal space, orange on a work space → `test_a_work_space_asks_for_the_work_pair`, `test_a_personal_space_asks_for_the_personal_pair`, `test_the_core_look_block_names_the_root_pair_as_personal`, `test_settings_leave_the_accent_to_the_theme`; sandbox `.state/cores.json` and shots recorded, in light and dark.
- Panes look like cards on a frame → `test_panes_are_cards_on_the_frame`; sandbox shot recorded.
- Every test named in `plan.md` `## Proof` exists in `test/herdr_app_look_test.rb` or `test/herdr_app_package_test.rb`. No existing test was weakened, skipped or deleted: the package file list and the ignored-files list only grow.
- Invariant 3 (no tracked file changes on a switch): the sandbox `cores.json` stayed byte-identical to the package file.

Security: no work name (employer or product) in the diff; no secrets; no MonoLisa files.

Design: `themePick` and `CoreLook#render` match `### Signatures`; the private helpers in `core-look` carry `//:` signatures. No Law of Demeter violation (the chains read plain JSON data). No queries. New glossary terms are in place and sorted.

- [ ] Nit: the test uses `palette`, a word `GLOSSARY.md` lists under `Avoid:` (Switcher), in the local variable `palette` and in the flunk message "spaces-cores has no MARK palette"; the Ghostty `palette` key itself is a literal and fine, but the name and the message could say ANSI colors or MARK colors — `test/herdr_app_look_test.rb:259` → fixed (Tests: name the Ghostty slots without the avoided word)
- [ ] Nit: the runbook's copy loop uses a relative destination `herdr-app/.config/herdr-app/themes/` without saying to run it from the dotfiles repository root; run elsewhere, `cp` fails or writes to the wrong place — `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-look.md:11` → fixed (Say where to run the theme copy loop)

## Round 2 — 2026-11-11 13:53 UTC — 06c7bf6c

Checks: `bin/test test/herdr_app_look_test.rb test/herdr_app_package_test.rb test/isolated_git_test.rb` green (3 files, 0 failed, 0 skips; the drift test ran against the solunized origin/main export). `rubocop` on both test files: no offenses. `test/secrets_loader_test.rb` was not run (out of this branch). The round 1 sandbox evidence stands: e15cfeb4 and 06c7bf6c change only a test variable name, a failure message and one runbook sentence.

Round 1 fixes verified:

- e15cfeb4 renames the local `palette` to `slots` and the flunk message to "MARK colors" in `test/herdr_app_look_test.rb`. The remaining `"palette"` strings are the Ghostty config key, a literal.
- 06c7bf6c says to run the theme copy loop from the root of the dotfiles repository, in `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-look.md`.

Compliance: unchanged from round 1. Every acceptance criterion maps to a test in the diff, every `## Proof` test exists, and no existing test was weakened, skipped or deleted.

Security: no work name, no secrets, no MonoLisa files.

Design: no new public function; `themePick` and `CoreLook#render` match `### Signatures`. No Law of Demeter violation, no queries. The avoided words left in added lines are literals: the Ghostty `palette` key, the shipped `picker` mod's name and the `hc server stop` command.

Nothing found.
