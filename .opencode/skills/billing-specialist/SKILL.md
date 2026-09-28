---
name: billing-specialist
description: "Expert in subscription billing with Pay gem. Activate for tasks involving subscriptions, payment processors (Stripe, Paddle, Braintree), payment webhooks, plan gating, per-seat pricing, one-time payments, or dunning. Use proactively when user discusses billing features, payment integration, subscription management, or revenue operations."
user-invocable: false
---

You are a subscription billing specialist for Jumpstart Pro Rails applications. You manage all aspects of billing, subscriptions, payment webhooks, one-time purchases, and revenue operations using the Pay gem.

## Scope and precedence

This skill carries Jumpstart Pro-specific billing guidance. Resolve choices in this order: (1) the application's own billing code and dependencies, (2) the Jumpstart Pro patterns here, (3) general Rails guidance from a companion package such as 37signals-skills when present, (4) conventional Rails defaults.

Billing runs through the Pay gem and its processor integrations. Do not hand-roll subscription, charge, or customer models, and do not call a payment processor API directly where Pay already provides the operation. Account billing is scoped through the account's `payment_processor`.

## When to use this skill

✅ **Subscription billing** (Pay gem integration, all processors)
✅ **Payment processor webhooks** (Stripe, Paddle Billing, Paddle Classic, Braintree)
✅ **Subscription lifecycle** (create, update, cancel, pause, swap plans)
✅ **One-time payments** (Checkout Sessions, fulfillment automation)
✅ **Payment methods** and customer management
✅ **Plan and feature gating** (trial periods, usage limits, feature flags)
✅ **Per-seat pricing** for team accounts
✅ **Webhook signature validation** and idempotency
✅ **Payment failure handling** and dunning workflows
✅ **Marketing automation** (ConvertKit, Drip, Mailchimp integration)

## Fetching current library documentation

Payment processor APIs, webhook payloads, and Pay gem behavior change between versions, so fetch current documentation for the processor and the Pay gem before implementing processor-specific features (webhook handlers, processor integrations, payment methods, per-seat or metered billing). Use the lookup the host runtime provides: a Context7 MCP server (`resolve-library-id`, then `query-docs`), built-in web search, or a project-local source. Known library IDs: `/stripe/stripe-ruby`, `/pay-rails/pay`, `/braintree/braintree_ruby`. Resolve Paddle Billing and any other processor by name first.

When the fetched documentation changes the implementation, name the source you relied on.

## Defer to other skills

❌ **Multi-tenancy scoping** → multi-tenancy-specialist (Current.account, ActsAsTenant.with_tenant)
❌ **Authorization policies** → multi-tenancy-specialist (Pundit, policy scoping)
❌ **API endpoints** → api-specialist (ApiToken authentication, API endpoints)
❌ **Non-payment webhooks** → api-specialist (OAuth, general integrations)
❌ **Frontend billing UI** → hotwire-specialist (forms, Turbo, Stimulus)
❌ **Database migrations** → database-specialist (schema changes, indexes)
❌ **Security audits** → security-specialist (Jumpstart Pro security review)

## Related skills

- **multi-tenancy-specialist** for account-scoped billing and ActsAsTenant.with_tenant in jobs
- **hotwire-specialist** for billing UI, subscription forms, and Turbo-powered dashboards
- **api-specialist** for billing API endpoints (seat changes, subscription management)
- **security-specialist** for webhook security reviews and impersonation guard audits

---

## Payment Processor Capabilities Matrix

| Feature | Stripe | Paddle Billing | Paddle Classic | Braintree |
|---------|--------|----------------|----------------|-----------|
| **Subscriptions** | ✅ | ✅ | ✅ | ✅ |
| **One-time payments** | ✅ | ✅ | ✅ | ✅ |
| **Per-seat pricing** | ✅ | ✅ | ❌ | ❌ |
| **Pause subscriptions** | ✅ (`pause_collection`) | ✅ | ❌ | ❌ |
| **Metered billing** | ✅ | ✅ | ❌ | ❌ |
| **Tax handling** | Manual | Automatic | Automatic | Manual |
| **PayPal support** | ❌ | ✅ | ✅ | ✅ |
| **Webhook signature** | HMAC SHA-256 | HMAC SHA-256 | RSA Public Key | HMAC SHA-256 |
| **Sandbox/Test mode** | ✅ | ✅ | ✅ | ✅ |

## Webhook Endpoints Quick Reference

| Processor | Endpoint | Signature Header | Verification Method |
|-----------|----------|------------------|---------------------|
| **Stripe** | `/webhooks/stripe` | `Stripe-Signature` | `Stripe::Webhook.construct_event` |
| **Paddle Billing** | `/webhooks/paddle_billing` | `Paddle-Signature` | HMAC SHA-256 with `signing_secret` |
| **Paddle Classic** | `/webhooks/paddle_classic` | (in body) | RSA verify with `public_key_base64` |
| **Braintree** | `/webhooks/braintree` | (params) | `WebhookNotification.parse` |

---

# Playbook 1: Setup & Configuration

## Account / Pay Gem Relationships

Jumpstart Pro accounts include the `Pay::Billable` concern, which provides billing capabilities:

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  include Pay::Billable  # Provides payment processor integration

  # Relationships created by Pay::Billable:
  # has_many :pay_customers, class_name: "Pay::Customer", as: :owner
  # has_many :pay_charges, through: :pay_customers, source: :charges
  # has_many :pay_subscriptions, through: :pay_customers, source: :subscriptions
  # has_many :pay_payment_methods, through: :pay_customers, source: :payment_methods
end
```

### Multi-tenancy Context Requirement

Pay calls act on the account they are called on. Pay models inherit from `ApplicationRecord`, not `AccountRecord`, so they are not tenant-scoped, and neither `Current.account` nor `ActsAsTenant.with_tenant` changes what `account.payment_processor` returns. Pick the account explicitly: `Current.account` in a controller, or an account passed as a job argument.

Tenant context matters when billing code also reads or writes `AccountRecord` models. In a controller, `SetCurrentRequestDetails` sets the tenant from `Current.account`. Outside a request (jobs, Pay webhook processing, console), `Current.account` is nil and does not set the tenant. Because Jumpstart Pro sets `config.require_tenant = false`, a tenant-scoped query with no tenant returns every account's rows. Wrap that work in `ActsAsTenant.with_tenant`:

```ruby
# In a controller: the account comes from the request
Current.account.set_payment_processor :stripe
Current.account.payment_processor.subscribe(plan: "pro_monthly")

# In a job: pass the account and set the tenant before touching AccountRecord models
ActsAsTenant.with_tenant(account) do
  account.payment_processor.subscription.sync!
  UsageRecord.where(billed: false).update_all(billed: true)  # AccountRecord model, scoped to account
end
```

## Processor Enablement

Configure enabled processors in `config/jumpstart.yml`:

```yaml
# config/jumpstart.yml
payment_processors:
  - stripe
  - paddle_billing
  # - paddle_classic
  # - braintree
```

Check processor availability:

```ruby
Jumpstart.config.payment_processors  # => ["stripe", "paddle_billing"]
Jumpstart.config.stripe?              # => true
Jumpstart.config.paddle_billing?      # => true
```

## Credentials Configuration

Store API keys securely in encrypted credentials:

```yaml
# config/credentials.yml.enc (edit with: make rails credentials:edit)

stripe:
  publishable_key: pk_test_xxx
  secret_key: sk_test_xxx
  signing_secret: whsec_xxx  # From Stripe Dashboard → Developers → Webhooks

paddle_billing:
  environment: sandbox  # or 'production'
  seller_id: xxx
  api_key: xxx
  client_token: xxx
  signing_secret: xxx  # From Paddle → Notifications → Notification Settings

paddle_classic:
  vendor_id: xxx
  vendor_auth_code: xxx
  public_key_base64: xxx  # From Paddle → Public Key (base64 only, no headers)

braintree:
  environment: sandbox  # or 'production'
  merchant_id: xxx
  public_key: xxx
  private_key: xxx
```

## Plan Seeding

Define subscription plans in your seeds or initializer:

```ruby
# db/seeds.rb or config/initializers/plans.rb

# Free plan with fake processor (no payment required)
Plan.where(name: "Free").first_or_create(
  hidden: true,
  amount: 0,
  currency: "usd",
  interval: "month",
  trial_period_days: 0,
  fake_processor_id: "free"
)

# Standard plan with trial
Plan.where(name: "Standard").first_or_create(
  amount: 2900,  # $29.00 in cents
  currency: "usd",
  interval: "month",
  trial_period_days: 14,
  stripe_id: "price_xxx",
  paddle_billing_id: "pri_xxx"
)

# Pro plan with per-seat pricing
Plan.where(name: "Pro").first_or_create(
  amount: 9900,  # $99.00 per seat per month
  currency: "usd",
  interval: "month",
  trial_period_days: 14,
  per_seat: true,
  stripe_id: "price_yyy",
  paddle_billing_id: "pri_yyy"
)
```

## Setting Up Free Subscriptions

For admin users or free-tier accounts:

```ruby
# In seeds or user creation flow
account = user.accounts.first
account.set_payment_processor :fake_processor, allow_fake: true
account.payment_processor.subscribe(plan: "free")
```

---

# Playbook 2: Subscription Lifecycle

## Creating Subscriptions

```ruby
# Set processor for account (only needed once)
account.set_payment_processor :stripe

# Subscribe to a plan
subscription = account.payment_processor.subscribe(
  plan: "pro_monthly",          # Plan identifier
  trial_period_days: 14,        # Optional trial
  quantity: 1,                  # For per-seat plans
  add_invoice_items: [          # Optional one-time fees
    {price: "price_setup_fee", quantity: 1}
  ]
)

# Access the subscription
account.payment_processor.subscription  # => Pay::Subscription
account.payment_processor.subscribed?   # => true
```

## Swapping Plans

```ruby
subscription = account.payment_processor.subscription

# Immediate plan change with proration
subscription.swap("pro_yearly")

# Change at period end (no proration)
subscription.swap_and_invoice("pro_yearly")
```

## Pausing Subscriptions (Stripe and Paddle Billing only)

**IMPORTANT**: `pause` behavior is processor-specific.

```ruby
subscription = account.payment_processor.subscription

# Stripe: pause_collection behavior
if account.payment_processor.stripe?
  subscription.pause  # Pauses billing, access continues
end

# Paddle Billing: pause subscription
if account.payment_processor.paddle_billing?
  subscription.pause  # Pauses billing and may restrict access
end

# Paddle Classic and Braintree: pause NOT supported
# Implement pause logic manually by canceling and tracking state
```

## Canceling Subscriptions

```ruby
subscription = account.payment_processor.subscription

# Cancel at period end (user retains access until end date)
subscription.cancel

# Cancel immediately (revokes access now)
subscription.cancel_now!
```

## Resuming Subscriptions

```ruby
subscription = account.payment_processor.subscription

# Resume a canceled subscription (before period ends)
if subscription.cancelled? && !subscription.ended?
  subscription.resume
end
```

---

# Playbook 3: Per-Seat & Usage-Based Billing

## Per-Seat Pricing Implementation

### Seat Calculation

```ruby
# app/models/account/billing.rb
module Account::Billing
  extend ActiveSupport::Concern

  def per_seat_pricing?
    plan&.per_seat?
  end

  def seats_count
    account_users.active.count
  end

  def calculate_monthly_cost
    return 0 unless per_seat_pricing?

    plan.amount * seats_count
  end
end
```

### Updating Subscription Quantity

**CRITICAL**: Update subscription quantity when team members are added/removed:

```ruby
# app/controllers/account_users_controller.rb
class AccountUsersController < ApplicationController
  def create
    @account_user = current_account.account_users.create!(account_user_params)

    # Update subscription quantity for per-seat plans
    update_subscription_quantity if current_account.per_seat_pricing?

    redirect_to account_users_path, notice: "Team member added"
  end

  def destroy
    @account_user.destroy!

    # Update subscription quantity for per-seat plans
    update_subscription_quantity if current_account.per_seat_pricing?

    redirect_to account_users_path, notice: "Team member removed"
  end

  private

  def update_subscription_quantity
    return unless current_account.subscribed?

    subscription = current_account.payment_processor.subscription

    # Stripe and Paddle Billing support quantity updates
    if subscription.processor.in?(["stripe", "paddle_billing"])
      subscription.update_quantity(current_account.seats_count)
    end
  end
end
```

### Seat Synchronization Job

For async seat count updates (e.g., after bulk operations):

```ruby
# app/jobs/sync_subscription_quantity_job.rb
class SyncSubscriptionQuantityJob < ApplicationJob
  queue_as :default

  def perform(account)
    return unless account.per_seat_pricing? && account.subscribed?

    ActsAsTenant.with_tenant(account) do
      subscription = account.payment_processor.subscription
      subscription.update_quantity(account.seats_count) if subscription.active?
    end
  end
end
```

---

# Playbook 4: One-Time Payments & Fulfillment

## Stripe Checkout Sessions

Create a Checkout Session for one-time payments:

```ruby
# app/controllers/checkout_controller.rb
class CheckoutController < ApplicationController
  def create
    # Ensure payment processor is set
    current_account.set_payment_processor :stripe unless current_account.payment_processor

    # Create Checkout Session
    @checkout_session = current_account.payment_processor.checkout(
      mode: "payment",
      line_items: [{price: "price_1xxx", quantity: 1}],
      allow_promotion_codes: true,
      success_url: checkout_completed_url(session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: pricing_url
    )

    redirect_to @checkout_session.url, allow_other_host: true
  end
end
```

### Handling Completion

Sync payment details after checkout (before webhook arrives):

```ruby
# app/controllers/checkout/completed_controller.rb
class Checkout::CompletedController < ApplicationController
  def show
    # Sync charge from Stripe
    @charge = Pay::Stripe::Charge.sync_from_checkout_session(params[:session_id])

    # Fulfillment happens via PayChargeExtension (see below)
    redirect_to dashboard_path, notice: "Payment successful!"
  end
end
```

## Paddle Billing Checkout

JavaScript-based checkout flow:

```erb
<!-- app/views/checkout/new.html.erb -->
<%= tag.div data: {
  controller: "paddle--billing",
  paddle__billing_environment_value: Pay::PaddleBilling.environment,
  paddle__billing_client_token_value: Pay::PaddleBilling.client_token,
  paddle__billing_target: "form",
  paddle__billing_email_value: current_account.email,
  paddle__billing_items_value: [{price_id: @price_id}].to_json,
  paddle__billing_success_url_value: checkout_completed_url,
  paddle__billing_custom_data_value: {account_id: current_account.id, order_id: @order.id}.to_json
} do %>
  <button type="button" data-action="click->paddle--billing#openCheckout">
    Purchase Now
  </button>
<% end %>
```

Sync after completion:

```ruby
# app/controllers/checkout/completed_controller.rb
def show
  # Set processor if needed
  current_account.set_payment_processor :paddle_billing,
    processor_id: params[:customer_id]

  # Sync transaction
  @charge = Pay::PaddleBilling::Charge.sync_from_transaction(params[:transaction_id])

  redirect_to dashboard_path, notice: "Payment successful!"
end
```

## Automated Fulfillment with PayChargeExtension

Automatically fulfill purchases when charges are created:

```ruby
# app/models/pay_charge_extension.rb
module PayChargeExtension
  extend ActiveSupport::Concern

  included do
    # Trigger fulfillment after charge is committed to database
    after_commit :fulfill_purchase, on: :create
  end

  def fulfill_purchase
    # Extract order ID from charge metadata
    order_id = metadata["order_id"]
    return unless order_id

    # Pay processes webhooks in a background job with no tenant set, so set the
    # tenant from the paying account before looking up the order. With Order
    # inheriting from AccountRecord, an order_id from another account finds nothing.
    ActsAsTenant.with_tenant(owner) do
      order = Order.find_by(id: order_id)
      return unless order
      return if order.completed?  # Skip if already fulfilled

      order.fulfill!
      order.update!(status: :completed)

      # Optional: Add to marketing list
      add_to_marketing_list(order.account.email)
    end
  rescue StandardError => e
    # Log but don't raise (webhook will retry)
    Rails.logger.error("Fulfillment failed for charge #{id}: #{e.message}")
    Honeybadger.notify(e) if defined?(Honeybadger)
  end

  private

  def add_to_marketing_list(email)
    return unless Jumpstart.config.convertkit?

    Jumpstart::Clients.convertkit.add_subscriber_to_form(
      ENV["CONVERTKIT_FORM_ID"],
      email
    )
  end
end

# Register extension
Rails.configuration.to_prepare do
  Pay::Charge.include PayChargeExtension
end
```

---

# Playbook 5: Webhooks & Automation

## Webhook Routes

Pay mounts its engine automatically, so do not add webhook routes to `config/routes.rb`. Pay's default mount path is `/pay`, but Jumpstart Pro sets `config.routes_path = "/"` in `config/initializers/pay.rb`, so the endpoints are:

```ruby
# POST /webhooks/stripe         => Pay::Webhooks::StripeController
# POST /webhooks/paddle_billing => Pay::Webhooks::PaddleBillingController
# POST /webhooks/paddle_classic => Pay::Webhooks::PaddleClassicController
# POST /webhooks/braintree      => Pay::Webhooks::BraintreeController
```

Each route exists only while its processor is enabled.

## How Pay Handles Webhooks

1. The processor's webhook controller verifies the signature.
2. If a listener is subscribed to the event (for example `stripe.invoice.payment_failed`), the controller stores the payload in a `Pay::Webhook` record and enqueues `Pay::Webhooks::ProcessJob`. Pay responds `200 OK` and discards events that no listener subscribes to.
3. The job calls `Pay::Webhook#process!`, which publishes the event through `Pay::Webhooks.delegator` (built on `ActiveSupport::Notifications`). Pay's built-in listeners sync customer, subscription, charge, and payment method records.
4. After every listener returns, Pay deletes the `Pay::Webhook` record. If a listener raises, the job fails and the record remains.

**Do NOT manually construct webhook events or override Pay's controllers**. Add custom behavior by subscribing a listener. A listener is any object that responds to `call(event)`:

```ruby
# app/webhooks/stripe_subscription_canceled.rb
class StripeSubscriptionCanceled
  def call(event)
    pay_subscription = Pay::Subscription.find_by_processor_and_id(:stripe, event.data.object.id)
    return unless pay_subscription

    account = pay_subscription.customer.owner
    ActsAsTenant.with_tenant(account) do
      SubscriptionCanceledMailer.notify(account).deliver_later
    end
  end
end
```

```ruby
# config/initializers/pay_webhooks.rb
ActiveSupport.on_load(:pay) do
  Pay::Webhooks.delegator.subscribe "stripe.customer.subscription.deleted", StripeSubscriptionCanceled.new
end
```

Listener rules:

- **Name events as `<processor>.<event type>`**, for example `stripe.customer.subscription.deleted` or `paddle_billing.subscription.canceled`.
- **Pay's listeners run first.** Pay registers its built-in listeners before application initializers run, so by the time a custom listener runs for the same event, Pay has already synced its records.
- **The event object depends on the processor.** Stripe listeners receive a `Stripe::Event`, so read the object from `event.data.object`. Paddle Billing listeners receive only the event's `data` payload, wrapped in an object with method access, so read fields directly (`event.id`, `event.customer_id`). Braintree listeners receive a parsed `Braintree::WebhookNotification`.
- **Set the tenant explicitly.** Listeners run inside a background job with no `Current.account`, so look up the account from the Pay record and wrap tenant-scoped work in `ActsAsTenant.with_tenant`.
- **Check Pay's own emails.** Pay already sends emails for some events, including `payment_failed` and `receipt`. Check `Pay.send_email?(:payment_failed, pay_subscription)` before sending a similar email, or disable Pay's version with `config.emails.payment_failed = false` in `Pay.setup`.
- **Replace a built-in listener** with `Pay::Webhooks.delegator.unsubscribe "stripe.charge.succeeded"`. This removes every listener already subscribed to that event, including Pay's, so subscribe the replacement afterward.

## Processor-Specific Webhook Verification

### Stripe

Pay automatically verifies via `Stripe::Webhook.construct_event`:

```ruby
# Pay gem handles this internally - DO NOT duplicate
Stripe::Webhook.construct_event(
  request.body.read,
  request.headers["Stripe-Signature"],
  Rails.application.credentials.dig(:stripe, :signing_secret)
)
```

### Paddle Billing

Pay verifies HMAC SHA-256 signature:

```ruby
# Pay gem handles this - signing_secret from credentials
signature = request.headers["Paddle-Signature"]
# Verification happens automatically
```

### Paddle Classic

Pay verifies RSA public key signature:

```ruby
# Pay gem handles this - public_key_base64 from credentials
# Signature is in webhook body, not headers
```

### Braintree

Pay uses `WebhookNotification.parse`:

```ruby
# Pay gem handles this internally
Braintree::WebhookNotification.parse(
  params[:bt_signature],
  params[:bt_payload]
)
```

## Webhook Event Types

These lists show the events Pay 11 subscribes to. Pay discards any other event, even if the processor sends it, until a custom listener subscribes to it. For example, Pay has no listener for Stripe `invoice.payment_succeeded` or Paddle Billing `transaction.payment_failed`. The processor's webhook settings must also send every event a listener needs.

### Stripe Events Pay Handles

- `charge.succeeded`, `charge.updated`, `charge.refunded`
- `payment_intent.succeeded`
- `invoice.upcoming`, `invoice.updated`, `invoice.payment_action_required`, `invoice.payment_failed`
- `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `customer.subscription.trial_will_end`
- `customer.updated`, `customer.deleted`
- `payment_method.attached`, `payment_method.updated`, `payment_method.card_automatically_updated`, `payment_method.detached`
- `checkout.session.completed`, `checkout.session.async_payment_succeeded`
- `account.updated`

### Paddle Billing Events Pay Handles

- `subscription.created`, `subscription.activated`, `subscription.updated`, `subscription.trialing`, `subscription.past_due`, `subscription.paused`, `subscription.resumed`, `subscription.canceled`, `subscription.imported`
- `transaction.completed`

### Paddle Classic Events Pay Handles

- `subscription_created`, `subscription_updated`, `subscription_cancelled`
- `subscription_payment_succeeded`, `subscription_payment_refunded`

### Braintree Events Pay Handles

- `subscription_went_active`, `subscription_charged_successfully`, `subscription_charged_unsuccessfully`, `subscription_went_past_due`, `subscription_trial_ended`, `subscription_canceled`, `subscription_expired`

## Idempotency

Pay does not deduplicate webhook events. The `pay_webhooks` table stores only `processor`, `event_type`, the `event` payload, and timestamps, and Pay deletes each row after processing it. A processor that retries delivery, or a job that runs twice, calls every listener again.

Pay's built-in listeners are safe to repeat because they sync records from the processor. Custom listeners must be safe to repeat too. Either make the work idempotent (update to a known state rather than incrementing or appending), or record the processor's event ID (`event.id` for Stripe) in an application table with a unique index and skip events already recorded.

## Webhook Testing

### Stripe CLI

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks to local server
stripe listen --forward-to http://localhost:3000/webhooks/stripe

# Trigger test events
stripe trigger customer.subscription.created
stripe trigger invoice.payment_succeeded
stripe trigger invoice.payment_failed
```

### Testing in Specs

```ruby
# test/integration/webhooks/stripe_test.rb
class StripeWebhookTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @account.set_payment_processor :stripe, processor_id: "cus_test"
  end

  test "handles subscription created webhook" do
    event = stripe_event("customer.subscription.created",
      customer: @account.payment_processor.processor_id,
      subscription: "sub_test123"
    )

    post pay_webhooks_stripe_path, params: event.to_json,
      headers: {"Stripe-Signature" => generate_stripe_signature(event.to_json)}

    assert_response :success
    assert @account.payment_processor.subscribed?
  end

  private

  def stripe_event(type, **attrs)
    StripeMock.mock_webhook_event(type, attrs)
  end

  def generate_stripe_signature(payload)
    # Use Stripe's test helper or generate manually
    Stripe::Webhook::Signature.generate_header(
      payload,
      Rails.application.credentials.dig(:stripe, :signing_secret),
      Time.current.to_i
    )
  end
end
```

---

# Playbook 6: Plan & Feature Gating

## Checking Plan Features

Define feature checks in `app/models/account/billing.rb`:

```ruby
module Account::Billing
  extend ActiveSupport::Concern

  def can_export?
    subscribed? && plan&.has_feature?(:exports)
  end

  def users_limit
    plan&.user_limit || 5  # Default limit for free tier
  end

  def api_rate_limit
    case plan&.name
    when "Pro" then 10_000
    when "Standard" then 1_000
    else 100
    end
  end
end
```

## Jumpstart Config Feature Flags

Combine global feature flags with plan-based gating:

```yaml
# config/jumpstart.yml
features:
  - exports
  - api_access
  - custom_branding
  - priority_support
```

```ruby
# app/helpers/application_helper.rb
def feature_enabled?(feature)
  # Feature must be enabled globally AND in user's plan
  Jumpstart.config.feature?(feature) &&
    current_account.plan&.has_feature?(feature)
end
```

## Controller Gating

```ruby
# app/controllers/exports_controller.rb
class ExportsController < ApplicationController
  before_action :require_export_access

  def create
    # Export logic
  end

  private

  def require_export_access
    return if current_account.can_export?

    redirect_to pricing_path,
      alert: "Upgrade to Pro to export data"
  end
end
```

## Usage Limits

Enforce limits based on plan:

```ruby
# app/controllers/api/v1/projects_controller.rb
class Api::V1::ProjectsController < Api::BaseController
  before_action :check_project_limit, only: [:create]

  private

  def check_project_limit
    limit = current_account.plan&.project_limit || 3

    if current_account.projects.count >= limit
      render json: {
        error: "Project limit reached",
        limit: limit,
        upgrade_url: pricing_url
      }, status: :payment_required
    end
  end
end
```

## View Helpers

```erb
<!-- Show upgrade CTA when feature unavailable -->
<% if feature_enabled?(:custom_branding) %>
  <%= render "custom_branding_form" %>
<% else %>
  <div class="card">
    <h3>Custom Branding</h3>
    <p>Upgrade to Pro to customize your branding.</p>
    <%= link_to "Upgrade Now", pricing_path, class: "btn btn-primary" %>
  </div>
<% end %>
```

---

# Playbook 7: Dunning & Recovery

## Detecting Payment Failures

```ruby
# app/models/account/billing.rb
module Account::Billing
  extend ActiveSupport::Concern

  def payment_failed?
    subscription&.past_due?
  end

  def days_past_due
    return 0 unless payment_failed?
    return 0 unless subscription&.current_period_end

    (Date.current - subscription.current_period_end.to_date).to_i
  end

  def in_grace_period?
    payment_failed? && days_past_due <= 7
  end

  def should_suspend?
    payment_failed? && days_past_due > 7
  end

  private

  def subscription
    payment_processor&.subscription
  end
end
```

## Dunning Workflow

```ruby
# app/jobs/dunning_workflow_job.rb
class DunningWorkflowJob < ApplicationJob
  queue_as :default

  def perform(account)
    ActsAsTenant.with_tenant(account) do
      return unless account.payment_failed?

      days_overdue = account.days_past_due

      case days_overdue
      when 1
        # First failure - friendly reminder
        PaymentFailedMailer.first_attempt(account).deliver_later
      when 3
        # Second reminder
        PaymentFailedMailer.second_attempt(account).deliver_later
      when 7
        # Final warning before suspension
        PaymentFailedMailer.final_warning(account).deliver_later
      when 10
        # Suspend account
        account.update!(suspended: true)
        AccountSuspensionMailer.notify(account).deliver_later
      end
    end
  end
end
```

## Webhook Handler for Failed Payments

Subscribe a listener to the payment failure event to start dunning (see Playbook 5 for how listeners work):

```ruby
# app/webhooks/stripe_payment_failed.rb
class StripePaymentFailed
  def call(event)
    invoice = event.data.object
    pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: invoice.customer)
    return unless pay_customer

    DunningWorkflowJob.perform_later(pay_customer.owner)
  end
end
```

```ruby
# config/initializers/pay_webhooks.rb
ActiveSupport.on_load(:pay) do
  Pay::Webhooks.delegator.subscribe "stripe.invoice.payment_failed", StripePaymentFailed.new
end
```

Pay's own `stripe.invoice.payment_failed` listener already sends a payment failed email when the invoice belongs to a subscription that is not `incomplete`. If the dunning emails replace it, set `config.emails.payment_failed = false` in `Pay.setup`. For Paddle Billing, Pay does not subscribe to `transaction.payment_failed`, so subscribe a listener to `paddle_billing.transaction.payment_failed` or `paddle_billing.subscription.past_due` and enable that event in Paddle's notification settings.

## Grace Period Logic

Allow continued access during grace period:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :check_account_status

  private

  def check_account_status
    return unless user_signed_in?
    return if current_account.blank?

    if current_account.suspended?
      redirect_to suspended_account_path
    elsif current_account.payment_failed? && !current_account.in_grace_period?
      redirect_to update_payment_method_path,
        alert: "Your payment has failed. Please update your payment method."
    end
  end
end
```

---

# Playbook 8: Security & Compliance

## Impersonation Guards

**CRITICAL**: Block billing changes during impersonation. Jumpstart Pro impersonates users with the `pretender` gem, so `current_user` is the impersonated user and `true_user` is the signed-in admin. `require_current_account_admin` checks the impersonated user, so an admin impersonating an account admin passes it. Jumpstart Pro ships no guard for this.

Use the `ImpersonationGuard` concern described in multi-tenancy-specialist, which blocks the action when `current_user != true_user`:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include ImpersonationGuard
end

# app/controllers/billing_controller.rb (copied from lib/jumpstart/app/controllers/)
class BillingController < ApplicationController
  before_action :authenticate_user!
  before_action :require_current_account_admin, except: [:show]
  before_action :block_during_impersonation, except: [:show]
  # ...
end
```

Apply the same `before_action` to the other controllers that change billing: `Billing::SubscriptionsController`, the controllers under `Billing::Subscriptions::` (cancels, pauses, resumes, payment methods), and `CheckoutsController`. These live under `lib/jumpstart/app/controllers/`. Copy each one to the same path under `app/controllers/`, which takes precedence, and keep the copies in sync during upstream merges.

## Webhook Logging

Log all webhook requests for debugging and audit trails. Pay has no shared base controller for webhooks (each processor's controller inherits from `ActionController::API`), so add the callback to each enabled processor's controller. The controllers only verify and enqueue events, so this logs receipt. Failures inside listeners surface in `Pay::Webhooks::ProcessJob`.

```ruby
# config/initializers/pay_webhooks.rb
Rails.configuration.to_prepare do
  # List the controller for each processor enabled in config/jumpstart.yml
  [
    Pay::Webhooks::StripeController,
    Pay::Webhooks::PaddleBillingController
  ].each do |controller|
    controller.class_eval do
      around_action :log_webhook_event

      private

      def log_webhook_event
        processor = self.class.name.demodulize.delete_suffix("Controller").underscore
        event_id = params[:id] || params[:event_id]
        event_type = params[:type] || params[:event_type] || params[:alert_name]
        details = "processor=#{processor} event_id=#{event_id} event_type=#{event_type} request_id=#{request.request_id}"

        Rails.logger.info("Webhook received #{details}")
        yield
        Rails.logger.info("Webhook accepted #{details} status=#{response.status}")
      rescue StandardError => e
        Rails.logger.error("Webhook failed #{details} error=#{e.class}: #{e.message}")

        # Send to error tracker
        Honeybadger.notify(e, context: {processor: processor, event_id: event_id}) if defined?(Honeybadger)

        raise
      end
    end
  end
end
```

`Rails.logger` methods accept a message string, not keyword arguments. Passing keywords, as in `Rails.logger.info("Webhook received", processor: processor)`, raises `ArgumentError`.

## Sensitive Data Redaction

Never log API keys, card details, or tokens:

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :password,
  :secret,
  :token,
  :api_key,
  :client_secret,
  :private_key,
  :card_number,
  :cvv,
  :ssn
]
```

## API Key Rotation

Periodically rotate payment processor API keys:

```bash
# 1. Generate new keys in processor dashboard
# 2. Update credentials
make rails credentials:edit

# 3. Update processor configuration
# 4. Test webhook delivery
stripe listen --forward-to https://yourdomain.com/webhooks/stripe

# 5. Revoke old keys after verification
```

## Rate Limiting Webhooks

Prevent webhook abuse:

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Allow 100 webhook requests per minute per IP
  throttle("webhooks/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/webhooks/")
  end

  # Exponential backoff for blocked requests
  Rack::Attack.blocklisted_responder = lambda do |request|
    [429, {}, ["Retry later\n"]]
  end
end
```

---

# Playbook 9: Testing Recipes

## Testing with Pay::TestHelpers

```ruby
# test/test_helper.rb
require "pay/test_helpers"

class ActiveSupport::TestCase
  include Pay::TestHelpers
end
```

## Subscription Tests

```ruby
# test/models/account_test.rb
class AccountTest < ActiveSupport::TestCase
  test "creates subscription with trial" do
    account = accounts(:one)
    account.set_payment_processor :fake_processor, allow_fake: true

    subscription = account.payment_processor.subscribe(
      plan: "pro_monthly",
      trial_period_days: 14
    )

    assert account.payment_processor.subscribed?
    assert subscription.on_trial?
    assert_equal 14.days.from_now.to_date, subscription.trial_ends_at.to_date
  end

  test "per-seat pricing updates quantity" do
    account = accounts(:team)
    account.set_payment_processor :fake_processor, allow_fake: true
    account.payment_processor.subscribe(plan: "pro_per_seat")

    # Add team member
    account.account_users.create!(user: users(:two), admin: false)

    # Update quantity
    subscription = account.payment_processor.subscription
    subscription.update_quantity(account.seats_count)

    assert_equal account.seats_count, subscription.quantity
  end
end
```

## Webhook Tests

```ruby
# test/integration/webhooks/stripe_webhook_test.rb
class StripeWebhookTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @account.set_payment_processor :stripe, processor_id: "cus_test"
  end

  test "handles payment succeeded webhook" do
    event_payload = {
      id: "evt_test_#{SecureRandom.hex}",
      type: "invoice.payment_succeeded",
      data: {
        object: {
          subscription: "sub_test",
          customer: @account.payment_processor.processor_id
        }
      }
    }.to_json

    signature = generate_stripe_signature(event_payload)

    assert_difference "Pay::Webhook.count", 1 do
      post pay_webhooks_stripe_path,
        params: event_payload,
        headers: {"Stripe-Signature" => signature}
    end

    assert_response :success
  end

  test "rejects invalid signature" do
    event_payload = {id: "evt_test", type: "invoice.payment_succeeded"}.to_json

    post pay_webhooks_stripe_path,
      params: event_payload,
      headers: {"Stripe-Signature" => "invalid_signature"}

    assert_response :bad_request
  end

  private

  def generate_stripe_signature(payload)
    timestamp = Time.current.to_i
    secret = Rails.application.credentials.dig(:stripe, :signing_secret)
    signed_payload = "#{timestamp}.#{payload}"
    signature = OpenSSL::HMAC.hexdigest("sha256", secret, signed_payload)
    "t=#{timestamp},v1=#{signature}"
  end
end
```

## Feature Gating Tests

```ruby
# test/integration/feature_gating_test.rb
class FeatureGatingTest < ActionDispatch::IntegrationTest
  test "free plan cannot access exports" do
    account = accounts(:free_tier)
    sign_in account.owner

    get exports_path

    assert_redirected_to pricing_path
    assert_equal "Upgrade to Pro to export data", flash[:alert]
  end

  test "pro plan can access exports" do
    account = accounts(:pro_tier)
    sign_in account.owner

    get exports_path

    assert_response :success
  end
end
```

## Dunning Workflow Tests

```ruby
# test/jobs/dunning_workflow_job_test.rb
class DunningWorkflowJobTest < ActiveJob::TestCase
  test "sends first reminder on day 1" do
    account = accounts(:past_due)
    account.update!(last_payment_failed_at: 1.day.ago)

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      DunningWorkflowJob.perform_now(account)
    end
  end

  test "suspends account on day 10" do
    account = accounts(:past_due)
    account.payment_processor.subscription.update!(current_period_end: 10.days.ago)

    DunningWorkflowJob.perform_now(account)

    assert account.reload.suspended?
  end
end
```

---

## Common Pitfalls

- ❌ Using `ends_at`, `canceled?`, or `on_grace_period?` for dunning. Pay sets `ends_at` when a subscription is canceled, so `on_grace_period?` means a canceled subscription that has not ended yet, not a failed payment.
- ✅ Detect failed payments with `past_due?` and measure the grace period from `current_period_end`, as in Detecting Payment Failures.
