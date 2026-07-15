# UI Layout and Interaction Detail

Based on Apple's macOS dialog guidance and the referenced dialog placement guide:
[Correct button placement in confirmation dialogs on Mac OS X](https://www.tempel.org/DialogButtonPlacement).

Rule precedence (highest to lowest):

- Safety rules override layout preferences.
- Dialog placement rules override generic page-level conventions.
- Control semantics (`<a>` vs `<button>`) follow whether the action navigates.

These rules apply to user-facing action patterns across the UI, including modal dialogs, sheets,
and page-level action groups:

- The rightmost button continues the action the user invoked.
- The button immediately to its left is `Cancel` and aborts the action.
- If a third dismissal button exists, place it left of `Cancel`.
- Pressing `Esc` must always trigger `Cancel`.
- Pressing `Return` must trigger the safest operation for the context:
  - If the action is destructive and there is no undo, default to `Cancel`.
  - Otherwise, default to the preferred continuation action.
- Label buttons with verbs (`Delete`, `Send`, `Proceed`, `Save`).
- Avoid `OK`, `Yes`, and `No` labels in confirmation dialogs.
- Back/Cancel control type:
  - Use `<a>` when Cancel/Back navigates to another page or URL.
  - Use `<button type="button">` when Cancel dismisses or resets in-place UI.

**Color semantics**

- Destructive actions (delete, remove, destroy) are red.
- Mutating actions (change, update, edit state) are orange.
- Primary constructive actions (save, publish, confirm) use the default primary style (primary
  color/filled).

**Forgiveness and reversibility**

Prefer reversible actions and design safety nets (undo, revert) where possible. Before an
irreversible destructive action, require explicit confirmation. Never silently destroy data.

**Default / primary action styling**

The primary constructive action (rightmost button) is styled as a filled/prominent button (blue by
convention). It is activated by the Return key, so it must always be the safest forward action for
that context. Never make a destructive action the default.

**Confirmation dialogs for destructive actions**

Use a modal confirmation when an action is irreversible. Name the confirm button with the action
verb (`Delete`, not `OK`). Describe what will happen (for example: `Delete this board? This cannot
be undone.`). Avoid vague prompts such as `Are you sure?`. In destructive confirmations, `Cancel`
is the default Return-key action.

**Progressive disclosure**

Show only the controls needed for the current task. Reveal advanced options, secondary actions,
and edge-case settings on demand.

**Minimize modes**

Prefer inline editing for single-field changes. When using the Rails show/edit split, keep the
edit view visually close to the show view so users feel they are in the same place. Always provide
a clear Cancel path back to show. Avoid nesting modes inside other modes.

**Immediate feedback**

Every user action should produce immediate visible feedback. Never leave users uncertain about
whether an action succeeded.
