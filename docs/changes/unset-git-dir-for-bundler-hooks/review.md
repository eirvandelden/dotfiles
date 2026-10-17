# Review: unset-git-dir-for-bundler-hooks

## Round 1 — 2026-10-17T06:00Z — eb0dc9d2 (codex)

No findings. Codex ran the guard, refresh and Bundler hook tests; all passed.

## Round 2 — 2026-10-17T06:03Z — eb0dc9d2 (claude)

Bugs and Security: no findings in `lefthook.yml` or `lefthook-remotes-refresh`. The refresh command passes git arguments as an array, clears the hook variables and disables terminal prompts. Ran the guard, refresh, Bundler and RuboCop git gem tests (31 runs, all green), RuboCop on the changed Ruby files and `yamllint lefthook.yml`: clean. The full suite (`test/*_test.rb`) passes.

Compliance: every intent criterion maps to a named test in `plan.md`'s Proof, and each named test exists. `test/lefthook_rubocop_git_gem_test.rb` keeps all six tests unchanged. Live proof state: sticker-app `update-dependencies` matches its upstream, and the sticker-app cache is on `main` at `73268db2`, an ancestor of current `origin/main` with the same `lefthook.yml`.

- [ ] Nit: the guard reads only each hook's `commands:` map. Lefthook 2.2.2 (installed here) also runs jobs declared under a hook's `jobs:` list, so a Bundler job added there passes the "fails closed" guard unseen. Read `jobs:` entries too (name, or index when unnamed), or fail on any hook that has a `jobs:` key — `test/lefthook_git_dir_guard_test.rb:91` → fixed (test: the GIT_DIR guard reads lefthook jobs lists and groups)

## Round 3 — 2026-10-17T06:25Z — 2e27b7f6 (codex)

No findings. Codex ran the refresh, guard and Bundler hook tests; all passed.

## Round 4 — 2026-10-17T06:47Z — 2e27b7f6 (claude)

No findings. The repository has no `REVIEW.md`, so this round ran the default Bugs, Security and Compliance passes.

Bugs and Security: no findings in `lefthook.yml`, `lefthook-remotes-refresh` or the guard. Every Bundler job (`erb_lint` ×2, `brakeman`, `minitest`, `rspec`, `migrations` `bundle` and `migrate`) clears the hook variables, and `: {files}` stays first in the `migrations` jobs. The guard now reads `commands:`, `jobs:` lists and nested groups, which closes the round 2 nit. The refresh command passes git arguments as an array, removes the hook variables and disables terminal prompts.

Compliance: each acceptance criterion maps to a named test in `plan.md`'s Proof, and each named test exists. `test/lefthook_rubocop_git_gem_test.rb` only moved its fixture into `test/git_gem_fixture.rb`. Checks: the full suite (`test/*_test.rb`, `|| exit 1`) is green. RuboCop on the six changed Ruby files and `yamllint lefthook.yml` are clean. Live proof state: sticker-app `update-dependencies` matches its upstream. The sticker-app cache is on `main` at `73268db`, an ancestor of `origin/main` with the same `lefthook.yml`.
