# Rails Architecture — Examples

General OOP examples (Tell Don't Ask, Dependency Injection, Composition over Inheritance, Law of
Demeter) moved to the `object-oriented-design` skill — they aren't Rails-specific. What's below is
Rails/ActiveRecord-specific mechanics only.

## Avoid service objects, prefer rich models

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

## Guard clause over if/else

```ruby
# ❌ Don't: if/else/end when a guard clause fits
if closed?
  return false
else
  do_thing
end

# ✅ Do: guard clause
return false if closed?

do_thing
```

## Controller and view object rule

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

## Concern definition (`ActiveSupport::Concern`)

```ruby
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

## State as records and horizontal behaviour

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

## `_later` / `_now` convention

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

## YARD `@action` / `@route` controller documentation

```ruby
# Creates a new board for the current account.
# @action POST
# @route /boards
def create
  # ...
end
```
