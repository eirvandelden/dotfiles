# Rails Testing — Examples

## Test data selection discipline

```ruby
# ❌ Don't: create generic then mutate
user = create(:user)
user.update!(role: :admin, confirmed_at: Time.current)

# ✅ Prefer: use an existing factory trait or fixture that is already correct
user = create(:user, :admin)   # factory trait
user = users(:admin)           # fixture

# ✅ Also fine: build the correct object directly
user = create(:user, role: :admin, confirmed_at: Time.current)
```
