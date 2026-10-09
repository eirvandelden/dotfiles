# Review: nvim-startup-errors

## Round 1 — 2026-10-09T09:04Z — caf8a68b

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` apply.

Checks run: `ruby -Itest test/neovim_avante_dependencies_test.rb` green (2 runs, 6 assertions). `rubocop` on the new test: no offenses. `stylua --check` on `ai.lua`: clean. Full suite: every file green except `test/review_report_check_test.rb`, which errors in `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point` (`git commit --quiet -m advance main failed`). The branch does not touch that test or the script it covers. The failure is local: the test commits on `main` in a temporary repository, and the global hooks in `~/.config/git/hooks` apply there. Not a finding for this branch.

Bugs pass: nothing found. The dependency entry in `ai.lua` matches the upstream README form, sits in avante's `dependencies` list, and lazy.nvim loads it before avante's `VeryLazy` load. The lockfile already pins avante at `4f49656`, the first commit that needs the mega plugins, so the lockfile and the spec agree.

Security pass: nothing found. The two new plugins are public GitHub repositories, unpinned by design; the intent approves them and keeps auto-update.

Compliance pass:

| Acceptance criterion | Proof in the diff |
| --- | --- |
| No error notification at startup; `<leader>un` lists no errors | Static proxy `test_avante_spec_declares_mega_cmdparse_with_mega_logging`; behaviour proof is the startup probe (Run A, Run B), which lives outside the branch |
| `:Avante` runs and `<leader>aa` opens the ask prompt | Static proxy `test_lockfile_pins_mega_cmdparse_and_mega_logging`; behaviour proof is the startup probe, outside the branch |

Both tests named in `plan.md`'s `## Proof` exist with the named names. Files changed match the plan's "Files that change" exactly; nothing unplanned. Commits follow the plan's order and messages. No existing test was weakened, skipped, or deleted.

- [x] Nit: Neither acceptance criterion has a committed test that exercises Neovim; both rest on the startup probe, by the plan's accepted design (no Neovim in CI). The probe outputs for steps 2, 5 and 6 are not on the branch, so this review cannot confirm a red run and two `RESULT pass` runs happened. The pull request body must carry them, as plan step 11 says. — `docs/changes/nvim-startup-errors/plan.md:57` → dismissed: no branch change needed; the coordinator puts the red run and the RESULT pass runs (Run A, Run B, and a re-run on the rebased branch) in the PR body
- [x] Nit: The pull request body must also name the uncommitted `lazy-lock.json` drift in the main checkout and leave keep or discard to Etienne, per the plan's Risks section. Nothing on the branch shows this yet. — `docs/changes/nvim-startup-errors/plan.md:198` → dismissed: no branch change needed; the coordinator names the main-checkout lockfile drift in the PR body and leaves keep or discard to Etienne

## Round 2 — 2026-10-09T09:12Z — c0803d05 (codex)

`codex review --base origin/main`: no findings. Codex checked that the dependency entry in `ai.lua` and the two lockfile entries agree, and ran `ruby -Itest test/neovim_avante_dependencies_test.rb` (2 runs, 6 assertions, green).
