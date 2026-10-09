# Plan: Quieter herdr notification sounds

From `intent.md` (2026-10-09). Status: accepted.

## Context

herdr 0.9.3 plays each `[ui.sound]` file with a bare `afplay <file>` and has no volume setting. The three tones are too loud. Etienne approved the level of `afplay -v 0.3`. The fix makes a quieter mp3 copy of each tone outside the repository and points herdr at the copies. The originals in `~/Documents/Tones` stay untouched, and no audio enters this public repository.

## Design decisions

- **The script is a Bash script in the herdr package:** `herdr/.config/herdr/scripts/quieter-tones.sh`, next to the two worker scripts. It belongs to herdr, and shellcheck already lints `*.sh`. Etienne runs it from the repository path; it appears in `~/.config/herdr/scripts/` only after he restows the `herdr` package himself.
- **Interface:** `quieter-tones.sh <source.mp3>...`. Each argument is one source tone. Each copy lands at `$HOME/Documents/Tones/herdr/<basename of source>`. The script holds no list of tones, so a tone swap needs no code change: one run with the new source gives its copy. The script prints each copy path it wrote.
- **Level:** ffmpeg's `volume=0.3` filter, a linear amplitude factor of 0.3 (about −10.5 dB). Apple documents the `afplay`/AVAudioPlayer volume as linear gain from 0.0 to 1.0, so the two match. The factor is a constant in the script, not an option: the intent fixes it at 0.3.
- **Encoding:** `libmp3lame` at VBR quality 2 (`-q:a 2`), sample rate and channel count left as the source has them. Metadata is dropped (`-map_metadata -1`); herdr does not read it. herdr plays only mp3, so the copy is always mp3.
- **Refusals, all with a message on stderr and exit status 1, before anything is written:**
  - no arguments (prints usage);
  - a source that does not exist;
  - a source whose name does not end in `.mp3` (herdr plays only mp3, and a same-name copy of a non-mp3 file would fall back to the default sound without an error);
  - a source that already sits in `~/Documents/Tones/herdr/` (a copy of a copy compounds the gain to 0.09);
  - `ffmpeg` missing from `PATH` (the message says so; the script never installs anything).
- **Safe writes:** `mktemp "$out_dir/.<basename>.XXXXXX"` makes a hidden temporary file in the output folder. That file already exists and has no `.mp3` extension, so the ffmpeg call carries `-y` (overwrite it) and `-f mp3` (the format is not inferable from the name). Full call: `ffmpeg -hide_banner -loglevel error -y -i <source> -map_metadata -1 -af volume=0.3 -c:a libmp3lame -q:a 2 -f mp3 <tmp>`. On success the script moves the temporary file over the destination with `mv -f`, which is atomic within one folder. A `trap` removes the temporary file on any exit, so a failed run leaves neither a partial copy nor a stray hidden file, and an existing copy at the destination stays as it was. herdr never reads a half-written file. The source is only ever an ffmpeg input, so it cannot change. Re-running overwrites an existing copy with an identical-level copy.
- **Output folder:** created with `mkdir -p` if absent. It derives from `$HOME`, so tests point `HOME` at a temporary folder and never touch the real tone collection.
- **Config:** `path`, `request_path` and `done_path` in `[ui.sound]` point at `/Users/etienne.vandelden/Documents/Tones/herdr/<same basename>.mp3`. The commented `ForTheMaster02.mp3` alternative also points at the herdr folder. A comment above the block says the paths are quieter copies and gives the exact command that makes one. The existing comments about `~` and mp3 stay.
- **"No mp3 file is in the repo":** taken literally, this criterion fails today and after this change. The repository already tracks `tones/.config/audioclips/{come-here,get-over-here,wc3-work-complete}.mp3` from before this change. Deleting them changes a stow package the intent does not name, so this plan does not guess. It proves the part it owns, "this change adds no audio, and no herdr tone or its copy is tracked", and leaves the literal reading open as a decision for Etienne (see Risks). The implement stage reports this criterion as partly met until he decides.

## Integration points

- herdr 0.9.3 reads `[ui.sound]` from `~/.config/herdr/config.toml`, a stow link to `herdr/.config/herdr/config.toml`. The running server picks up a change only after `herdr server reload-config`, which Etienne runs himself.
- `ffmpeg` at `/opt/homebrew/bin/ffmpeg`, built with `libmp3lame`. Already installed; no new dependency.
- `~/Documents/Tones/Warcraft/Humans/{jobs-done,milord,ready-to-serve}.mp3` and `~/Documents/Tones/Overlord/MinionVoiceData_ENGLISH/ForTheMaster02.mp3`: read only.
- CI (`.github/workflows/dotfiles-tests.yml`) runs every `test/*_test.rb` on `ubuntu-latest`, which has neither `ffmpeg` nor `herdr`. The workflow does not change (rule 13).

## Files that change

- `herdr/.config/herdr/scripts/quieter-tones.sh` — new, executable. The script described above.
- `herdr/.config/herdr/config.toml` — `[ui.sound]` paths and the comment above them.
- `herdr/.config/herdr/README.md` — a short "Notification sounds" section: why the copies exist, the command for a tone swap, and the `reload-config` step.
- `test/herdr_quieter_tones_test.rb` — new. Script tests.
- `test/herdr_config_test.rb` — new tests for the `[ui.sound]` paths and for tracked audio.

## Order of work

1. Write `test_each_sound_points_at_its_quieter_copy` in `test/herdr_config_test.rb` (acceptance test for the config criteria). Run `ruby -Itest test/herdr_config_test.rb`; watch it fail on the current Warcraft paths.
2. Write the script tests in `test/herdr_quieter_tones_test.rb`, one at a time, each red before green:
   - stubbed-`ffmpeg` tests first (they run in CI): argument wiring, output path, refusals, safe write;
   - then the real-`ffmpeg` tests (skipped only when `ffmpeg` is absent): mp3 output, the −10.46 dB level, source checksum unchanged.
   - Build `quieter-tones.sh` test by test.
3. Change `[ui.sound]` in `config.toml`; step 1's test goes green. Add `test_no_herdr_tone_is_tracked`; it passes at once since nothing audio is added, which is its point as a guard.
4. Run the script for real, with a checksum gate around it:
   - `shasum -a 256 <the four sources> > "$scratch/before.sha"`;
   - `herdr/.config/herdr/scripts/quieter-tones.sh` on the three Warcraft sources and on `ForTheMaster02.mp3`;
   - `shasum -a 256 <the four sources> | diff "$scratch/before.sha" -` must exit 0. A non-zero exit stops the work and is reported; it never gets explained away;
   - `ffmpeg -af volumedetect -f null -` mean volume of each original and copy; each drop must be within 0.5 dB of −10.46 dB.
   - Put the hashes, the `diff` result and the volume table in the PR description.
5. Run `herdr config check` against the worktree config (`HERDR_CONFIG_PATH=herdr/.config/herdr/config.toml herdr config check`), which `test_herdr_accepts_the_config` also does.
6. Update `herdr/.config/herdr/README.md`.
7. Full suite: `for f in test/*_test.rb; do ruby -Itest "$f" || exit 1; done`. Lint: `shellcheck -x -S warning herdr/.config/herdr/scripts/quieter-tones.sh`, `rubocop` on both test files, the markdown hard-wrap check on the README.
8. The live playback check is a pre-merge gate that only Etienne can pass: an agent cannot hear, and the running herdr reads the main checkout's config, not this worktree's. The PR description carries a short audition checklist: check out the branch (or point `HERDR_CONFIG_PATH` at the worktree config), run `herdr server reload-config`, let one agent finish and one ask for input, and compare each against `afplay -v 0.3 <original>`. Until he does, the implement stage reports the three playback criteria as "file level verified, playback unheard", never as verified.

## Risks

- **Linear vs. perceived match.** If `afplay -v` were not linear, 0.3 in ffmpeg would not sound like `afplay -v 0.3`. Apple documents it as linear; the measured −10.46 dB drop in step 4 confirms the file side. Etienne's audition before merge (step 8) is the last word.
- **Re-encode artefacts.** Decoding and re-encoding an mp3 adds a small generation loss. At VBR q2 on short voice clips this is not audible. Rejected: a lossless gain change (mp3gain-style global-gain edits), because it needs a new tool (rule 11) and adjusts only in 1.5 dB steps, so it cannot hit 0.3 exactly.
- **Clipping.** Gain below 1 cannot clip.
- **Stale copies.** A copy does not follow later edits to its source. Re-running the script refreshes it; the README says so.
- **Basename collision.** Two sources with the same file name in different folders map to one copy; the later run wins. The four tones in scope have distinct names. Accepted, not guarded.
- **CI coverage.** CI has no `ffmpeg`, so the real-audio tests skip there and only the stub tests run. The real tests run locally, where the change is verified. Rejected: installing ffmpeg in CI, because it edits a workflow file (rule 13) for a Mac-only feature.
- **Hardcoded home path.** The config already hardcodes `/Users/etienne.vandelden`, because herdr does not expand `~`. The new paths follow that. The script itself uses `$HOME`.
- **Already-tracked audio.** `tones/.config/audioclips/` tracks `wc3-work-complete.mp3` and other game clips in this public repo. That conflicts with the intent's reason for keeping tones out. Removing them is a separate change. Decision needed: whether to remove the `tones/` package audio from the public repository in a separate change.
- **Rejected alternatives:** an `afplay` wrapper and system volume changes (out of scope by the intent); a `--volume` option (the level is fixed); reading sources from `config.toml` (the config points at the copies, so it cannot also name the sources without a second, parsed list).

## Out of scope

- Upstream herdr volume support, or any GitHub post about it.
- An `afplay` wrapper or system volume changes.
- Per-agent sounds; changing which tones play.
- Running `stow` or `herdr server reload-config`; both are Etienne's.
- The audio already tracked under `tones/`.

## Proof

- When an agent finishes, herdr plays "jobs done" at the 0.3 level (playback heard by Etienne in step 8) → `test/herdr_config_test.rb` `test_each_sound_points_at_its_quieter_copy`, plus `test/herdr_quieter_tones_test.rb` `test_the_copy_is_three_tenths_of_the_source_level`.
- When an agent needs action, herdr plays "milord" at the 0.3 level → same two tests.
- The default notification plays "ready to serve" at the 0.3 level → same two tests.
- The three originals keep their checksums → `test/herdr_quieter_tones_test.rb` `test_the_source_is_left_byte_for_byte_unchanged`, plus the step 4 gate: `shasum -a 256 <sources> | diff before.sha -` exits 0.
- After a swap to `ForTheMaster02.mp3`, one run gives a 0.3 copy → `test/herdr_quieter_tones_test.rb` `test_one_run_copies_every_source_given`, plus `test/herdr_config_test.rb` `test_the_commented_alternative_also_points_at_a_quieter_copy`, plus the real run in step 4.
- No mp3 file is in the repo → `test/herdr_config_test.rb` `test_no_herdr_tone_is_tracked` proves this change adds no audio. Etienne decided on 2026-10-09 that the criterion reads "this change adds no mp3"; the pre-existing `tones/` mp3s stay and are out of scope, so this criterion is met in full.
- `herdr config check` reports no problems → `test/herdr_config_test.rb` `test_herdr_accepts_the_config` (existing), plus the manual run in step 5.

Per changed file, the unit tests expected:

- `herdr/.config/herdr/scripts/quieter-tones.sh` (in `test/herdr_quieter_tones_test.rb`):
  - stub `ffmpeg`: `test_one_run_copies_every_source_given`, `test_the_copy_keeps_the_source_file_name_in_the_herdr_tones_folder`, `test_ffmpeg_is_asked_for_three_tenths_volume_as_mp3`, `test_the_output_folder_is_created_when_missing`, `test_no_arguments_prints_usage_and_fails`, `test_a_missing_source_is_refused_and_nothing_is_written`, `test_a_source_that_is_not_mp3_is_refused`, `test_a_source_inside_the_herdr_tones_folder_is_refused`, `test_ffmpeg_is_told_to_overwrite_and_write_mp3_to_a_temporary_file`, `test_a_failed_conversion_leaves_no_partial_copy`, `test_a_failed_conversion_keeps_an_existing_copy_unchanged`, `test_a_failed_conversion_leaves_no_temporary_file`, `test_a_missing_ffmpeg_is_reported`;
  - real `ffmpeg`: `test_the_copy_is_an_mp3`, `test_the_copy_is_three_tenths_of_the_source_level` (mean volume drop of 20·log10(0.3) ≈ −10.46 dB, within 0.5 dB), `test_the_source_is_left_byte_for_byte_unchanged`.
- `herdr/.config/herdr/config.toml` (in `test/herdr_config_test.rb`): `test_each_sound_points_at_its_quieter_copy` (each of `path`, `request_path`, `done_path` is absolute, ends in `.mp3`, sits in `/Documents/Tones/herdr/`, and keeps its tone: `ready-to-serve`, `milord`, `jobs-done`), `test_the_commented_alternative_also_points_at_a_quieter_copy`, `test_no_herdr_tone_is_tracked` (`git ls-files` holds no file named after a `[ui.sound]` tone, and nothing under `herdr/` is audio), `test_herdr_accepts_the_config` (existing).

Test setup: each script test gets a temporary `HOME`. Stub tests put a fake `ffmpeg` first on `PATH` that records its arguments and writes a few bytes to its last argument (or exits 1 on demand). Real tests generate a two-second 440 Hz sine mp3 with `ffmpeg -f lavfi -i sine=frequency=440:duration=2` into the temporary folder, and skip with "ffmpeg is not installed" when it is absent, as `test_herdr_accepts_the_config` does for `herdr`. No real tone file is read by any test.

---
Domain skills applied: dotfiles-maintenance (stow layout, no stow runs), dependencies (no new tool; ffmpeg already installed), rails-testing (Minitest in the repo's style).

## Critique

### Round 1 (codex exec -p terra)

- The plan silently narrows "No mp3 file is in the repo"; three mp3s are already tracked under `tones/.config/audioclips/`. Remove them or amend the criterion. → fixed (the design decision now states the literal criterion fails before and after; Proof marks it partly met; the literal reading goes to Etienne as a decision instead of a guess, since deleting another package's files is outside the intent)
- The atomic write lacks ffmpeg details: the temporary file exists and has no mp3 extension, so ffmpeg needs `-y` and `-f mp3`; clean up with a trap; test that a failed conversion keeps an existing copy. → fixed (full ffmpeg call with `-y -f mp3`, `mktemp` name, `trap` cleanup and `mv -f` spelled out; three new tests for the overwrite flags, the kept existing copy and no stray temporary file)
- The checksum step records hashes but never compares them. → fixed (step 4 now saves hashes before the run and makes `shasum -a 256 ... | diff before.sha -` a required exit-0 gate)
- The only live sound check is deferred until after merge, though three criteria need herdr playback. → fixed (step 8 makes Etienne's audition a pre-merge gate with a checklist in the PR; until then the implement stage reports those criteria as "file level verified, playback unheard")
