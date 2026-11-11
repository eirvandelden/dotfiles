# Plan: `; space` opens the go-to picker in terminals too

From `intent.md` (2026-11-11). Status: accepted.

## Design

### Domain terms

- **Leader** (glossary): the `;` key that starts every herdr-app shortcut sequence. `; ;` types a `;` in a terminal. The glossary line stays true after this change.
- **`picker` mod**: herdr-app's shipped go-to mod, opened by `mod.open:picker`. It is a code name, not a glossary term. The glossary's "Switcher" entry avoids "picker" for the Rex panel only, so no conflict.
- **`global` section** and **`terminal` section** of `keys.json`: with a terminal focused, a `terminal` key wins over the same `global` key (the test helper `terminal_bindings` models this).
- No new terms.

### Diagrams

Not affected: no classes, flows or states change. One JSON key goes away.

### Signatures

`HerdrAppKeysTest` (`test/herdr_app_keys_test.rb`) checks the tracked `keys.json`. One test is renamed and rewritten:

```ruby
#: -> void
def test_space_opens_the_picker_in_a_terminal
  refute(section("terminal").key?("; space"), "a terminal override hides the picker")
  assert_equal("mod.open:picker", terminal_bindings["; space"])
end
```

It replaces `test_space_in_a_terminal_types_semicolon_space`. The private helpers do not change.

Not checked: the dotfiles test files carry inline `#:` comments, but the repository runs no `steep check`.

### Complexity

Not affected: a key lookup in a static JSON file. No new path, no I/O beyond the cached `keys` read.

### Invariants

- The `terminal` section holds no `; space` key. Enforced by the `refute` in `test_space_opens_the_picker_in_a_terminal`.
- With a terminal focused, `; space` resolves to `mod.open:picker`. Enforced by the `assert_equal` on `terminal_bindings` in the same test.
- `; ;` still resolves to `send:;` in a terminal. Enforced by the existing `test_semicolon_twice_types_one_semicolon`.
- Every other binding stays. Enforced by the existing `test_the_leader_map_binds_every_row`, `test_the_chords_repeat_their_leader_twins` and `test_the_cmd_defaults_stay` (`ORIGINAL_BINDINGS` never held `; space` in `terminal`, so it needs no edit).

### Alternatives

1. **Chosen: remove the override (minimal).** Delete `"; space": "send:; "` from `terminal`. Rewrite the one test so it refutes the key and asserts the resolved action.
2. **Rejected: remove the override and add `test_no_terminal_binding_shadows_a_leader_key`**, which fails when any `terminal` key equals a global `; ` key. It guards future regressions. Rejected because it pins a policy over every other leader binding, which the intent puts out of scope, and it would block a deliberate terminal-only leader override without a decision from Etienne.
3. **Rejected: keep a `terminal` entry and point it at the picker** (`"; space": "mod.open:picker"` in `terminal`). It duplicates the global binding for no gain, and a later edit of one copy drifts from the other.

## Design decisions

- The rewritten test both refutes the `terminal` key and asserts the resolved action. The refute alone would pass if the global binding vanished; the resolved assertion alone would pass with a redundant `terminal` copy (alternative 3).
- The test name changes, as the intent asks the test to describe the new behaviour.
- The class comment of `HerdrAppKeysTest` (lines 6–9) also changes: it describes the removed override. This is the same test file the intent names.
- No conflict with intent's `## Decisions`.

## Integration points

- herdr-app loads `~/.config/herdr-app/keys.json` (a stow link into the main checkout). One bad binding drops every binding, and herdr-app then writes `$HERDR_APP_HOME/keys.error`.
- The runbook `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md` documents the leader for Etienne and agents.

## Files that change

- `herdr-app/.config/herdr-app/keys.json` — remove line 180, `"; space": "send:; ",`, from `terminal`. Nothing else moves.
- `test/herdr_app_keys_test.rb` — replace `test_space_in_a_terminal_types_semicolon_space` with `test_space_opens_the_picker_in_a_terminal` (above). Rewrite the class comment on lines 6–9 to: "keys.json gives herdr-app a `;` leader: `; t` and its siblings, written once in the `global` section, which GPUI applies inside terminals too, so `; space` opens the `picker` mod there as well. The file must also work on Linux, where `cmd` is the Super key, and keep herdr-app's own defaults. The tests read the tracked file only; CI runs on Linux without herdr-app." Wrap under 120 characters, as now.
- `agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md` line 36 — replace "In a terminal, `; ;` types a `;` and `; space` types a semicolon and a space." with "In a terminal, `; ;` types a `;`, and `; space` opens the `picker` mod as it does elsewhere. To type `; `, type `; ;` and then a space. A `; ` typed in a shell or an agent prompt, as in `cd a; ls`, opens the picker." Keep the paragraph on one line.

## Order of work

1. Rewrite the test in `test/herdr_app_keys_test.rb` to `test_space_opens_the_picker_in_a_terminal`. Run `bin/test test/herdr_app_keys_test.rb`. Watch it fail on the `refute` for the `terminal` `; space` key.
2. Remove `"; space": "send:; ",` from the `terminal` section of `keys.json`. Run the test file again; it passes.
3. Rewrite the class comment in the test file.
4. Correct the runbook sentence on line 36.
5. Run `rubocop --force-exclusion test/herdr_app_keys_test.rb` (as lefthook's pre-commit job does), `markdownlint --config ~/.config/markdownlint/no-hardwrap.json --rules ~/.config/markdownlint/no-hardwrap.cjs` on the runbook, and `ruby -rjson -e 'JSON.parse(File.read("herdr-app/.config/herdr-app/keys.json"))'`.
6. Run `bin/test`. Note any known unrelated hang (`test/secrets_loader_test.rb` when the 1Password agent is down) rather than skipping it silently.
7. Sandbox check (see Test setup): load the new `keys.json` in a sandbox herdr-app window. Confirm `keys.error` is absent and `herdr-app status` shows no keys error. Then walk `; space`, `; ;` + space, and `; space` with the sidebar focused, and record what each did.
8. Re-read the diff: only the three files above change.

## Risks

- Every `; ` typed in a terminal now opens the picker: `cd a; ls` in zsh, and prose in a Claude or Codex prompt. Accepted in intent's `## Decisions`; the runbook says so.
- A typo in `keys.json` drops every binding. Step 5's JSON parse and step 7's sandbox load catch it.
- The sandbox can leak into Etienne's live cores. Follow the sandbox rules in Test setup; stop the sandbox by its own pid, never with `app.quit`.
- The test cannot prove GPUI's runtime precedence; it proves the file's content. The sandbox walk in step 7 covers runtime behaviour.

Out of scope: any other leader binding or chord, the `picker` mod itself, the `herdr-app-mod-imports` bugfix, stowing the package, and reloading Etienne's own herdr-app (Etienne does those).

## Proof

- In a terminal, `;` then space opens the go-to picker and the shell receives nothing → `test/herdr_app_keys_test.rb` `test_space_opens_the_picker_in_a_terminal`; runtime → check: sandbox window, focus a terminal, press `;` then space, see the picker open and no `; ` in the shell.
- In a terminal, `;`, `;`, then space shows `; ` in the shell → `test/herdr_app_keys_test.rb` `test_semicolon_twice_types_one_semicolon`; runtime → check: sandbox window, press `;`, `;`, space in a terminal, see `; ` at the prompt.
- In the sidebar, `; space` still opens the go-to picker → `test/herdr_app_keys_test.rb` `test_the_leader_map_binds_every_row` (global `; space` → `mod.open:picker`); runtime → check: sandbox window, focus the sidebar, press `;` then space, see the picker open.
- After the new `keys.json` loads, herdr-app reports no keys error → check: in the sandbox, `test ! -e "$HERDR_APP_HOME/keys.error"` and `herdr-app status` shows `errors: []`.
- The runbook no longer says `; space` types a semicolon and a space in a terminal → check: `grep -n 'space\` types a semicolon' agents/.agents/skills/dotfiles-maintenance/references/herdr-app-cores.md` prints nothing.
- Invariant: the `terminal` section holds no `; space` key, enforced by `keys.json` content → `test/herdr_app_keys_test.rb` `test_space_opens_the_picker_in_a_terminal`.
- Invariant: other bindings stay, enforced by `keys.json` content → `test/herdr_app_keys_test.rb` `test_the_leader_map_binds_every_row`, `test_the_chords_repeat_their_leader_twins`, `test_the_cmd_defaults_stay`.

Per changed file, the unit tests expected:

- `test/herdr_app_keys_test.rb`: `HerdrAppKeysTest#test_space_opens_the_picker_in_a_terminal` (new, replaces `test_space_in_a_terminal_types_semicolon_space`); every other test unchanged and green.
- `herdr-app/.config/herdr-app/keys.json`: configuration, no own test; covered by the test file above.
- `herdr-app-cores.md`: documentation, checked by the grep above and markdownlint.

Test setup: the tests read the tracked `keys.json` only; no fixtures. The sandbox follows the earlier `herdr-app-keys` delivery: a short `HERDR_APP_HOME` under `/private/tmp/claude-502/<short>` (socket path length), a fresh `HC_SESSION` name, the window started under `env -i HOME USER LANG SHELL PATH HC_SESSION HERDR_APP_HOME`, the worktree's `keys.json` copied into that home, the core status checked with `ps` (never `hc server status`, which starts a core), and the window stopped by its own pid.

---
Domain skills applied: software-design, glossary, diagrams (none needed), ruby-style (test method shape).

## Critique

### Round 1 (Codex gpt-6.1-sol, medium)

No findings.
