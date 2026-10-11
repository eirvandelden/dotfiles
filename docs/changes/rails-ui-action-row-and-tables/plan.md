# Plan: rails-ui action row and table width rules

From `intent.md` (2026-10-11). Status: accepted.

## Context

The `rails-ui` skill points agents to `claude/.claude/skills/rails-ui/references/interaction-design.md` for button placement and dialog rules. That reference places every action group the same way: continue rightmost, `Cancel` directly left of it, a third button left of `Cancel`. It says nothing about where Delete belongs and nothing about table width. This change rewrites the reference so an agent builds the layout Etienne chose on 2026-10-11, and adds a test that pins the rules. It also links the skill for Codex, which reads it through `agents/.agents/skills/`. The change edits markdown, adds one Ruby test file, adds one symlink and one YAML file, and edits the skill parity test. It does not run `stow` and it touches no app.

## Design decisions

- **One test file pins the prose.** The repository already tests first-party skill prose with Minitest (`test/hotwire_native_skill_test.rb`, `test/mobile_testing_exception_test.rb`). A new `test/rails_ui_interaction_design_test.rb` follows that pattern. It reads the reference, cuts it into sections by heading, and asserts each rule inside its own section. CI runs every `test/*_test.rb` file already (`.github/workflows/dotfiles-tests.yml`), so no workflow change is needed.
- **Real headings replace the bold pseudo-headings.** The current file fails the repository's markdownlint config (`markdownlint/.config/markdownlint/config`) with seven MD036 errors, one per `**Bold line**`. The rewrite uses `##` and `###` headings. That makes the file lint clean, and it gives the test stable section names.
- **Fixed heading outline.** The test depends on these exact headings, in this order:
  - `# UI Layout and Interaction Detail` — intro, both source links, rule precedence.
  - `## Action rows` — the rules every action group shares.
  - `### Edit pages and sheets` — the macOS save-sheet layout.
  - `### Confirmation dialogs` — the two-button destructive confirmation; absorbs today's "Confirmation dialogs for destructive actions" paragraph.
  - `### Where Delete lives` — Delete only on the edit page.
  - `## Color semantics`
  - `## Default button` — replaces "Default / primary action styling".
  - `## Tables` — with `### Width`, `### Responsive tables` and `### Screen readers`.
  - `## Forgiveness and reversibility`, `## Progressive disclosure`, `## Minimize modes`, `## Immediate feedback` — today's text, unchanged apart from the heading level.
- **Shared action-row rules.** `## Action rows` keeps: the rightmost button continues the action; `Cancel` sits directly left of it; `Esc` triggers `Cancel`; `Return` triggers the safest action; verb labels; no `OK`, `Yes` or `No`; the `<a>` versus `<button type="button">` rule. The old "third dismissal button goes left of `Cancel`" line goes. The far-left rule does not live here: it applies only to edit pages and save sheets, so `### Edit pages and sheets` owns it. `## Action rows` says so in one line, and points to `### Confirmation dialogs` for the destructive case, where the red `Delete` is rightmost.
- **Edit page layout.** `### Edit pages and sheets` states: the red `Delete…` button stands apart on the far left; `Cancel` and `Save` sit together on the right; `Save` is rightmost and is the default button. A three-button save sheet follows the same shape: `Don't Save` far left, `Cancel`, `Save`, as in the macOS save sheet. The ellipsis says that a confirmation follows. The section gives the CSS idea in one line: a flex row where the destructive button takes `margin-inline-end: auto`. Sizes stay in `rem`, and mvpa.css comes first, as `SKILL.md` already says.
- **Delete opens a dialog, outside the edit form.** `Delete…` is a `<button type="button">`, because it opens in-place UI. It opens a `<dialog>` that holds the `button_to … method: :delete` form. The dialog sits outside the edit `<form>`, because HTML forbids nested forms. The reference names Invoker Commands (`commandfor` with `command="show-modal"`) as the no-JS way to open it, and a small Stimulus controller as the fallback. It does not use `data-turbo-confirm`: the browser's `confirm()` shows `OK`, which the label rule forbids, and it cannot colour Delete red.
- **Confirmation dialog layout.** `### Confirmation dialogs` states: the red `Delete` is rightmost and `Cancel` sits directly left of it, as in macOS confirmation dialogs. The edit page's far-left rule never applies inside a confirmation dialog. `Cancel` has `autofocus`, so `Return` triggers it; `Esc` closes the dialog, which the native `<dialog>` cancel event already does. The prompt names the item and the result (`Delete this budget? This cannot be undone.`), never `Are you sure?`. No typing of the item's name. The existing rules stay word for word where they still hold.
- **Default button wording.** `## Default button` says the default button is the safest forward action. On an edit page that is `Save`, rightmost and filled. In a destructive confirmation it is `Cancel`, and the red `Delete` is never the default. Today's text says "the rightmost button is activated by Return", which contradicts the dialog rule; the rewrite removes that contradiction.
- **Delete placement.** `### Where Delete lives` states: for a record with editable fields, Delete appears only on the edit page. Never in an index table row, never on that record's show page, never between other buttons. An index row links to the record; a show page links to Edit.
- **Records with no editable fields.** Etienne decided this after round 1. A record with no editable fields (an account alias, a link between a transaction and a transfer) gets no edit page only to hold Delete. Its `Delete…` sits on the show page as a visible red button, never inside an "Acties" menu or any other pull-down. It takes the same spot as on an edit page: apart, on the far left of the bottom action row. It still opens the confirmation dialog. `### Where Delete lives` states this exception in one item, right after the main rule, so no other show page reads it as permission.
- **Table width.** `### Width` states: a table is never wider than the content area, which is the viewport width minus the sidebar. The page never scrolls sideways. A horizontal scroll wrapper (`overflow-x: auto`) is not the fix, because the table is then still wider than the content area. The table takes `max-inline-size: 100%`, and text cells may break anywhere (`overflow-wrap: anywhere`, no `white-space: nowrap`), so a long ID or URL cannot widen it. When the table still needs more room, it stacks.
- **Breakpoint on the content area.** `### Responsive tables` prefers a container query (`@container`) because the width that matters is the content area, not the viewport. The layout CSS declares `container-type: inline-size` on the content area; a table component never sets it on `main` itself, per the `SKILL.md` component rule. Without such a container, a `@media` query in `rem` that adds the sidebar width is the fallback. A container query cannot find the width where a table stops fitting by itself. The agent picks the breakpoint per table: it loads the page with realistic data, narrows the window until the table no longer fits, and sets the breakpoint above that width, in `rem`. A ten-column table may then stack even at desktop width rather than overflow.
- **Stacking technique.** Below the breakpoint each `tr` becomes a block, each `td` a row of label and value. Each `td` carries `data-label`, and `td::before { content: attr(data-label) }` shows it. `attr(data-label)` renders the attribute value as is, so the attribute holds the translated text, not a key. The `<th>` and each `td`'s `data-label` call the same `t(...)` key, so both show `Bedrag`; the i18n rule forbids a hardcoded string. Both CSS-Tricks articles are linked: [Responsive Data Tables](https://css-tricks.com/responsive-data-tables/) and [Making Tables Responsive With Minimal CSS](https://css-tricks.com/making-tables-responsive-with-minimal-css/).
- **Screen readers.** `### Screen readers` states: keep native `<table>`, `<thead>`, `<th scope="col">` and `<td>` markup. Give the table a name with a `<caption>` (it may be visually hidden) or `aria-labelledby`. Hide the header row visually with a clip-based visually-hidden rule, never `display: none`, so screen readers keep it. A changed `display` on table elements drops table semantics in some browsers, so the elements whose `display` changes get explicit roles: `role="table"`, `role="rowgroup"`, `role="row"`, `role="columnheader"` and `role="cell"`. Check the stacked table once with a screen reader (VoiceOver) or the browser's accessibility tree. The section links the [WAI-ARIA table pattern](https://www.w3.org/WAI/ARIA/apg/patterns/table/).
- **Codex link.** Etienne decided this after round 1. `agents/.agents/skills/rails-ui` becomes a relative symlink, `../../../claude/.claude/skills/rails-ui`, the same shape as the `hotwire-native` link. `claude/.claude/skills/rails-ui/agents/openai.yaml` gets an `interface` block with `display_name: "Rails UI"` and a `short_description`, like `hotwire-native`'s. It sets no `policy` key: `rails-ui` has no `disable-model-invocation`, so implicit invocation stays allowed, and `test_implicit_invocation_policy_matches_between_frontmatter_and_openai_yaml` expects exactly that. `rails-ui` is removed from `CLAUDE_ONLY` in `test/skill_parity_test.rb`. The implementer reads `SKILL.md` and all three references for Claude-only wording (a Claude tool name, `~/.claude/` paths) and reports any it finds as a finding instead of rewriting those files, because that is outside this change.
- **`SKILL.md` pointer.** The pointer paragraph under `## UI interaction and dialog rules` lists "button placement, color semantics, confirmation dialogs, progressive disclosure". It gets rewritten as one line that also names the edit-page action row, where Delete lives and table width. Only that paragraph changes. The rest of `SKILL.md` stays hard-wrapped, because rule 21 forbids unrelated hunks; rule 26 governs the prose this change writes. The `no-hardwrap` lint reports 18 existing errors on `SKILL.md` today and keeps reporting them. The `lefthook.yml` hook ends in `exit 0`, so it does not block the commit. A test, not that lint, proves the pointer paragraph is one line.

## Integration points

- `claude/.claude/skills/rails-ui/SKILL.md` links the reference by path; the path stays the same.
- Codex: `rails-ui` is in `CLAUDE_ONLY` in `test/skill_parity_test.rb` and has no link under `agents/.agents/skills/`. This change adds the link and the `openai.yaml`, and removes `rails-ui` from `CLAUDE_ONLY`. Codex picks the link up after the next `stow` run, which Etienne runs; this change does not run it.
- CI: `.github/workflows/dotfiles-tests.yml` runs `ruby -Itest` on every `test/*_test.rb`, so the new test runs there with no workflow edit.
- Lint: `lefthook.yml`'s `no-hardwrap` pre-commit hook runs on staged markdown. The repository's general markdownlint config lives at `markdownlint/.config/markdownlint/config`.

## Files that change

- `test/rails_ui_interaction_design_test.rb` — new. Pins every acceptance criterion against the reference's sections.
- `claude/.claude/skills/rails-ui/references/interaction-design.md` — rewritten to the outline above. One line per paragraph and list item.
- `claude/.claude/skills/rails-ui/SKILL.md` — the pointer paragraph under `## UI interaction and dialog rules` only.
- `test/skill_parity_test.rb` — `rails-ui` is removed from `CLAUDE_ONLY`.
- `agents/.agents/skills/rails-ui` — new relative symlink to the Claude skill folder.
- `claude/.claude/skills/rails-ui/agents/openai.yaml` — new, `interface` block only.

## Order of work

1. Write `test/rails_ui_interaction_design_test.rb` with `test_edit_page_puts_delete_far_left_and_cancel_then_save_on_the_right` first. Run `ruby -Itest test/rails_ui_interaction_design_test.rb`. Watch it fail, because `### Edit pages and sheets` does not exist.
2. Add the remaining tests from `## Proof`. Run the file; every new test fails for a missing section or a missing phrase, and the regression test for surviving rules fails only on the missing `## Action rows` section.
3. Rewrite `interaction-design.md`: the heading outline first, then `## Action rows` and `### Edit pages and sheets`. Run the file until the action-row tests pass.
4. Write `### Confirmation dialogs`, `### Where Delete lives`, `## Color semantics` and `## Default button`. Run until those tests pass.
5. Write `## Tables` with its three subsections. Run until those tests pass.
6. Move the four unchanged sections under `##` headings. Run until the whole file passes.
7. Rewrite the `SKILL.md` pointer paragraph as one line. Run until `test_skill_pointer_names_the_action_row_delete_and_table_rules` passes.
8. Remove `rails-ui` from `CLAUDE_ONLY`. Run `ruby -Itest test/skill_parity_test.rb` and watch `test_shared_skill_names_match_on_both_sides` fail. Add the symlink; watch `test_implicit_invocation_policy_matches_between_frontmatter_and_openai_yaml` fail for the missing `openai.yaml`. Add `test_codex_metadata_names_the_skill` and watch it fail, then add `openai.yaml`; run both files until they pass. Read the skill's files for Claude-only wording and note any in the report.
9. Run every lint check from `## Proof` (markdownlint, no-hardwrap, RuboCop, Yamllint) and the behaviour check. Run the full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`.
10. Re-read the diff. Every hunk must belong to the six paths above.

## Risks

- **Prose tests are brittle.** A rewording breaks a test without a rule change. Mitigation: assert key phrases inside a named section, with case-insensitive patterns, not whole sentences.
- **Prose tests do not prove agent behaviour.** A test proves the rule is written down, not that an agent follows it. Mitigation: the behaviour check below asks a fresh agent to build the budget edit form and the transactions table from the reference alone, and records the output as evidence.
- **Invoker Commands support.** `commandfor`/`command` is recent HTML. Older browsers ignore it, so the reference names a Stimulus fallback. Rejected: `data-turbo-confirm`, because `confirm()` shows `OK` and no red button.
- **Container queries need layout CSS.** A table component may not declare the container on `main`. Mitigation: the reference says the layout declares it, and gives the `@media` fallback.
- **Rejected: a horizontal scroll wrapper.** It hides the overflow but leaves the table wider than the content area, which the intent forbids.
- **Rejected: unwrapping all of `SKILL.md`.** It would add unrelated hunks. A separate change can do it.
- **Codex reads Claude-flavoured text.** The skill may mention Claude-only tools or paths. Mitigation: the implementer checks and reports them; a later change fixes the wording.
- **The link works only after `stow`.** The symlink lives in the repository; Codex sees it once Etienne restows. The parity test proves the repository side.

## Out of scope

- Any change to journal_administration, mvpa.css or appkit.
- Navigation hubs, Beheer and page anatomy.
- Vendored skills and their references.
- `core-values.yml`.
- Rewriting Claude-only wording inside the `rails-ui` skill for Codex.
- Running `stow`.
- Unwrapping the rest of `rails-ui/SKILL.md`.

## Proof

- An agent builds a budget edit form with red `Verwijderen…` far left, apart, and `Annuleren` then `Opslaan` together on the right → `test/rails_ui_interaction_design_test.rb` `test_edit_page_puts_delete_far_left_and_cancel_then_save_on_the_right`
- An agent builds a delete confirmation with `Annuleren` directly left of a red `Verwijderen`, and Return triggers `Annuleren` → `test/rails_ui_interaction_design_test.rb` `test_confirmation_dialog_puts_cancel_directly_left_of_red_delete_and_return_triggers_cancel`
- An agent adds no Delete button to transaction index rows or to the show page → `test/rails_ui_interaction_design_test.rb` `test_delete_lives_only_on_the_edit_page`
- An agent puts a visible red `Verwijderen…` on an account alias's show page, outside any "Acties" menu → `test/rails_ui_interaction_design_test.rb` `test_record_without_editable_fields_puts_delete_on_its_show_page_outside_menus`
- A Codex agent finds the skill, and the parity test passes with `rails-ui` no longer Claude-only → `test/skill_parity_test.rb` `test_shared_skill_names_match_on_both_sides`, `test_agents_skills_are_symlinks_into_the_claude_skill_folder`, `test_implicit_invocation_policy_matches_between_frontmatter_and_openai_yaml`; `test/rails_ui_interaction_design_test.rb` `test_codex_metadata_names_the_skill`
- The new Ruby test and changed parity test pass RuboCop → check: `rubocop --force-exclusion test/rails_ui_interaction_design_test.rb test/skill_parity_test.rb` exits 0
- The new YAML passes Yamllint → check: `yamllint claude/.claude/skills/rails-ui/agents/openai.yaml` exits 0
- An agent keeps a ten-column table from scrolling sideways at desktop width and stacks it with column names at phone width → `test/rails_ui_interaction_design_test.rb` `test_tables_never_exceed_the_content_area_and_stack_with_data_labels`
- A reader finds no rule that puts a third button left of `Cancel` on an edit page, or Delete in a table row → `test/rails_ui_interaction_design_test.rb` `test_no_rule_puts_a_third_button_left_of_cancel_or_delete_in_a_row`
- The markdown passes the repository's markdownlint config → check: `markdownlint --config markdownlint/.config/markdownlint/config claude/.claude/skills/rails-ui/references/interaction-design.md` exits 0
- The rewritten reference is one line per paragraph → check: `markdownlint --config markdownlint/.config/markdownlint/no-hardwrap.json --rules markdownlint/.config/markdownlint/no-hardwrap.cjs claude/.claude/skills/rails-ui/references/interaction-design.md` exits 0
- The `SKILL.md` pointer paragraph is one line → `test/rails_ui_interaction_design_test.rb` `test_skill_pointer_names_the_action_row_delete_and_table_rules`
- An agent follows the rules → check: run `claude -p --model sonnet` with a prompt that gives it only `interaction-design.md` and asks for (a) the ERB action row of a Dutch budget edit page, (b) the delete confirmation dialog, (c) a ten-column transactions index with its CSS, (d) the show page of an account alias, which has no editable fields. Record the output in the implement report and confirm: `Verwijderen…` first and apart, `Annuleren` then `Opslaan`; dialog `Annuleren` with `autofocus` directly left of a rightmost red `Verwijderen`; no Delete in rows; every `td` has a translated `data-label`; the table has a caption; no `overflow-x` wrapper; the alias show page has a visible red `Verwijderen…` and no "Acties" menu holding it.

Per changed file, the unit tests expected, named as behaviour:

- `test/rails_ui_interaction_design_test.rb` (against `interaction-design.md`):
  - `test_edit_page_puts_delete_far_left_and_cancel_then_save_on_the_right` — `### Edit pages and sheets` names the save sheet, `Delete…`, red, far left, apart, and `Save` rightmost as the default.
  - `test_confirmation_dialog_puts_cancel_directly_left_of_red_delete_and_return_triggers_cancel` — `### Confirmation dialogs` says `Delete` rightmost and red, `Cancel` directly left of it, `autofocus`, `Return` triggers `Cancel`, and that the far-left rule does not apply there.
  - `test_far_left_rule_is_scoped_to_edit_pages_and_save_sheets` — `## Action rows` (the shared part above its first `###`) has no far-left placement rule of its own.
  - `test_delete_opens_a_dialog_outside_the_edit_form` — `### Edit pages and sheets` or `### Confirmation dialogs` names `<dialog>`, `commandfor`, nested forms, and refuses `data-turbo-confirm`.
  - `test_delete_lives_only_on_the_edit_page` — `### Where Delete lives` scopes the rule to records with editable fields: only the edit page, never an index table row, never their show page. The same section holds the exception for records with no editable fields.
  - `test_record_without_editable_fields_puts_delete_on_its_show_page_outside_menus` — `### Where Delete lives` names records with no editable fields, the show page, a visible red `Delete…`, and refuses a menu.
  - `test_no_rule_puts_a_third_button_left_of_cancel_or_delete_in_a_row` — the whole file has no line matching a third button left of `Cancel`, and no line that allows Delete in a row.
  - `test_default_button_is_save_on_edit_pages_and_cancel_in_destructive_confirmations` — `## Default button` names both cases and says Delete is never the default.
  - `test_tables_never_exceed_the_content_area_and_stack_with_data_labels` — `### Width` names the content area, the sidebar and no sideways scroll, `max-inline-size: 100%` and `overflow-wrap: anywhere`, and refuses `overflow-x`; `### Responsive tables` names `data-label`, `attr(data-label)`, a translated value (`t(`), `@container`, a measured breakpoint, and both CSS-Tricks URLs.
  - `test_stacked_tables_keep_headers_for_screen_readers_and_add_table_roles` — `### Screen readers` names `scope="col"`, `<caption>` or `aria-labelledby`, visually hidden headers, refuses `display: none`, names `role="table"`, `role="row"`, `role="columnheader"`, `role="cell"`, and names a screen-reader check.
  - `test_existing_rules_survive` — `## Action rows` keeps `Esc` → `Cancel`, verb labels, no `OK`/`Yes`/`No`, `<a>` versus `<button type="button">`; `## Color semantics` keeps red, orange and primary; the file still links tempel.org.
- `test/rails_ui_interaction_design_test.rb` (against `agents/openai.yaml`):
  - `test_codex_metadata_names_the_skill` — `interface.display_name` is `Rails UI` and `interface.short_description` is a non-empty string.
- `test/rails_ui_interaction_design_test.rb` (against `SKILL.md`):
  - `test_skill_pointer_names_the_action_row_delete_and_table_rules` — the paragraph under `## UI interaction and dialog rules` is one line, and names `references/interaction-design.md`, Delete and tables.

Test setup: none. The test reads the two markdown files from the repository root with `File.read`. A private `section(text, heading)` helper returns the lines after a heading up to the next heading of the same or a higher level, and fails the test when the heading is missing.

---
Domain skills applied: rails-ui, rails-testing (Minitest prose-test pattern of this repository), dotfiles-maintenance (source files only, no stow; skill parity between Claude and Codex).

## Critique

### Round 1 (codex exec -p terra)

- The intent names Codex as a reader, but `rails-ui` is `CLAUDE_ONLY` with no `agents/.agents/skills/` link; record it as a decision → dismissed: linking the skill changes the accepted scope, which the intent's In scope list does not include; the report raises it as a Decision needed line for Etienne.
- The shared far-left rule in `## Action rows` contradicts the confirmation rule that puts `Cancel` directly left of a red `Delete` → fixed (the far-left rule moved into `### Edit pages and sheets` only; `### Confirmation dialogs` states `Delete` rightmost and excludes the far-left rule; new test `test_far_left_rule_is_scoped_to_edit_pages_and_save_sheets`)
- The `no-hardwrap` check on `SKILL.md` cannot pass, because the file has 18 existing hard-wrap errors → fixed (the check now covers the reference only; a test proves the pointer paragraph is one line; the plan records that the hook always exits 0 and does not block)
- A `data-label` that holds a translation key renders the key, not `Bedrag` → fixed (the attribute holds the translated text from the same translation call as the `<th>`)
- Removing `white-space: nowrap` does not stop long unbroken values from widening the table, and a container query cannot find the fitting width by itself → fixed (`max-inline-size: 100%` and `overflow-wrap: anywhere` added; the breakpoint is measured per table with realistic data)
  - `table-layout: fixed` is not mandated: it forces equal columns, which hurts a ten-column table more than it helps.
- The ARIA guidance over-applies roles and lacks a table name and a screen-reader check → fixed (native table markup with `th scope="col"` stays; a `<caption>` or `aria-labelledby` names the table; roles go only on elements whose `display` changes; a VoiceOver or accessibility-tree check is required; the WAI-ARIA table pattern is linked)

### Round 2 (codex exec -p terra)

- The plan says `rails-ui` "leaves" `CLAUDE_ONLY`, which reads less clearly than the intent's removal → fixed (both places now say it is removed from `CLAUDE_ONLY`)
- `test_delete_lives_only_on_the_edit_page` demands an unconditional "never on a show page", which contradicts the exception for records with no editable fields → fixed (the rule and its test are scoped to records with editable fields; the exception sits in the same section)
- The parity tests only require that `openai.yaml` exists and agrees on policy, not that it has `display_name` and `short_description` → fixed (new test `test_codex_metadata_names_the_skill`)
- Proof names only markdown lint, while the change adds Ruby and YAML that lefthook checks with RuboCop and Yamllint → fixed (both commands added to Proof and to step 9)
- Test commands lack fail-fast mode → dismissed: plain Minitest 6.0.6, which this repository runs through `ruby -Itest`, has no fail-fast flag; the full-suite loop already stops at the first failing file with `|| exit 1`, and `-i <name>` runs one test
