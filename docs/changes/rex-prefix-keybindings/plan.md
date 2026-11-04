# Plan: Rex prefix keybindings like herdr

From `intent.md` (2026-11-04). Status: accepted.

## Design

### Domain terms

- **Prefix** — the `ctrl+s` key that starts a key sequence, as in herdr. Rex writes a sequence as `ctrl+s>key`.
- **Stow package** — a top-level directory of the repository whose dot-prefixed entries link into `$HOME`. This change adds `rex`.

No new glossary term. `Avoid:` words from the glossary do not occur in the intent.

### Diagrams

Not affected: the change is one Lua file of `rex.bind` lines. It has no objects.

### Signatures

Not affected: the Lua config defines no Ruby classes or methods.

Not checked: this repository declines Steep for the Lua file.

### Complexity

Not affected: Rex reads the file once at start and on `rex config reload`. Each binding is one table entry.

### Invariants

- Every binding in `init.lua` loads without error. Enforced by `rex config check`, which exits non-zero on an error.
- The bindings that exist today keep their keys and actions. Enforced by comparing the `rex keymap` rows for them.

### Alternatives

- Keep the loose `~/.config/rex/init.lua` and only edit it. Rejected: it stays unversioned and is lost on a new machine.
- Generate `init.lua` from a template. Rejected: 30 static lines need no generator.
- Put the file in the existing `herdr` package. Rejected: the user is leaving herdr, and a package per tool is the repository's rule.

## Design decisions

- The package holds `rex/.config/rex/init.lua` and a `README.md` beside it, as the `herdr` package does. Stow links both; the README is inert in `~/.config/rex`.
- `|` cannot be written in a key sequence: `rex config check` reports `unknown key "|"`. The binding uses `ctrl+s>shift+\`, which is the same physical key chord and loads without error.
- `ctrl+s>1..9` go to tabs through `client.tab.goto` with `index = n`, written as a loop over 1..9 to avoid nine copies.
- `ctrl+s>shift+n` is `session.new`. `n` and `p` stay next and previous tab, as the intent lists.
- The new bindings, all after `ctrl+s>`:

  | Key | Action | Argument |
  |---|---|---|
  | `shift+\` | `pane.split.right` | — |
  | `v` | `pane.split.down` | — |
  | `w` | `pane.close` | — |
  | `z` | `pane.zoom` | — |
  | `=` | `pane.balance` | — |
  | `t` | `client.tab.new` | — |
  | `shift+t` | `client.tab.close` | — |
  | `n` | `client.tab.next` | — |
  | `p` | `client.tab.previous` | — |
  | `1`..`9` | `client.tab.goto` | `index = n` |
  | `shift+n` | `session.new` | — |
  | `r` | `client.tab.rename` | — |

- Nothing about herdr's workspace keys (`shift+1..9`) is bound: `session.select` needs a session id and a plain key cannot carry one. The intent already puts it out of scope.

## Integration points

- Rex reads `~/.config/rex/init.lua`. The stow link will point there.
- `packages.conf` lists stow packages in `STOW`. The installer runs `stow <name>` for each.
- `test/stow_package_roots_test.rb` checks that every declared package root holds only dot-prefixed entries. `rex/.config` and nothing else at the root passes.

## Files that change

- `rex/.config/rex/init.lua` — new: today's bindings plus the new prefix bindings.
- `rex/.config/rex/README.md` — new: the keys, and the switch-over steps for Etienne.
- `packages.conf` — add `rex` to `STOW`.

## Order of work

1. Write `init.lua` in the package: copy the current bindings unchanged, then add the new ones from the table above.
2. Run `REX_CONFIG=<package file> rex config check`. It must report no error.
3. Check every action name in the file against the Rex app's action list, as the first Proof check says.
4. Write the README, with the switch-over steps: move the loose file away with `trash`, `stow -t "$HOME" rex`, `rex config reload`.
5. Add `rex` to `STOW` in `packages.conf`.
6. Run `test/stow_package_roots_test.rb`, then `bin/test`.
7. Lint: `markdownlint` on the README.

## Risks

- A key name Rex rejects. Mitigation: `rex config check` before commit, as step 2 does.
- The existing `~/.config/rex/init.lua` is a real file. `stow rex` refuses to link over it. The README tells Etienne to move it away with `trash` first. Agents never run `stow` and never touch `~/.config/rex`.
- Dvorak: `shift+\` names a key by its label, not its position. If Rex matches the physical key, `|` sits on the same key on Dvorak, so the binding still works. Etienne confirms after stowing.
- `rex keymap` shows the config the running server loaded, and `REX_CONFIG` does not change that. Before stowing, the proof is the file itself plus the action check. After stowing and `rex config reload`, `rex keymap` shows the new bindings.
- Rex keys cannot be pressed by an agent. Etienne presses the keys once after stowing.

## Proof

Let `FILE` be `rex/.config/rex/init.lua` and `APP` the Rex app client id from `rex client ls`.

- `ctrl+s |` splits right and `ctrl+s v` splits down → check: `grep -F 'ctrl+s>shift+\\' FILE` shows `pane.split.right` and `grep -F 'ctrl+s>v' FILE` shows `pane.split.down`. The file holds a single backslash after `shift+`; `grep -F` matches it literally.
- `ctrl+s w` closes the focused pane → check: `grep -F 'ctrl+s>w' FILE` shows `pane.close`.
- `ctrl+s z` zooms the focused pane and a second press restores the layout → check: `grep -F 'ctrl+s>z' FILE` shows `pane.zoom`. `pane.zoom` toggles, per its title in `rex actions`.
- `ctrl+s 3` goes to the third tab → check: `grep -F 'client.tab.goto' FILE` shows the loop over 1..9 with `index`.
- The other new keys (`=`, `t`, `shift+t`, `n`, `p`, `shift+n`, `r`) match the table in `## Design decisions` → check: `grep -F` each `ctrl+s>key` in FILE and compare its action with the table.
- `ctrl+s ctrl+s` still sends a literal `ctrl+s` → check: `grep -F 'ctrl+s>ctrl+s' FILE` shows `pane.send_key` with `key = "ctrl+s"`.
- Every action name exists in the Rex app → check: `grep -oE '"(pane|client|session)\.[a-z_.]+"' FILE | tr -d '"' | sort -u` gives the names. Each must appear in `rex -C APP actions`.
- After stowing and `rex config reload`, `rex keymap` lists the new bindings and `~/.config/rex/init.lua` links into the repository → check: Etienne runs `stow -t "$HOME" rex`, `rex config reload`, `rex keymap` and `ls -l ~/.config/rex/init.lua`. Not run by an agent (playbook rule 12).
- Invariant: every binding loads, enforced by `rex config check` → check: `REX_CONFIG=FILE rex config check` exits 0.
- Invariant: existing bindings keep their keys and actions → check: `diff` of the old file's `rex.bind` lines against the new file's shows only added lines.
- `rex` is registered → check: `grep -qx '  rex' packages.conf`.
- Package root holds only dot-prefixed entries → `test/stow_package_roots_test.rb` (existing, over `packages.conf`).

Per changed file, the unit tests expected: none. The change is configuration and has no tests (playbook rule 3).

Test setup: none.

---
Domain skills applied: None.

## Critique

### Round 1 (codex terra)

- Keymap proof reads the wrong config: `REX_CONFIG` does not change what `rex keymap` shows → fixed (the Proof now greps the file and checks action names; `rex keymap` is used only after stowing and reload)
- The switch-over omits `rex config reload` → fixed (step 4 and the post-stow Proof check include `rex config reload`)
- Action proof does not validate client actions → fixed (new Proof check compares every action name with `rex -C APP actions`)
- Several required bindings lack an action map and proof → fixed (key and action table added; one Proof check covers the remaining keys)
- The stow-root test does not prove registration → fixed (new Proof check: `grep -qx '  rex' packages.conf`)
- The split-right grep pattern is over-escaped → fixed (Proof uses `grep -F` with a single literal backslash)
