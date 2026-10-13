# Intent: gh-dash sections for what needs my attention

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-13). Type: chore. Delivery: autonomous.

## Problem

gh-dash shows only its default sections. Work review requests, personal PRs that are ready, and my own work PRs that need a reply are mixed with everything else. I cannot see at a glance what needs my action. The gh-dash config also lives outside the dotfiles repository, so it is not versioned.

## Proposed outcome

The PR view opens on the work PRs that wait for my review. The next sections show personal PRs ready to review, then my own work PRs that need action. The issues view opens on issues assigned to me. The default sections follow. The config is versioned in dotfiles.

## Affected users and systems

- Etienne, on every machine that stows the `github` package.
- gh-dash v4.26.0, which uses GitHub's classic search (`type: ISSUE`).

## Constraints

- Classic search does not support `OR` between qualifiers; such a query returns 0 results. A section is one AND-only query.
- PR sections fetch only PRs. Issues go in the issues view.
- The dotfiles repository is public. Etienne allows the `org:nedap` reference in this change, this once.
- Rule 12: agents never run `stow`. Etienne trashes the current `~/.config/gh-dash/config.yml` and restows `github` himself.
- No new dependencies.
- Approved permissions: none beyond the rule 12 step above, which Etienne does by hand.

## In scope

- Move the gh-dash config into the `github` stow package, keeping the existing pager and `C` keybinding.
- PR sections, in this order:
  1. Work PRs (`org:nedap`) where my review is requested (team requests included), I have not reviewed yet, and the PR is not a draft.
  2. Open non-draft PRs in my personal repositories (`user:eirvandelden`), dependabot included.
  3. My own open work drafts.
  4. My own open non-draft work PRs that have comments or reviews, excluding approved PRs.
  5. Default "My Pull Requests".
  6. Default "Involved".
- Issues sections, in this order: issues assigned to me, default "My Issues", default "Involved".

## Out of scope

- `smartFilteringAtLaunch` stays at its default. Starting gh-dash inside a repository still narrows every section to that repository.
- Notifications sections, layouts, theme, other keybindings.
- The stale `~/.config/gh-dash/config.yml.bak`.
- Running `stow`.

## Acceptance criteria

- A non-draft nedap PR with a team review request for me, which I have not reviewed, shows in the first PR section.
- After I submit a review on that PR, it no longer shows in the first section, even if the team request remains.
- A draft nedap PR with a review request for me does not show in the first section.
- A non-draft dependabot PR in an `eirvandelden` repository shows in the second section; a draft there does not.
- My open nedap draft shows in the third section.
- My open nedap PR with "changes requested" shows in the fourth section.
- My open nedap PR with only commented reviews shows in the fourth section.
- My open approved nedap PR does not show in the fourth section; it shows in "My Pull Requests".
- My open non-draft nedap PR with no comments and no review shows in neither the third nor the fourth section.
- The default "Needs My Review" section is gone; "My Pull Requests" and "Involved" follow the new sections.
- The issues view opens on open issues assigned to me; the default "Assigned" section is gone.
- The `C` keybinding still opens the PR in octo.nvim through herdr.
- After Etienne restows `github`, `~/.config/gh-dash/config.yml` is a symlink into dotfiles and gh-dash loads it without errors.

## Flagged concerns

- Classic search cannot express "draft OR reviewed OR commented", and it counts a PR with only commented reviews as `review:none`. Chosen side (Etienne, 2026-10-13, during the plan stage): two sections, and section 4 matches any comment. Section 4 therefore also shows PRs whose only comments come from bots or from me.
- `-reviewed-by:@me` hides a PR where my review was re-requested after I reviewed. Chosen side: accept that, to keep handled team requests out.

## Open questions

None.
