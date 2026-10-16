# Plan: rails-ui action row and table width rules — native confirm revision

From `intent.md` (2026-10-16). Status: accepted.

## Context

Branch `rails-ui-action-row-and-tables` (PR #194, open) already rewrote the `rails-ui` interaction-design reference: the macOS save-sheet action row, where Delete lives, the table width rules, and a Codex link. The first plan for that work is in git history (commit `c9052274`). On 2026-10-16 Etienne changed one decision after delivery: a delete asks for the browser's native confirm through `data-turbo-confirm`, and the custom Cancel | Delete `<dialog>` goes. This plan covers that revision only. Everything else the branch delivered stays.

Since the branch was cut, `origin/main` moved (PR #208, agnostic-skills). Skills now live in `agents/.agents/skills/<name>/`. `claude/.claude/skills/<name>` is a relative link to that folder. `rails-ui` already has `agents/openai.yaml` on main, and `test/skill_parity_test.rb` has no `CLAUDE_ONLY` list any more. The branch must rebase onto `origin/main` before the revision, and its Codex-link work becomes redundant.

The change edits markdown and one Ruby test file. It does not run `stow` and it touches no app.

## Design decisions

- **Rebase first, keep main's layout.** Playbook rule 20 requires a rebase before the push. Main renamed `claude/.claude/skills/rails-ui/*` to `agents/.agents/skills/rails-ui/*`, and git's rename detection carries the branch's edits to `SKILL.md` and `interaction-design.md` across. A trial merge of the branch without its Codex-link files onto `origin/main` (`git merge-tree`) is clean and leaves only `SKILL.md`, `interaction-design.md`, the change folder and the new test in the diff. Two commits conflict:
  - `e66ef2c5` stops on a file/directory conflict. A trial apply (`git merge-tree --merge-base e66ef2c5^ origin/main e66ef2c5`) shows that its `SKILL.md` and `interaction-design.md` edits land in `agents/.agents/skills/rails-ui/` already. The conflict is the branch's new `claude/.claude/skills/rails-ui/agents/openai.yaml`, which keeps a directory where main has its link. Resolve: `git rm` that file, restore main's link with `git checkout origin/main -- claude/.claude/skills/rails-ui`, keep main's `agents/.agents/skills/rails-ui/agents/openai.yaml` unchanged, and check that both moved files carry the branch's edits before `git rebase --continue`.
  - The later commits that touch `claude/.claude/skills/rails-ui/` follow the same rename. After each one, `claude/.claude/skills/rails-ui` must still be a link (`test -L`), and no `~origin_main` or `~HEAD` path may remain.
  - `91bc0956` adds the symlink `agents/.agents/skills/rails-ui` and edits `CLAUDE_ONLY` in `test/skill_parity_test.rb`. Main already has the real folder and no `CLAUDE_ONLY`. Take main's side for both paths. The commit is then empty: `git rebase --skip` it.
  - Main's `short_description` stays: `Views, Hotwire, Stimulus, Turbo, CSS, forms, i18n and accessibility`. `test_codex_metadata_names_the_skill` only needs `display_name` `Rails UI` and a non-empty `short_description`, so it passes as is.
- **The test reads the source folder.** `SKILL_DIR` in `test/rails_ui_interaction_design_test.rb` moves from `claude/.claude/skills/rails-ui` to `agents/.agents/skills/rails-ui`, as main did for its other skill tests (`test: read skills from the agents package`). Reading through the Claude link also works, but the source path is what main's tests use.
- **The native confirm sits on the `Delete…` button.** Turbo reads `data-turbo-confirm` from the submitter first, then from the form: `getAttribute("data-turbo-confirm", this.submitter, this.formElement)` in `src/core/drive/form_submission`, checked on 2026-10-16 in `hotwired/turbo` main and in tag `v7.2.0`. On the button, it matches the acceptance criterion literally. The reference names no version fallback.
- **No nested form: the button names its form.** The custom dialog used to solve the nested-form problem: `button_to` renders a `<form>`, and HTML forbids one inside the edit `<form>`. Without the dialog, the delete form sits after the edit form, and the `Delete…` button in the edit form's action row points to it with the HTML `form` attribute. In Rails: `form_with(model: budget, method: :delete, id: dom_id(budget, :delete)) {}` after the edit form, and `button_tag t(".delete"), form: dom_id(budget, :delete), data: { turbo_confirm: t(".confirm", name: budget.name) }` in the row. `button_tag` passes unknown options through as HTML attributes, so `form:` becomes `form="delete_budget_1"`.
  - This keeps the Return rule true. A form's default button is its first submit button whose form owner is that form. The `Delete…` button's owner is the delete form, so `Save` stays the edit form's default.
  - The `### Edit pages and sheets` bullet "Every button left of it is a link or a `<button type="button">`" gains a third case: a button that submits another form through its `form` attribute.
  - Rejected: `button_to` placed outside the edit form and moved into the row with CSS. It breaks the flex row and the far-left rule.
  - Rejected: a `<button name="_method" value="delete" formaction="…">` inside the edit form. The edit form already sends `_method=patch`, and which value Rack keeps depends on field order.
- **The show-page exception keeps `button_to`.** A show page of a record with no editable fields has no edit form around the action row, so `button_to t(".delete"), record, method: :delete, data: { turbo_confirm: … }` works there. Its `Delete…` asks for the same native confirm. `button_to` puts `data:` on the button, which Turbo reads as the submitter.
- **`### Confirmation dialogs` keeps its heading and shrinks.** The heading stays, so `## Action rows` and the existing tests still point to it. It now says: confirm a delete with the browser's native confirm, through `data-turbo-confirm`; build no custom confirmation `<dialog>`; the message names the item and the result (`Delete the budget "Groceries"? This cannot be undone.`), never `Are you sure?`; the message comes from `t(...)` with the item's name; never make the user type the item's name; the browser sets the buttons, their order and the Return-key default, and the reference accepts that. One more bullet: the confirm runs only when Turbo handles the form, through Drive or a Turbo Frame, so the form never carries `data-turbo="false"`.
- **Removed mechanics.** These lines go from the reference: the dialog outside the edit form, Invoker Commands (`commandfor`, `command="show-modal"`, `command="close"`), the Stimulus fallback, `autofocus` on `Cancel`, `<form method="dialog">` (also its bullet under `## Action rows`, which this branch added for the dialog), the red `Delete` rightmost in a dialog, and "Never use `data-turbo-confirm`".
- **Exemptions, scoped by one phrase.** The `OK`/`Yes`/`No` ban and the Cancel default stay "for UI the app builds itself". `## Action rows` and `## Default button` each say that the native confirm is exempt, and point to `### Confirmation dialogs`. `## Default button` keeps "the red `Delete` is never the default"; on an edit page that stays true, because `Save` is the edit form's default button.
- **Shared pointer line.** `## Action rows` currently says a destructive button gets a fixed place in two layouts. It becomes: one layout, `### Edit pages and sheets`, plus the show-page exception under `### Where Delete lives`; the browser places the native confirm's buttons, see `### Confirmation dialogs`. The line still names both sections and still has no "far left", so `test_far_left_rule_is_scoped_to_edit_pages_and_save_sheets` holds.
- **`SKILL.md` stays.** Its pointer lists "confirmation dialogs" among the topics, which still describes `### Confirmation dialogs`. The intent allows an edit only where the pointer no longer fits, so none is needed.
- **`Delete…` keeps its ellipsis.** A confirmation still follows. The existing bullet stays word for word.

## Integration points

- Turbo (`data-turbo-confirm`, `FormSubmission`): read only, to state where the attribute goes.
- HTML form ownership (`form` attribute, default button): read only.
- `test/skill_parity_test.rb` and `agents/.agents/skills/rails-ui/agents/openai.yaml` on main: kept as main has them.
- CI: `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb`. No workflow edit.
- Open PR #194: the rebase rewrites the branch, so the push uses `--force-with-lease`. The PR body describes the custom dialog; updating it is the `deliver` stage's job, not this one's.

## Files that change

- `agents/.agents/skills/rails-ui/references/interaction-design.md` (after the rebase; `claude/.claude/skills/rails-ui/references/interaction-design.md` before it) — `## Action rows`, `### Edit pages and sheets`, `### Confirmation dialogs`, `### Where Delete lives` and `## Default button` as decided above. No other section changes.
- `test/rails_ui_interaction_design_test.rb` — `SKILL_DIR` path; two tests replaced, three extended, as listed under `## Proof`.
- Rebase only, no new content: `agents/.agents/skills/rails-ui/SKILL.md` keeps the branch's pointer line; `openai.yaml`, the symlink and `test/skill_parity_test.rb` end up as on main.

## Order of work

1. Rebase onto `origin/main` with the `sync` skill: `git fetch origin`, `git rebase origin/main`. Resolve `e66ef2c5`, the later `claude/` commits and `91bc0956` as in `## Design decisions`; skip `91bc0956` once it is empty. Then run `ruby -Itest test/rails_ui_interaction_design_test.rb` and `ruby -Itest test/skill_parity_test.rb`; both pass before any new work. Commit nothing new in this step.
2. Move `SKILL_DIR` to `agents/.agents/skills/rails-ui`. Run the file; it passes. Commit: `test: read rails-ui from the agents package`.
3. Write `test_delete_confirmation_uses_the_native_confirm` first, the walking skeleton. Run `ruby -Itest test/rails_ui_interaction_design_test.rb -n test_delete_confirmation_uses_the_native_confirm`. Watch it fail on the missing `data-turbo-confirm` in `### Confirmation dialogs`.
4. Replace `test_delete_opens_a_dialog_outside_the_edit_form` with `test_delete_button_submits_a_separate_form_through_its_form_attribute`. Add `test_native_confirm_is_exempt_from_the_ok_label_and_cancel_default_rules` and `test_no_custom_confirmation_dialog_mechanics_remain`. Delete `test_confirmation_dialog_puts_cancel_directly_left_of_red_delete_and_return_triggers_cancel`; the new tests replace what it checked. Extend the three tests listed under `## Proof`. Run the file; each new or changed test fails for its missing phrase, the others pass.
5. Rewrite `### Confirmation dialogs`. Run until the walking-skeleton test passes.
6. Rewrite the `Delete…` bullets of `### Edit pages and sheets` and the Return-rule bullet. Run until the form-attribute test passes.
7. Edit `## Action rows` (the exemption, the shared pointer line, the removed `<form method="dialog">` bullet), `## Default button` and the show-page bullet of `### Where Delete lives`. Run until the whole file passes.
8. Run the lint checks and the full suite from `## Proof`. Commit: `rails-ui: confirm a delete with the native confirm`.
9. Re-read `git diff origin/main...HEAD`. Every hunk belongs to the paths under `## Files that change` or the change folder. Push with `git push --force-with-lease`.

## Risks

- The rebase drops branch work by mistake. Guard: after step 1, `git diff origin/main...HEAD --stat` lists only `SKILL.md`, `interaction-design.md`, the change folder and the new test, and both focused test files pass.
- `button_tag` without `type:` is a submit button. That is correct here, because it submits the delete form through its `form` attribute. A reader can mistake it for a second submit button of the edit form. The Return-rule bullet says why it is not.
- A button with the `form` attribute but no matching `id` submits nothing, silently. The reference names `dom_id(record, :delete)` on both sides, so one helper makes both values.
- An app with `data-turbo="false"` on forms, or without Turbo, gets no confirm and deletes at once. The reference states that the confirm needs Turbo to handle the form, through Drive or a Turbo Frame.
- The browser's confirm shows `OK` and makes it the Return default in most browsers. Etienne accepted this on 2026-10-16. The reference says so, so a later review does not flag it again.
- A test that refutes `<dialog>` across the whole reference would also refute the sentence "build no custom confirmation `<dialog>`". The removed-mechanics test refutes only `commandfor`, `show-modal`, `command="close"`, `method="dialog"`, `autofocus` and `Stimulus`.
- `test/review_report_check_test.rb` fails locally under a global git hook (known, out of scope, noted in review round 15). Report it if it still fails; do not change it.

Out of scope: journal_administration, mvpa.css and appkit; a custom confirm through Turbo's `config.forms.confirm`; the PR body; `SKILL.md` content; `core-values.yml`; vendored skills.

## Proof

- An agent builds a budget edit form with red `Verwijderen…` far left, apart, and `Annuleren` then `Opslaan` on the right → `test/rails_ui_interaction_design_test.rb` `test_edit_page_puts_delete_far_left_and_cancel_then_save_on_the_right`
- An agent gives `Verwijderen…` a `data-turbo-confirm` message that names the budget and says the delete cannot be undone, and builds no custom `<dialog>` → `test/rails_ui_interaction_design_test.rb` `test_delete_confirmation_uses_the_native_confirm`, `test_delete_button_submits_a_separate_form_through_its_form_attribute`, `test_no_custom_confirmation_dialog_mechanics_remain`
- No rule forbids `data-turbo-confirm`, and no rule says a native confirm breaks by its `OK` label or its Return default → `test/rails_ui_interaction_design_test.rb` `test_native_confirm_is_exempt_from_the_ok_label_and_cancel_default_rules`
- No Delete in a transactions index row or on a transaction's show page → `test/rails_ui_interaction_design_test.rb` `test_delete_lives_only_on_the_edit_page`
- An account alias show page has a visible red `Verwijderen…`, outside any "Acties" menu, with the native confirm → `test/rails_ui_interaction_design_test.rb` `test_record_without_editable_fields_puts_delete_on_its_show_page_outside_menus`
- A Codex agent finds `rails-ui`, and the parity test passes with `rails-ui` not Claude-only → `test/skill_parity_test.rb` (main's version, whole file), `test/rails_ui_interaction_design_test.rb` `test_codex_metadata_names_the_skill`
- A ten-column table does not scroll sideways at desktop width and stacks with `Bedrag`, `Datum` and the other labels at phone width → `test/rails_ui_interaction_design_test.rb` `test_tables_never_exceed_the_content_area_and_stack_with_data_labels`, `test_stacked_tables_keep_headers_for_screen_readers_and_add_table_roles`
- No rule puts a third button left of `Cancel` on an edit page or Delete in a table row → `test/rails_ui_interaction_design_test.rb` `test_no_rule_puts_a_third_button_left_of_cancel_or_delete_in_a_row`
- The reference passes markdownlint → check: `markdownlint --config markdownlint/.config/markdownlint/config agents/.agents/skills/rails-ui/references/interaction-design.md` exits 0
- The reference is one line per paragraph → check: `markdownlint --config markdownlint/.config/markdownlint/no-hardwrap.json --rules markdownlint/.config/markdownlint/no-hardwrap.cjs agents/.agents/skills/rails-ui/references/interaction-design.md` exits 0
- The test passes RuboCop → check: `rubocop --force-exclusion test/rails_ui_interaction_design_test.rb` exits 0
- The full suite passes → check: `for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`

Per changed file, the unit tests expected, named as behaviour:

- `test/rails_ui_interaction_design_test.rb` (against `interaction-design.md`):
  - `test_delete_confirmation_uses_the_native_confirm` — new. `### Confirmation dialogs` names `data-turbo-confirm` and the native confirm; says no custom confirmation `<dialog>`; gives a message example with the item and `cannot be undone`; names `Are you sure?` as the prompt to avoid; names `t(`; refuses typing the item's name; says the browser sets the buttons and the Return default; names `data-turbo="false"` as what stops the confirm.
  - `test_delete_button_submits_a_separate_form_through_its_form_attribute` — replaces `test_delete_opens_a_dialog_outside_the_edit_form`. `### Edit pages and sheets` names nested forms, the `form` attribute, `dom_id(` with `:delete`, `button_tag` and `data-turbo-confirm` on the button; the Return-rule bullet names a button that submits another form.
  - `test_native_confirm_is_exempt_from_the_ok_label_and_cancel_default_rules` — new. `## Action rows` scopes the `OK`/`Yes`/`No` line to UI the app builds itself and exempts the native confirm; `## Default button` scopes the Cancel default the same way and exempts the native confirm; the whole reference refutes `/never[^.\n]*data-turbo-confirm/i` and the old sentence about `confirm()` showing `OK`.
  - `test_no_custom_confirmation_dialog_mechanics_remain` — new. The whole reference refutes `commandfor`, `show-modal`, `command="close"`, `method="dialog"`, `autofocus` and `Stimulus`.
  - `test_record_without_editable_fields_puts_delete_on_its_show_page_outside_menus` — extended. `### Where Delete lives` names `button_to` with `data-turbo-confirm` for the show-page case, and refutes "opens the confirmation dialog".
  - `test_default_button_is_save_on_edit_pages_and_cancel_in_destructive_confirmations` — extended. The Cancel default line carries "builds itself"; `Delete` is still never the default.
  - `test_existing_rules_survive` — changed. Drops the `<form method="dialog">` assertion on `## Action rows`, which line 38 of the test made; keeps the rest.
  - Unchanged and still passing: the edit-page, far-left scope, show-page pointer, Delete placement, third-button, both table tests, Codex metadata and `SKILL.md` pointer tests.

Test setup: none. The test reads the reference, `SKILL.md` and `openai.yaml` from `agents/.agents/skills/rails-ui` with `File.read`, and cuts the reference into sections with the existing private `section` helper.

---
Domain skills applied: rails-ui (action rows, forms, i18n in confirm messages), rails-testing (the repository's Minitest prose-test pattern), dotfiles-maintenance (agents package as skill source, no stow), sync (rebase onto `origin/main`).

## Critique

### Round 1 (codex exec -p terra)

- The rebase resolution is incomplete: `e66ef2c5` conflicts on the moved `SKILL.md` and `interaction-design.md`, and rename detection does not carry them → fixed (a trial apply of `e66ef2c5` onto `origin/main` shows both edits do land in `agents/.agents/skills/rails-ui/`; the only conflict is the branch's `claude/` `openai.yaml` against main's link; the plan now gives the exact resolution and a per-commit link check)
- The older-Turbo fallback is unsupported, since Turbo 7.3 already reads the submitter → fixed (checked: tag `v7.2.0` also reads the submitter first; the fallback and its test assertion are gone)
- The confirm is not limited to Turbo Drive, because Turbo Frames use the same `FormSubmission` → fixed (the reference and the risk now say Turbo handles the form through Drive or a Turbo Frame)
