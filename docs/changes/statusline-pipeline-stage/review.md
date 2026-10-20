# Review: statusline-pipeline-stage

## Round 1 — 2026-10-20T13:35Z — 5ca8018e

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. Tests: 31 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🛠️ hammering | https://example.invalid/pull/1` in 0.08 s.

Compliance: draft intent → `test_shows_interviewing_for_a_draft_intent`; accepted intent without accepted plan → `test_shows_scheming_for_an_accepted_intent_with_a_draft_plan`; accepted plan → `test_shows_hammering_for_an_accepted_plan`; open review → `test_shows_sleuthing_for_a_review_with_open_findings`; shipped → `test_shows_shipped_when_there_is_no_change_folder_but_a_pr_url`; no label → `test_shows_no_label_when_there_is_no_change_folder_and_no_pr_url`; label order → `test_puts_the_label_before_the_last_reply_and_the_pr_url`. Every test in `plan.md`'s Proof exists. The twelve existing tests are unchanged. Security: nothing found; the script only reads files under `workspace.current_dir`.

- [ ] Important: Non-object JSON other than an array still raises. `echo null | claude/.claude/statusline-command.rb` raises `NoMethodError` (undefined method `[]` for nil); `"abc"` and `true` raise the same way. The plan's design decision says input that parses to something other than an object renders an empty line, and the intent says the statusline never raises. `rescue TypeError` catches only the array case, and only the array case has a test. A guard such as `return "" unless data.is_a?(Hash)` covers every case and lets the broad `TypeError` rescue go — `claude/.claude/statusline-command.rb:72` → fixed (Harden the statusline against odd JSON and paths)
- [ ] Nit: `Dir.glob(File.join(current_dir, …))` treats glob characters in `current_dir` as a pattern. A repository at `…/proj[1]` with one accepted intent shows no label instead of `🧠 scheming` (checked by hand). `Dir.glob("docs/changes/*/", base: current_dir)` avoids this; the same applies to line 66 — `claude/.claude/statusline-command.rb:11` → fixed (Harden the statusline against odd JSON and paths)
- [ ] Nit: The shipped check globs `docs/changes/*`, which also matches plain files. A `docs/changes/README.md` with no change folder and a PR URL shows no `🎉 shipped` label (checked by hand), though the intent says no change folder plus a PR URL shows shipped — `claude/.claude/statusline-command.rb:66` → fixed (Harden the statusline against odd JSON and paths)

## Round 2 — 2026-10-20T13:50Z — 14f0e799

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. Tests: 35 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1` (the untracked `review.md` is present), 0.08 s of CPU. The three round 1 fixes hold: `null`, `"abc"`, `true` and `42` render an empty line; `proj[1]` shows the label; a plain `docs/changes/README.md` still gives `🎉 shipped`. Security: nothing found.

Compliance: every Proof test exists and passes. The intent's constraint "No change folder, no label" and its acceptance criterion "No change folder and a PR URL shows 🎉 shipped" pull in different directions; the plan follows the criterion, so a repository without change folders and with a PR now shows `🎉 shipped`. This follows the accepted plan and is not a finding.

- [ ] Important: A `Status:` line with a byte the string's encoding cannot hold makes `Regexp#match?` raise `ArgumentError`, which nothing rescues, so the script exits 1 with a backtrace. With `LANG=C`, an `intent.md` of `Author: Ëtienne — A. Status: accepted.` raises "invalid byte sequence in US-ASCII"; under UTF-8, a stray `\xff` on that line raises "invalid byte sequence in UTF-8" (both checked by hand). The intent says the statusline never raises and unreadable files give no label. Reading with `File.read(file, encoding: Encoding::UTF_8).scrub` (or rescuing `ArgumentError` in `stage_label`) covers both, with a test for the invalid-byte case — `claude/.claude/statusline-command.rb:34` → fixed (Read change files as scrubbed UTF-8 in the statusline)

## Round 3 — 2026-10-20T14:05Z — 123bdc8b

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. Tests: 36 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1`, also under `LANG=C LC_ALL=C`; 0.13 s wall time. The round 2 fix holds: `test_shows_the_label_when_the_status_line_holds_invalid_bytes` passes, and the read is scrubbed UTF-8. Security: nothing found.

Compliance: every Proof test in `plan.md` exists and passes. The twelve existing tests are unchanged apart from the shared `@root` teardown.

- [ ] Nit: A `current_dir` with a NUL byte makes `Dir.glob` raise `ArgumentError` ("path name contains null byte"), which nothing rescues, so the script exits 1 with a backtrace (checked by hand with `{"workspace":{"current_dir":"/tmp/a\u0000b"}}`). No real path holds a NUL, so this needs odd input, but the intent says the statusline never raises. Rescuing `ArgumentError` next to `SystemCallError` in `stage_label` covers it, with a test. `transcript_path` has the same behaviour on `origin/main`; that is outside this change — `claude/.claude/statusline-command.rb:11` → fixed (Rescue invalid paths in the statusline stage label)

## Round 4 — 2026-10-20T13:46Z — 123bdc8b

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. `git fetch origin` failed (SSH agent refused to sign), so the diff is against the local `origin/main`. Tests: 37 runs, 0 failures, with the staged change. RuboCop: no offences. The round 3 fix holds in the working tree: a `current_dir` of `/tmp/a\u0000b` with a PR URL prints `https://example.invalid/pull/1` and exits 0. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1`. Security: nothing found.

Compliance: every Proof test in `plan.md` exists and passes. The twelve existing tests are unchanged apart from the shared `@root` teardown.

- [ ] Important: The round 3 fix exists only in the index. `rescue SystemCallError, ArgumentError` and `test_shows_no_label_when_current_dir_holds_a_null_byte` are staged but not committed, and no commit named "Rescue invalid paths in the statusline stage label" exists on the branch, although round 3 closes its finding with that subject. `commit-review` commits `review.md` alone, so a push now would deliver the branch without the fix while the review reads as closed. Commit the staged change under the subject round 3 cites — `claude/.claude/statusline-command.rb:71` → fixed (Rescue invalid paths in the statusline stage label)

## Round 5 — 2026-10-20T18:55Z — 5aedddb4

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. `git fetch origin` succeeded; the diff is against the current `origin/main`. The working tree is clean apart from this file. Tests: 37 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1`, exit 0, 0.16 s wall time. The round 4 fix holds: commit 5aedddb4 "Rescue invalid paths in the statusline stage label" holds the `ArgumentError` rescue and `test_shows_no_label_when_current_dir_holds_a_null_byte`, and a `current_dir` of `/tmp/a\u0000b` prints only the PR URL with exit 0. Security: nothing found.

Compliance: every Proof test in `plan.md` exists and passes. The twelve existing tests are unchanged apart from the shared `@root` teardown.

- [ ] Nit: An empty `current_dir` mixes two roots. `Dir.glob("docs/changes/*/", base: "")` searches the process's working directory, but `File.join("", folder)` gives `/docs/changes/<slug>/`, so the stage comes from files that do not exist. Run from this worktree with `{"workspace":{"current_dir":""},"pr":{"url":"u"}}`, the script prints `🤔 interviewing | u` instead of the folder's `🕵️ sleuthing`; run from `/tmp`, it prints `🎉 shipped | u` (both checked by hand). The plan says a missing `current_dir` gives no label, and an empty string carries no directory either. A guard such as `return unless current_dir.is_a?(String) && !current_dir.empty?`, with a test, covers it — `claude/.claude/statusline-command.rb:65` → fixed (Show no stage label for an empty current_dir)

## Round 6 — 2026-10-20T19:10Z — ccea620a

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. `git fetch origin` succeeded; the diff is against the current `origin/main`. The working tree is clean apart from this file. Tests: 38 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1`, exit 0, 0.49 s wall time. The round 5 fix holds: commit ccea620a adds the empty-string guard and `test_shows_no_label_when_current_dir_is_empty`; an empty `current_dir` prints only `u`, from this worktree and from `/tmp`. Also checked by hand: a `current_dir` that is a file, a missing path, `.` and `~` all exit 0. Security: nothing found.

Compliance: every Proof test in `plan.md` exists and passes. The twelve existing tests are unchanged apart from the shared `@root` teardown.

- [ ] Nit: An unreadable `docs/changes/` claims the change shipped. `Dir.glob` returns `[]` on `EACCES` instead of raising, so the `SystemCallError` rescue never fires, and `stage_label` falls through to `🎉 shipped`. With `docs/changes/` at mode 000 and an accepted intent inside, the input `{"workspace":{"current_dir":"<dir>"},"pr":{"url":"u"}}` prints `🎉 shipped | u` (checked by hand). The intent says unreadable files give no label. Checking `File.directory?` and `File.readable?` on `docs/changes` before the shipped fallback, with a test, covers it — `claude/.claude/statusline-command.rb:70` → fixed (Show no stage label when docs/changes is unreadable)

## Round 7 — 2026-10-20T18:58Z — 794eedd4

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. `git fetch origin` succeeded; the diff is against the current `origin/main`. The working tree is clean apart from this file. Tests: 39 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1`, exit 0, 0.16 s wall time. The round 6 fix holds: commit 794eedd4 adds the readable check and `test_shows_no_label_when_docs_changes_is_unreadable`; with `docs/changes/` at mode 000 and an accepted intent inside, the script prints only `u`, exit 0. Security: nothing found.

Compliance: every Proof test in `plan.md` exists and passes. The twelve existing tests are unchanged apart from the shared `@root` teardown.

- [ ] Nit: An unsearchable change folder claims the change is in the interview stage. `read` guards with `File.exist?`, which returns false on `EACCES`, so every file in the folder reads as missing and `stage_label` falls through to `🤔 interviewing`. With `docs/changes/x/` at mode 000 and an accepted intent inside, the input `{"workspace":{"current_dir":"<dir>"},"pr":{"url":"u"}}` prints `🤔 interviewing | u`; with `docs/changes/` at mode 444 it prints the same (both checked by hand). The intent says unreadable files give no label. Calling `File.read` without the `File.exist?` guard and rescuing only `Errno::ENOENT` there to mean "missing" lets `EACCES` reach the `SystemCallError` rescue in `stage_label`, and covers both cases, with a test — `claude/.claude/statusline-command.rb:44` → fixed (Show no stage label when a change folder is unsearchable)

## Round 8 — 2026-10-20T19:01Z — 096e2a63

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. `git fetch origin` succeeded; the diff is against the current `origin/main`. The working tree is clean apart from this file. Tests: 40 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1`, exit 0, 0.16 s wall time. The round 7 fix holds: commit 096e2a63 drops the `File.exist?` guard in `read` and adds `test_shows_no_label_when_the_change_folder_is_unsearchable`; with `docs/changes/x/` at mode 000, or `docs/changes/` at mode 444, the script prints only `u`, exit 0. The permission tests run as the non-root runner user on `ubuntu-latest`, so `chmod` takes effect in CI. Security: nothing found.

Compliance: every Proof test in `plan.md` exists and passes. The twelve existing tests are unchanged apart from the shared `@root` teardown.

Not a finding: input JSON with a non-ASCII byte under `LANG=C` makes `JSON.parse` raise `Encoding::InvalidByteSequenceError`, exit 1 (checked by hand). `origin/main` behaves the same, so it is outside this change.

- [ ] Nit: An unsearchable `docs/` or `current_dir` claims the change shipped. `shipped?` asks `File.exist?(changes)`, which returns false on `EACCES` as well as on `ENOENT`, so `!File.exist?` short-circuits to `🎉 shipped`. With `docs/` at mode 000 and an accepted intent in `docs/changes/x/`, the input `{"workspace":{"current_dir":"<dir>"},"pr":{"url":"u"}}` prints `🎉 shipped | u`; with `<dir>` itself at mode 000 it prints the same (both checked by hand). The intent says unreadable files give no label; round 6 closed this for `docs/changes/` only. Asking the directory itself, for example with `Dir.children(changes)` and only `Errno::ENOENT` rescued to mean "no folder", lets every other `SystemCallError` reach the rescue in `stage_label` and covers `docs/changes/`, `docs/` and `current_dir` in one rule, with a test — `claude/.claude/statusline-command.rb:16` → fixed (Show no stage label when docs or the working dir is unsearchable)

## Round 9 — 2026-10-20T19:03Z — 189d23d1

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. `git fetch origin` succeeded; the diff is against the current `origin/main`. The working tree is clean apart from this file. Tests: 42 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1`, exit 0, 0.11 s wall time. The round 8 fix holds: commit 189d23d1 asks `Dir.children` and adds `test_shows_no_label_when_docs_is_unsearchable` and `test_shows_no_label_when_current_dir_is_unsearchable`; with `docs/` or `<dir>` at mode 000 and an accepted intent inside, the script prints only `u`, exit 0. Also checked by hand: no `docs/`, an empty `docs/changes/`, a plain `docs/changes/README.md` and a dangling link in `docs/changes/` each give `🎉 shipped | u`; `docs/changes` as a file and a `current_dir` that is a file give only `u`; all exit 0. Security: nothing found.

Compliance: every Proof test in `plan.md` exists and passes. The twelve existing tests are unchanged apart from the shared `@root` teardown.

- [ ] Nit: `ChangeFolder` now has two definitions of a change folder. `folders_in` globs `docs/changes/*/`, which skips dot-directories, but `shipped?` counts every directory from `Dir.children`, dot-directories included. A `docs/changes/` that holds only `.hidden/` has no change folder for `in`, yet blocks `🎉 shipped`: the input `{"workspace":{"current_dir":"<dir>"},"pr":{"url":"u"}}` prints only `u` (checked by hand); before 189d23d1 it printed `🎉 shipped | u`. The intent says no change folder and a PR URL shows shipped. Skipping entries that start with `.` in `shipped?`, so both methods share one rule, with a test, covers it — `claude/.claude/statusline-command.rb:16` → fixed (Ignore hidden directories when deciding a change shipped)

## Round 10 — 2026-10-20T19:10Z — 3dc12b73

No `REVIEW.md` in the repository; the default Bugs, Security and Compliance passes apply. `git fetch origin` succeeded; the diff is against the current `origin/main`. The working tree is clean apart from this file. Tests: 43 runs, 0 failures. RuboCop: no offences. Manual run in this worktree gives `🕵️ sleuthing | https://example.invalid/pull/1`, exit 0, 0.13 s of CPU. The round 9 fix holds: commit 3dc12b73 skips entries that start with `.` in `shipped?` and adds `test_shows_shipped_when_docs_changes_holds_only_a_hidden_directory`; a `docs/changes/` with only `.hidden/` gives `🎉 shipped | u`, exit 0. Also checked by hand: `.hidden/` next to a folder with an accepted intent gives `🧠 scheming | u`; a symlinked change folder gives `🤔 interviewing | u`; a dangling link gives `🎉 shipped | u`; a `current_dir` with a space and a dated `accepted (2026-10-20)` plan gives `🛠️ hammering | u`; all exit 0. `folders_in` and `shipped?` now share one rule for a change folder. Security: nothing found.

Compliance: every Proof test in `plan.md` exists and passes. The twelve existing tests are unchanged apart from the shared `@root` teardown.

No findings.
