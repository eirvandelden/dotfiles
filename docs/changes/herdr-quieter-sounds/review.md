# Review: herdr-quieter-sounds

## Round 1 — 2026-10-13T08:05Z — 4a0202ca

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the reviewer defaults apply. Suite state before review: `test/herdr_quieter_tones_test.rb` 16 runs green (real-ffmpeg tests ran, none skipped), `test/herdr_config_test.rb` 5 runs green, shellcheck clean, rubocop clean on both test files. `HERDR_CONFIG_PATH=herdr/.config/herdr/config.toml herdr config check` prints `config: ok`. The four copies exist in `~/Documents/Tones/herdr/`.

### Bugs

- [x] Important: `test_no_herdr_tone_is_tracked` is vacuous. It runs `git ls-files` with `chdir: herdr/.config/herdr`, so git lists only that subfolder, relative to it (`README.md`, `config.toml`, `scripts/…`). The `\Aherdr/` pattern never matches any line, so `herdr_audio` is always empty. The tone-name check also sees only `herdr/.config/herdr/`, so a `jobs-done.mp3` committed anywhere else in the repository passes. Verified: from that folder, 6 lines are listed and 0 start with `herdr/`. This is the only proof for the "no mp3 in the repo" criterion. Run `git ls-files` from the repository root (for example `chdir: File.expand_path("..", __dir__)`) and confirm the test goes red on a staged dummy `herdr/x.mp3`. — `test/herdr_config_test.rb:37` → fixed in 0c628925 (git ls-files from the repository root; a staged dummy `herdr/x.mp3` now turns it red)
- [x] Nit: the real-ffmpeg tests ignore the script's exit status. `test_the_source_is_left_byte_for_byte_unchanged` passes when the script fails before ffmpeg runs, so it does not prove that a conversion left the source alone. Assert `status.success?` (and the copy's existence) before the checksum compare. — `test/herdr_quieter_tones_test.rb:182` → fixed in d8c577ed (real-ffmpeg tests go through `convert`, which asserts success and the copy's existence)
- [x] Nit: `test_a_missing_ffmpeg_is_reported` relies on `/usr/bin` and `/bin` having no `ffmpeg`. On a Linux box with a distro `ffmpeg` in `/usr/bin` the script finds it and the test fails. A `PATH` of the empty stub folder plus only the tools the script needs would make it independent of the host. — `test/herdr_quieter_tones_test.rb:149` → fixed in d8c577ed (PATH is the stub folder holding only a `bash` link)
- [x] Nit: copies are written with mode `0600`, because `mktemp` creates the file that way and `mv -f` keeps it. Verified on disk: all four copies in `~/Documents/Tones/herdr/` are `-rw-------`, while the folder is `0755`. Harmless for herdr under the same user, but a re-run also tightens a copy that had wider permissions. A `chmod 644` before the `mv` keeps copies like ordinary files. — `herdr/.config/herdr/scripts/quieter-tones.sh:46` → fixed in 525ed449 (`chmod 644` before `mv`; test added; the four real copies regenerated, now `-rw-r--r--`, source checksums unchanged)

### Security

Nothing found. Every path in the script is quoted, the source is only ever an ffmpeg input, the temporary file sits in the output folder, and no audio or secret enters the public repository. The new config paths repeat the home path the config already held.

### Compliance

| Acceptance criterion (intent.md) | Proof in the diff |
| --- | --- |
| "jobs done" plays at the 0.3 level | `test_each_sound_points_at_its_quieter_copy`, `test_the_copy_is_three_tenths_of_the_source_level`; live playback is Etienne's pre-merge audition (plan step 8), not yet recorded |
| "milord" plays at the 0.3 level | same two tests; playback unheard |
| default "ready to serve" plays at the 0.3 level | same two tests; playback unheard |
| originals keep their checksums | `test_the_source_is_left_byte_for_byte_unchanged` (see the Nit above); the step 4 `shasum … \| diff` gate belongs in the PR description, not visible in the branch |
| one run after a swap to `ForTheMaster02.mp3` gives a 0.3 copy | `test_one_run_copies_every_source_given`, `test_the_commented_alternative_also_points_at_a_quieter_copy`; the copy exists on disk |
| no mp3 file is in the repo (read as "this change adds no mp3") | `test_no_herdr_tone_is_tracked` — present but vacuous, see the Important finding; the diff itself adds no audio |
| `herdr config check` reports no problems | `test_herdr_accepts_the_config` (existing, green); manual run prints `config: ok` |

- Every test named in `plan.md` `## Proof` exists: 13 stub tests and 3 real-ffmpeg tests in `test/herdr_quieter_tones_test.rb`, 3 new tests plus the existing `test_herdr_accepts_the_config` in `test/herdr_config_test.rb`.
- No existing test was weakened, skipped or deleted; the diff to `test/herdr_config_test.rb` only adds.
- [x] Nit: one README sentence has 21 words and chains two "and" clauses, against the playbook's Simplified Technical English rule (at most 20 words, one statement per sentence). Split it into "herdr plays only mp3, so the script refuses anything else." and "It also refuses a file that already sits in the copies folder." — `herdr/.config/herdr/README.md:96` → fixed in 13e5bc81

Totals: 1 Important, 4 Nit.

## Round 2 — 2026-10-13T08:10Z — 4a0202ca — Codex (`codex review --base origin/main`)

Transcribed from the Codex CLI. Codex ran `test/herdr_quieter_tones_test.rb` (16 runs green, real-ffmpeg tests included), `test/herdr_config_test.rb` (5 runs green) and `shellcheck -x -S warning` on the script (clean).

### Bugs

Nothing found. Codex: "The new script, sound configuration, and tests are consistent with the stated behavior."

### Security

Nothing found.

### Compliance

Nothing found.

Totals: 0 findings.

## Round 3 — 2026-10-13T08:15Z — 7bbd46b2

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the reviewer defaults apply. Suite state before review: `test/herdr_quieter_tones_test.rb` 17 runs green (real-ffmpeg tests ran, none skipped), `test/herdr_config_test.rb` 5 runs green, shellcheck clean, rubocop clean on both test files, `herdr config check` on the worktree config prints `config: ok`. The four copies in `~/Documents/Tones/herdr/` are now `-rw-r--r--`. All round 1 fixes hold. Note: the local branch is rebased and has diverged from `origin/herdr-quieter-sounds` (92 local, 3 remote commits), so the next push needs `--force-with-lease`. No pull request exists yet.

### Bugs

- [x] Nit: the copy-of-a-copy guard compares only the physical folder of the path given, not of the file it resolves to. A source that is a symlink to a file in `~/Documents/Tones/herdr/` passes the guard. The script then reads that copy and replaces it with a 0.09-level copy. Verified in a scratch `HOME`: a symlink `src/a.mp3 → Documents/Tones/herdr/a.mp3` exits 0 and rewrites `a.mp3`. Resolving the file itself (for example `cd` into its folder and follow the link, or compare `pwd -P` of the link target's folder) closes the gap. — `herdr/.config/herdr/scripts/quieter-tones.sh:33` → fixed in 277b8684 (the guard compares the folder of `realpath "$source"`; `test_a_link_to_a_quieter_copy_is_refused` added, red first)
- [x] Nit: `test_no_herdr_tone_is_tracked` ignores the exit status of `git ls-files`. Outside a work tree git exits 128 with empty output (verified), so both `assert_empty` calls pass without checking anything. Assert the status succeeded, or that `tracked` holds at least this test file. — `test/herdr_config_test.rb:37` → fixed in e74dc3ee (asserts `git ls-files` succeeded; verified red outside a work tree)

### Security

Nothing found. Every path in the script is quoted. The source is only ever an ffmpeg input. A SIGTERM during conversion leaves no hidden temporary file (verified with a slow ffmpeg stub). No audio or secret enters the public repository.

### Compliance

| Acceptance criterion (intent.md) | Proof in the diff |
| --- | --- |
| "jobs done" plays at the 0.3 level | `test_each_sound_points_at_its_quieter_copy`, `test_the_copy_is_three_tenths_of_the_source_level`; playback unheard until Etienne's pre-merge audition (plan step 8) |
| "milord" plays at the 0.3 level | same two tests; playback unheard |
| default "ready to serve" plays at the 0.3 level | same two tests; playback unheard |
| originals keep their checksums | `test_the_source_is_left_byte_for_byte_unchanged` (now asserts a successful run first); the step 4 `shasum … \| diff` evidence still needs to go in the pull request description |
| one run after a swap to `ForTheMaster02.mp3` gives a 0.3 copy | `test_one_run_copies_every_source_given`, `test_the_commented_alternative_also_points_at_a_quieter_copy`; the copy exists on disk |
| no mp3 file is in the repo (read as "this change adds no mp3") | `test_no_herdr_tone_is_tracked`, now run from the repository root (see the Nit above about its exit status) |
| `herdr config check` reports no problems | `test_herdr_accepts_the_config` (existing, green); manual run prints `config: ok` |

- Every test named in `plan.md` `## Proof` exists, plus `test_the_copy_is_readable_like_an_ordinary_file` from the round 1 fix.
- No existing test was weakened, skipped or deleted.

Totals: 0 Important, 2 Nit.

## Round 4 — 2026-10-13T08:20Z — 7bbd46b2 — Codex (`codex review --base origin/main`)

Transcribed from the Codex CLI. Codex ran both herdr test files (green), `shellcheck` on the script (clean) and `git diff --check` (clean).

### Bugs

Nothing found. Codex: "No actionable defects found."

### Security

Nothing found.

### Compliance

Nothing found.

Totals: 0 findings.

## Round 5 — 2026-10-13T08:19Z — b09e5165

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the reviewer defaults apply. Suite state before review: `test/herdr_quieter_tones_test.rb` 18 runs green (real-ffmpeg tests ran, none skipped), `test/herdr_config_test.rb` 5 runs green, shellcheck clean, rubocop clean on both test files, `git diff --check` clean, `herdr config check` on the worktree config prints `config: ok`. The round 3 fixes hold: a link to a copy is refused, and the tracked-audio test asserts that `git ls-files` succeeded. The local branch has still diverged from `origin/herdr-quieter-sounds` (97 local, 3 remote commits), so the next update of the remote branch needs `--force-with-lease`. No pull request exists yet.

### Bugs

- [x] Nit: `test_no_herdr_tone_is_tracked` misses audio with a non-ASCII name under `herdr/`. With the default `core.quotePath`, `git ls-files` prints such a path in quotes with octal escapes, so the `\Aherdr/` pattern does not match it. Verified in a scratch repository: a tracked `herdr/tône.mp3` lists as `"herdr/t\303\264ne.mp3"` and the grep returns `[]`. `git ls-files -z` with a split on `"\0"` gives raw paths. — `test/herdr_config_test.rb:37` → fixed in 07ea2dfc (`git ls-files -z`, split on NUL; a staged `herdr/tône.mp3` now turns it red)
- [x] Nit: `bash_path` is 125 characters, over the playbook limit of about 120 characters per line. Rubocop does not flag it, so only the playbook rule catches it. Break the chain over two lines. — `test/herdr_quieter_tones_test.rb:225` → fixed in 97496abe

### Security

Nothing found. Every path in the script is quoted. The source is only ever an ffmpeg input. The copy-of-a-copy guard resolves links. No audio or secret enters the public repository.

### Compliance

| Acceptance criterion (intent.md) | Proof in the diff |
| --- | --- |
| "jobs done" plays at the 0.3 level | `test_each_sound_points_at_its_quieter_copy`, `test_the_copy_is_three_tenths_of_the_source_level`; playback unheard until Etienne's pre-merge audition (plan step 8) |
| "milord" plays at the 0.3 level | same two tests; playback unheard |
| default "ready to serve" plays at the 0.3 level | same two tests; playback unheard |
| originals keep their checksums | `test_the_source_is_left_byte_for_byte_unchanged`; the step 4 `shasum … \| diff` evidence still needs to go in the pull request description |
| one run after a swap to `ForTheMaster02.mp3` gives a 0.3 copy | `test_one_run_copies_every_source_given`, `test_the_commented_alternative_also_points_at_a_quieter_copy`; the copy exists on disk (`-rw-r--r--`) |
| no mp3 file is in the repo (read as "this change adds no mp3") | `test_no_herdr_tone_is_tracked` (see the Nit above about quoted paths); the diff adds no audio |
| `herdr config check` reports no problems | `test_herdr_accepts_the_config` (existing, green); manual run prints `config: ok` |

- Every test named in `plan.md` `## Proof` exists, plus `test_the_copy_is_readable_like_an_ordinary_file` and `test_a_link_to_a_quieter_copy_is_refused` from earlier fixes.
- No existing test was weakened, skipped or deleted.

Totals: 0 Important, 2 Nit.

## Round 6 — 2026-10-13T08:22Z — b09e5165 — Codex (`codex review --base origin/main`)

Transcribed from the Codex CLI. Codex ran both herdr test files (green).

### Bugs

Nothing found. Codex: "The changes match the documented behavior."

### Security

Nothing found.

### Compliance

Nothing found.

Totals: 0 findings.

## Round 7 — 2026-10-13T08:23Z — 40bb86e0

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the reviewer defaults apply. Suite state before review: `test/herdr_quieter_tones_test.rb` 18 runs green (real-ffmpeg tests ran, none skipped), `test/herdr_config_test.rb` 5 runs green, shellcheck clean, rubocop clean on both test files, `git diff --check` clean, `herdr config check` on the worktree config prints `config: ok`. The four copies in `~/Documents/Tones/herdr/` are `-rw-r--r--`. The round 5 fixes hold: the tracked-audio test lists raw paths with `-z`, and `bash_path` fits the line limit.

### Bugs

- [x] Nit: a relative source with a colon in its name fails inside ffmpeg, not in the refusals. ffmpeg reads `a:b.mp3` as protocol `a` and stops with "Protocol not found", exit status 8, after `mkdir -p` already ran. macOS stores a `/` typed in Finder as `:` on disk, so such names occur. Verified in a scratch `HOME`: `quieter-tones.sh a:b.mp3` exits 8; the absolute path to the same file exits 0. Nothing is damaged. Passing `file:$source` (or the `realpath` result) to `-i` makes both forms work. — `herdr/.config/herdr/scripts/quieter-tones.sh:48` → fixed in 5ab30347 (ffmpeg gets `file:$source`; `test_a_relative_source_with_a_colon_in_its_name_is_converted` added, red first)
- [x] Nit: a source whose name starts with `-` reaches `realpath` and `basename` as an option. `realpath` then fails inside the command substitution, the guard compares `.` against the copies folder, and the copy-of-a-copy check passes open. The run stops later only because `basename` fails too. Verified: `quieter-tones.sh -x.mp3` prints the `realpath` and `basename` usage texts and exits 1, with no copy written. `realpath -- "$source"` and `basename -- "$source"` remove the option reading; a failed `realpath` should refuse the source, not pass it. — `herdr/.config/herdr/scripts/quieter-tones.sh:34` → fixed in 5ab30347 (`realpath --`, `dirname --`, `basename --`; a failed `realpath` refuses the source; `test_a_source_named_like_an_option_is_still_checked` added, red first)

### Security

Nothing found. Every path in the script is quoted. The source is only ever an ffmpeg input. The temporary file sits in the output folder and the `EXIT` trap removes it. No audio or secret enters the public repository.

### Compliance

| Acceptance criterion (intent.md) | Proof in the diff |
| --- | --- |
| "jobs done" plays at the 0.3 level | `test_each_sound_points_at_its_quieter_copy`, `test_the_copy_is_three_tenths_of_the_source_level`; playback unheard until Etienne's pre-merge audition (plan step 8) |
| "milord" plays at the 0.3 level | same two tests; playback unheard |
| default "ready to serve" plays at the 0.3 level | same two tests; playback unheard |
| originals keep their checksums | `test_the_source_is_left_byte_for_byte_unchanged`; the step 4 `shasum … \| diff` evidence still needs to go in the pull request description |
| one run after a swap to `ForTheMaster02.mp3` gives a 0.3 copy | `test_one_run_copies_every_source_given`, `test_the_commented_alternative_also_points_at_a_quieter_copy`; the copy exists on disk |
| no mp3 file is in the repo (read as "this change adds no mp3") | `test_no_herdr_tone_is_tracked`; the diff adds no audio |
| `herdr config check` reports no problems | `test_herdr_accepts_the_config` (existing, green); manual run prints `config: ok` |

- Every test named in `plan.md` `## Proof` exists, plus `test_the_copy_is_readable_like_an_ordinary_file` and `test_a_link_to_a_quieter_copy_is_refused` from earlier fixes.
- The diff changes only the files `plan.md` names, plus the change folder.
- No existing test was weakened, skipped or deleted.

Totals: 0 Important, 2 Nit.

## Round 8 — 2026-10-13T08:26Z — 40bb86e0 — Codex (`codex review --base origin/main`)

Transcribed from the Codex CLI. Codex ran both herdr test files (green).

### Bugs

Nothing found. Codex: "No actionable defects found in the diff."

### Security

Nothing found.

### Compliance

Nothing found.

Totals: 0 findings.

## Round 9 — 2026-10-13T08:27Z — 7e24fa33

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the reviewer defaults apply. Suite state before review: `test/herdr_quieter_tones_test.rb` 20 runs green (real-ffmpeg tests ran, none skipped), `test/herdr_config_test.rb` 5 runs green, shellcheck clean, rubocop clean on both test files, `git diff --check` clean, no changed line over 120 characters, `herdr config check` on the worktree config prints `config: ok`. The four copies in `~/Documents/Tones/herdr/` are `-rw-r--r--`. The round 7 fixes hold: ffmpeg gets `file:$source`, and `realpath`, `dirname` and `basename` take `--`, with a failed `realpath` refusing the source. The local branch has still diverged from `origin/herdr-quieter-sounds` (105 local, 3 remote commits), so the next update of the remote branch needs `--force-with-lease`. No pull request exists yet.

### Bugs

Nothing found. The refusals all run before `mkdir -p` and before any write. The temporary file sits in the output folder, gets mode 644, and moves over the destination in one `mv -f`. The `EXIT` trap removes it on any failure. Known limits stay as `plan.md` accepts them: two sources with one file name map to one copy, and a stale copy needs a re-run.

### Security

Nothing found. Every path in the script is quoted. The source is only ever an ffmpeg input, read through the `file:` protocol. No audio or secret enters the public repository.

### Compliance

| Acceptance criterion (intent.md) | Proof in the diff |
| --- | --- |
| "jobs done" plays at the 0.3 level | `test_each_sound_points_at_its_quieter_copy`, `test_the_copy_is_three_tenths_of_the_source_level`; playback unheard until Etienne's pre-merge audition (plan step 8) |
| "milord" plays at the 0.3 level | same two tests; playback unheard |
| default "ready to serve" plays at the 0.3 level | same two tests; playback unheard |
| originals keep their checksums | `test_the_source_is_left_byte_for_byte_unchanged`; the step 4 `shasum … \| diff` evidence still needs to go in the pull request description |
| one run after a swap to `ForTheMaster02.mp3` gives a 0.3 copy | `test_one_run_copies_every_source_given`, `test_the_commented_alternative_also_points_at_a_quieter_copy`; the copy exists on disk |
| no mp3 file is in the repo (read as "this change adds no mp3") | `test_no_herdr_tone_is_tracked`; the diff adds no audio |
| `herdr config check` reports no problems | `test_herdr_accepts_the_config` (existing, green); manual run prints `config: ok` |

- Every test named in `plan.md` `## Proof` exists, plus `test_the_copy_is_readable_like_an_ordinary_file`, `test_a_link_to_a_quieter_copy_is_refused`, `test_a_source_named_like_an_option_is_still_checked` and `test_a_relative_source_with_a_colon_in_its_name_is_converted` from earlier fixes.
- The diff changes only the files `plan.md` names, plus the change folder.
- No existing test was weakened, skipped or deleted.

Totals: 0 Important, 0 Nit.
