# Intent: Show the pipeline stage in the Claude statusline

Author: Etienne van Delden de la Haije. Status: accepted.
Type: feature. Delivery: autonomous

## Problem

The statusline shows the last reply time and the PR URL. It does not show where the current change is in the intent, plan, implement, review pipeline. Etienne has to open `docs/changes/<slug>/` to find out.

## Proposed outcome

The statusline starts with a playful stage label with an emoji. It follows the state of the change folder in the session's working directory.

## Affected users and systems

Etienne, in every session inside a repository that uses `docs/changes/<slug>/`. The system is `claude/.claude/statusline-command.rb` and its test.

## Constraints

- No new gems, tools, migrations or deploy files. No extra permissions are needed.
- The label comes first, before "Last reply" and the PR URL.
- No change folder, no label. The statusline stays as it is today.
- The statusline must stay fast and must never raise. Unreadable files give no label.

## In scope

- Detect the stage from `docs/changes/<slug>/` under the session's `workspace.current_dir`.
- Show the stage with these labels: 🤔 interviewing, 🧠 scheming, 🛠️ hammering, 🕵️ sleuthing, 🎉 shipped.
- Tests for each stage and for the no-label cases.

## Out of scope

- Colours or ANSI tinting.
- Changing the intent, plan, implement or review skills.
- The gh-dash configuration and the 1Password setting.
- A stage for repositories that do not use change folders.

## Acceptance criteria

- A change folder with a draft `intent.md` shows "🤔 interviewing".
- An accepted `intent.md` with no accepted `plan.md` shows "🧠 scheming".
- An accepted `plan.md` shows "🛠️ hammering".
- A `review.md` with open findings shows "🕵️ sleuthing".
- No change folder and a PR URL shows "🎉 shipped".
- No change folder and no PR URL shows no label.
- The label comes before "Last reply" in the output.

## Open questions

None.
