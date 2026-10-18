# Review: replace-yarn-with-npm

## Round 1 — 2026-10-17T09:01Z — a135f0c9 (codex)

- [ ] Important: The globally installed dependencies skill says "Node: use npm, not yarn", which conflicts with the unchanged work repos that stay on yarn — `agents/.agents/skills/dependencies/SKILL.md:13` → fixed (Scope the npm rule to personal repos)

## Round 2 — 2026-10-17T09:20Z — a135f0c9 (claude)

Acceptance criteria for Phase 0: the `dependencies` skill says npm, not yarn, proven by the grep check in `plan.md`; the lefthook behaviour is proven by the pull-hook and local-hook tests named in `plan.md`. Every test named for Phase 0 exists. No test was weakened, skipped or deleted. `test/lefthook_pull_hooks_test.rb` ran green (16 runs, 0 failures). `test/lefthook_local_hooks_test.rb` ran green too (15 runs, 0 failures, about 14 minutes), including the two new `npx --no` tests. The criteria for the repos in Phases 1-9 are not in this diff.

- [ ] Nit: `command_log_path` is a one-line wrapper around `@log_file`, and the new tests could use `@log_file` directly like the rest of the file — `test/lefthook_pull_hooks_test.rb:281` → fixed (test: drop the command_log_path wrapper)
- [ ] Nit: `npx --no` cannot resolve linters in a yarn Plug'n'Play work repo that loads this shared config, where `yarn stylelint` could. Plan accepts yarn node_modules repos only; note it or confirm no PnP repo uses the remote — `lefthook.yml:11` → dismissed: no repo uses Plug'n'Play; the work repos set nodeLinker: node-modules and none has a .pnp.cjs

Round 1's open finding (skill wording versus yarn work repos) stands; no duplicate raised.

## Round 3 — 2026-10-18T08:00Z — 9636830b (codex)

No findings.

## Round 4 — 2026-10-18T08:48Z — 9636830b (claude)

No findings.
