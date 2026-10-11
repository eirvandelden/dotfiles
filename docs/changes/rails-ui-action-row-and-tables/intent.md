# Intent: rails-ui action row and table width rules

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-11). Type: chore. Delivery: autonomous.

## Problem

The `rails-ui` skill's interaction-design reference tells agents where buttons go and what a table may do, and it gives answers Etienne does not want.

- It places every action group the same way: the continue button rightmost, `Cancel` directly left of it, and any third button left of `Cancel`. On an edit page, that leaves the red Delete button wherever an agent puts it. In journal_administration, Delete ended up in table rows, on show pages and between other buttons.
- It says nothing about where Delete belongs, so agents add it to index tables and show pages.
- It says nothing about table width. Wide tables push the page wider than the window and make it scroll sideways, most of all on a phone.

## Proposed outcome

An agent that follows the skill builds the layout Etienne chose in the journal_administration UI review on 2026-10-11:

- An edit page's action row follows the macOS save-sheet layout. The red destructive button (`Delete…`) stands apart on the far left. `Cancel` and `Save` sit together on the right, with `Save` rightmost as the default button.
- A delete confirmation dialog shows `Cancel` directly left of the red `Delete`. `Cancel` is the Return-key default there, as today.
- Delete appears only on the edit page, never in an index table row and never on a show page.
- A table is never wider than the content area: the viewport width minus the sidebar. When a table needs more room than that, it becomes a responsive table below a breakpoint. Each row stacks into a block, and each cell shows its column name before its value, using a `data-label` attribute and `td::before { content: attr(data-label) }`. The techniques come from [Responsive Data Tables](https://css-tricks.com/responsive-data-tables/) and [Making Tables Responsive With Minimal CSS](https://css-tricks.com/making-tables-responsive-with-minimal-css/).
- A stacked table keeps its header row available to screen readers, and adds ARIA table roles where a changed `display` drops the table semantics.
- A record with no editable fields has no edit page. Its `Delete…` sits on the show page as a visible red button, not inside an "Acties" menu.
- Codex agents read the `rails-ui` skill too.

## Affected users and systems

- Claude agents that load the `rails-ui` skill, in personal and work projects alike. Codex agents too, once this change links the skill into `agents/.agents/skills/`; today it is Claude-only.
- The file `claude/.claude/skills/rails-ui/references/interaction-design.md`, and the summary line in `claude/.claude/skills/rails-ui/SKILL.md` that points to it if that line needs to mention tables.
- Etienne, who reviews UI built with the skill.

## Constraints

- The rules apply to personal and work projects both.
- The reference stays based on Apple's macOS guidance. The new action-row rule must match the macOS save-sheet layout, and the dialog rule must keep matching macOS confirmation dialogs.
- Existing rules that still hold stay: Esc triggers Cancel, verb labels, no OK/Yes/No, the red/orange/primary colour semantics, the `<a>` versus `<button type="button">` rule, Cancel as the default in destructive confirmations.
- Markdown prose follows playbook rule 26 (one line per paragraph or list item) and the repository's markdownlint configuration.
- No permissions are needed under playbook rules 8, 9, 11, 12 or 13. The change edits markdown in the dotfiles source only. It does not run `stow`.

## In scope

- Rewrite the button-placement rules in `interaction-design.md` so edit pages and sheets use the macOS save-sheet layout, and confirmation dialogs keep `Cancel` directly left of the verb button.
- Add the rule that Delete lives only on the edit page.
- Add the table width rule and the responsive table technique, with links to the two CSS-Tricks articles and the accessibility caveats.
- Adjust `rails-ui/SKILL.md` only where its pointer to the reference no longer describes the content.
- Add the exception for records with no editable fields: Delete on the show page, visible, not in a menu.
- Link `rails-ui` for Codex: the `agents/.agents/skills/rails-ui` symlink, the skill's `agents/openai.yaml`, and its removal from `CLAUDE_ONLY` in `test/skill_parity_test.rb`.

## Out of scope

- Any change to journal_administration, mvpa.css or appkit. Those follow in their own changes.
- The other UI review decisions (navigation hubs, Beheer, page anatomy).
- Vendored skills and their references.
- `core-values.yml`, which does not mirror these rules.

## Acceptance criteria

- An agent that reads the skill and builds an edit form for a budget places `Verwijderen…` in red on the far left, apart from the other buttons, and `Annuleren` then `Opslaan` together on the right.
- An agent that builds a delete confirmation dialog places `Annuleren` directly left of a red `Verwijderen`, and Return triggers `Annuleren`.
- An agent that builds a transactions index adds no Delete button to the rows, and a transaction's show page has no Delete button.
- An agent that builds the show page of an account alias, which has no editable fields, puts a visible red `Verwijderen…` on that show page, not inside an "Acties" menu.
- A Codex agent finds the `rails-ui` skill, and the skill parity test passes with `rails-ui` no longer Claude-only.
- An agent that builds a table with ten columns keeps the page from scrolling sideways at desktop width, and at phone width shows each transaction as a stacked block with `Bedrag`, `Datum` and the other column names before their values.
- A reader of the reference finds no rule that still says the third button goes left of `Cancel` on an edit page, or that Delete may sit in a table row.

## Decisions after acceptance

On 2026-10-11 the plan stage raised two decisions. Etienne chose to link `rails-ui` for Codex in this change, and to put Delete on the show page, outside any menu, for records with no editable fields. The sections above include both.

## Open questions

None.
