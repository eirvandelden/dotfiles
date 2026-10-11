# UI Layout and Interaction Detail

Based on Apple's macOS dialog guidance and the referenced dialog placement guide: [Correct button placement in confirmation dialogs on Mac OS X](https://www.tempel.org/DialogButtonPlacement). Table rules follow two CSS-Tricks articles, linked under Responsive tables.

Rule precedence (highest to lowest):

- Safety rules override layout preferences.
- Dialog placement rules override generic page-level conventions.
- Control semantics (`<a>` vs `<button>`) follow whether the action navigates.

## Action rows

These rules apply to user-facing action patterns across the UI, including modal dialogs, sheets, and page-level action groups:

- The rightmost button continues the action the user invoked.
- The button immediately to its left is `Cancel` and aborts the action.
- Pressing `Esc` must always trigger `Cancel`.
- Pressing `Return` must trigger the safest operation for the context:
  - If the action is destructive and there is no undo, default to `Cancel`.
  - Otherwise, default to the preferred continuation action.
- Label buttons with verbs (`Delete`, `Send`, `Proceed`, `Save`).
- Avoid `OK`, `Yes`, and `No` labels in confirmation dialogs.
- Back/Cancel control type:
  - Use `<a>` when Cancel/Back navigates to another page or URL.
  - Use `<button type="button">` when Cancel dismisses or resets in-place UI.
  - Inside a `<form method="dialog">`, Cancel is a plain `<button>`. Its default submit closes the dialog without sending anything.
- A destructive button gets a fixed place in two layouts only: see Edit pages and sheets, and Confirmation dialogs. The one exception is the show page of a record with no editable fields: see Where Delete lives. Do not invent another.

### Edit pages and sheets

An edit page follows the macOS save sheet. The red `Delete…` button stands apart on the far left of the action row. `Cancel` and `Save` sit together on the right, with `Save` rightmost.

- `Save` is rightmost and is the default button: filled, primary style.
- A three-button save sheet keeps the shape: `Don't Save` stands apart on the far left, then `Cancel`, then `Save`.
- The ellipsis in `Delete…` says that a confirmation follows. Translate the label, keep the ellipsis.
- Build the row as a flex row. The destructive button takes `margin-inline-end: auto`, which pushes `Cancel` and `Save` to the right. Use `rem` sizes, and take mvpa.css styles first.
- `Delete…` is a `<button type="button">`, because it opens in-place UI. It opens a `<dialog>` that holds the `button_to … method: :delete` form.
- Put that `<dialog>` outside the edit `<form>`. HTML forbids nested forms.
- Open the dialog with Invoker Commands: `commandfor` on the button and `command="show-modal"`. Add a small Stimulus controller as the fallback for browsers without them.
- Never use `data-turbo-confirm` for this. The browser's `confirm()` shows an `OK` button, and it cannot colour Delete red.

### Confirmation dialogs

Use a modal confirmation when an action is irreversible. The red `Delete` is rightmost and `Cancel` sits directly left of it, as in macOS confirmation dialogs. The far-left rule of an edit page never applies inside a confirmation dialog.

- Name the confirm button with the action verb (`Delete`, not `OK`).
- Describe the item and the result (for example: `Delete this budget? This cannot be undone.`). Avoid vague prompts such as `Are you sure?`.
- `Cancel` carries `autofocus`, so `Return` triggers `Cancel`, never the red `Delete`.
- A click on `Cancel` closes the dialog. Use `<button type="button" commandfor="…" command="close">`. Or put a plain `<button>` (a submit button, not `type="button"`) in a `<form method="dialog">`, which works without Invoker Commands.
- `Esc` closes the dialog. The native `<dialog>` cancel event already does this.
- Never require the user to type the item's name to confirm a deletion — a confirmation dialog is enough.

### Where Delete lives

For a record with editable fields, Delete appears only on the edit page.

- Never in an index table row. A row links to the record.
- Never on that record's show page. A show page links to Edit.
- Never between other buttons. It stands apart, as described under Edit pages and sheets.
- Inline editing of a single field does not move Delete. The record keeps its edit page, and Delete stays there.
- A record with no editable fields (an account alias, a link between two records) gets no edit page only to hold Delete. Its `Delete…` sits on the show page as a visible red `Delete…` button, in the same spot as on an edit page: apart, on the far left of the bottom action row. It still opens the confirmation dialog.
- Never put that `Delete…` inside an "Actions" menu or any other pull-down.
- This exception does not let any other show page carry Delete.

## Color semantics

- Destructive actions (delete, remove, destroy) are red.
- Mutating actions (change, update, edit state) are orange.
- Primary constructive actions (save, publish, confirm) use the default primary style (primary color/filled).

## Default button

The default button is the safest forward action for the context. `Return` activates it.

- On an edit page the default is `Save`: rightmost and filled.
- In a destructive confirmation the default is `Cancel`. The red `Delete` is never the default.

## Tables

### Width

A table is never wider than the content area. The content area is the viewport width minus the sidebar. The page never scrolls sideways.

- A scroll wrapper (`overflow-x: auto`) is not the fix. The table is then still wider than the content area.
- Give the table `max-inline-size: 100%`.
- Text cells may break anywhere: `overflow-wrap: anywhere`, and no `white-space: nowrap`. A long ID or URL then cannot widen the table.
- When the table still needs more room, it stacks. See Responsive tables.

### Responsive tables

Below a breakpoint, `table`, `thead`, `tbody`, `tr`, `th` and `td` all get `display: block`. Each `tr` becomes a stacked block, and each `td` becomes a row of label and value. Changing only `tr` and `td` leaves anonymous table boxes and a half-stacked layout.

- Prefer a container query (`@container`). The width that matters is the content area, not the viewport.
- The layout CSS declares `container-type: inline-size` on the content area, which is often `main`. Table CSS never declares it.
- Without such a container, use a `@media` query in `rem` that adds the sidebar width.
- A container query cannot find the width where a table stops fitting. Pick the breakpoint per table: load the page with realistic data, narrow the window until the table no longer fits, and set the breakpoint above that width, in `rem`. A ten-column table may stack even at desktop width.
- Each `td` carries `data-label`. Below the breakpoint, `td::before { content: attr(data-label) / "" }` shows it. The `/ ""` part is explained under Screen readers. Above the breakpoint, the visible header row names the columns, so the label stays hidden.
- `attr(data-label)` renders the attribute as is. The attribute holds the translated text, not a key. The `<th>` and each `td` call the same `t(...)` key, so both show the same words. The i18n rule forbids a hardcoded string.
- Sources: [Responsive Data Tables](https://css-tricks.com/responsive-data-tables/) and [Making Tables Responsive With Minimal CSS](https://css-tricks.com/making-tables-responsive-with-minimal-css/).

### Screen readers

Keep native `<table>`, `<thead>`, `<th scope="col">` and `<td>` markup.

- Name the table with a `<caption>` (it may be visually hidden) or `aria-labelledby`.
- Below the breakpoint, hide the header row with a clip-based visually hidden rule. Never use `display: none`, because screen readers then lose the headers.
- Above the breakpoint, the header row stays visible. Sighted users need it on a table that does not stack.
- Mark the label as decorative: `td::before { content: attr(data-label) / "" }`. The empty alternative text keeps a screen reader from announcing the column name twice, once from the header and once from the label.
- A changed `display` on table elements drops table semantics in some browsers. Give the elements whose `display` changes explicit roles: `role="table"`, `role="rowgroup"`, `role="row"`, `role="columnheader"` and `role="cell"`.
- Check the stacked table once with VoiceOver or the browser's accessibility tree.
- Pattern: [WAI-ARIA table pattern](https://www.w3.org/WAI/ARIA/apg/patterns/table/).

## Forgiveness and reversibility

Prefer reversible actions and design safety nets (undo, revert) where possible. Before an irreversible destructive action, require explicit confirmation. Never silently destroy data.

## Progressive disclosure

Show only the controls needed for the current task. Reveal advanced options, secondary actions, and edge-case settings on demand.

## Minimize modes

Prefer inline editing for single-field changes. When using the Rails show/edit split, keep the edit view visually close to the show view so users feel they are in the same place. Always provide a clear Cancel path back to show. Avoid nesting modes inside other modes.

## Immediate feedback

Every user action should produce immediate visible feedback. Never leave users uncertain about whether an action succeeded.
