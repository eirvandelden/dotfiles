# Review: install-golden-ratio-plugin

## Round 1 — 2026-11-06T07:59Z — 0571f93e

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes from the reviewer agent ran. Checks: `bin/test test/herdr_plugins_install_test.rb` green (10 runs). `shellcheck -x -S warning`, `bash -n packages.conf`, `rubocop` and `markdownlint` green. Full `bin/test`: 93 of 94 files green; `test/secrets_loader_test.rb` fails 5 tests because it reaches the real 1Password `op` CLI ("token" isn't an item in the "Private" vault). This branch does not touch that test or the secrets loader. On this machine: `go version` prints go1.27.3; `herdr plugin list --plugin vv.golden-ratio --json` shows `enabled: true`; the README range holds no "not installed".

Compliance: `go version` → checked, go1.27.3. Plugin enabled → checked. `packages.conf` lists `go` → `test_packages_conf_installs_go_and_lists_the_golden_ratio_plugin`. README → checked. Two panes at about 61.8% → no evidence in the branch (see the Nit below). Every test named in `## Proof` exists. No existing test changed. The jq expression deviates from the plan's `// "missing"` for a good reason: `false // "missing"` gives `missing`, so the plan's form would reinstall a disabled plugin.

- [ ] Nit: The `STOW_SHARED` comment says herdr clones plugins into `~/.config/herdr/plugins/github`; herdr 0.9.5 clones into `~/.config/herdr/plugins/github-installations/` (the installed plugin's `managed_path`). The invariant still holds, because `plugins/` stays a real directory, but the comment names the wrong path — `packages.conf:333` → fixed (Name the real herdr plugin clone directory in the STOW_SHARED comment)
- [ ] Nit: `herdr_plugin_state` sends `herdr plugin list` stderr to `/dev/null`, and `errexit` does not reach the `$(…)` subshell, so any herdr failure reads as `missing` and runs `herdr plugin install -y` on a plugin that may be installed, with the original error lost. Keep stderr so a failed run shows why — `install/utils.sh:620` → fixed (Keep herdr stderr when reading plugin state)
- [ ] Nit: `assert_match(/go/, stderr)` matches any "go" in stderr. Match the `require_cmd` message, `Missing required command(s): go` — `test/herdr_plugins_install_test.rb:58` → fixed (Match the require_cmd message in the missing-go test)
- [ ] Nit: The branch records no evidence for the two-pane check (both `rect.width / area.width` readings) or for the step 9 run with `HERDR_SOCKET_PATH=/nonexistent/herdr.sock`. Record both readings where the delivery account will carry them — `docs/changes/install-golden-ratio-plugin/plan.md:175` → dismissed: the change folder is removed on delivery, so the readings go into the delivery account (`deliver-install-golden-ratio-plugin.md`): focused pane 139 of 225 columns, 0.618

## Round 2 — 2026-11-06T08:01Z — a62732db

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes from the reviewer agent ran. Checks: `bin/test test/herdr_plugins_install_test.rb` green (10 runs, 44 assertions). `shellcheck -x -S warning`, `bash -n packages.conf`, `rubocop` and `markdownlint` green. On this machine: `go version` prints go1.27.3; `herdr plugin list --plugin vv.golden-ratio --json` shows `enabled: true`; the README range holds no "not installed".

The three fixes from round 1 hold. `packages.conf` names `~/.config/herdr/plugins/github-installations`. `herdr_plugin_state` keeps herdr's stderr; a failed list still reads as `missing`, and the following `herdr plugin install` then fails the task under `set -e` with the error visible. The missing-go test matches `Missing required command(s): go`.

Bugs: none. Security: none; the plugin source and the `go` install are approved in the intent. Compliance: unchanged from round 1; every acceptance criterion has a test or a recorded check, every `## Proof` test exists, no existing test changed. Design: both shell functions match `### Signatures`; no Ruby outside the test; no glossary `Avoid:` word.

Nothing found.
