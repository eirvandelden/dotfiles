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
  - If the action is destructive and there is no undo, default to `Cancel`, in confirmation UI the app builds itself. The native confirm is exempt: the browser sets its default.
  - Otherwise, default to the preferred continuation action.
- Label buttons with verbs (`Delete`, `Send`, `Proceed`, `Save`).
- Avoid `OK`, `Yes`, and `No` labels in confirmation UI the app builds itself. The browser's native confirm is exempt: see Confirmation dialogs.
- Back/Cancel control type:
  - Use `<a>` when Cancel/Back navigates to another page or URL.
  - Use `<button type="button">` when Cancel dismisses or resets in-place UI.
- A destructive button gets one fixed place: see Edit pages and sheets. The one exception is the show page of a record with no editable fields: see Where Delete lives. The browser places the buttons of the native confirm: see Confirmation dialogs. Do not invent another.

### Edit pages and sheets

An edit page follows the macOS save sheet. The red `Delete…` button stands apart on the far left of the action row. `Cancel` and `Save` sit together on the right, with `Save` rightmost.

- `Save` is rightmost and is the default button: filled, primary style.
- A three-button save sheet keeps the shape: `Don't Save` stands apart on the far left, then `Cancel`, then `Save`. `Don't Save` is a link or a `<button type="button">`, never a submit button.
- Pressing Return in a text field presses the form's first submit button, so that button must be `Save`. Every button left of it is a link, a `<button type="button">`, or a button that submits another form through its `form` attribute, which is not a submit button of this form.
- The ellipsis in `Delete…` says that a confirmation follows. Translate the label, keep the ellipsis.
- Build the row as a flex row with `justify-content: flex-end`, so `Cancel` and `Save` sit on the right even on a page without `Delete…`, such as a new page that shares the form partial. The destructive button takes `margin-inline-end: auto`, which keeps it apart on the left. Use `rem` sizes, and take mvpa.css styles first.
- `Delete…` is a `button_tag` that submits a separate delete form through its `form` attribute. It stays in the row and out of the edit form's own fields.
- HTML forbids nested forms, so put the delete form after the edit `<form>`: `form_with(model: budget, method: :delete, id: dom_id(budget, :delete)) {}`. Point the button at it: `button_tag t(".delete"), form: dom_id(budget, :delete), data: { turbo_confirm: t(".confirm", name: budget.name) }`. Use one `dom_id(record, :delete)` call for both values, because a `form` value without a matching `id` submits nothing.
- The `data-turbo-confirm` message asks the browser for its native confirm: see Confirmation dialogs.

### Confirmation dialogs

Confirm a delete with the browser's native confirm, through `data-turbo-confirm` on the `Delete…` button. Build no custom confirmation `<dialog>`.

- Describe the item and the result (for example: `Delete the budget "Groceries"? This cannot be undone.`). Never write `Are you sure?`.
- The message comes from `t(...)` with the item's name. The i18n rule forbids a hardcoded string.
- Never require the user to type the item's name to confirm a deletion.
- The browser sets the buttons, their order and the `Return` default. The reference accepts them. The `OK` ban and the `Cancel` default do not apply to the native confirm.
- The confirm runs only when Turbo handles the form, through Drive or a Turbo Frame. A `data-turbo="false"` on the delete form, on the `Delete…` button or on any ancestor deletes at once, with no confirm, so never set it there. With Drive off, put `data-turbo="true"` on both the delete form and the `Delete…` button. Turbo checks the form and the button that submits it, and on an edit page that button sits outside the delete form. A `button_to` button sits inside its own form, so there the form alone is enough.

### Where Delete lives

For a record with editable fields, Delete appears only on the edit page.

- Never in an index table row. A row links to the record.
- Never on that record's show page. A show page links to Edit.
- Never between other buttons. It stands apart, as described under Edit pages and sheets.
- Inline editing of a single field does not move Delete. The record keeps its edit page, and Delete stays there.
- A record with editable fields where every field is edited inline still gets an edit page. That page holds the fields and Delete.
- A record with no editable fields (an account alias, a link between two records) gets no edit page only to hold Delete. Its show page holds a visible red `Delete…` button, in the same spot as on an edit page: apart, on the far left of the bottom action row. It uses `button_to` with `data-turbo-confirm` (`data: { turbo_confirm: … }`), because no edit form surrounds the row. `button_to` wraps the button in its own form, and that form is the flex item in the row. Give that form the far-left margin through `form_class:`, with a class that sets `margin-inline-end: auto`. It asks for the same native confirm.
- Never put that `Delete…` inside an "Actions" menu or any other pull-down.
- This exception does not let any other show page carry Delete.

## Color semantics

- Destructive actions (delete, remove, destroy) are red.
- Mutating actions (change, update, edit state) are orange.
- Primary constructive actions (save, publish, confirm) use the default primary style (primary color/filled).

## Default button

The default button is the safest action for the context. `Return` activates it. Usually that is the forward action.

- On an edit page the default is `Save`: rightmost and filled.
- In a destructive confirmation the app builds itself, the default is `Cancel`. The red `Delete` is never the default.
- The native confirm is exempt: the browser sets its default.

## Tables

### Width

A table is never wider than the content area. The content area is the viewport width minus the sidebar. The page never scrolls sideways.

- A scroll wrapper (`overflow-x: auto`) is not the fix. The table is then still wider than the content area.
- Give the table `max-inline-size: 100%`.
- Free-text cells (names, notes, IDs, URLs) may break anywhere: `overflow-wrap: anywhere`. A long ID or URL then cannot widen the table.
- Amounts and dates never break. Give only those cells `white-space: nowrap`, so a value stays whole.
- When the content area is a grid or flex item (for example `main` beside the sidebar in a grid layout), give it `min-inline-size: 0`. Without it, a cell that cannot wrap pushes the content area wider than the viewport.
- When the table still needs more room, it stacks. See Responsive tables.

### Responsive tables

Below a breakpoint, `table`, `thead`, `tbody`, `tr`, `th` and `td` all get `display: block`. Each `tr` becomes a stacked block, and each `td` becomes a row of label and value. Changing only `tr` and `td` leaves anonymous table boxes and a half-stacked layout.

- Prefer a container query (`@container`). The width that matters is the content area, not the viewport.
- The layout CSS declares `container-type: inline-size` on the content area, which is often `main`. Table CSS never declares it.
- Without such a container, use a `@media` query in `rem` that adds the sidebar width.
- A container query cannot find the width where a table stops fitting. Pick the breakpoint per table: load the page with realistic data, narrow the window until an amount or date no longer fits, or a text column gets too narrow to read, and set the breakpoint above that width, in `rem`. A ten-column table may stack even at desktop width.
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
