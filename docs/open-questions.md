# Open Questions

Areas intentionally left open, to be decided per project. Not rules — nothing here constrains a
coding session, which is why it lives outside the always-read playbook.

- Front end performance budget: LCP, bundle size, Lighthouse targets.
- Authentication: web stays session-based, API stays Bearer token; external providers (Auth0 etc.)
  only when required.
- Continuous integration and delivery: GitHub Actions vs GitLab CI vs other options.
- Front end documentation: Storybook, zeroheight, or rely on code and tests.
- Onboarding: identify common blockers that prevent a new developer from opening a pull request
  within about one hour.
- Linting stack: finalise a modern HTML, CSS, and JavaScript linting setup that works without
  bundlers.
- Architecture direction: monoliths vs extracting services later.
