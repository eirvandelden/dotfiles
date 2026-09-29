# Plan: herdr notifications stop freezing the session

From `spec.md` (2026-09-29). Status: accepted.

## Steps

1. In `herdr/.config/herdr/config.toml`, change `[ui.toast] delivery` from `"system"` to `"terminal"`.

## Proof

- `test/herdr_config_test.rb`: notifications go through the terminal; herdr accepts the config (`herdr config check`, skipped where herdr is not installed, as in CI).
- Acceptance: `herdr config check` on the changed file reports no diagnostics. After merge, `herdr server reload-config` in both sessions succeeds and an agent finishing shows a Ghostty notification while the session keeps taking input.

Reproduction: committed
