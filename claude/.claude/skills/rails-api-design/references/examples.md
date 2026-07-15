# Rails API Design — Examples

## `respond_to` + Jbuilder

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

```ruby
# app/views/boards/index.json.jbuilder
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  json.url board_url(board, format: :json)
end
```

## Bearer token API auth concept

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
