# Phase 6: the consent guard in Codex, rules purge, hook parity test

Part of the change on branch `ai-native-workflow`. Its documents are merged to `main` and live at `~/Developer/dotfiles/docs/changes/ai-native-workflow/` until the change finishes; read them there (read `intent.md`, `spec.md`, `plan.md`, `habits.md` first). Repository: `~/Developer/dotfiles`. Requires phase 1 merged. Work in a worktree, PR against `origin`.

## Context

`claude/.claude/hooks/consent-guard.rb` (tested by `test/consent_guard_test.rb`) is a `PreToolUse` hook on `Bash`: it reads JSON from stdin, looks at `tool_input.command`, and exits 2 with a message for `--force` without `--force-with-lease`, and for `--no-verify`, `gh pr/issue comment`, `gh pr review`, `kamal deploy|exec`, `cap deploy`, and pushes to remotes outside the user's own GitHub account or `~/.claude/consent-guard-allowed-remotes.txt`, unless the command is prefixed `I_HAVE_USER_CONSENT=1 `. Codex has no guard; `codex/.codex/rules/default.rules` has eight hand-written `prompt` rules and ~125 auto-appended `allow` rules, some of which (`git push --no-verify`, `gh pr create`, machine-specific paths, employer names) undo the intent of the hand-written ones and sit in a public repo.

Verified against Codex docs (2026-09-18, `learn.chatgpt.com/docs/hooks`, `.../agent-configuration/rules`, `.../config-file/config-reference`):

- Hooks load from `~/.codex/hooks.json` **or** inline `[hooks]` in `~/.codex/config.toml` (`features.hooks` is already `true`). Events include `PreToolUse`; the stdin JSON carries `tool_name`, `tool_input` (shell command in `tool_input.command`), `cwd`, `session_id`; `matcher` is a regex on the tool name, example `"Bash"`; exit code 2 with the reason on stderr blocks; `hookSpecificOutput.permissionDecision: "deny"` also blocks. Same contract as Claude — the Ruby script can run unchanged.
- `~/.codex/hooks.json` is written by herdr ("managed by herdr … add custom hooks beside this file instead of editing it"). Dotfiles must not touch it; inline `[hooks]` in `config.toml` is the stow-managed place.
- Rules: `prefix_rule(pattern=[...], decision="allow"|"prompt"|"forbidden", justification=...)`. "Codex applies the most restrictive decision when more than one rule matches (forbidden > prompt > allow)." Auto-append of `allow` on TUI approval cannot be turned off.

## Talk first

- **Which `allow` rules survive.** Show Etienne the current `allow` list grouped by command (`git`, `gh`, `bundle`, `rails`, paths); propose a short vetted list of generic, read-only or routine commands. Everything with a machine path, an employer name, or a guarded command goes.
- **Hook coexistence.** Confirm by a one-off spike (below) that Codex merges `hooks.json` and inline `[hooks]`, so herdr's SessionStart hook keeps working. If it does not merge, stop and discuss; do not edit herdr's file.

## Steps

1. **Spike (throwaway, not committed).** Add a temporary inline `[hooks]` `PreToolUse` entry in a copy of `config.toml` (or via `codex exec --ignore-user-config` with a temp config) that runs `cat > /tmp/codex-hook-probe.json`; trigger a shell command; read the probe to learn the exact `tool_name` value Codex sends for shell commands and confirm herdr's SessionStart hook still fires. Record both facts in the PR. Delete the probe.

2. **RED — guard test for the Codex payload.** In `test/consent_guard_test.rb`, add a case feeding the probe's JSON shape (with the guarded commands) and asserting exit 2 and the same message as for the Claude shape. Run: it may already pass if the shapes agree — if so, keep the test as a pin and say so; if `tool_name` differs and the script filters on it, fix the script to accept both.

2a. **Test guard in Codex.** The phase-1 probe also records the tool name and `tool_input` field Codex uses for file edits. Add a `test/test_guard_test.rb` case for that payload shape; adapt `claude/.claude/hooks/test-guard.rb` if the field differs; add a second inline `PreToolUse` entry for it in step 3. If Codex edits files only through the shell tool, the guard runs from the shell-command entry instead and inspects the command for test paths — say so in the PR.

3. **Inline hook in `codex/.codex/config.toml`.** Add the `[hooks]` table with a `PreToolUse` entry, `matcher` = the probed tool name, `command = "$HOME/.claude/hooks/consent-guard.rb"` (`$HOME` expansion: verify the docs' example; if unsupported, use the absolute path the Claude settings already use), `timeout = 10`. Keep `~/.claude/hooks/...` as the single location of the script — both tools read it.

4. **Rewrite `default.rules`.** Keep the eight hand-written `prompt` rules. Add `forbidden` for `git push --force` (without `--force-with-lease`) and `prompt` for the other guarded patterns as a second layer under the hook. Delete every auto-appended `allow` not on the vetted list. Add a header comment: "Codex appends `allow` rules here on approval; review this file in every commit that touches `codex/`; the parity test rejects guarded patterns."

5. **RED — parity test extension.** In `test/skill_parity_test.rb` (or a new `test/guard_parity_test.rb`, one place): parse `default.rules`; assert no `allow` rule's pattern begins with a guarded command (`git push --force`, `git commit --no-verify`, `git push --no-verify`, `gh pr comment`, `gh pr review`, `gh issue comment`, `kamal deploy`, `kamal app exec`, `cap deploy`); assert no rule contains a path under `/Users/` or `/private/tmp/`; assert the inline `[hooks]` `PreToolUse` command in `config.toml` points at the same script as `claude/.claude/settings.json`'s `PreToolUse` `Bash` hook. Run: red until step 4 is complete.

6. **Playbook and habits.** `agents.md` §7.19/§7.20: note that the guard now runs in both tools. `habits.md` "Switch tools, not process" slip "push from Claude before phase 6 lands" becomes obsolete once step 7 passes — update the line to say so.

## Files

`test/consent_guard_test.rb`, `codex/.codex/config.toml` (`[hooks]` only), `codex/.codex/rules/default.rules`, `test/skill_parity_test.rb` or `test/guard_parity_test.rb`, `agents.md`, `docs/changes/ai-native-workflow/habits.md`.

## Verification

- `test/` green.
- Fresh `codex` session in a throwaway repo: `git push --force origin x` is blocked with the guard's message; `git push --force-with-lease origin x` is not; herdr pane title still updates (SessionStart hook alive).
- `git grep -n -i` for employer names and `/Users/` in `codex/` returns nothing.
- **Etienne, by hand, after merge:** `stow -R --no-folding codex`. Then use Codex for a push once, on purpose, to see the guard fire.

## Out of scope

`~/.codex/hooks.json`, `~/.codex/herdr-agent-state.sh`, anything herdr owns. Codex `[projects.*]`/`[hooks.state]` churn (phase 7). Changing what the guard blocks.
