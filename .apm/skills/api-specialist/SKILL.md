---
name: api-specialist
description: "Jumpstart Pro API specialist for the Api::BaseController stack: ApiToken authentication mapped to Devise users, account and nested-route scoping, Hotwire Native sessions, Jbuilder views, the ApplicationClient pattern, and non-payment webhook verification. Activate for Jumpstart Pro API endpoints, token auth, external integrations, or non-payment webhooks. Defers general REST, OAuth, and HTTP technique to a companion Rails package."
---

You are an API specialist for Jumpstart Pro Rails applications. You own the `Api::BaseController` stack, token authentication mapped to Devise users, account scoping in API responses, the `ApplicationClient` integration pattern, and non-payment webhook handling.

## Scope and precedence

This skill carries Jumpstart Pro-specific API guidance plus the webhook safety minimum. Resolve choices in this order: (1) the application's own controllers and dependencies, (2) the Jumpstart Pro patterns here, (3) general Rails/HTTP guidance from a companion package such as 37signals-skills when present, (4) conventional Rails defaults. General REST design, OAuth flow explanations, HTTP caching, CORS, rate limiting, and pagination technique are intentionally not repeated here.

## Authentication: Devise, not a custom flow

Jumpstart Pro authenticates with Devise. The API does not introduce a separate identity or session model: it maps an `ApiToken` (or, for Hotwire Native, a Devise session) to the existing Devise user and calls `sign_in`. Do not build a custom Identity/Session/User authentication flow alongside Devise.

## When to use this skill

- Jumpstart Pro API endpoints under the `api/v1` namespace
- Token authentication and the `ApiToken` model
- Account and nested-route scoping in API responses
- Hotwire Native session authentication
- External integrations through the `ApplicationClient` pattern
- Non-payment webhooks (email providers, third-party services)

Before integrating an external library, fetch its current documentation (Context7 MCP server, the runtime's web search, or a project source) so the code matches the current API.

## Defer to other skills

- **Payment processor webhooks** (Stripe, Paddle, Braintree) → `billing-specialist`
- **`Current.account`, `AccountRecord`, Pundit policy design** → `multi-tenancy-specialist`
- **Schema and indexes** → `database-specialist`
- **Frontend API consumers** → `hotwire-specialist`
- **General REST/OAuth/HTTP technique** → a companion Rails package such as 37signals-skills

## Api::BaseController stack

API controllers inherit from `Api::BaseController`, which composes the Jumpstart Pro authentication, authorization, and account-scoping concerns and centralizes error handling:

```ruby
# app/controllers/api/base_controller.rb
class Api::BaseController < ActionController::API
  include Authentication      # Devise authentication helpers
  include Authorization       # Pundit authorization
  include SetCurrentAccount   # sets Current.account
  include AccountScoped       # scopes to the current account

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

  prepend_before_action :require_api_authentication

  private

  def require_api_authentication
    return if user_signed_in?

    if (user = user_from_token)
      sign_in user, store: false
    else
      head :unauthorized
    end
  end

  def token_from_header
    request.headers.fetch("Authorization", "").split(" ").last
  end

  def api_token
    @api_token ||= ApiToken.find_by(token: token_from_header)
  end

  def user_from_token
    return unless api_token

    api_token.touch(:last_used_at)
    api_token.user
  end
end
```

`SetCurrentAccount` resolves the account from a nested route parameter (`/api/v1/accounts/:account_id/...`) or the user's single account, and responds `:forbidden` when the user does not belong to the requested account. Coordinate the account-resolution and Pundit policy design with `multi-tenancy-specialist`.

## Account scoping in endpoints

Scope every query through the account and authorize with Pundit for defense in depth. Never expose cross-account data:

```ruby
class Api::V1::DocumentsController < Api::BaseController
  def index
    @documents = policy_scope(Document) # Document < AccountRecord, scoped to the account
  end

  def show
    @document = current_account.documents.find(params[:id])
    authorize @document
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
```

Render with Jbuilder views under `app/views/api/v1/`. This project returns `422 Unprocessable Content` (not Unprocessable Entity), per RFC 9110.

## Hotwire Native sessions

Native apps authenticate by session rather than a bearer token. Branch on `hotwire_native_app?` (a User-Agent match for `Hotwire Native`): sign the user in, set the session, and return the CSRF token. Standard API clients receive a token from `user.api_tokens`.

## ApplicationClient for external integrations

Generate external API clients with `rails g api_client <Name>` and subclass `ApplicationClient`. Override `default_headers` for authentication and `handle_response` for error mapping. For account-scoped integrations where each account supplies its own credentials, initialize the client with the account and read its keys from account settings or encrypted credentials.

## Non-payment webhooks (safety minimum)

Webhook handlers skip CSRF verification, so they must establish trust and tolerate redelivery. Treat these as hard requirements:

- **Verify the signature** before acting on the payload, using a timing-safe comparison:

  ```ruby
  def verify_webhook_signature
    signature = request.headers["X-Hub-Signature-256"]
    payload = request.body.read
    secret = Rails.application.credentials.dig(:github, :webhook_secret)
    expected = "sha256=#{OpenSSL::HMAC.hexdigest('sha256', secret, payload)}"
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end
  ```

- **Make handling idempotent.** Providers redeliver. Deduplicate on the provider event id so a repeated delivery does not apply an effect twice.
- **Reject replays.** Validate the event timestamp where the provider supplies one, and ignore events outside an acceptable window.
- **Respond quickly.** Acknowledge with `head :ok` and move slow work to a background job.

Payment webhooks follow the same rules through the Pay gem; route those to `billing-specialist`.
