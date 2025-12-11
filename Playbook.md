# Etienne van Delden – Personal and Work Rails Playbook

Snapshot: latest revision including method design and naming rules and AI
instructions.

## 0. How to Read This Playbook

- Personal: applies to personal projects.
- Work: applies to professional and Nedap projects.
- Both: applies to all projects.
- If an item differs per scope, both are listed.

## 1. Core Philosophy

### 1.1 Principles

- Use Domain Driven Design and SOLID.
- Prefer intention revealing names.
- Short names are fine in hot paths.
- Longer names are fine in less used code.

### 1.2 Layout and Formatting

- Target a maximum line length of 120 characters.
- Keep classes under roughly 100 lines.
- Use blank lines between methods.
- Group related private methods together.
- Use explicit `private` and `protected` sections.
- Avoid abbreviations unless they are universal (for example `id`, `url`,
  `api`).

## 1.3 Method Design and Naming (Ruby)

### Single responsibility

- Each method should do exactly one thing.
- The name of the method should reflect that single purpose.
- If a method starts to do more than one job, extract helper methods.

### Bang methods (`!`)

- Methods that end in `!` are considered unsafe.
- Unsafe means they mutate the receiver or behave more dangerously than a
  corresponding safe variant.
- There should normally be a safe variant without `!` when a `!` method exists.

### Predicate methods (`?`)

- Methods that end in `?` must always return a boolean value.
- Predicate methods must never change state or have side effects.
- They should be pure queries about an object.

## 2. Rendering and Front End

### 2.1 Rendering model

- Use server side rendering with Hotwire (Turbo and Stimulus).
- Do not build single page applications.

### 2.2 JavaScript stack

- Use `importmap-rails`.
- Do not use bundlers such as Webpack, esbuild, Vite or similar tools.
- Prefer native JavaScript modules.
- Stimulus controllers live in a flat folder unless there is a clear need
  for namespacing.

### 2.3 Components and behaviour

- On the server side use ERB partials, not component frameworks.
- On the client side prefer native HTML and a small amount of JavaScript.
- Use custom elements only when they remove real duplication.
- Use progressive enhancement:
  - JavaScript is expected and should improve the experience.
  - Core flows should still work without JavaScript when possible.

### 2.4 Accessibility

- Aim for good contrast, keyboard navigation and semantic HTML.
- Use browser tools to simulate colour blindness and to check contrast.
- Prefer simple and predictable interactions over flashy ones.

## 3. CSS

### 3.1 Processing and architecture

- Use plain CSS files.
- Do not use Sass or PostCSS.
- Follow a SMACSS style structure for CSS organisation.

### 3.2 Base stack

- Start with a modern `normalize.css` (for example from Josh W Comeau).
- Layer `mvp.css` for sensible defaults.
- Add project specific CSS on top.

## 4. Assets and Deployment

### 4.1 Asset pipeline

- Use Propshaft for assets.
- Serve assets directly from Rails.
- Do not use a CDN by default.

### 4.2 Third party assets

- Avoid npm in new projects.
- Prefer CDN delivered scripts and styles.
- If a build step is unavoidable, do a one off build outside the project and
  commit the generated file to the repository.

### 4.3 Deployment

- Personal projects:
  - Deploy with Kamal and Docker.
- Work projects:
  - Depends on the team.
  - Historically Capistrano on bare metal.
- Target Debian based Linux servers.

## 5. Testing

### 5.1 Framework choice

- Personal projects:
  - Use Minitest and aim for idiomatic Ruby tests.
- Work projects:
  - Use RSpec and follow advice from betterspecs.org.

### 5.2 Style

- Think in behaviour driven terms, even when using Minitest.
- Focus on observable behaviour and outcomes.

### 5.3 Data setup

- Personal projects:
  - Prefer Rails fixtures.
- Work projects:
  - Comfortable using FactoryBot.

### 5.4 Front end tests

- Use `@hotwired/stimulus-testing` for Stimulus controllers.
- Run JavaScript tests with Jest in a separate repository or folder.
- Use Capybara system tests for Hotwire flows.

## 6. Error Handling and Observability

### 6.1 Error handling

- Raise errors freely when something goes wrong.
- Rescue at higher layers so users do not see raw exceptions.
- Return user friendly error pages.

### 6.2 Error tracking

- Personal projects:
  - Prefer a simple, self hosted error tracker when needed.
- Work projects:
  - Use Datadog as the default.

### 6.3 Performance monitoring

- Use Rack Mini Profiler in development.
- Aim for render times under roughly 100 milliseconds.
- Treat anything over 250 milliseconds as a candidate for optimisation.

## 7. Data and Persistence

### 7.1 Integrity and modelling

- Use database constraints for hard rules.
- Mirror those constraints with Rails validations.
- Use concerns to share behaviour and reduce model size.

## 8. Documentation and Security Tooling

### 8.1 Documentation

- Write YARD comments for Ruby code.
- Use YARD style comments for other languages where it fits.
- Let Solargraph use these comments for better editor support.
- Keep READMEs up to date with setup and deployment instructions.

### 8.2 Security tooling

- Run Bundler Audit regularly and before pushes.
- Run Brakeman regularly and before pushes.
- Always use strong parameters in controllers.

## 9. Tooling and Editor Setup

### 9.1 Editors

- Primary editor is Nova on macOS.
- Secondary editors are Zed and VS Code.
- Use VS Code mainly when debugging with RDBG.

### 9.2 Language servers

- Use Solargraph as the default Ruby language server.
- Experiment with Ruby LSP but do not assume it is always available.

### 9.3 Ruby management

- Use `chruby` with `ruby-install`.
- Do not use RVM or rbenv in new setups.

### 9.4 Linters and formatters

- Use RuboCop for Ruby.
- Use `scss-lint` for SCSS when it appears in legacy code.
- Use Herb and cspell where they add value.

### 9.5 Git hooks and continuous integration

- Run Bundler Audit before pushing.
- Run Brakeman before pushing.
- Expect continuous integration to run the full test suite.

## 10. Application UX and API

### 10.1 Forms and validation

- Use HTML5 validation attributes where useful.
- Always validate on the server as the source of truth.
- Show clear error messages next to fields.

### 10.2 API design

- Use RESTful controllers.
- Avoid GraphQL by default.
- Prefer clear and well documented endpoints over clever abstractions.

### 10.3 Internationalisation

- Use Rails i18n YAML files.
- Do not hardcode strings in templates or Ruby code.
- Default to English text when another language is not specified.

## 11. Open Questions

These areas are intentionally left open and should be decided per project.

- Front end performance budget:
  - Decide LCP, bundle size and Lighthouse targets.
- Authentication:
  - Choose between Devise sessions, JWT or external providers such as Auth0.
- Continuous integration and delivery:
  - Choose between GitHub Actions, GitLab CI and other options.
- Front end documentation:
  - Decide whether to use Storybook, zeroheight or rely on code and tests.
- Onboarding:
  - Identify common blockers that prevent a new developer from opening a pull
    request within about one hour.
- Linting stack:
  - Finalise a modern HTML, CSS and JavaScript linting setup that works
    without bundlers.
- Architecture direction:
  - Decide whether projects remain monoliths or might extract services later.

## 12. Instructions to AI Models

When an AI model generates code or suggestions for Etienne van Delden, it
should follow these rules.

1. Always consult this playbook before assuming defaults.
2. Respect the scope for personal, work or both.
3. Do not suggest React, Vue, Tailwind, SPA patterns or bundlers.
4. Assume Hotwire with server side rendering and `importmap-rails`.
5. Use SMACSS, normalize CSS, MVP.css and plain CSS.
6. Use native ES modules and Stimulus for JavaScript.
7. Default testing choices:
   - Personal projects use Minitest and fixtures.
   - Work projects use RSpec and FactoryBot.
8. Prefer REST controllers and ERB partials for views.
9. Consider accessibility and WCAG in suggestions.
10. Avoid npm unless Etienne explicitly asks for it.
11. Mention Propshaft for assets and Kamal for personal deployments when
    relevant.
12. Ask for clarification when the playbook does not define something.
13. Always document classes and methods with YARD or similar comments.
14. Follow layout rules:
    - Try to keep lines under 120 characters.
    - Keep classes under roughly 100 lines.
    - Group related private methods below a clear `private` section.
15. Follow naming rules:
    - Avoid abbreviations unless they are universal and obvious.
16. Apply Ruby method semantics:
    - Methods should have one clear purpose.
    - Methods that end in `!` are unsafe and usually mutate state.
    - Methods that end in `?` return booleans only and never change state.
