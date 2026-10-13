# Evidence: design-altitude-in-plans

Recorded 2026-10-13 on macOS, Ghostty, herdr, beautiful-mermaid 1.1.3, mermaid-cli (`mmdc`), timg.

## Step 13: real render

Four diagrams of one small domain (a board, its cards, a card's closure) went through `mermaid-show` as text and with `--image`.

### Text mode

All four print and exit 0. beautiful-mermaid drops method parameters (`add_card(title)` prints as `add_card`) and class multiplicities (`"1" --> "*"`). The state diagram stacks the two labels of the `Open ⇄ Closed` pair on one edge. The image keeps all of these.

Class diagram:

```text
┌─────────────────┐
│ Board           │
├─────────────────┤
│ +name: String   │
├─────────────────┤
│ +add_card: Card │
└─────────────────┘
         │
         │
         ▼
┌─────────────────┐
│ Card            │
├─────────────────┤
│ +title: String  │
├─────────────────┤
│ +close: Closure │
└─────────────────┘
         │
         │
         ▼
┌─────────────────┐
│ Closure         │
├─────────────────┤
│ +closer: Person │
└─────────────────┘
```

ER diagram:

```text
┌────────────────┐      ┌─────────────────┐
│ BOARD          │      │ CARD            │
├────────────────┤      ├─────────────────┤
│ PK int id      ││───○╟│ PK int id       │
│    string name │ has  │ FK int board_id │
└────────────────┘      │    string title │
                        └─────────────────┘
                                 │
     ───────────────────────────── closed by
     │                           │
    ○│                           │
┌─────────┐
│ CLOSURE │
└─────────┘
```

Sequence diagram:

```text
┌────────┐          ┌──────┐    ┌─────────┐
│ Person │          │ Card │    │ Closure │
└────┬───┘          └───┬──┘    └────┬────┘
     │                  │            │
     │  close(closer)   │            │
     │──────────────────▶            │
     │                  │            │
     │                  │  create    │
     │                  │────────────▶
     │                  │            │
     │                  │  closure   │
     │                  ◀╌╌╌╌╌╌╌╌╌╌╌╌│
     │                  │            │
     │     closure      │            │
     ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│            │
     │                  │            │
┌────┴───┐          ┌───┴──┐    ┌────┴────┐
│ Person │          │ Card │    │ Closure │
└────────┘          └──────┘    └─────────┘
```

State diagram:

```text
●────────●
│        │
●────────●
     │
     │
     │
     │
     ▼
╭────────╮
│        │
│  Open  │
│        │
╰────┬───╯
     ▲
   close
     │
  reopen
     ▼
╭────┴───╮
│        │
│ Closed │
│        │
╰────┬───╯
     │
     │
     │
     │
     ▼
╔════════╗
║        ║
╚════════╝
```

### Image mode

- `mmdc` renders all four to PNG with parameters, multiplicities and both state labels; checked by eye on a contact sheet of the four PNGs.
- In a herdr pane in Ghostty, `mermaid-show --image` exits 0 for all four. The pane's text buffer holds blank rows and no block characters, so timg drew with a graphics protocol rather than its block fallback.
- From an agent's Bash tool there is no terminal, so timg cannot read a size and exits non-zero. `--image` is for a human's pane; agents use text mode.

### Missing package

- Agent shells put Homebrew's `node` (pulled in by `mermaid-cli`) ahead of chnode's, so `npm root -g` points at Homebrew's global folder. There `mermaid-show` prints the one-line install hint and exits 1.
- Before commit "mermaid-show: give the install hint only when beautiful-mermaid is missing" the hint came with a Node stack trace, and any Node failure showed it. Now the helper exits 3 for a missing package only.

## Step 14: viewer check

The viewer runs its `markdown` command without a shell, so the candidate is a wrapper script: `mermaid-show --markdown | glow "$@"`. The viewer rewrites `-w` to the pane width. The check ran the wrapper with the plugin's bundled `assets/markdown-style.json` at `-w 40` and `-w 100` on a markdown file with prose, an ER fence and two headings.

- `-w 100`: headings keep ANSI palette colours (`35;1`, `34;1`), so the light/dark swap still works. The diagram prints intact.
- `-w 40`: glow wraps the text diagram's lines, and the boxes break apart.

Result: fails the plan's criterion "the diagram does not wrap". The viewer config stays untouched; Mermaid fences in the viewer stay source. Use `mermaid-show <file.md>` in a pane to read a plan's diagrams.
