# Intent: herdr notifications stop freezing the session

Author: Etienne van Delden. Status: accepted. Type: bugfix.

## Problem

When an agent finishes, herdr shows a desktop notification and waits until the notification program exits. With `[ui.toast] delivery = "system"` that program is `terminal-notifier`. The first one on PATH is fastlane's Intel-only 2.0.0 gem, which never exits. The herdr session then stops taking keyboard input until the notification is clicked or the program is killed.

## Proposed outcome

An agent finishing still shows a notification, and the session keeps taking input.

## Affected users and systems

Every herdr session on this machine, through the shared `herdr/.config/herdr/config.toml`. Ghostty shows the notification instead of terminal-notifier.

## Constraints

- The Ruby 4.0 fastlane and terminal-notifier gems were leftovers (the one project using fastlane pins its own version on another Ruby) and are already uninstalled, outside this change.
- Homebrew's terminal-notifier 3.1.0 is still installed by hand; this change must not depend on it.

## Open questions

- Clicking a notification may no longer bring Ghostty to the front. Acceptable for now.
