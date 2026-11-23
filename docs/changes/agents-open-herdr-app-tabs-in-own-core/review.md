# Review: agents-open-herdr-app-tabs-in-own-core

## Round 1 — 2026-11-19T15:44Z — c393ba68

No REVIEW.md or REVIEW.local.md at the repository root: the reviewer's default passes ran (Bugs, Security, Compliance, Design). Checks: the six changed test files pass under rv Ruby 4.0.9 (machine 10, tabs 10, skill 6, panes 39, pane CLI 11, skill parity 19 runs; 0 failures). Full `bin/test`: 128 of 129 files pass. `test/herdr_app_look_test.rb` fails in `test_the_cloned_tabs_mod_differs_from_tabs_only_in_the_padding`: it compares the `tabs-cores` mod with the tabs mod that the installed Herdr.app ships, and that shipped mod changed. This branch touches no mod, so it is not a finding here; per playbook rule 25 it needs its own branch (re-clone the tabs mod). `rubocop` on the 12 touched Ruby files: no offenses. markdownlint did not run: this worktree has no `node_modules`, so `npx --no-install markdownlint-cli2` refused.

Compliance — acceptance criteria:

- Work-core tab opens in the work core while personal has focus → `test/herdr_app_pane_cli_test.rb` `test_tab_from_the_work_core_opens_in_the_work_space_while_a_personal_space_has_focus`
- Default-core tab opens in the default core while work has focus → `test/herdr_app_pane_cli_test.rb` `test_tab_from_the_default_core_opens_in_the_personal_space_while_a_work_space_has_focus`
- The skill never sends agents to the `herdr` CLI or the old app's browser command → `test/herdr_app_tabs_skill_test.rb` (three tests)
- `open` and `close` from a work terminal → `test/herdr_app_pane_cli_test.rb` `test_open_from_a_work_terminal_splits_beside_it_and_prints_an_hc_address`, `test_close_from_a_work_terminal_closes_its_own_pane`
- Default terminal unchanged → existing tests, plus `test_open_from_a_default_terminal_ignores_a_work_space_with_the_same_hc_address`
- `SKILLS-INDEX.md` lists the skill → `test_skills_index_lists_herdr_app_tabs`
- No existing test weakened, skipped or deleted; the two moved fixtures match Design decisions.

Security: nothing found. `tab.new` arguments go to herdr-app as JSON through `CommandLine`, with no shell.

- [ ] Important: two Window unit tests that `plan.md`'s Proof names for `panes.rb` are missing: "Window#space_of answers hc terminal addresses and herdr-app pane addresses" and "Window#split answers an hc terminal address". No test calls `Window#space_of` or `Window#split` directly; the address translation is only proven through `Panes` and `Tabs` — `herdr-app/.local/share/herdr-app-pane/panes.rb:53` → fixed (Test Window#space_of and Window#split in both cores)
- [ ] Important: the branch holds no evidence of plan step 1 (probe of the `tab.new` answer) or step 13 (live check from a scratch terminal of each core), which the Proof's "Live behaviour" line and §7a require. The harness header calls the `tab.new` shape "assumed" and points to "the plan's delivery account", which does not exist. If the live answer has no `terminal` key, `herdr-app-pane tab` exits 0 and prints nothing, so a wrong shape fails silently. Record the probe answer and the step 13 `herdr-app ls`/`status` evidence, and correct the header — `test/herdr_app_harness.rb:22` → fixed (Refuse in herdr-app-pane tab when tab.new names no terminal (live probe cited in the commit body; harness header corrected))
- [ ] Nit: `tab_arguments` passes `<cwd>` to `tab.new` as typed. A relative folder (`herdr-app-pane tab . --name x`) reaches herdr-app unresolved, so the tab roots wherever herdr-app resolves `.`. Expand it, or make the skill say "absolute folder" — `herdr-app/.local/bin/herdr-app-pane:48` → fixed (Expand the folder of herdr-app-pane tab to an absolute path)
- [ ] Nit: the skill uses "focused space", a word `GLOSSARY.md` lists under Avoid (Own space). The plan says "selected space" for the same thing — `agents/.agents/skills/herdr-app-tabs/SKILL.md:45` → fixed (Use the plan's wording in the herdr-app-tabs skill)
- [ ] Nit: the existing `HerdrAppCommandLineTest` comment ("CommandLine runs stub executables…") now sits above the new `HerdrAppPanesWorkCoreTest` comment, not above its own class — `test/herdr_app_panes_test.rb:421` → fixed (Move the CommandLine test comment above its own class)
- [ ] Nit: in `test_close_from_a_work_terminal_makes_the_same_calls_as_from_a_default_one`, the variable `default` holds the work-core calls, and `calls` then holds the default-core calls. Name it `work` — `test/herdr_app_panes_test.rb:465` → fixed (Name the work-core calls work in the close comparison test)
- [ ] Nit: `tab_call` is a new top-level method that `### Signatures` does not sign (it has an inline RBS signature) — `herdr-app/.local/bin/herdr-app-pane:60` → fixed (List tab_call in the plan's signatures)

2 more nits not listed: the `||` fallback in `add_work_agent` never runs, because `add_terminal` already stores the answer under `work/<address>`; and the skill line "Never read … `herdr-automate`" uses "read" for a command.

Round 1 closures: the unlisted `add_work_agent` nit → fixed (Drop the no-op terminal re-key from add_work_agent); the unlisted skill-wording nit → fixed (Use the plan's wording in the herdr-app-tabs skill).

## Round 2 — 2026-11-19T17:30Z — 1b0940ae

No REVIEW.md or REVIEW.local.md at the repository root: the default passes ran (Bugs, Security, Compliance, Design). Checks under rv Ruby 4.0.9: the seven changed and parity test files pass (13 runs, 0 failures). Full `bin/test`: 129 of 130 files pass. `test/rubocop_fallback_test.rb` fails because stderr carries "Ignoring bootsnap-1.18.6 / ffi-1.17.4 because its extensions are not built" from the local gem set; this branch touches no rubocop file, so it is environment, not a finding. `rubocop` on the 13 touched Ruby files: no offenses. markdownlint did not run: this worktree still has no `node_modules`. The local branch was rebased: it and `origin/agents-open-herdr-app-tabs-in-own-core` have diverged (15 vs 7 commits over main), so a plain push needs `--force-with-lease`.

All seven round 1 findings and both unlisted nits are closed by the named commits. The Proof list maps to tests that exist and pass, including the two new `Window` tests in `test/herdr_app_window_test.rb`. Security: nothing found.

- [ ] Important: the live evidence for plan step 13 is partial. The body of 90c454e0 records `tab` in both cores, `open --unlisted` in the work core and `close` of a default-core tab terminal. It records no `close` from a work terminal, so `pane.close` with a `work/` pane address — a named Risk and the acceptance criterion "`herdr-app-pane close` from it closes the right pane" — is proven only against the harness. It also records no `herdr-app status` check that `focus: false` left focus in the other core's space, the second named Risk. Run the rest of step 13 (work core: `close <printed terminal>`; both cores: `status` before and after) and record it — `docs/changes/agents-open-herdr-app-tabs-in-own-core/plan.md:274` → fixed (Record the round 2 live check in plan step 13)
- [ ] Nit: the `Window#split` comment still reads "Answers {"pane","terminal"} of the new pane."; `### Signatures` says "…, the terminal as an hc address", which is what the method now does — `herdr-app/.local/share/herdr-app-pane/panes.rb:102` → fixed (Say Window#split answers an hc terminal address)
- [ ] Nit: the "tab.new answered no terminal" refusal fires after herdr-app opened the tab, so the agent reports a failure while a tab exists. Say so in the message, such as "tab.new opened a tab but named no terminal" — `herdr-app/.local/bin/herdr-app-pane:61` → fixed (Say in the tab refusal that herdr-app opened the tab)
- [ ] Nit: plan step 1 still says that a `tab.new` answer without `terminal` makes the CLI print nothing; since 90c454e0 the CLI refuses with exit 1 — `docs/changes/agents-open-herdr-app-tabs-in-own-core/plan.md:262` → fixed (State in plan step 1 that the CLI refuses without a terminal)

## Round 3 — 2026-11-23T14:37Z — 7e030a40

No REVIEW.md or REVIEW.local.md at the repository root: the default passes ran (Bugs, Security, Compliance, Design). Checks under rv Ruby 4.0.9: the seven changed and parity test files pass (machine, tabs, tabs skill, panes 39 runs, pane CLI 13 runs, window, skill parity; 0 failures). Full `bin/test`: 134 of 134 files pass. `rubocop` on the 11 touched Ruby files: no offenses. The `no-hardwrap` markdownlint hook passes on the touched Markdown. The local branch is rebased on current main: it and `origin/agents-open-herdr-app-tabs-in-own-core` have diverged (ahead 64, behind 7).

All four round 2 findings are closed by the named commits. Step 13 now records `close` from a work terminal (`close t2q` from `t2p`) and a `herdr-app status` `focused_pane` check before and after both `tab` calls. The evidence states its own limit: for the work-core run, focus sat in another work space, not a personal one; the acceptance test `test_tab_from_the_work_core_opens_in_the_work_space_while_a_personal_space_has_focus` covers that case, and `Tabs#open` never reads focus. Security: nothing found.

No findings.
