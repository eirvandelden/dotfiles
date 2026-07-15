---
name: rails-api-design
description: Use when designing or implementing REST API endpoints, JSON responses, authentication, pagination, or versioning.
---

# Rails API Design

- Use REST-only controllers and routes. Never use GraphQL.
- Prefer the same controllers for HTML and JSON via `respond_to` blocks — do not create separate
  "API controllers" when `respond_to` works.
- Use Jbuilder templates for JSON responses — do not inline JSON in controllers, do not introduce
  serializer frameworks by default.
- Authentication defaults:
  - Web: session-based authentication.
  - API: token-based authentication (Bearer token). Do not rely on sessions for API auth.
- Use proper HTTP status codes (`201`, `204`, `404`, `422`, etc.).
- Pagination: when returning paginated collections as JSON, include pagination headers
  (`X-Total-Count`, `X-Total-Pages`, `X-Page`, `X-Per-Page`). Prefer simple page-based pagination
  by default; consider cursor pagination only when needed.
- API versioning: version APIs when making breaking changes, prefer URL-based versioning
  (`/api/v1/...`).
- Prefer clear and well documented endpoints over clever abstractions.

See `references/examples.md` for `respond_to` + Jbuilder + Bearer-token auth code.
