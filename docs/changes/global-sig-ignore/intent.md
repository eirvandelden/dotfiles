# Intent: Ignore generated signature folders globally

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-18). Type: chore.
Delivery: autonomous

## Problem

Steep, `rbs collection` and rbs-inline write a `sig/` folder and a `.gem_rbs_collection/` folder into Ruby repositories. Git lists them as untracked in every repository, personal and work. Each repository must ignore them by hand, and `new-repo-setup` step 12 tells you to add `.gem_rbs_collection/` to each repository's `.gitignore`. Signatures live inline as `#:` / `# @rbs` comments, so these folders are generated output and are never committed.

## Proposed outcome

Git ignores `sig/` and `.gem_rbs_collection/` in every repository on the machine, through the global excludes file. A gem that publishes its types is the one exception: it commits a `sig/` generated from its inline comments, and its own `.gitignore` re-includes the folder with `!sig/`. The skills state this rule, so a new repository no longer needs its own ignore line.

## Affected users and systems

- `git/.config/git/ignore.global`, the global `core.excludesfile` (stow-linked to `~/.config/git/ignore.global`).
- Every git repository on the machine, personal and work.
- The `new-repo-setup` skill (step 12) and the `ruby-style` skill, for Claude and Codex both.

## Constraints

- The ignore goes in the global excludes file, not a per-repository `.gitignore`.
- A repository's own `.gitignore` takes precedence over the global excludes file, so `!sig/` in a gem's `.gitignore` re-includes the folder.
- RBS 4.2 `docs/gem.md`: a consumer loads a gem's types only from `/sig` inside the gem package. Inline comments in the gem source are not read.
- No checkout under `~/Developer` tracks `sig/` on its current branch (checked 2026-10-17), so the global ignore hides nothing that is committed today.
- The rbs 4.2 CLI cannot write `sig/` from inline comments. The `rbs-inline` gem can (`rbs-inline --output=sig lib`).
- Approved permissions: none. No gems, system tools, migrations or deploy files in this repository. `ignore.global` is already stow-linked, so no `stow` run is needed. Any later need for a permission is a stop-and-ask.

## In scope

- Add `sig/` and `.gem_rbs_collection/` to `git/.config/git/ignore.global`.
- `new-repo-setup` step 12: drop the per-repository `.gem_rbs_collection/` line; say `sig/` is generated and never committed; describe the gem exception (`!sig/` in the gem's `.gitignore`, `sig/` generated from inline comments, CI regenerates it and fails when the committed copy differs).
- `new-repo-setup`: a CI recipe for such a gem that regenerates `sig/` with `rbs-inline --output=sig lib` and fails on `git diff --exit-code sig/`. The gem adds `rbs-inline` as a development dependency in its own repository.
- `ruby-style`: the same rule in one line.
- A Minitest test in `test/` that guards the ignore lines (through `git check-ignore` in a temporary repository) and the skill wording.

## Out of scope

- Changes in any gem repository, such as appkit: its `!sig/` line, its `rbs-inline` dependency and its CI job.
- Per-repository `.gitignore` files in other checkouts. An existing `.gem_rbs_collection/` line there stays; it is redundant but harmless.
- Steep, RBS or `rbs_collection.yaml` setup beyond the step 12 wording.
- Installing or upgrading `rbs`, `rbs-inline` or Steep.

## Acceptance criteria

- In a repository with no ignore lines of its own, `sig/foo.rbs` and `.gem_rbs_collection/` do not show up as untracked.
- In a gem repository whose `.gitignore` has `!sig/`, `sig/foo.rbs` shows up as untracked and can be committed.
- A new repository set up through `new-repo-setup` gets no `.gem_rbs_collection/` line in its `.gitignore`.
- The `new-repo-setup` skill shows a gem's CI step: it runs `rbs-inline --output=sig lib`, and a stale committed `sig/` fails the build.
- The `ruby-style` skill says that `sig/` is generated, never committed, except in a gem that publishes its types.

## Open questions

None.
