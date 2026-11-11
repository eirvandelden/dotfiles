# Review: herdr-app-pipeline

## Round 1 — 2026-11-11 14:35 UTC — f7bfe33b

Checks: 116 test files green (all but `test/secrets_loader_test.rb`, which was not run: it reaches the real 1Password), herdr-app variables cleared. rubocop, shellcheck and markdownlint (no-hardwrap) are clean on every changed file. The branch contains `origin/main`. No `REVIEW.md` exists, so the default passes ran.

Compliance, phase 5 acceptance criteria:

- `implement handoff` opens the stage pane in herdr-app and its final line comes back → `test/herdr_app_worker_scripts_test.rb` `test_implement_handoff_opens_a_stage_pane_beside_the_coordinator_and_reports_back`, plus the sandbox live check (a).
- `review` opens its review pane in herdr-app → `test/herdr_app_worker_scripts_test.rb` `test_start_review_opens_a_review_pane_in_the_row`.
- `worktree-create` opens a pane rooted in the new worktree → `test/worktree_pane_herdr_app_test.rb` `test_worktree_create_opens_a_pane_rooted_in_the_new_worktree`, plus live check (c).
- The existing herdr TUI and Rex tests stay green → this run, and `test/test_runner_test.rb` `test_clears_herdr_app_variables_for_each_test_file`.

Every test that `plan.md`'s `## Proof` names exists. No existing test was weakened, skipped or deleted: the edits to existing tests only clear the herdr-app variables, add herdr-app cases, or extend the package file list.

- [ ] Important: `Window#space_of` finds the coordinator's space in `herdr-app ls` by `id` alone and ignores the space's `machine`. Invariant 1 depends on space ids being unique across machines, and nothing proves that. Terminal addresses repeat across cores, `probe.md` does not record the shape or uniqueness of space ids, and `test_open_never_anchors_on_a_terminal_of_another_space` uses two different ids (`sp0`, `sp1`). If ids repeat per core, a work-core coordinator can resolve to a personal space with the same id. `open` can then anchor in the wrong space, and `close_idle` and `close_at` can close panes of the other machine whose addresses match the row record. Probe the id shape with two cores, or narrow the match by machine too. Add a test with the same space id on two machines. — `herdr-app/.local/share/herdr-app-pane/panes.rb:51` → fixed (Refuse a space id that herdr-app lists on two machines)
- [ ] Nit: The plan's `### Signatures` signs only `Panes` and the two `Helpers` methods. The public methods of `Window`, `Terminal` and `RowRecord` are named in a prose departure note only, and `Terminal.real` is not named at all. All of them have inline RBS, so only the plan is behind. — `herdr-app/.local/share/herdr-app-pane/panes.rb:12` → fixed (docs: sign the herdr-app-pane window, terminal and row record in the plan)
- [ ] Nit: Glossary `Avoid:` word "binary" in a method name and in comments: `binary(tool)` and "name the binaries" in `command_line.rb`, and "stub binaries" / "herdr-app binary" in `test/herdr_app_harness.rb:6`, `:11`, `:209`, `:308` and `test/herdr_app_worker_scripts_test.rb:12`. The glossary uses "executable" for this. — `herdr-app/.local/share/herdr-app-pane/command_line.rb:28` → fixed (Say executable, not binary, in herdr-app-pane)
- [ ] Nit: Law of Demeter: `Panes` asks `Window` for a `Terminal` and then asks that `Terminal`: `@window.terminal(...).at?(target)` in `shown?`, and `.agent?` / `.at?` in `shell_at?` (`:255`). A `Window` method that answers the question for an address would keep `Panes` off `Terminal`. — `herdr-app/.local/share/herdr-app-pane/panes.rb:178` → fixed (Ask the window, not its terminals, where a terminal runs)
- [ ] Nit: The "reports back" half of the criterion 1 test proves only that the stub `hc` logged the `hc send` that the test itself ran. The send that matters comes from the worker, which follows the prompt, so this half adds no proof beyond the prompt assertions on lines 100–101. Drop the self-send, or say in a comment that the round trip rests on the live check. — `test/herdr_app_worker_scripts_test.rb:103` → fixed (Name test executables and drop the self-sent report check)

## Round 2 — 2026-11-11 19:43 UTC — 8156adc1

Checks: 116 test files green (all but `test/secrets_loader_test.rb`, not run), herdr-app variables cleared. rubocop, shellcheck and markdownlint (no-hardwrap) are clean on every changed file. The branch contains `origin/main` (46cd4b69). No `REVIEW.md` exists, so the default passes ran.

Round 1 closures, checked against the code:

- Space id on two machines: `Window#space_of` now selects every listed space with the id and raises `Refusal` when there is more than one (455ca427). `test_open_refuses_a_space_id_listed_on_two_machines` and `test_close_idle_closes_nothing_when_the_space_id_is_ambiguous` prove that no split and no close happens (96d92dcc). The real space ids in `~/.config/herdr-app/view.json` are `sp` plus 32 hex digits, so a collision across cores is not expected and the refusal is a guard, not a daily stop. Invariant 1 and its Proof line name the refusal. Holds.
- Signatures: `### Signatures` now signs `Terminal`, `Window` (with `shows?` and `shell_at?`), `RowRecord` and `HerdrAppPane::AGENTS` (8156adc1), and matches the inline RBS in `panes.rb` and `row_record.rb`. Holds.
- "binary": no added line of the branch outside the change folder uses it now; `CommandLine::EXECUTABLES` and `#executable` replace it (f8d7d58c), and the harness comments say "executables" (5a207b59). Holds.
- Law of Demeter: `Panes#shown?` and `Panes#shell_at?` ask `Window#shows?` and `Window#shell_at?`; `Window#terminal` is private, so `Panes` no longer reaches a `Terminal` (855e66fb). Holds.
- Self-sent report: the test no longer sends `hc send` itself; a comment says the round trip rests on the sandbox live check, which recorded `Handoff done:` reaching t1 (5a207b59). Holds.

Compliance, phase 5 acceptance criteria:

- `implement handoff` opens the stage pane in herdr-app and its final line comes back → `test/herdr_app_worker_scripts_test.rb` `test_implement_handoff_opens_a_stage_pane_beside_the_coordinator_and_reports_back` (pane, row record and the prompt's `hc send t10` line), plus live check (a).
- `review` opens its review pane in herdr-app → `test/herdr_app_worker_scripts_test.rb` `test_start_review_opens_a_review_pane_in_the_row`.
- `worktree-create` opens a pane rooted in the new worktree → `test/worktree_pane_herdr_app_test.rb` `test_worktree_create_opens_a_pane_rooted_in_the_new_worktree`, plus live check (c).
- The existing herdr TUI and Rex tests stay green → this run, and `test/test_runner_test.rb` `test_clears_herdr_app_variables_for_each_test_file`.

Every test that `plan.md`'s `## Proof` names exists. No existing test was weakened, skipped or deleted; the one assertion dropped since Round 1 was the self-sent report check that Round 1 asked to remove.

Nothing found.
