# Evidence: gh-dash-attention-sections

Recorded 2026-10-13. Plan steps 6 and 7.

## Step 6: gh-dash in a herdr pane

- `command gh dash --config github/.config/gh-dash/config.yml` in pane `w1:pCZ`. The plain `gh` alias runs through `op plugin run` and timed out on the 1Password prompt, so `command gh` uses the keyring token.
- gh-dash v4.26.0 loaded the config without errors and opened on "Work reviews". It listed work PR A, work PR D, and two more work repo 1 PRs.
- Pressing `C` on work PR A opened herdr pane `w1:pC0`, running `nvim -c silent Octo pr edit <number> <owner/repo>`.
- Pressing `s` opened the issues view on "Assigned to me". Smart filtering added `repo:eirvandelden/dotfiles`, as the intent accepts.

## Step 7: live search (`gh api graphql`, `search(type: ISSUE)`)

- Section 1: 4 PRs (work PR A, work PR B, work PR C; work PR D). Each has a team review request, none is a draft, none has a review by me.
- Post-review exclusion: the section 1 filter without `-reviewed-by:@me` adds no PR today.
- Section 2: 74 PRs, 53 from dependabot, 0 drafts.
- Section 3: work PR E (draft) is present.
- Section 4: 6 PRs: work PR F, work PR G (changes requested), work PR H, work PR I (bot and own comments only, accepted), work PR J, work PR K.
- `comments:` counts inline review comments: work PR G and work PR F have 0 issue comments and still match `comments:>0`.
- Approved nedap PRs of mine: 0.
- Non-draft nedap PRs of mine with `comments:0 review:none`: 16, absent from sections 3 and 4.
- Draft nedap PRs with a review request for me: 0, so the draft exclusion in section 1 has no live example.
- Other counts: My Pull Requests 46, Involved (PRs) 2, Assigned to me 9, My Issues 155, Involved (issues) 22.

## Base

- `origin/main` already shipped `github/.config/gh-dash/config.yml` (pager and `C` only, since d5c08489). The intent's premise that the config lives outside dotfiles was stale. This branch now extends that file. `~/.config/gh-dash/config.yml` on this machine is still a plain file, so the trash-and-restow step stays with Etienne.
