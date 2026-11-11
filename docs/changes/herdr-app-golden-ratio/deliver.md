# Delivery: Golden ratio in herdr-app

## Behaviour delivered

herdr-app has a local `golden-ratio` mod. After the focus rests on a pane for 120 ms, the mod resizes the tab so the focused pane gets 61.8% on each axis it shares with a sibling. The `cores` layout mounts it as a zero-size block with the props `ratio`, `debounce_ms` and `min_delta`.

## Evidence

- Sandbox run (own `HC_SESSION`, own state directory, own app home, cores layout). Weights read with `hc connect` and `doc.get herdr-app`.
- Two side-by-side panes: the focused pane held 0.618 and its sibling 0.382, in both directions, on four focus changes.
- Three panes (a column beside a pane): each axis the focused pane shares with a sibling held 0.618.
- Three focus changes 80 ms apart produced one settled result for the last pane only.
- `ratio: 0.7` in the layout props gave 0.7 and 0.3.
- The zero-size block mounted and rendered at `px: 0`. Sizes 1 to 20 behaved the same.
- `herdr-app check` passed on the mod folder.

## Check results

- `ruby test/herdr_app_golden_ratio_test.rb`: 32 runs, 97 assertions, 0 failures.
- `ruby test/herdr_app_package_test.rb` and `ruby test/isolated_git_test.rb`: 0 failures.
- `bin/test`: 113 files. Two failed. `test/isolated_git_test.rb` failed because the new test file did not require the helper; fixed, now green. `test/secrets_loader_test.rb` hangs in this agent shell on the main checkout too, so it is not caused by this change; it is unconfirmed.
- rubocop and markdownlint: clean on every touched file.
- Brakeman and Bundler Audit: not applicable, the change has no Ruby application code and no dependency.

## Review outcome

Two Claude rounds. Round 1 found one Important finding and three nits; all four are fixed with regression tests first. Round 2 found nothing. The Codex plan critique raised twelve findings: ten fixed in the plan, two dismissed with reasons.

## Known limits

- The mod resizes only while the herdr-app window paints. An occluded or background window resizes at the next repaint.
- A pane in a space on a remote machine (the work core) is skipped. This is a candidate for a separate change.
- The new mod files need a restow of the `herdr-app` package before the real app loads them. Etienne runs it.
- The sandbox left a scratch directory under `/tmp/gr.iwqJ5K` and a note `/tmp/gr_path_note`. Remove both with `trash`.
