# Plan: Switcher moves with the arrow keys, not j and k

From `intent.md` (2026-11-04). Status: accepted.

## Design

### Domain terms

- **Switcher**, **Switcher row** and **Snapshot** keep the meaning in `GLOSSARY.md`. No new term.

### Diagrams

Not affected: the change removes two key binds. The state diagram of the parent plan loses no state.

### Signatures

Not affected: no new public interface. `pick.sh esc` and `pick.sh slash` keep their contracts. They print shorter key lists: `rebind(w,b,d,a,/)` and `unbind(w,b,d,a,/)`.

Not checked: this dotfiles repository declined Steep and `rbs_rails`, and the change adds no Ruby production code.

### Complexity

Not affected: no new calls or processes.

### Invariants

- No bind claims `j`, `k` or the arrow keys. fzf's default arrow handling stays in effect. Enforced in `pick.sh`.

### Alternatives

- **Bind the arrows explicitly** (`up:up`, `down:down`). Rejected: fzf already does it, and an explicit bind could hide a later change of fzf's default.
- **Replace `j` and `k` with Dvorak-friendly letters.** Rejected: Etienne asked for the arrow keys.
- No architect run: the change holds no design choice, only a removal.

## Design decisions

- None left open by `intent.md`. No conflict with its `## Decisions`.

## Integration points

- fzf: default `up` and `down` actions, 0.74.5 installed. With `--disabled`, a typed letter still enters the query, it only stops filtering. So after the change `j` and `k` type into the list-mode query like every other unbound letter. They move nothing, which is what the acceptance criterion asks.

## Files that change

- `rex/.config/rex/switcher/pick.sh` — remove the `j` and `k` binds, and `j,k` from the `unbind` and `rebind` lists.
- `test/rex_switcher_scripts_test.rb` — update the two tests that name `j,k`, and add one test that no bind claims them.

## Order of work

1. Update `test_slash_enters_search_mode_and_remembers_the_filter_in_the_prompt` and `test_esc_in_search_mode_leaves_search_and_reloads_the_rows_of_the_same_filter` to expect `w,b,d,a,/`. Add `test_no_bind_claims_j_k_or_the_arrow_keys`. Run them. Watch them fail.
2. Remove the binds and the list entries in `pick.sh`. Run the tests. Watch them pass.
3. Check live in Rex, with the worktree's own scripts: `switcher.lua` starts `$HOME/.config/rex/switcher/pick.sh`, so run with a throwaway `HOME` whose `.config/rex` links to this worktree's `rex/.config/rex`. Open the switcher with `rex do`, then send `down`, `up`, `j` and `k` one by one with `rex send-key`, capturing the screen after each. Down and up move the selection marker. `j` and `k` leave it where it is, and only show in the query.
4. After `deliver`, retarget the PR with `gh pr edit <number> --base rex-agent-switcher`. Read the base back with `gh pr view <number> --json baseRefName` and expect `rex-agent-switcher`.

## Risks

- A future fzf release could change the default arrow handling. Unlikely; the intent accepts it.
- The switcher also sits in PR #252, so this change is stacked on it and must merge after it. Step 4 checks that the PR base is `rex-agent-switcher`.

## Proof

- The down arrow moves the selection down, the up arrow up → check: live run in Rex with the worktree scripts (step 3): send `down` then `up` with `rex send-key`, and capture the screen after each.
- `j` or `k` in list mode does not move the selection → `test/rex_switcher_scripts_test.rb` `test_no_bind_claims_j_k_or_the_arrow_keys`, and check: the same live run, sending `j` and `k` separately and capturing the selection marker after each.
- `/` unbinds only `w`, `b`, `d`, `a` and `/`; `esc` in search mode rebinds only those → `test/rex_switcher_scripts_test.rb` `test_slash_enters_search_mode_and_remembers_the_filter_in_the_prompt`, `test_esc_in_search_mode_leaves_search_and_reloads_the_rows_of_the_same_filter`
- Invariant: no bind claims `j`, `k` or the arrow keys, enforced by `pick.sh` → `test/rex_switcher_scripts_test.rb` `test_no_bind_claims_j_k_or_the_arrow_keys`

Per changed file, the unit tests expected, named as behaviour:
- `rex/.config/rex/switcher/pick.sh`: `slash unbinds only w, b, d, a and slash`, `esc rebinds only w, b, d, a and slash`, `no bind claims j, k or the arrow keys`

Test setup: the stub `fzf` and `rex` of `test/rex_switcher_scripts_test.rb`. No new setup.

---
Domain skills applied: None.

## Critique

### Round 1 (codex terra)

- With `--disabled` a typed letter still enters the query, so a no-bind test cannot prove that `j` and `k` do nothing → fixed (Integration points now says the letters type into the query like any unbound letter and move nothing, which is the criterion)
- The Rex check does not run the worktree's own `pick.sh` → fixed (step 3 runs with a throwaway HOME that links to the worktree package)
- Step 3 tested only down and `j` → fixed (step 3 and the Proof now send down, up, `j` and `k` separately)
- The plan has no step that proves the PR base → fixed (step 4 retargets the PR and reads the base back)
