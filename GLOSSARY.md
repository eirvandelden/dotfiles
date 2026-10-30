# Glossary

- **Binstub** — the RubyGems Ruby script `lefthook` on `PATH`, which boots Ruby and then starts the native lefthook. Avoid: shim.
- **Chained test** — one test that runs the steps of several former tests in one repository and keeps every former assertion.
- **Covering test** — the test that still proves the behaviour of a deleted test.
- **Fixture copy** — one test's own copy of the original, with every git path repointed into the copy.
- **Git fixture** — the git repositories that one test file builds once and then copies for each test. Avoid: template, shared repo.
- **Hook scripts** — the tracked scripts in `git/.config/git/hooks/`.
- **Hooks copy** — the one read-only copy of the hook scripts per test process, at which test repositories point `core.hooksPath`.
- **Native lefthook** — the Go executable: `libexec/lefthook-<os>-<arch>/lefthook` inside a gem, or a stand-alone executable such as CI's `/usr/local/bin/lefthook`. Avoid: binary.
- **Original** — the directory a git fixture's build block fills once per process; no test gets its path. Avoid: template, seed.
- **PATH stub** — an executable that a test writes into its own bin directory to stand in for a tool.
- **Run root** — the one `dotfiles-test*` directory the Runner makes per run, the `TMPDIR` of every test file, removed at the end of the run.
- **Runner** — `bin/test`, from PR #229, which runs test files in parallel and fails when one fails.
- **Scope** — which secrets `unlock` and `secrets` load: `personal`, `work` or `both`.
- **Scope menu** — the numbered list "cancel, personal, work, both" that a bare `unlock` or `secrets` shows on a terminal.
- **Test file** — one `test/*_test.rb`, run as its own process.
