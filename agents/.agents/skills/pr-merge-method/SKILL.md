---
name: pr-merge-method
description: Use when asked to set, change or remove how pull requests merge from gh-dash — "squash-merge this repository's PRs", "use a merge commit", "rebase merge", "gh-dash merge method".
---

# gh-dash merge method

The gh-dash merge key (`ctrl+m` or `M`) runs `~/.config/gh-dash/scripts/merge-pr.sh`. The script reads the merge method from git config. Without a setting the method is `merge` (a merge commit).

## Settings

Key: `pr-merge.<subsection>.method`. Value: `merge`, `squash` or `rebase`. Any other value makes the merge fail with an error.

- `pr-merge.<owner>/<repo>.method` — one repository.
- `pr-merge.<owner>.method` — every repository of that owner.

The repository setting wins over the owner setting. Names match case-insensitively.

## Where to write it

Always write to the machine-local file `~/.config/git/pr-merge.config` with `--file`. Never use `git config --global`: it writes into the dotfiles repository, which is public.

Never write an employer's owner or repository name into any file of the dotfiles repository.

## Recipes

Take the owner and repository from `git remote get-url origin` when the user says "this repository".

```bash
# Squash every repository of an owner
git config --file ~/.config/git/pr-merge.config pr-merge.OWNER.method squash

# Merge commits for one repository (overrides the owner setting)
git config --file ~/.config/git/pr-merge.config pr-merge.OWNER/REPO.method merge

# Remove a setting
git config --file ~/.config/git/pr-merge.config --unset pr-merge.OWNER.method
git config --file ~/.config/git/pr-merge.config --unset pr-merge.OWNER/REPO.method

# Show every setting and the file it comes from
git config --show-origin --get-regexp '^pr-merge\.'
```

After removing both settings, the default `merge` applies again.

## Checking

Press `ctrl+m` on a PR in gh-dash. The prompt names the method: `Merge OWNER/REPO#N with squash and delete its branch?`. Answer `n` and Enter to cancel. Press `r` after a real merge to refresh the list.
