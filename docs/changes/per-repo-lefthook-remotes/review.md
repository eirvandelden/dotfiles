# Review: per-repo-lefthook-remotes

## Round 1 — 2026-11-09T08:59Z — b4b853d6

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default passes ran (Bugs, Security, Compliance, Design).

Suite: `bin/test` 104 of 105 files green. `test/secrets_loader_test.rb` fails (5 failures): the real `op` answers instead of the stub, so it is environmental. This branch touches no secrets file. `worktree_init_on_create_test.rb` 6/6 green. `rubocop`, `shellcheck` and `yamllint` are clean on the touched files. The package `rubocop/.rubocop.yml` reports RbsInline offenses on the renamed test, but the old `post_checkout_hook_test.rb` on `origin/main` already had 10 of them.

Scratch checks (lefthook 2.2.2, git 2.56.0, `GIT_CONFIG_GLOBAL=/dev/null`): a repo with the branch's `lefthook.yml` as a `file://` remote, and a small remote of its own.

- [ ] Important: The empty `reference-transaction: {}` and `post-index-change: {}` sections make lefthook print its banner and "summary: (skip) empty" on every ref update and every index write. With this branch's shared config, one `git commit` prints 12 lefthook banners, 7 of them `reference-transaction`. `git checkout -q -b` prints 14, despite `-q`. `git add` and `git status` print a `post-index-change` banner. The plan's Risks name only the speed cost. Every installed repository and every agent that reads git output gets this noise. — `lefthook.yml:420` → fixed (Leave reference-transaction and post-index-change out of the shared config)
- [ ] Important: With `reference-transaction` installed, a broken shared config blocks every ref update in every installed repository, not only commits. It stays blocked for up to 24 hours after the fix lands upstream. Scratch check: a remote config with a YAML error was fetched after `FETCH_HEAD` expired. Then `git commit` exited 128 ("update aborted by the reference-transaction hook"), and `git checkout -b` created no branch. After the remote was fixed, the next commit still failed: the fetch had made `FETCH_HEAD` fresh, so lefthook did not refetch. The plan's Risks do not name this. The README gives no recovery step (for example `LEFTHOOK=0`, then a fetch in the remote clone). — `lefthook.yml:420` → fixed (Leave reference-transaction and post-index-change out of the shared config)
- [ ] Nit: The glossary's Remote clone path is `.git/info/lefthook-remotes/<name>`. Lefthook 2.2.2 names the directory `<name>-<ref>`: the scratch remote `shared` with `ref: main` cloned to `shared-main`. — `GLOSSARY.md:21` → fixed (Fix the clone path, a retired term and a test name)
- [ ] Nit: The comment on `remove_run_root` gives the retired term "Hooks copy" as the reason for `chmod_R`. After this branch no test makes a Hooks copy. — `bin/test:56` → fixed (Fix the clone path, a retired term and a test name)
- [ ] Nit: `test_main_update_migration_hooks_pass_changed_files_to_nested_migration_hook` now also checks the keys of the `post-checkout` job, which is not what its name describes. — `test/rv_ci_fallback_test.rb:27` → fixed (Fix the clone path, a retired term and a test name)

### Compliance

Acceptance criteria from `intent.md`, with evidence. The plan proves them with scratch checks, not tests (configuration has no tests):

- The shared jobs and the repo's own jobs run on commit after one `lefthook install`: scratch check passed. Install wrote all 28 hooks, and the shared `pre-commit` job ran on commit.
- `lefthook-local.yml` overrides the shared job of the same name: scratch check passed. Only the local job's line was logged.
- The repo picks up a shared change on its first run after 24 hours: scratch check passed. With `FETCH_HEAD` aged, a commit in a linked worktree refetched, and the remote clone moved to the new commit. The repo's own refs did not change.
- A hook run without network access still commits: scratch check passed. The output had "Couldn't sync … Will continue with fallback version", and the commit was created.
- A `bundle exec` job in a linked worktree does not see `GIT_DIR`: the scratch check confirmed that jobs see `GIT_DIR` in a linked worktree. Read in the diff: `unset GIT_DIR` is in pre-commit and pre-push `erb_lint`, `minitest`, `rspec`, and both `migrations` callers. `rubocop` and `bundle-audit` already had it.
- A repo with no `lefthook.yml` and no install runs no hooks: the branch's `git/.config/git/config` sets no `core.hooksPath`, and a fresh repo's `.git/hooks` holds only samples.
- A new hook type runs after refetch with no new install: all 22 empty `{}` sections made `lefthook install` write a hook file.
- Invariant, no tracked `core.hooksPath`: `git grep hooksPath` finds only `-c core.hooksPath=/dev/null` isolation in tests.
- Invariant, `worktree-init-on-create` always exits 0: `test_still_exits_0_when_worktree_init_fails`.
- The unit tests named in the Proof list exist, renamed as planned: 6 tests.
- Deleted hook-run tests (nine files and `hook_scripts(_test).rb`): the accepted plan records this as Etienne's decision of 2026-11-08, so it is not a finding.

### Security

Nothing found. The Starter config fetches the public repository over HTTPS, so a clone needs no credential.

### Design

No Ruby public method changes, so the signature, Law of Demeter and N+1 checks have nothing to check. No glossary `Avoid:` word appears in the added lines.

## Round 2 — 2026-11-09T16:39Z — b7ef8dbc

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default passes ran (Bugs, Security, Compliance, Design). This round reads the two fix commits on top of round 1's base.

Suite: `bin/test` 104 of 105 files green; `test/secrets_loader_test.rb` fails as in round 1 (environmental, untouched). `worktree_init_on_create_test.rb` 6/6 green. `yamllint lefthook.yml` and `rubocop` on `bin/test` and `test/rv_ci_fallback_test.rb` are clean.

Scratch check (lefthook 2.2.2, `GIT_CONFIG_GLOBAL=/dev/null`, this branch as a `file://` remote): `lefthook install` writes 26 hooks, with no `reference-transaction` or `post-index-change`. `git checkout -q -b` and `git add` print no banner. One `git commit` prints 4 banners, down from 12. Round 1's three nits hold: the glossary path, the `bin/test` comment and the split test.

- [ ] Important: Commit 4241f043 reverses a recorded decision of Etienne's without a new one. The plan says "All 28 hook types lefthook 2.2.2 knows are listed … after Etienne weighed the cost of `reference-transaction`, `post-index-change` and `push-to-checkout` on 2026-11-08". The intent's Decisions say to list every git hook type. The intent's last acceptance criterion (a new hook type runs after refetch with no new install) now fails for these two types. `plan.md` still says 28 types and 22 empty sections. This delivery is step-by-step, so Etienne decides: keep the omission and record it in the plan's Design decisions and Risks, or restore the two sections. — `lefthook.yml:420` → fixed (Leave prepare-commit-msg and post-commit out of the shared config too)
- [ ] Nit: The comment above the empty sections says "Every other git hook type", and the ADR's Decision says "The shared config lists every git hook type". Both are now false; the ADR's Consequences contradict its own Decision. — `lefthook.yml:404` → fixed (Leave prepare-commit-msg and post-commit out of the shared config too)
- [ ] Nit: The empty `prepare-commit-msg` and `post-commit` sections print a lefthook banner and "summary: (skip) empty" on every commit: 2 of the 4 banners per commit. The plan's Risks do not name this noise. — `lefthook.yml:411` → fixed (Leave prepare-commit-msg and post-commit out of the shared config too)

### Compliance

Round 1's evidence still holds, except for the last acceptance criterion: see the Important finding above. The other criteria and both invariants are unchanged by the fix commits.

### Security

Nothing found. The fix commits remove config and change comments only.

### Design

No Ruby public method changes. The split test `test_post_checkout_runs_only_the_worktree_init_job` has one assertion that its name describes. No glossary `Avoid:` word appears in the added lines.

## Round 3 — 2026-11-10T08:54Z — 4821ed3a

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default passes ran (Bugs, Security, Compliance, Design). This round reads d9d62706 (two more unlisted hook types) and 4821ed3a (intent and plan updates) on top of round 2's base.

Suite: `bin/test` 104 of 105 files green; `test/secrets_loader_test.rb` fails as in rounds 1 and 2 (environmental, untouched). `worktree_init_on_create_test.rb` 6/6 green. `yamllint lefthook.yml` is clean. markdownlint did not run: the worktree has no `node_modules`. The changed markdown lines are one line each.

Scratch checks (lefthook 2.2.2, `GIT_CONFIG_GLOBAL=/dev/null`, this branch as a `file://` remote): `lefthook install` writes 24 hooks, with no `reference-transaction`, `post-index-change`, `prepare-commit-msg` or `post-commit`. `git add` and `git checkout -q -b` print no banner. One `git commit` prints 2 banners (`pre-commit`, `commit-msg`), down from 4. The amended criterion holds for a listed type: after install with an empty `pre-rebase: {}`, a `pre-rebase` job was committed to the remote and `FETCH_HEAD` aged. The next commit refetched, and the next `git rebase` ran the job with no new `lefthook install`.

Round 2's Important finding is closed: `intent.md` and `plan.md` now record Etienne's decision of 2026-11-10 in Decisions, Design decisions, Complexity and Risks, and the ADR's Decision and Consequences agree.

- [ ] Nit: The Proof check for the refetch criterion still uses `post-commit`: "right after install, `.git/hooks/post-commit` exists; then commit a `post-commit` job". `post-commit` is now unlisted, so the check fails as written. Use a listed type such as `pre-rebase`. — `docs/changes/per-repo-lefthook-remotes/plan.md:139` → fixed (docs: plan for per-repo-lefthook-remotes)
- [ ] Nit: Two docs still say `lefthook install` "writes every hook". It writes 24 of 28. The `new-repo-setup` skill is what a new repository follows. — `agents/.agents/skills/new-repo-setup/SKILL.md:23`, `git/.config/git/worktree-tools/README.md:161` → fixed (Say that lefthook install writes the listed hooks, not every hook)

### Compliance

Round 1's evidence still holds for every criterion and both invariants. The last criterion now reads "a listed hook type" and names the four unlisted types; the scratch check above proves it for `pre-rebase`. `lefthook.yml` lists 6 used and 18 empty sections, 24 in all, as the plan says.

### Security

Nothing found. The fix commit removes two empty sections and changes comments and docs only.

### Design

No Ruby public method changes. No glossary `Avoid:` word appears in the added lines.

## Round 4 — 2026-11-10T09:07Z — ea26966d

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default passes ran (Bugs, Security, Compliance, Design). This round reads dac1f551 (two docs say "writes the hooks it lists") and ea26966d (the refetch Proof check uses `pre-rebase`) on top of round 3's base.

Suite: `bin/test` 104 of 105 files green; `test/secrets_loader_test.rb` fails (5 failures) as in rounds 1 to 3 (environmental, untouched). `yamllint lefthook.yml lefthook-branch-guard.yml` is clean. The `no-hardwrap` markdownlint rule is clean on every changed markdown file.

Round 3's two nits are closed. `git grep` finds no "writes every hook", "every git hook type", "all 28" or "22 empty" outside this file. `intent.md:11` says "every hook type in the merged config", which stays true. The plan's refetch check now names `pre-rebase`, the type round 3's scratch check proved.

Nothing found.

### Compliance

Round 3's evidence still holds for every criterion and both invariants. The fix commits change docs only. `lefthook.yml` is unchanged since round 3.

### Security

Nothing found. The fix commits change docs only.

### Design

No Ruby public method changes. No glossary `Avoid:` word appears in the added lines.
