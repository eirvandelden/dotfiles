---
name: rails-architecture
description: Use when designing or reviewing Rails domain models — where business logic and state transitions should live in an ActiveRecord/Rails app specifically.
---

# Rails Architecture

Rich domain models by default. Business logic lives in models, not in separate service classes.
This skill covers Rails-specific mechanics; the underlying design principles (Tell Don't Ask,
Dependency Injection, Composition over Inheritance, Law of Demeter — these apply in any language,
not just Rails) live in the `object-oriented-design` skill.

## Never use service objects (Rails mechanics)

Service objects are NOT the correct pattern in any situation. If something feels like it needs
orchestration, use these instead, in order of preference:

1. A model method (always try this first)
2. A concern (for horizontal behaviour shared across models)
3. A state record (see "State as records" below)
4. An ActiveJob worker running inline (when cross-model orchestration is genuinely needed)
5. A PORO only for presentation/view helpers, never for business logic

This is the Rails-specific version of the general "rich object over anemic model + service layer"
principle — see `object-oriented-design` for the reasoning. See `references/examples.md` here for
the Rails before/after code (concerns, ActiveJob).

## Controller and view object rule

Controllers should instantiate only one object. Views should only know about one instance variable
and should only send messages to that object. Let the model (or a presenter built on one model)
provide everything the view needs. See `references/examples.md`.

## Resource modeling ("everything is CRUD" in Rails)

Avoid non-RESTful controller actions beyond the standard seven. Model state transitions as nested
resources (e.g. `resource :closure` for close/reopen with POST/DELETE) instead of custom actions.
This is the Rails-specific mechanics for the general "model actions as resources" principle in
`object-oriented-design`.

## Concerns and data/persistence

- Use database constraints for hard rules; mirror them with Rails validations.
- Prefer database column defaults over application-level defaults (`change_column_default` in a
  migration) so every entry point — console, rake tasks, app code — gets the same default.
- Rich models by default: put domain behavior (commands and predicates) on the model that owns the
  state. Prefer explicit verbs for actions (`publish`, `archive`, `close`) and predicates for
  queries (`closed?`, `assigned_to?`).
- Horizontal behaviour concerns: encapsulate reusable cross-cutting behaviours (e.g. `Closeable`,
  `Watchable`, `Assignable`, `Eventable`, `Broadcastable`).
- State as records (prefer over booleans where it clarifies behavior): represent state transitions
  as associated records (e.g. `Closure`) instead of boolean columns like `closed: true`. Use
  `where.missing(:association)` / joins-based scopes for open/closed-style querying.
- Use `Current.user` / `Current.account` for request-scoped defaults and model methods that need
  the acting user/account.
- Async vs sync side effects: use `_later` for job-enqueued versions and `_now` for synchronous
  versions (`notify_recipients_later` vs `notify_recipients_now`).

See `references/examples.md` for the state-as-records and `_later`/`_now` code.

## Method style and layout

Rule specifics (single responsibility, bang/predicate methods, guard clauses, line length,
class/method size) live in the core playbook — they apply broadly enough to stay always-loaded.
See `references/examples.md` for the guard-clause example.

## Documentation

- Write YARD comments for Ruby code (Solargraph uses these for editor support). Keep documentation
  concise and direct — speak directly about the thing being documented ("Represents a card in a
  board"), never verbose patterns like "Domain model for Card".
- For Rails controller actions, use custom YARD tags `@action` (HTTP method) and `@route` (URL
  path) to document routing. See `references/examples.md`.
