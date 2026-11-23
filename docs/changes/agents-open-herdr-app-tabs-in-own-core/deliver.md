# Delivery account: agents-open-herdr-app-tabs-in-own-core

## Behaviour delivered

- `herdr-app-pane tab <cwd> [--name <name>] [-- <command>...]` opens a tab in the agent's own core and own space, without moving focus. The own core comes from `HC_SESSION`, else the core named by `HC_TERMINAL_SOCKET`, else `default`.
- `herdr-app-pane open`, `close`, `close-idle` and `close-at` now work from a `work`-core terminal. Before, they refused there, because the space match compared a bare id with `work/`-prefixed ids.
- New skill `herdr-app-tabs` tells agents to open tabs this way and never through the `herdr` TUI, `HERDR_ENV`, `herdr-automate` or the stale Herdr UI skills. It has an index line in `SKILLS-INDEX.md`. Four glossary terms are agreed.

## Evidence

- Live check, work core, scratch space `probe-work`: `tab` printed `t2q` inside the space, and `close t2q` removed that pane through its `work/` address.
- Live check, default core, scratch space `probe-default`: `tab` printed `t133`, and `close` removed it. `focused_pane` stayed the same before and after `tab` in both cores. Scratch spaces are closed.
- Harness tests cover a work agent while personal has focus and a default agent while work has focus, with the same terminal and space ids in both cores and a decoy work space.

## Checks

- `bin/test`: 134 files, 0 failed, recorded with `delivery-evidence` against the final content.
- `rubocop`, `yamllint` and `markdownlint` clean on the touched files.
- No Brakeman or Bundler Audit: the repository has no `Gemfile.lock`.

## Review

- Round 1: 2 Important findings and 7 nits, all fixed. Round 2: 1 Important finding and 3 nits, all fixed. Round 3: no findings. Claude reviewer only; no Codex review.
- The plan critique (Codex gpt-6.1-sol) closed 4 findings on the first plan and 3 on the second.

## Limits

- Agents get the `tab` subcommand only after merge, because `~/.local/bin/herdr-app-pane` links into the main checkout.
- Etienne trashed the stale `herdr-gpui-browser` and `herdr-automations` skills by hand. Herdr UI may rewrite them while the old app runs. The `herdr` TUI uninstall was Etienne's own step.
- Follow-up, not in this change: stage panes find macOS Ruby 2.6 before rv's Ruby 4, because `herdr-app-pane` starts the agent without a login shell. Cause and a proposed fix are known.
- `herdr_app_look_test` failed on the first branch state because of an unrelated tabs-mod drift; it passes after the rebase.
