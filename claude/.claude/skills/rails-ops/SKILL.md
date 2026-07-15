---
name: rails-ops
description: Use when making deployment, error tracking, or performance monitoring decisions for a Rails app.
---

# Rails Ops

## Deployment

- Personal projects: deploy with Kamal and Docker.
- Work projects: depends on the team. Current approach: GitHub Actions CI builds a Docker image
  and deploys it to Nomad allocations. Historically Capistrano on bare metal.
- Target Debian based Linux servers.

## Error tracking

- Personal projects: prefer a simple, self-hosted error tracker when needed.
- Work projects: use Datadog as the default.

## Performance monitoring

- Use Rack Mini Profiler in development.
- Aim for render times under roughly 100 milliseconds.
- Treat anything over 250 milliseconds as a candidate for optimisation.
