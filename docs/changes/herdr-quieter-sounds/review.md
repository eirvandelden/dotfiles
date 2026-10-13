# Review: herdr-quieter-sounds

## Round 1 — 2026-10-13T08:05Z — 4a0202ca

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the reviewer defaults apply. Suite state before review: `test/herdr_quieter_tones_test.rb` 16 runs green (real-ffmpeg tests ran, none skipped), `test/herdr_config_test.rb` 5 runs green, shellcheck clean, rubocop clean on both test files. `HERDR_CONFIG_PATH=herdr/.config/herdr/config.toml herdr config check` prints `config: ok`. The four copies exist in `~/Documents/Tones/herdr/`.

### Bugs

- [ ] Important: `test_no_herdr_tone_is_tracked` is vacuous. It runs `git ls-files` with `chdir: herdr/.config/herdr`, so git lists only that subfolder, relative to it (`README.md`, `config.toml`, `scripts/…`). The `\Aherdr/` pattern never matches any line, so `herdr_audio` is always empty. The tone-name check also sees only `herdr/.config/herdr/`, so a `jobs-done.mp3` committed anywhere else in the repository passes. Verified: from that folder, 6 lines are listed and 0 start with `herdr/`. This is the only proof for the "no mp3 in the repo" criterion. Run `git ls-files` from the repository root (for example `chdir: File.expand_path("..", __dir__)`) and confirm the test goes red on a staged dummy `herdr/x.mp3`. — `test/herdr_config_test.rb:37` →
- [ ] Nit: the real-ffmpeg tests ignore the script's exit status. `test_the_source_is_left_byte_for_byte_unchanged` passes when the script fails before ffmpeg runs, so it does not prove that a conversion left the source alone. Assert `status.success?` (and the copy's existence) before the checksum compare. — `test/herdr_quieter_tones_test.rb:182` →
- [ ] Nit: `test_a_missing_ffmpeg_is_reported` relies on `/usr/bin` and `/bin` having no `ffmpeg`. On a Linux box with a distro `ffmpeg` in `/usr/bin` the script finds it and the test fails. A `PATH` of the empty stub folder plus only the tools the script needs would make it independent of the host. — `test/herdr_quieter_tones_test.rb:149` →
- [ ] Nit: copies are written with mode `0600`, because `mktemp` creates the file that way and `mv -f` keeps it. Verified on disk: all four copies in `~/Documents/Tones/herdr/` are `-rw-------`, while the folder is `0755`. Harmless for herdr under the same user, but a re-run also tightens a copy that had wider permissions. A `chmod 644` before the `mv` keeps copies like ordinary files. — `herdr/.config/herdr/scripts/quieter-tones.sh:46` →

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
- [ ] Nit: one README sentence has 21 words and chains two "and" clauses, against the playbook's Simplified Technical English rule (at most 20 words, one statement per sentence). Split it into "herdr plays only mp3, so the script refuses anything else." and "It also refuses a file that already sits in the copies folder." — `herdr/.config/herdr/README.md:96` →

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
