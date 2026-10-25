# Plan: Write the test-suite terms to GLOSSARY.md

From `intent.md` (2026-10-25). Status: accepted.

## Design

### Domain terms

The repository has no `GLOSSARY.md` yet, so no existing term conflicts. The change adds the nine terms that issue #232 lists, agreed on 2026-10-21: Binstub, Chained test, Covering test, Hook scripts, Hooks copy, Native lefthook, PATH stub, Runner, Test file. Each definition keeps the issue's meaning in one sentence. "binary" is on the `Avoid:` list of Native lefthook, so no definition uses that word: the issue's "stand-alone binary" becomes "stand-alone executable".

### Diagrams

Not affected: the change adds one markdown file and touches no objects.

### Signatures

Not affected: no code changes.

Not checked: the change has no Ruby code.

### Complexity

Not affected: the change adds one static file and no code path.

### Invariants

- Line 1 is the only top-level heading, `# Glossary`. markdownlint MD041 and MD025 enforce this.
- Each term is one bullet on one source line. The explicit `no-hardwrap` markdownlint check in `## Proof` enforces this. The lefthook `no-hardwrap` pre-commit command only warns: it exits 0 after it lints.
- The bullets are in alphabetical order, case-insensitive and byte-wise: "Hook scripts" comes before "Hooks copy" because a space sorts before "s". No linter enforces this; the check in `## Proof` and the review do.
- Only Native lefthook (`Avoid: binary.`) and Binstub (`Avoid: shim.`) have an `Avoid:` list. The check in `## Proof` and the review enforce this.

### Alternatives

1. Minimal file (chosen): a `# Glossary` heading, a blank line and nine bullets in the `glossary` skill format. It meets every acceptance criterion and passes both markdown linters.
2. Guarded file: the same file plus a new `test/glossary_file_test.rb` that checks the format, the order, the nine terms and the two `Avoid:` lists. Rejected: it contradicts the intent's constraint "the change is documentation, so it gets no test of its own" and its out-of-scope line "Any change to the tests". It also copies the skill's format into a regex, so a format change must touch two places. A format and order guard for every future entry is a separate change, if Etienne wants it.
3. File with an intro paragraph and a "Test suite" section heading. Rejected: the `glossary` skill format is a flat alphabetical list, and sections would break that when terms from other changes arrive.

## Design decisions

- The file starts with `# Glossary`. The `glossary` skill does not show a heading, but markdownlint MD041 (on in `markdownlint/.config/markdownlint/config`) requires one. A heading does not conflict with the skill format.
- Definitions start in lowercase after the em dash, as in the skill's format example.
- Runner keeps "from PR #229", because one sentence holds it.
- The plan stage writes no glossary terms. The `plan` skill's Write step 8 tells the plan stage to write agreed terms into the glossary after `commit-plan`. Here the glossary is the deliverable, and the intent's constraint gives that work to the implement stage. This follows the intent; it does not conflict with any of its `## Decisions`.

## Integration points

- The `glossary`, `intent` and `plan` skills read `GLOSSARY.md` at the repository root and challenge avoided words.
- `test/glossary_skill_test.rb` checks that `GLOSSARY.md` stays committable (not ignored). It reads no file content, so it stays green.
- The lefthook `no-hardwrap` pre-commit command lints the staged `GLOSSARY.md`. It is advisory: it exits 0, so a commit with a hard-wrapped line still succeeds.

## Files that change

- `GLOSSARY.md` (new, repository root) — the nine terms, with this exact content:

```markdown
# Glossary

- **Binstub** — the RubyGems Ruby script `lefthook` on `PATH`, which boots Ruby and then starts the native lefthook. Avoid: shim.
- **Chained test** — one test that runs the steps of several former tests in one repository and keeps every former assertion.
- **Covering test** — the test that still proves the behaviour of a deleted test.
- **Hook scripts** — the tracked scripts in `git/.config/git/hooks/`.
- **Hooks copy** — the one read-only copy of the hook scripts per test process, at which test repositories point `core.hooksPath`.
- **Native lefthook** — the Go executable: `libexec/lefthook-<os>-<arch>/lefthook` inside a gem, or a stand-alone executable such as CI's `/usr/local/bin/lefthook`. Avoid: binary.
- **PATH stub** — an executable that a test writes into its own bin directory to stand in for a tool.
- **Runner** — `bin/test`, from PR #229, which runs test files in parallel and fails when one fails.
- **Test file** — one `test/*_test.rb`, run as its own process.
```

The file is 11 lines and ends with one newline. This content passed both linter commands below in a scratch copy during planning.

## Order of work

No criterion needs a test (intent constraint: documentation gets no test of its own), so the work starts with the change.

1. Create `GLOSSARY.md` at the repository root with the content in `## Files that change`.
2. Run the checks in `## Proof`. Fix the file until each one passes.
3. Run `bin/test` once to confirm the suite stays green.
4. Commit `GLOSSARY.md` alone: `docs: glossary terms for 232-write-the-test-suite-terms-to-glossary-md`.

Out of scope: terms from other changes, any change to `test/`, `bin/test`, the hook scripts or the `glossary` skill, an ADR, and a test that guards the glossary format.

## Risks

- The alphabetical order has no automatic guard after this change. A later edit can break it. Rejected guard: alternative 2.
- A locale-aware `sort` ignores spaces and puts "Hooks copy" before "Hook scripts". The order check therefore runs with `LC_ALL=C`.
- A definition could drift from the issue's meaning while it is fitted into one sentence. The review compares each bullet with issue #232.

## Proof

- A reader finds all nine terms in `GLOSSARY.md` at the root, one bullet each → check: `grep -c '^- \*\*' GLOSSARY.md` prints `9`, and the nine terms are exactly Binstub, Chained test, Covering test, Hook scripts, Hooks copy, Native lefthook, PATH stub, Runner, Test file.
- The terms are in alphabetical order → check: `grep -o '^- \*\*[^*]*' GLOSSARY.md | sed 's/^- \*\*//' | LC_ALL=C sort -f -c` exits 0.
- Each definition is one sentence and keeps the issue's meaning; Binstub says it is the RubyGems Ruby script `lefthook` on `PATH` that boots Ruby and then starts the native lefthook → check: read each bullet against issue #232 (`gh issue view 232`).
- Native lefthook lists `Avoid: binary`, Binstub lists `Avoid: shim`, and no other term has an `Avoid:` list → check: `grep -c 'Avoid:' GLOSSARY.md` prints `2`, and `grep 'Avoid:' GLOSSARY.md` shows only those two bullets.
- The markdown linters pass on `GLOSSARY.md` → check: `markdownlint GLOSSARY.md` and `markdownlint --config ~/.config/markdownlint/no-hardwrap.json --rules ~/.config/markdownlint/no-hardwrap.cjs GLOSSARY.md` both exit 0.
- Invariant: one top-level heading on line 1, enforced by markdownlint MD041 and MD025 → check: the first linter command above.

Per changed file, the unit tests expected:

- `GLOSSARY.md`: none; documentation gets no test (intent constraint).

Test setup: none. The suite runs unchanged through `bin/test`.

---
Domain skills applied: glossary, software-design, diagrams (no diagram applies).

## Critique

### Round 1 (codex terra)

- The plan says the lefthook `no-hardwrap` command enforces one-line bullets, but it exits 0 after linting and only warns → fixed (Invariants and Integration points now call it advisory; the explicit markdownlint check in Proof stays the enforcement)
