---
name: code-review
description: Use when reviewing a pull request or implementing fixes requested from a code review.
---

# Code Review Workflow

When asked to review work: combine the rules found in the applicable `agents.md` (project-local,
or the `~/Developer/dotfiles/agents.md` fallback — see core playbook) with any existing review
criteria (PR description, CLAUDE.md, explicit instructions) rather than replacing them.

When asked to implement fixes for issues found during a review (e.g. "implement fixes for the
issues you've found", "please fix the issues you've found", "implement a fix for issue X"):

1. Run linters on every touched file and fix all issues.
2. Run the full test suite. Only fix failures that are directly caused by your changes; do not fix
   pre-existing failures. Report any pre-existing failures explicitly.
3. If linters or tests caused by your changes cannot be made green, proceed to re-review but
   explicitly report the failures.
4. After fixes are applied, perform the review again using the same parameters.
5. Explicitly report whether new issues were found or whether the re-review is clean.
