---
name: object-oriented-design
description: >-
  Use when designing or reviewing object-oriented code in any language — class or method
  responsibilities, dependency injection, composition vs inheritance, Law of Demeter, or resisting
  an anemic-model-plus-service-layer design.
---

# Object-Oriented Design

Framework- and language-agnostic design principles (Sandi Metz). These apply regardless of
whether the code is Ruby, Rails, Python, Go, TypeScript, or anything else — they're not Rails
conventions, they're general OOP discipline.

## Prefer rich objects over anemic models + service layers

Business logic belongs on the object that owns the data, not in a separate orchestrating class.
Anemic objects (data bags with no behavior) plus a scattered layer of service/manager/helper
classes around them tend to: hide business logic in hard-to-find places, violate single
responsibility (the object should own its behavior), and add indirection without benefit.

If something feels like it needs orchestration, in order of preference:

1. A method on the object that owns the behavior
2. Shared behavior via composition (a mixin/module/trait — not inheritance)
3. A dedicated object representing the state or transition itself, instead of a boolean flag
4. An existing application boundary that delegates to rich objects, not a new service/manager class
5. A stateless helper, only for presentation/formatting — never for business rules

See `references/examples.md`. For how this maps onto Rails specifically (concerns, ActiveJob,
state records as ActiveRecord associations), see the `rails-architecture` skill.

## Tell, Don't Ask

Tell objects what to do rather than querying their state and then deciding what to do with it from
outside. Decisions about an object's state should live inside that object.

## Dependency Injection

Inject collaborators rather than hard-coding them inside a constructor/initializer. Use
keyword/named arguments with sensible defaults so callsites stay clean and objects stay easy to
test and swap.

## Composition over inheritance

Prefer composing behaviour through mixins/modules and delegation over deep inheritance
hierarchies. Inheritance is appropriate for a genuine, stable is-a relationship (a specialised
subclass that never changes what it is); use composition for shared, cross-cutting behaviour.

## Law of Demeter

Only talk to your immediate neighbours — avoid reaching through a chain of objects. If you're
writing `a.b.c`, the middle object (`b`) should expose what you need directly, either by delegating
or wrapping.

## Model actions as resources, not ad hoc procedures

Prefer expressing behavior as resources with standard verbs (create/read/update/delete-style
operations) over bespoke, one-off procedures bolted on for each new action. Model a state
transition as its own resource/object rather than a boolean flag or a custom RPC-style call. This
applies whether the interface is Rails routes, a Django REST endpoint, a plain HTTP handler in Go,
or an internal library's public API. For the Rails-specific mechanics (nested resource routes, the
standard seven controller actions), see the `rails-architecture` and `rails-api-design` skills.

See `references/examples.md` for a worked example of each principle above.
