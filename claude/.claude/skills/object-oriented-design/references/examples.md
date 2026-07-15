# Object-Oriented Design — Examples

Illustrated in Ruby for brevity, but framework-free — no Rails/ActiveRecord calls. The same shapes
apply in any OOP language.

## Rich object over anemic model + service layer

```ruby
# ❌ Don't: orchestrator class holding behavior that belongs on Card
class CloseCardService
  def initialize(card, user)
    @card = card
    @user = user
  end

  def call
    @card.closed = true
    @card.closed_by = @user
    @card.save!
    NotificationCenter.notify(@card, :closed)
  end
end

# ✅ Do: the object owns its own behavior
class Card
  def close(user:)
    self.closed = true
    self.closed_by = user
    save!
    NotificationCenter.notify(self, :closed)
  end
end
```

## Tell, Don't Ask

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
  self.closed = false
end
```

## Dependency Injection

```ruby
# ❌ Don't: hard-coded collaborator
class Order
  def notify_customer
    Mailer.new.confirmation(self).deliver
  end
end

# ✅ Do: inject the collaborator, default to the real one
class Order
  def notify_customer(mailer: Mailer.new)
    mailer.confirmation(self).deliver
  end
end
```

## Composition over inheritance

```ruby
# ✅ Inheritance is fine for a genuine is-a relationship
class AdminUser < User
  def admin? = true
end

# ✅ Prefer a mixin for shared behaviour across otherwise-unrelated classes
module Closeable
  def close
    self.closed = true
  end

  def closed?
    !!closed
  end
end

class Card
  include Closeable
end

class Task
  include Closeable
end
```

## Law of Demeter

```ruby
# ❌ Don't: reach through the object graph
user.account.subscription.plan.name

# ✅ Do: expose a forwarding method so callsites stay simple
class User
  def plan_name = account.plan_name
end

class Account
  def plan_name = subscription.plan_name
end

class Subscription
  def plan_name = plan.name
end

user.plan_name
```
