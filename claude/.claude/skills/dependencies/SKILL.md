---
name: dependencies
description: Use when adding, removing, or upgrading a gem, npm package, or any other dependency — gem sources, version constraint style, personal gems from GitHub, Dependabot config, and the never-skip-a-major upgrade rule.
---

# Dependencies and Versioning

Approval comes first: never add or remove a dependency without asking, and the request must
explain why it is needed and what it does (core playbook, rule 11).

## Sources

- Personal: Gemfile source is `gem.coop`, not rubygems.org.
- Node: use yarn, not npm. Prefer a gem over adding a JavaScript dependency.

## Version constraints

- Do not pin gem versions by default; let them update.
- When a constraint is needed, use major.minor (`~> 9.3`) and no upper bound.
- Add an upper bound only when something actually breaks.

## Personal gems

Reference personal gems from GitHub without a version restriction:

```ruby
gem "mvpa-css", github: "eirvandelden/mvpa.css"
```

They are versioned by git SHA, not semver tags. The same applies to
`rubocop-eirvandelden`.

## Dependabot

Minimal config, all ecosystems, all update types, cooldown of 1 week.

## Upgrades

- Never skip major versions. Rails 6 → 7 → 8, step by step.
- Fix deprecation warnings as part of the work instead of leaving them behind.
- Never run `bundle update` for all gems without explicit instruction. Prefer
  `bundle update <specific-gem>`.
