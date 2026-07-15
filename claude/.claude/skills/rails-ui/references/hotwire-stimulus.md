# Hotwire, Stimulus, and Component Detail

## Rendering model

- Use server side rendering with Hotwire (Turbo and Stimulus).
- Do not build single page applications.
- Prefer Turbo Frames for:
  - Lazy loading expensive content (e.g. comments panels, statistics).
  - Modal flows (render forms into a `turbo_frame_tag "modal"`).
  - Inline editing (frame-wrapped partials).
- Prefer Turbo Stream broadcasts from models for real-time updates:
  - Use `after_create_commit`, `after_update_commit`, and `after_destroy_commit` to broadcast.
  - Keep controllers thin; let models broadcast updates to the relevant streams.
- Prefer morphing for complex updates:
  - Use `turbo_stream.morph` when you want to preserve focus/scroll and avoid janky replacements.
  - Consider global defaults via meta tags:
    - `turbo-refresh-method: morph`
    - `turbo-refresh-scroll: preserve`

## JavaScript stack

- Use `importmap-rails`.
- Do not use bundlers such as Webpack, esbuild, Vite or similar tools.
- Prefer native JavaScript modules.
- Stimulus controllers live in a flat folder unless there is a clear need for namespacing.

## Components and behaviour

- On the server side use ERB partials, not component frameworks.
- On the client side prefer native HTML and a small amount of JavaScript.
- Use custom elements only when they remove real duplication.
- Use progressive enhancement:
  - JavaScript is expected and should improve the experience.
  - Core flows should still work without JavaScript when possible.
- Stimulus usage rules:
  - Stimulus is for "sprinkles", not frameworks.
  - Controllers must be small and single-purpose (ideally under ~50 LOC).
  - Prefer configuration via Stimulus values/classes/targets over hardcoding.
  - Prefer Turbo over `fetch` for most interactions. If using `fetch`, include CSRF tokens and keep
    it focused on UI affordances (not business logic).
  - Always clean up event listeners/timeouts/observers in `disconnect()`.
