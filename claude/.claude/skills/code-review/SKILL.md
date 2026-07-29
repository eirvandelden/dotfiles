---
name: code-review
description: Use when reviewing a pull request or implementing fixes requested from a code review.
---

# Code Review Workflow

When asked to review work: combine the rules found in the applicable `agents.md` (project-local,
or the `~/Developer/dotfiles/agents.md` fallback — see core playbook) with any existing review
criteria (PR description, CLAUDE.md, explicit instructions) rather than replacing them.

When asked to implement fixes for issues found during a review (e.g. "implement fixes for the
issues you've found", "verify and fix the above findings", "implement a fix for issue X"):

1. Verify each finding before touching code — confirm it is real using systematic debugging;
   write a failing test that demonstrates it where possible. Report findings that do not hold
   instead of "fixing" them.
2. Fix the verified findings (failing test first, per the playbook TDD rule).
3. Run linters on every touched file and fix all issues.
4. Run the full test suite. Only fix failures that are directly caused by your changes; do not fix
   pre-existing failures. Report any pre-existing failures explicitly.
5. If linters or tests caused by your changes cannot be made green, proceed to re-review but
   explicitly report the failures.
6. After fixes are applied, perform the review again using the same parameters.
7. Loop verify → fix → lint → test → re-review until the review is clean or you are in a
   deadlock. On deadlock, stop and explain the remaining findings instead of making
   speculative changes.

After a push (pushing itself needs explicit approval): wait for CI to finish, inspect the
results, fix any failure, and repeat until all checks are green.
