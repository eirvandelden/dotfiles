# Intent: Branch guard messages name deliver

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-16). Type: bugfix.
Delivery: autonomous

## Problem

The CI on main is red on two tests. The main/master guard gives two different instructions for one rule. Commit 9f72927d changed two messages in `lefthook.yml` to "Create a feature branch; deliver opens the PR." The branch guard change (2d8a4125) added the shared `lefthook-branch-guard.yml` and two more messages in `lefthook.yml`, all with the old "open a PR" text. A person or agent that the guard stops can read "open a PR" and open one by hand, but only `deliver` opens a pull request (playbook rule 5).

- `test/branch_guard_test.rb` `test_the_fallback_config_duplicates_the_guard_commands_exactly` fails: the guard file and `lefthook.yml` no longer hold equal commands.
- `test/pull_request_flow_test.rb` `test_lefthook_messages_send_pull_requests_through_deliver` fails: it expects 2 refusal messages in `lefthook.yml` and finds 4.

## Proposed outcome

Every main/master refusal message, in both `lefthook.yml` and `lefthook-branch-guard.yml`, says that deliver opens the PR. The two files hold equal guard commands again. Both tests pass on main.

## Affected users and systems

- Etienne and every agent that tries to commit or push on main/master.
- The dotfiles repository itself and every repository that falls back to its `lefthook.yml`.
- Every repository that extends `lefthook-branch-guard.yml` from its own `lefthook-local.yml`.
- The CI on main.

## Constraints

- The guard behaviour does not change: the same commits and pushes stay refused or allowed. Only the message text changes.
- `lefthook.yml` and `lefthook-branch-guard.yml` keep equal `no-push-to-main` commands; the equality test stays as it is.
- No new permissions are needed: no dependencies, system tools, migrations or deploy files.

## In scope

- The four refusal messages in each file name deliver:
  - pre-commit: "Direct commit to $branch is not allowed. Create a feature branch; deliver opens the PR."
  - commit-msg (empty commit): "Direct commit to $branch is not allowed. Create a feature branch; deliver opens the PR."
  - pre-push (current branch): "Direct push to $branch is not allowed. Create a feature branch; deliver opens the PR."
  - pre-push (remote ref): "Pushing to <branch> is not allowed. Push a feature branch; deliver opens the PR."
- `test_lefthook_messages_send_pull_requests_through_deliver` pins all four messages in both files: four per file, each names deliver, none says "open a PR".

## Out of scope

- The `isolated_git` require failures. A separate agent fixes them in PR #210.
- The `fail_text` lines. They do not mention a PR, so they stay as they are.
- Any change to what the guard refuses or allows.

## Acceptance criteria

- A commit on main in a repository that extends the guard file is refused with "Create a feature branch; deliver opens the PR."
- An empty commit on main is refused with the same text.
- A push from main is refused with "Direct push to main is not allowed. Create a feature branch; deliver opens the PR."
- A push of a feature branch to the remote `main` ref is refused with "Pushing to main is not allowed. Push a feature branch; deliver opens the PR."
- No refusal message in `lefthook.yml` or `lefthook-branch-guard.yml` says "open a PR".
- `test_the_fallback_config_duplicates_the_guard_commands_exactly` passes.
- `test_lefthook_messages_send_pull_requests_through_deliver` passes and finds four messages in each file.

## Open questions

None.
