# Review: Write the test-suite terms to GLOSSARY.md

## Round 1 — 2026-10-25T12:21:23Z — a3a50650

No findings.

- Bugs: none. `GLOSSARY.md` is byte-identical to the content in `plan.md`'s `## Files that change`.
- Security: none. The change is one markdown file.
- Compliance: every acceptance criterion holds.
  - Nine terms, one bullet each, alphabetical → `grep -c '^- \*\*'` prints 9; `LC_ALL=C sort -f -c` exits 0.
  - One-sentence definitions keep the meaning of issue #232 → each bullet read against `gh issue view 232`; Binstub names the RubyGems Ruby script `lefthook` on `PATH` that boots Ruby and then starts the native lefthook.
  - `Avoid:` only on Native lefthook (binary) and Binstub (shim) → `grep -c 'Avoid:'` prints 2, on those two bullets.
  - Markdown linters pass → `markdownlint` and the `no-hardwrap` rule both exit 0 on `GLOSSARY.md`, `intent.md` and `plan.md`.
  - No test was weakened, skipped or deleted; the intent gives documentation no test of its own. `bin/test`: 87 files, 0 failed.
- Design: no code, so no signatures, Law of Demeter or N+1 concerns. No avoided word appears outside its own `Avoid:` list and the change folder's quotes of it.
