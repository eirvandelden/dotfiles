# Review: The pushed-fixme hook test passes without the fixme check

## Round 1 — 2026-10-26T13:53:23Z — 708559fa

Nothing found.

The repository has no `REVIEW.md` or `REVIEW.local.md`; the default Bugs, Security, Compliance and Design passes ran.

- Bugs: none. The clean push and the refused push run in the same repository. The `todo.txt:1:` match pins the refusal to the `no-fixme` grep, which prints `--with-filename --line-number`.
- Security: none. The stub lives in the temporary test HOME; `lefthook.yml` and the hook scripts do not change.
- Compliance:
  - Changing the pre-push fixme pattern to the marker with an `X` appended, or to `NOSUCHMARKER`, makes the test fail → `test_pre_push_uses_global_fallback_and_rejects_a_pushed_fixme`. Checked in disposable scratch copies on 2026-10-26: the `X` mutation fails (1 failure), the `NOSUCHMARKER` mutation fails (1 failure), the unchanged pattern passes (4 assertions). `git diff lefthook.yml` in the worktree stays empty.
  - A push without the marker succeeds in the same setup → the clean-push assertion in the same test.
  - Regression first: at `14161cec` the test fails on "Expected a clean push to pass the global fallback".
  - Every Proof test exists. No existing test was weakened, skipped or deleted; the `refute` stays and gains an output match.
- Design: both changed methods carry `#: () -> void`, as `### Signatures` names them. No Law of Demeter chain, no query loop. The diff uses no glossary `Avoid:` word (shim, binary).

Checks: `ruby -Itest test/lefthook_local_hooks_test.rb` 11 runs, 0 failures. `bin/test` 87 files, 0 failed. `rubocop test/lefthook_local_hooks_test.rb` no offenses.
