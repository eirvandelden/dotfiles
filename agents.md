# Etienne van Delden – Personal and Work Rails Playbook

Snapshot: latest revision including Sandi Metz rules, OOP principles (Tell Don't Ask,
Dependency Injection, Composition over Inheritance, Law of Demeter), and AI instructions.

## 0. How to Read This Playbook

This document is the single source of truth for all code and suggestions — for humans and AI
agents alike. Read and apply every section before producing output.

- Personal: applies to personal projects.
- Work: applies to professional and Nedap projects.
- Both: applies to all projects.
- If an item differs per scope, both are listed.

## 1. Core Philosophy

### 1.0 Sources and Influences

The practices in this playbook are shaped by:

- **37signals** — Rails conventions, "everything is CRUD", opinionated defaults, and open-source
  tools such as Hotwire, Turbo, Stimulus, Kamal, Solid Queue/Cache/Cable, and the ONCE products.
- **thoughtbot** — Testing discipline, clean Ruby, and guides such as
  [thoughtbot/guides](https://github.com/thoughtbot/guides).
- **Sandi Metz** — Object-oriented design rules: small classes, short methods, limited parameters,
  Tell Don't Ask, Dependency Injection, and the Law of Demeter.

### 1.1 Principles

- Use Domain Driven Design, Rails convention/CRUD modeling, and SOLID principles.
- Apply “everything is CRUD”:
  - Prefer modeling behavior as resources over adding custom actions.
  - Avoid non-RESTful controller actions beyond the standard seven actions.
  - State transitions should usually be modeled as nested resources (e.g.
    `resource :closure` for close/reopen with POST/DELETE).
  - See also: §7.1 “Everything is CRUD (modeling discipline)”.
- Personal projects:
  - Prefer the Solid trifecta by default (Solid Queue, Solid Cache, Solid
    Cable) rather than introducing Redis/Sidekiq/etc.
  - See also: §4.3 (Kamal deployment) and §7.1 (Solid Queue/Cache defaults).
- Prefer incremental refactoring over rewrites:
  - Make small steps, keep tests green, and use feature flags for risky migrations and behavior changes.
- Prefer intention revealing names.
- Short names are fine in hot paths.
- Longer names are fine in less used code.
- Default to rich domain models:
  - Business logic lives in models, not in separate service classes.
  - NEVER use service objects. Service objects are NOT the correct pattern in any situation. If something feels like it needs orchestration, use these patterns instead (in order of preference):
    - A model method (always try this first)
    - A concern (for horizontal behaviour shared across models)
    - A state record (see 7.1 for modeling state transitions as resources)
    - An ActiveJob worker running inline (when cross-model orchestration is genuinely needed)
    - A PORO only for presentation/view helpers, never for business logic
- Use concerns for composition:
  - Prefer horizontal behaviour concerns over inheritance.
  - It is acceptable for a model to include many concerns, as long as each concern has one clear responsibility.

Example (avoid service objects, prefer rich models):

```ruby
# ❌ Don't: service object for domain behaviour
class CloseCardService
  def initialize(card, user)
    @card = card
    @user = user
  end

  def call
    ActiveRecord::Base.transaction do
      closure = @card.create_closure!(user: @user)
      @card.track_event("card_closed", user: @user)
      NotifyRecipientsJob.perform_later(@card)
    end
  end
end

# ✅ Do: rich model method
class Card < ApplicationRecord
  include Closeable

  def close(user: Current.user)
    create_closure!(user: user)
    track_event "card_closed", user: user
    notify_recipients_later
  end
end

# ✅ For complex cross-model orchestration, use an ActiveJob running inline
class ProcessOrderJob < ApplicationJob
  def perform(order)
    order.process_payment
    order.allocate_inventory
    order.notify_customer
  end
end

# In controller or model:
ProcessOrderJob.perform_now(order)
```

### 1.1.1 Why Never Service Objects?

Service objects extract business logic away from domain models, leading to:

- Anemic domain models (data bags without behavior)
- Scattered business logic that's hard to find and maintain
- Violation of single responsibility (the model should own its behavior)
- Unnecessary indirection and ceremony

If you think you need a service object:

1. First, add the method to the relevant domain model
2. If it's shared behavior, extract a concern
3. If it's a state transition, model it as a resource
4. If it genuinely orchestrates multiple models, use an ActiveJob running inline
5. Never reach for a service object - they are not part of this architecture

### 1.2 Layout and Formatting

- Target a maximum line length of 120 characters.
- Keep classes under roughly 100 lines.
- Target methods to be 5 lines; keep them under 10 lines.
- Pass no more than 4 parameters into a method. Hash options count as one parameter.
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

## 1.4 Tell, Don't Ask

- Tell objects what to do rather than querying their state and then deciding what to do with it.
- Decisions about an object's state should live inside that object.

Example:

```ruby
# ❌ Don't: ask for state, then act on it from outside
if card.closed?
  card.reopen
end

# ✅ Do: tell the object what to do
card.reopen

# The object handles its own guard internally
def reopen
  return if open?
  destroy_closure!
end
```

## 1.5 Dependency Injection

- Inject collaborators rather than hard-coding them inside `initialize`.
- This makes objects easier to test and swap out.
- Use keyword arguments with sensible defaults so callsites stay clean.

Example:

```ruby
# ❌ Don't: hard-coded collaborator
class NotificationSender
  def initialize(user)
    @mailer = UserMailer
    @user = user
  end
end

# ✅ Do: inject the collaborator, default to the real one
class NotificationSender
  def initialize(user, mailer: UserMailer)
    @mailer = mailer
    @user = user
  end
end
```

## 1.6 Prefer Composition Over Inheritance

- Prefer composing behaviour through concerns and delegation over deep inheritance hierarchies.
- Inheritance is appropriate when there is a genuine, stable is-a relationship (e.g. a specialised
  subclass that never changes what it is).
- For shared, cross-cutting behaviour, use concerns.

Example:

```ruby
# ✅ Inheritance is fine for a genuine is-a relationship
class AdminUser < User
  def admin? = true
end

# ✅ Prefer concerns for shared behaviour across unrelated models
module Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy
  end

  def close = create_closure!(user: Current.user)
  def closed? = closure.present?
end

class Card < ApplicationRecord
  include Closeable
end

class Task < ApplicationRecord
  include Closeable
end
```

## 1.7 Law of Demeter

- Only talk to your immediate neighbours. Avoid reaching through a chain of objects.
- If you find yourself writing `a.b.c`, the middle object (`b`) should expose what you need
  directly, either by delegating or wrapping.

Example:

```ruby
# ❌ Don't: reach through the object graph
user.account.subscription.plan.name

# ✅ Do: delegate through the chain so callsites stay simple
class User < ApplicationRecord
  delegate :plan_name, to: :account
end

class Account < ApplicationRecord
  delegate :plan_name, to: :subscription
end

class Subscription < ApplicationRecord
  delegate :name, to: :plan, prefix: true
end

user.plan_name
```

## 1.8 Controller and View Object Rule

- Controllers should instantiate only one object.
- Views should only know about one instance variable and should only send messages to that object.
- Let the model (or a presenter built on one model) provide everything the view needs.

Example:

```ruby
# ❌ Don't: multiple objects exposed to the view
def show
  @board = Board.find(params[:id])
  @members = @board.members
  @recent_cards = @board.cards.recent.limit(5)
end

# ✅ Do: expose one object; view reaches through it
def show
  @board = Board.find(params[:id])
end

# In the view:
# @board.members, @board.recent_cards — fine, they're on the same object
```

## 2. Rendering and Front End

### 2.1 Rendering model

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
  - Use `turbo_stream.morph` when you want to preserve focus/scroll and avoid
    janky replacements.
  - Consider global defaults via meta tags:
    - `turbo-refresh-method: morph`
    - `turbo-refresh-scroll: preserve`

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
- Stimulus usage rules:
  - Stimulus is for “sprinkles”, not frameworks.
  - Controllers must be small and single-purpose (ideally under ~50 LOC).
  - Prefer configuration via Stimulus values/classes/targets over hardcoding.
  - Prefer Turbo over `fetch` for most interactions. If using `fetch`, include
    CSRF tokens and keep it focused on UI affordances (not business logic).
  - Always clean up event listeners/timeouts/observers in `disconnect()`.

### 2.4 Accessibility

- Aim for good contrast, keyboard navigation and semantic HTML.
- Use browser tools to simulate colour blindness and to check contrast.
- Prefer simple and predictable interactions over flashy ones.

### 2.5 HTML structure

- Prefer semantic HTML elements over divs.
- Use divs only when no semantic element fits the content or purpose.
- Common semantic elements:
  - `<header>`, `<nav>`, `<main>`, `<article>`, `<section>`, `<aside>`, `<footer>` for page structure.
  - `<figure>`, `<figcaption>` for images with captions.
  - `<details>`, `<summary>` for collapsible content.
  - `<time>`, `<address>`, `<mark>` for specific content types.
- Personal projects:
  - Prefer classless HTML where possible.
  - Let CSS determine appearance through element and attribute selectors.
  - Add classes only when semantic targeting is insufficient.
  - This works naturally with MVP.css (see section 3.2).
- Work projects:
  - Use classes when team conventions or design systems require them.
  - Still prefer semantic elements as the foundation.

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
- Write lots of integration tests (both personal and work):
  - Prefer request/integration/system tests for core flows.
  - For APIs, test real HTTP requests, JSON parsing, status codes, and auth behavior.
- Test-driven development:
  - All generated code must be driven from tests.
  - If no test exists for the code you are about to write, create the test first.

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
- Prefer database column defaults over application-level defaults:
  - Use migrations to set defaults: `change_column_default :table, :column, from: nil, to: "value"`.
  - This ensures consistency across all entry points (console, rake tasks, etc.).
  - Application code (controllers, models) inherits the default automatically.
- Use concerns to share behaviour and reduce model size.
- Rich models by default:
  - Put domain behavior (commands and predicates) on the model that owns the state.
  - Prefer explicit verbs for actions (`publish`, `archive`, `close`) and
    predicates for queries (`closed?`, `assigned_to?`).
- Horizontal behaviour concerns:
  - Use concerns to encapsulate reusable cross-cutting behaviours.
  - Examples of horizontal concerns: `Closeable`, `Watchable`, `Assignable`, `Eventable`, `Broadcastable`.
- State as records (prefer this over booleans where it clarifies behavior):
  - Represent state transitions as associated records (e.g. `Closure`) instead of boolean columns like `closed: true`.
  - Use `where.missing(:association)` / joins-based scopes for “open/closed” style querying.
- Use `Current` for request context:
  - Use `Current.user` / `Current.account` for request-scoped defaults and model methods that need the acting user/account.
- Async vs sync side effects naming:
  - Use `_later` for job-enqueued versions and `_now` for synchronous versions (`notify_recipients_later` vs `notify_recipients_now`).
- Everything is CRUD (modeling discipline):
  - Prefer expressing “actions” as resources (state records, join models, etc.) and exposing them via REST routes.
  - Avoid inventing custom controller actions for state transitions; model them as nested resources and use POST/DELETE/PATCH appropriately.
  - Cross-reference: 1.1 “Apply everything is CRUD” and 11.1 “API design” (REST-only, respond_to).

Example (state as records and horizontal behaviour):

```ruby
class Closure < ApplicationRecord
  belongs_to :card, touch: true
  belongs_to :user, optional: true

  validates :card, uniqueness: true
end

class Card < ApplicationRecord
  include Closeable

  has_one :closure, dependent: :destroy

  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }

  def close(user: Current.user)
    create_closure!(user: user)
    track_event "card_closed", user: user
  end

  def closed?
    closure.present?
  end
end
```

Example (`_later` / `_now` convention):

```ruby
def notify_recipients_later
  NotifyRecipientsJob.perform_later(self)
end

def notify_recipients_now
  recipients.each do |recipient|
    Notification.create!(recipient: recipient, notifiable: self)
  end
end
```

## 8. Documentation and Security Tooling

### 8.1 Documentation

- Write YARD comments for Ruby code.
- Use YARD style comments for other languages where it fits.
- Let Solargraph use these comments for better editor support.
- Keep READMEs up to date with setup and deployment instructions.
- Keep documentation concise and direct:
  - Speak directly about the thing being documented (e.g., "Represents a card in a board").
  - Never use verbose patterns like "Domain model for Card".
- For Rails controller actions, use custom YARD tags to document routing:
  - `@action` for the HTTP method (GET, POST, PATCH, DELETE, etc.).
  - `@route` for the URL path.
  - Example:
    ```ruby
    # Creates a new board for the current account.
    # @action POST
    # @route /boards
    def create
      # ...
    end
    ```

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

- Use `rv` (from spinel-coop/rv) as the Ruby version manager.
- Installing, switching, or running commands with a specific Ruby version can be done via `rv`.
- Do not use RVM, rbenv, or chruby in new setups.

### 9.4 Linters and formatters

- Use RuboCop for Ruby.
- Use `scss-lint` for SCSS when it appears in legacy code.
- Use Herb and cspell where they add value.
- Never add linter disable comments (e.g., `rubocop:disable`, `eslint-disable`).
- If a file already contains linter disable comments, you do not need to refactor the file to remove them.

### 9.5 Git hooks and continuous integration

- Run Bundler Audit before pushing.
- Run Brakeman before pushing.
- Expect continuous integration to run the full test suite.

## 10. Application UX

### 10.1 Forms and validation

- Use HTML5 validation attributes where useful.
- Always validate on the server as the source of truth.
- Show clear error messages next to fields.

### 10.2 Internationalisation

- NEVER hardcode a user-facing string anywhere — not in views, templates, models, controllers,
  mailers, or jobs. Every string shown to a user must be a translation key.
- Personal projects:
  - Use Rails i18n with YAML files.
- Work projects:
  - Use gettext.
- Personal projects always support Dutch (`nl`), English (`en`), and Italian (`it`).
- Default to English text when another language is not specified.
- Use the `rails-i18n` gem for default Rails framework translations (date/time formats, validation messages, helpers, etc.).
- Use the `i18n-tasks` gem for translation management and testing in development/test groups.
- Namespace translations logically:
  - App-wide translations at root level (e.g., `app_name`, `navigation`).
  - Model-specific translations under model names (e.g., `time_entries`, `projects`).
  - Enum-like values in their own namespace (e.g., `entry_types`, `statuses`).
- Avoid duplication in translation files:
  - Don't repeat the same translations in multiple namespaces.
  - Use a single source of truth for each translatable value.
  - Reference shared translations where needed.
- Set database column defaults for enum-like fields instead of controller/model defaults when possible.
- This applies to validation errors too — pass a symbol key, never a string:

  ```ruby
  # ✅ Do
  errors.add(:base, :active_entry_exists)

  # ❌ Don't
  errors.add(:base, "You already have an active time entry")
  ```

- Enable i18n fallbacks in application.rb:
  ```ruby
  config.i18n.fallbacks = true
  ```

## 11. API Design

### 11.1 API design

- Use REST-only controllers and routes.
- Never use GraphQL.
- Prefer same controllers for HTML and JSON:
  - Use `respond_to` blocks.
  - Do not create separate "API controllers" when `respond_to` works.
- Use Jbuilder templates for JSON responses:
  - Do not inline JSON in controllers.
  - Do not introduce serializer frameworks by default.
- Authentication defaults:
  - Web: session-based authentication.
  - API: token-based authentication (Bearer token). Do not rely on sessions for API auth.
- Use proper HTTP status codes (`201`, `204`, `404`, `422`, etc.).
- Pagination:
  - When returning paginated collections as JSON, include pagination headers:
    - `X-Total-Count`, `X-Total-Pages`, `X-Page`, `X-Per-Page`
  - Prefer simple page-based pagination by default; consider cursor pagination only when needed.
- API versioning:
  - Version APIs when making breaking changes.
  - Prefer URL-based versioning (`/api/v1/...`) when versioning is needed.
- Prefer clear and well documented endpoints over clever abstractions.

Example (`respond_to` + Jbuilder):

```ruby
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards.includes(:creator)

    respond_to do |format|
      format.html
      format.json # renders index.json.jbuilder
    end
  end
end
```

Example (Jbuilder view):

```ruby
# app/views/boards/index.json.jbuilder
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  json.url board_url(board, format: :json)
end
```

Example (Bearer token API auth concept):

```ruby
module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_from_token, if: :api_request?
  end

  private

  def api_request?
    request.format.json?
  end

  def authenticate_from_token
    header = request.headers["Authorization"]
    token = header&.match(/Bearer (.+)/)&.captures&.first
    api_token = ApiToken.find_by(token: token)

    return render(json: { error: "Unauthorized" }, status: :unauthorized) unless api_token

    Current.user = api_token.user
    Current.account = api_token.account
  end
end
```

## 12. Open Questions

These areas are intentionally left open and should be decided per project.

- Front end performance budget:
  - Decide LCP, bundle size and Lighthouse targets.
- Authentication:
  - Web: session-based authentication (implementation may vary).
  - API: Bearer token authentication (no sessions).
  - External providers (Auth0, etc.) only when required.
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

## 13. AI Agent Workflow

The rules in sections 0–12 are the full ruleset. This section covers only behaviors specific to
how an AI agent should operate when working in this codebase.

1. Keep output concise:
   - Responses brief and to the point; plans scannable but complete.
   - Never add unsolicited verbosity, caveats, or filler text.
2. Lint all generated code before finishing:
   - Run linters on every file touched.
   - Fix all issues before considering the task done.
   - NEVER add linter disable comments.
3. Test-driven development:
   - Write the test first; never generate code without a corresponding test.
   - Run tests after every change and fix failures before finishing.
4. Ask for clarification when the playbook does not cover something.
5. Pull request workflow:
   - Always target `origin` (personal fork) over upstream.
   - If the target repository is ambiguous, ask before proceeding.
   - Never create PRs to an upstream project without explicit instruction.
6. Branch protection:
   - NEVER commit directly to `main` or `master`.
   - Always create a feature branch; merge via pull request.
