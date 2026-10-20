# Plan: Show the pipeline stage in the Claude statusline

From `intent.md` (2026-10-20). Status: accepted.

## Design decisions

- The stage comes from the files in one change folder, checked in this order. The first match wins:
  1. `review.md` is a readable regular file → `🕵️ sleuthing`.
  2. `plan.md` has an accepted status line → `🛠️ hammering`.
  3. `intent.md` has an accepted status line → `🧠 scheming`.
  4. Otherwise → `🤔 interviewing`. This covers a draft `intent.md` and a folder without `intent.md` yet.
- No change folder: `🎉 shipped` when the input has a PR URL, else no label.
- A `review.md` with every finding closed also shows `🕵️ sleuthing`. The intent names only "open findings"; it does not say what a closed review shows. A closed review is the short gap before `deliver` removes the folder, so the change is still in the review stage. This also keeps the script free of a copy of the review skill's finding grammar (`review_file.rb`). Every acceptance criterion still holds. The script still reads `review.md`, so an unreadable `review.md` gives no label, as the intent requires.
- "Accepted" means the first line that contains `Status:` matches `/Status: accepted(?: \(\d{4}-\d{2}-\d{2}\))?(?=\.|\s|\z)/`. The value is exactly `accepted` or `accepted (YYYY-MM-DD)`, the grammar `auto-accept` uses; `accepted-draft` does not match. This matches both artifact headers: `Author: … Status: accepted.` in `intent.md` and `From … Status: accepted.` in `plan.md`. It also matches the dated form `accepted (2026-10-20)` that `auto-accept` allows.
- The change folder is a direct subdirectory of `<workspace.current_dir>/docs/changes/`, as the intent says. The script does not walk up to the repository root and does not call git. A session in a subdirectory of the repository shows no folder.
- Several change folders: no label. The script cannot tell which folder belongs to the current branch without git, and a directory's modification time does not follow edits to the files inside it. A worktree normally has one folder.
- No `workspace.current_dir` in the input, or a value that is not a string: no label at all, also not `🎉 shipped`. The script cannot see the change folder, so it does not claim a stage. This keeps every existing test green, because those inputs have no `workspace`.
- Input JSON that parses to something other than an object (for example `[]`) renders an empty line. Today `render("[]")` raises `TypeError`; the intent requires the statusline never to raise.
- Errors: a `SystemCallError` (for example `EISDIR`, `EACCES`) while the script reads the folder gives no label. The rest of the line (last reply, PR URL) still shows. A missing file is not an error; it is a fact the stage order above uses.
- Shape: a small `ChangeFolder` class in `statusline-command.rb` owns the folder and answers its stage label (Tell, Don't Ask). `StatuslineCommand.stage_label(current_dir, pr_url)` picks the folder, falls back to shipped, and rescues. The class stays in the same file: the script is one symlinked file, and a second file would add a load path that can raise `LoadError` at start-up.
- Output: the label is the first segment, joined with the existing `" | "` separator, for example `🛠️ hammering | Last reply: 09:30 | https://…/pull/130`.

## Integration points

- Claude Code statusline input JSON: `workspace.current_dir` (new read), `pr.url` and `transcript_path` (already read). The command is wired in `claude/.claude/settings.json` (`"command": "~/.claude/statusline-command.rb"`); that wiring does not change.
- The artifact formats of the `intent`, `plan` and `review` skills: the status line in `intent.md` and `plan.md`, and the existence of `review.md`. The script only reads them.
- CI: `.github/workflows/statusline-command-test.yml` already runs `ruby claude/.claude/test/statusline_command_test.rb` on changes to both files. It does not change.

## Files that change

- `claude/.claude/test/statusline_command_test.rb` — new tests for every stage, the no-label cases, the order of segments and the error case. A helper writes a change folder under `@tmpdir`.
- `claude/.claude/statusline-command.rb` — add the `ChangeFolder` class and `StatuslineCommand.stage_label`; `render` puts the label first.

Nothing else changes. Out of scope: colours or ANSI tinting, the `intent`/`plan`/`implement`/`review`/`deliver` skills, `settings.json`, the CI workflow, gh-dash, the 1Password setting, and a stage for repositories without change folders.

## Order of work

1. Write the acceptance test `test_shows_hammering_for_an_accepted_plan`. Run `ruby claude/.claude/test/statusline_command_test.rb -n test_shows_hammering_for_an_accepted_plan`. Watch it fail on the missing label.
2. Add `ChangeFolder` with the accepted-plan rule and `stage_label`, and put the label first in `render`. Run the test until it is green.
3. Add, one at a time, red then green: interviewing (draft intent), interviewing (no intent yet), scheming (accepted intent, draft plan), scheming (accepted intent, no plan), sleuthing (open findings), sleuthing (closed review).
4. Add, red then green: shipped (no folder, PR URL), no label (no folder, no PR URL), no label (empty `docs/changes/`), no label (no `workspace.current_dir`).
5. Add the order test: label before "Last reply" and before the PR URL.
6. Add the error tests: `intent.md` is a directory, and `review.md` is a directory. Each read raises `EISDIR`; the line shows no label and keeps the PR URL. Add the several-folders test (no label), the `accepted-draft` test (not accepted), the JSON-array test (empty line) and the non-string `current_dir` test (no label).
7. Refactor: keep each method at about five lines and the file under about 100 lines. Run the full test file.
8. Run `rubocop claude/.claude/statusline-command.rb claude/.claude/test/statusline_command_test.rb` (with `GIT_DIR` unset, as `lefthook.yml` does). Fix every offence in the code; no disable comments, no config edits.
9. Verify by hand. From the worktree root, pipe a payload into the real script: `echo '{"workspace":{"current_dir":"'"$PWD"'"},"pr":{"url":"https://example.invalid/pull/1"}}' | claude/.claude/statusline-command.rb`. This worktree has an accepted `plan.md`, so expect `🛠️ hammering | https://example.invalid/pull/1`. Repeat with `current_dir` set to a directory without `docs/changes` and expect `🎉 shipped | https://example.invalid/pull/1`. Time one run with `time` and record that it stays well under 100 ms of script work.

## Risks

- A change to the artifact header format (for example `Status:` moving or being renamed) silently drops the stage back to interviewing or scheming. The tests pin the current headers; a format change in the skills must update the statusline too.
- `🛠️` and `🕵️` carry a variation selector (U+FE0F). Some terminals render them one column wide and misalign the rest of the line. Accepted: the intent fixes these emoji.
- A main checkout with several change folders shows no stage. Accepted: stage work happens in one worktree per change.
- Rejected: requiring `agents/.agents/skills/review/scripts/review_file.rb` to tell open from closed findings. It couples the statusline to another stow package, can raise `LoadError` before the script runs, and the CI workflow does not watch that file.
- Rejected: finding the repository root with `git rev-parse`. It adds a subprocess to every statusline refresh, and the intent names `workspace.current_dir`.

## Proof

- A change folder with a draft `intent.md` shows "🤔 interviewing" → `claude/.claude/test/statusline_command_test.rb` `test_shows_interviewing_for_a_draft_intent`
- An accepted `intent.md` with no accepted `plan.md` shows "🧠 scheming" → `claude/.claude/test/statusline_command_test.rb` `test_shows_scheming_for_an_accepted_intent_with_a_draft_plan`
- An accepted `plan.md` shows "🛠️ hammering" → `claude/.claude/test/statusline_command_test.rb` `test_shows_hammering_for_an_accepted_plan`
- A `review.md` with open findings shows "🕵️ sleuthing" → `claude/.claude/test/statusline_command_test.rb` `test_shows_sleuthing_for_a_review_with_open_findings`
- No change folder and a PR URL shows "🎉 shipped" → `claude/.claude/test/statusline_command_test.rb` `test_shows_shipped_when_there_is_no_change_folder_but_a_pr_url`
- No change folder and no PR URL shows no label → `claude/.claude/test/statusline_command_test.rb` `test_shows_no_label_when_there_is_no_change_folder_and_no_pr_url`
- The label comes before "Last reply" in the output → `claude/.claude/test/statusline_command_test.rb` `test_puts_the_label_before_the_last_reply_and_the_pr_url`

Per changed file, the unit tests expected, named as behaviour:
- `claude/.claude/statusline-command.rb` (`ChangeFolder` and `StatuslineCommand.stage_label`, tested through `render`): `test_shows_interviewing_when_the_folder_has_no_intent_yet`, `test_shows_scheming_for_an_accepted_intent_without_a_plan`, `test_shows_sleuthing_for_a_review_with_every_finding_closed`, `test_shows_no_label_when_docs_changes_is_empty`, `test_shows_no_label_without_a_current_dir`, `test_shows_no_label_but_keeps_the_pr_url_when_a_change_file_is_unreadable`, `test_shows_no_label_when_the_review_is_unreadable`, `test_shows_no_label_when_there_are_several_change_folders`, `test_does_not_treat_accepted_draft_as_accepted`, `test_shows_no_label_when_current_dir_is_not_a_string`, `test_is_blank_instead_of_raising_when_the_input_is_a_json_array`. The twelve existing tests stay green unchanged.

Test setup: Minitest, as today. A helper `change_folder(slug = "some-change", **files)` creates `@tmpdir/docs/changes/<slug>/` and writes each given file (`intent:`, `plan:`, `review:`) with a one-line header such as `Author: A. Status: accepted.` or `From \`intent.md\` (2026-01-15). Status: draft.`. Inputs set `workspace: { current_dir: @tmpdir }`. The unreadable cases make `intent.md` or `review.md` a directory, so they do not depend on file permissions or the user running the test. No mocks; the file system under `@tmpdir` is real.

---
Domain skills applied: ruby-style, ruby, object-oriented-design, sandi-metz-rules, dotfiles-maintenance.

## Critique

### Round 1 (codex exec -p terra)

- `review.md` existence is not enough: an unreadable `review.md` would still show sleuthing; read it and use the open-finding grammar → fixed (the script reads review.md as a regular file and a read error gives no label, with a test)
  - The open-finding grammar part stays out: a closed review still shows sleuthing, as recorded under Design decisions, and copying the review skill's grammar couples the two.
- `/Status: accepted\b/` accepts `accepted-draft`; use the anchored grammar of `auto-accept` → fixed (the status match allows only accepted or accepted with a date, with a test for accepted-draft)
- Picking the newest folder by modification time can show another change's stage → fixed (several change folders give no label, with a test)
- The script can still raise: `render("[]")` raises `TypeError` and the rescue covers only file system errors → fixed (non-object JSON renders an empty line and a non-string current_dir gives no label, with tests)
