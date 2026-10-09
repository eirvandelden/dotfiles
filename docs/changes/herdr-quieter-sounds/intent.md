# Intent: Quieter herdr notification sounds

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore. Delivery: autonomous.

## Problem

herdr's notification sounds are too loud: "done" (`jobs-done.mp3`), "needs action" (`milord.mp3`) and the default (`ready-to-serve.mp3`). herdr 0.9.3 has no volume setting. It plays each file at full level with a bare `afplay <file>`.

## Proposed outcome

All three herdr sounds play at the level that `afplay -v 0.3` gives for the same file. Etienne auditioned that level and approved it; 0.15 was too low. The tones themselves do not change, and the original files in `~/Documents/Tones` stay as they are.

## Affected users and systems

- Etienne, on this Mac, in every herdr session.
- `herdr/.config/herdr/config.toml`, the `[ui.sound]` block.
- The tone collection in `~/Documents/Tones`. It is read only; its originals are never modified.

## Constraints

- The dotfiles repo is public. The tone files are copyrighted game audio, so they and their quieter copies never enter the repo.
- The quieter copies live in `~/Documents/Tones/herdr/`.
- herdr plays only mp3. Other formats fall back to the default sound without an error.
- herdr does not expand `~`. Config paths must be absolute.
- Approved permissions: none needed. `ffmpeg` is already installed, so no new dependency comes in. There are no migrations or deploy files. `stow` is not run; Etienne reloads herdr himself.

## In scope

- A script in the dotfiles repo that makes a 0.3-level mp3 copy of each source tone in `~/Documents/Tones/herdr/`. Run it again after a tone swap, for example back to `ForTheMaster02.mp3`.
- The `[ui.sound]` paths `path`, `request_path` and `done_path` point at those copies.
- Tests for the script and the config, in the style of the repo's existing herdr tests.

## Out of scope

- A volume key upstream in herdr, or any GitHub post about one.
- A wrapper around `afplay`, or any change to the system volume.
- Per-agent sound settings.
- Changing which tones play.

## Acceptance criteria

- When an agent finishes, herdr plays "jobs done" as quietly as `afplay -v 0.3 jobs-done.mp3` does.
- When an agent needs action, herdr plays "milord" as quietly as `afplay -v 0.3 milord.mp3` does.
- The default notification plays "ready to serve" at that same 0.3 level.
- Each of the three originals in `~/Documents/Tones/Warcraft/Humans/` has the same checksum before and after the change.
- After Etienne swaps `done_path` back to `ForTheMaster02.mp3`, one run of the script gives him a 0.3 copy of it too.
- No mp3 file is in the repo.
- `herdr config check` reports no problems.

## Open questions

None.
