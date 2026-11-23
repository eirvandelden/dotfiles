# Delivery account: rubocop-fallback-test-gem-warnings

## Behaviour delivered

`test/rubocop_fallback_test.rb` ignores whole stderr lines that match RubyGems' `Ignoring <gem> because its extensions are not built. Try: gem pristine <name> --version <version>` warning. Any other stderr line still fails the test, and the failure message shows it. Four new tests inject stderr lines into the RuboCop child through `RUBYOPT`, so the behaviour is proven on every machine, CI included.

## Evidence

- Before the change, on this machine with an unbuilt `ffi-1.17.4`, all 16 fallback tests failed on the RubyGems warning.
- The implement stage saw both new tolerance tests fail before the fix and all 20 tests pass after it, with `ffi-1.17.4` still unbuilt.
- Round 1 fix: with a stub `rubocop` that exits 2 and `CI` unset, both rejection tests failed before the fix and skip after it.
- Round 2 fix: under `RUBYOPT=-W0`, both rejection tests failed before the fix and pass after it.

## Check results

- `bin/test`: 130 files, 0 failed (recorded at 60259134).
- `rubocop test/rubocop_fallback_test.rb`: no offenses (recorded at 1d362ffd).
- `ruby -Itest test/rubocop_fallback_test.rb`: 20 runs, 105 assertions, 0 failures, 0 skips.
- No Brakeman or Bundler Audit: the repository has no `Gemfile.lock`.

## Review outcome

- Round 1 (b85a544b): one Important finding (the rejection tests caught a `Minitest::Skip`), one Nit (missing `inject_stderr` signature). Both fixed in 3d4e80db.
- Round 2 (3d4e80db): one Nit (`warn` writes nothing under `-W0`). Fixed in 1d362ffd.
- Round 3 (1d362ffd): no findings.
- No Codex review round: `intent.md` records `Codex review: no`.

## Limitations

- `ffi-1.17.4` was rebuilt outside this delivery before the final runs. The real unbuilt-gem case was verified earlier; the final runs rely on injected warnings.
- The term "unbuilt-extensions warning" from `plan.md` is not in `GLOSSARY.md`.
- The test-first commit did not land separately: the first commit attempt failed its RuboCop hook under system Ruby, so tests and fix share commit b85a544b. The red run is recorded in the implement report only.
