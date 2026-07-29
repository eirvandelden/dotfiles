---
name: rails-ui
description: Use when working on views, Hotwire/Stimulus/Turbo, CSS, HTML structure, forms, i18n strings, accessibility, or UI interaction/dialog patterns.
---

# Rails UI

Server-side rendering with Hotwire (Turbo + Stimulus). No single page applications.

## Rendering and JavaScript

- Prefer Turbo Frames for lazy-loaded content, modal flows (`turbo_frame_tag "modal"`), and inline
  editing.
- Prefer Turbo Stream broadcasts from models (`after_create_commit` etc.) for real-time updates —
  keep controllers thin.
- Prefer `turbo_stream.morph` for complex updates to preserve focus/scroll.
- JS stack: `importmap-rails`, no bundlers (Webpack/esbuild/Vite), native JS modules. Stimulus
  controllers flat unless namespacing is clearly needed.
- ERB partials, not component frameworks. Native HTML + a small amount of JS. Progressive
  enhancement: JS improves the experience, core flows still work without it where possible.
- Stimulus is for "sprinkles", not frameworks: controllers small and single-purpose (~50 LOC),
  configure via values/classes/targets, prefer Turbo over `fetch`, always clean up
  listeners/timeouts/observers in `disconnect()`.

Full Hotwire/Stimulus/Turbo detail: `references/hotwire-stimulus.md`.

## CSS and assets

- Plain CSS files, no Sass/PostCSS. SMACSS-style organisation. Layer a modern `normalize.css`
  (e.g. from Josh W Comeau) + `mvp.css` + project-specific CSS on top.
- Personal apps load shared styling from the `mvpa-css` gem
  (`gem "mvpa-css", github: "eirvandelden/mvpa.css"`). Never copy its CSS into an app. Before
  writing custom CSS, check what mvpa already provides — and prefer fixing the HTML to match
  what mvpa expects over adding CSS. CSS useful to more than one app belongs upstream in
  mvpa.css (with an example in its `demo.html`), not in the app.
- SMACSS folders live under `app/assets/stylesheets/`, prefixed with a number (`1_base/`,
  `2_modules/`, …) so they load in SMACSS order. No loose top-level CSS files; never flatten
  the CSS into a single file.
- A component file styles its own component only — never restyle global layout (`body`,
  `main`) from a component. Target elements by class or data attribute, not by id.
- All sizes in `rem` — never `px`, and not `em`.
- Theme variants override CSS custom properties; never duplicate hardcoded hex values per theme.
- Dark mode follows the browser: `prefers-color-scheme` in CSS, no JS.
- Use Propshaft, serve assets directly from Rails, no CDN by default.
- Avoid npm in new projects — prefer CDN-delivered scripts/styles. If a build step is unavoidable,
  do a one-off build outside the project and commit the generated file.

## HTML and accessibility

- Prefer semantic HTML elements over divs (`<header>`, `<nav>`, `<main>`, `<article>`, `<section>`,
  `<aside>`, `<footer>`, `<figure>`/`<figcaption>`, `<details>`/`<summary>`, `<time>`, `<address>`,
  `<mark>`). Use divs only when no semantic element fits.
- Personal projects: prefer classless HTML, let CSS target via elements/attributes, add classes
  only when semantic targeting is insufficient (pairs naturally with `mvp.css`).
- Work projects: use classes when team conventions/design systems require them, semantic elements
  still the foundation.
- Aim for good contrast, keyboard navigation, semantic HTML. Simulate colour blindness / check
  contrast with browser tools. Prefer simple, predictable interactions over flashy ones.
- Personal projects: emoji over SVG icons — and sprinkle appropriate emoji to keep the app fun.
- Single-line fields (names, titles) are plain text inputs — never a rich text editor.

## Forms and i18n

- Use HTML5 validation attributes, always validate on the server as the source of truth, show
  clear errors next to fields.
- NEVER hardcode a user-facing string anywhere — every string shown to a user must be a
  translation key. Personal projects use Rails i18n (YAML); work projects use gettext.
- Work projects: after adding or updating translated strings, run `bin/verify-translations`
  before considering the change done.

Full i18n namespacing/fallback conventions: `references/i18n.md`.

## UI interaction and dialog rules

Button placement, color semantics, confirmation dialogs, progressive disclosure, and other
interaction-design rules (based on Apple's macOS dialog guidance): `references/interaction-design.md`.
