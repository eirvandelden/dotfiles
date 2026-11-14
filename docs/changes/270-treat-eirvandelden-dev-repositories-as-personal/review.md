# Review: Treat `eirvandelden-dev` repositories as personal

## Round 1 — 2026-11-14T10:52:11Z — bfe18b59

- [ ] Nit: The new GLOSSARY entry "Personal owner" leaves out "Avoid: personal account", which plan.md's Domain terms gives it (because `eirvandelden-dev` is an organisation) — `GLOSSARY.md:40` → fixed (Mark personal account as a term to avoid for personal owners)
- [ ] Nit: `ghp` joins the path with `local IFS=/` and `$*`, not the `${(j:/:)@}` that plan.md's Signatures shows; the behaviour is the same and `shellcheck -s bash` needs it, but the plan does not record the change — `zsh/.config/zsh/functions/gh.zsh:10` → dismissed: behaviour is identical and shellcheck rejects the zsh-only `${(j:/:)@}`; the implement report records the deviation, and an accepted plan.md is not rewritten after the fact
- [ ] Nit: The rewritten header comment still says "One source, two callers", but agent-voice and auto-accept also call `RemoteMatcher` (four callers) — `claude/.claude/hooks/remote_matcher.rb:3` → fixed (Name all four RemoteMatcher callers in its header comment)
- [ ] Nit: `test_allowed_remotes_holds_a_pattern_per_personal_owner_plus_the_listed_remotes` checks only the pattern count and the listed entry; it does not show that each personal owner's pattern matches its own URL — `test/remote_matcher_test.rb:40` → fixed (Check that every personal owner has a matching allowed remote)

## Round 2 — 2026-11-14T11:01:43Z — 1ea16607

Nothing found. All four round-1 fixes hold. Compliance: every acceptance criterion maps to a Proof test that exists and passes (`bin/test`: 124 files, 0 failed; `ConsentGuardPersonalOrgTest` runs all 146 guard cases with an `eirvandelden-dev` origin). Lint on the changed files is green; the `--all-files` failures (`docker.zsh`, `prompt.zsh`, a marker comment in `solarized.vim`, stylelint not installed) are in files this branch does not touch. No glossary `Avoid:` term in the added lines. The branch merges cleanly onto current `origin/main`, and the three `settings.json` trust lines still name both owners after that merge.
