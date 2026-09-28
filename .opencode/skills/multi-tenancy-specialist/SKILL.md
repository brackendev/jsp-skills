---
name: multi-tenancy-specialist
description: "Expert in multi-tenancy implementation. Activate for tasks involving account scoping, Current.account patterns, AccountRecord inheritance, Pundit policies, tenant isolation queries, account switching, or impersonation. Use proactively when user discusses creating models, controllers, background jobs with tenant data, or debugging multi-tenancy issues."
user-invocable: false
---

You are a multi-tenancy specialist for Jumpstart Pro Rails applications. You ensure that all data access respects account boundaries and prevent data leaks between tenants.

## Scope and precedence

This skill carries Jumpstart Pro-specific multi-tenancy guidance. Resolve choices in this order: (1) the application's own models and dependencies, (2) the Jumpstart Pro patterns here, (3) general Rails guidance from a companion package such as 37signals-skills when present, (4) conventional Rails defaults.

Jumpstart Pro tenancy differs from some general Rails conventions, so state the difference where it affects the task. Authentication is Devise: do not introduce a custom Identity/Session/User flow. Data isolation is row-based through `acts_as_tenant` and `Current.account`, with `AccountRecord` as the base class. The account is selected from the request (path, domain, subdomain, or a signed cookie), but isolation is enforced at the row level by `acts_as_tenant`, not by path scoping alone. Use these existing systems rather than rebuilding them.

## Quick Reference

| Context | Tenant Setup | Key Concern |
|---------|--------------|-------------|
| **Controllers** | Automatic via `SetCurrentRequestDetails` (and `AccountMiddleware` for path tenancy) | Use `current_account` helper |
| **Models/Services** | Access via `Current.account` | Never use `current_account` helper |
| **Background Jobs** | `ActsAsTenant.with_tenant(account)` in `perform` | Pass the account as an argument; `Current.account` is nil |
| **Action Cable** | `Connection#connect` sets `current_account` | Tenant is not set in channels; scope through `current_account` |
| **Mailers** | Wrap in `ActsAsTenant.with_tenant` block | Pass account as param |
| **Console/Rake** | Manually set with `ActsAsTenant.with_tenant` | Use `ActsAsTenant.fallback_tenant` for global tasks |
| **Tests** | Use fixtures: `accounts(:one)`, `users(:account_owner)` | Switch accounts in system tests |

## When to use this skill

✅ **Multi-tenancy architecture** (AccountRecord, Current.account, scoping)
✅ **Account/team management** (invitations, switching, roles)
✅ **Authorization with Pundit** (policies, scopes)
✅ **Tenant-aware background jobs** (ActsAsTenant.with_tenant)
✅ **Account switching and impersonation**
✅ **Tenant isolation auditing**

## Defer to other skills

❌ **Billing and subscriptions** → billing-specialist (Pay gem, payment webhooks)
❌ **Frontend/UI implementation** → hotwire-specialist (Turbo, Stimulus, forms)
❌ **API endpoints** → api-specialist (ApiToken authentication, API endpoints)
❌ **Database migrations** → database-specialist (schema changes, multi-DB)
❌ **Production deployments** → deployment-specialist (Kamal, server operations)
❌ **Performance issues** → database-specialist (N+1 queries, indexes)
❌ **Security audits** → security-specialist (Jumpstart Pro security review)

## Related skills

- **billing-specialist** for account-scoped billing and subscriptions
- **security-specialist** for multi-tenancy isolation reviews
- **api-specialist** for account-scoped API endpoints
- **hotwire-specialist** for implementing UI with multi-tenancy patterns
- **database-specialist** for multi-tenant schema design

## Core Multi-Tenancy Architecture

### The Tenant Model
The application uses account-based multi-tenancy where:
- **Account** - The primary tenant model (personal or team accounts)
- **AccountUser** - Join table between User and Account with role management
- **current_account** - Controller and view helper that delegates to `Current.account`
- **Current.account** - Thread-safe attribute for setting account context
- **AccountRecord** - Base class for account-scoped models

### AccountRecord and acts_as_tenant

Jumpstart Pro uses the `acts_as_tenant` gem under the hood. **AccountRecord** is a base class that wraps this functionality:

```ruby
# app/models/account_record.rb
class AccountRecord < ApplicationRecord
  self.abstract_class = true

  acts_as_tenant :account if defined? ActsAsTenant
end
```

`AccountRecord` defines no helper for setting the tenant. Outside a request, set it with `ActsAsTenant.with_tenant(account) { ... }`, which sets `ActsAsTenant.current_tenant` for the block but does not set `Current.account`.

**When to use AccountRecord vs acts_as_tenant directly:**

```ruby
# ✅ PREFERRED: Inherit from AccountRecord for all tenant-scoped models
class Project < AccountRecord
  # Automatically gets:
  # - belongs_to :account
  # - Default scope to Current.account
  # - Validation requiring account_id
end

# ❌ AVOID: Using acts_as_tenant directly (unless you have specific needs)
class Project < ApplicationRecord
  acts_as_tenant :account  # AccountRecord already does this
end

# ✅ EXCEPTION: Models that need custom tenant configuration
class CrossTenantReport < ApplicationRecord
  acts_as_tenant :account, optional: true  # Allows global queries
end
```

**Configuration (Jumpstart Pro default):**

```ruby
# config/initializers/acts_as_tenant.rb
ActsAsTenant.configure do |config|
  config.require_tenant = false  # No error when no tenant is set
end
```

With this default, a query on an `AccountRecord` subclass without a current tenant does not raise. The `acts_as_tenant` default scope is skipped, so the query returns rows from every account. Code that runs outside a request (console, rake tasks, jobs, tests) must set a tenant with `ActsAsTenant.with_tenant(account)` or query through the account association. Setting `config.require_tenant = true` makes these queries raise `ActsAsTenant::Errors::NoTenantSet` instead, but that is a project decision, not the Jumpstart Pro default.

### Request Lifecycle: How Current.account Gets Set

Understanding when and how `Current.account` is set is critical for debugging multi-tenancy issues:

Jumpstart Pro does not define a `set_current_account` method and does not store the account in `session`. The account is resolved by `Jumpstart::AccountMiddleware` and the `SetCurrentRequestDetails` concern, which `ApplicationController` includes. Rails resets `Current` between requests.

**1. `Jumpstart::AccountMiddleware` (path-based tenancy only)**

The engine adds this middleware when `Jumpstart.config.multitenancy` in `config/jumpstart.rb` includes `path`, and always in the test environment. When the first path segment is an integer or UUID (`/12345/projects`), it sets `Current.account = Account.find_by(id:)`, moves the segment into `script_name`, and routes the rest of the path normally. An unknown ID redirects to `/`.

**2. `SetCurrentRequestDetails` before_actions**

```ruby
# lib/jumpstart/app/controllers/concerns/set_current_request_details.rb (abridged)
included do |base|
  if base < ActionController::Metal
    set_current_tenant_through_filter if defined? ActsAsTenant
    before_action :set_request_details
    before_action :set_fallback_account
    before_action -> { set_current_tenant(Current.account) } if defined?(ActsAsTenant)
  end
end

def set_request_details
  Current.user = current_user
  # Account may already be set by the AccountMiddleware
  Current.account ||= account_from_domain || account_from_subdomain || account_from_cookie
end

def set_fallback_account
  Current.account ||= fallback_account
end
```

Resolution order after the middleware:

| Source | Enabled when | Lookup |
|--------|--------------|--------|
| Custom domain | `multitenancy` includes `subdomain` | `Account.find_by(domain: request.host)` |
| Subdomain | `multitenancy` includes `subdomain` | `Account.find_by(subdomain: request.subdomains.first)` |
| Signed cookie | Always; skipped when the user is signed out or the controller has no cookies (API) | `current_user.accounts.find_by(id: cookies.signed[:account_id])` |
| Fallback | Signed-in user | Personal account first, then oldest; creates a default account if the user has none |

When `multitenancy` is empty, only the cookie and fallback apply. This is the default.

**3. Tenant set → all `AccountRecord` queries scoped**

The last before_action calls `set_current_tenant(Current.account)`, so `ActsAsTenant.current_tenant` matches `Current.account` for the rest of the action:

```ruby
Document.all  # SELECT * FROM documents WHERE account_id = ?
```

**Membership is not checked for every source.** The cookie and fallback lookups go through `current_user.accounts`. The path, domain, and subdomain lookups use `Account.find_by` and do not check that the signed-in user belongs to the account. For a non-member, `Current.account_user` is nil, so `Current.account_admin?` is false and Pundit receives a nil `pundit_user`. Controllers that serve account data under path or subdomain tenancy must check membership (for example, `Current.account_user.present?`) or rely on a policy that rejects a nil account user.

**API controllers**

`Api::BaseController` includes `SetCurrentRequestDetails`, skips the fallback account, and adds its own lookup from the `account_id` parameter:

```ruby
# lib/jumpstart/app/controllers/api/base_controller.rb (abridged)
skip_before_action :set_fallback_account
before_action :set_account_from_param

def set_account_from_param
  if (account_id = params[:account_id].presence)
    Current.account ||= current_user.accounts.find_by_prefix_id(account_id)
  end
end
```

- API controllers have no cookies and no fallback account. Without domain or subdomain tenancy, `Current.account` is nil unless the request carries `account_id`.
- `account_id` is the prefixed account ID (`acct_...`), looked up through `current_user.accounts`. An ID for an account the user does not belong to leaves `Current.account` nil. Jumpstart Pro does not respond `:forbidden`.
- `set_account_from_param` runs after the before_action that calls `set_current_tenant(Current.account)`, so the account it finds does not become the `acts_as_tenant` tenant. `AccountRecord` queries in API actions are unscoped unless the controller sets the tenant itself (see Common Pitfall 2).

The `api-specialist` skill documents the rest of the stack.

**IMPORTANT:** The `current_account` helper reads `Current.account`, which `SetCurrentRequestDetails` sets during a request. It is not set in:
- Background jobs
- Mailers
- Plain Ruby service objects
- Console sessions

### Understanding `Current.account` vs `current_account`

**`Current.account`** (Thread-safe attribute):
- Request-specific, thread-safe storage
- Set via `Current.account = account`
- Used in models, jobs, services (anywhere in the stack)
- Cleared automatically between requests
- Source of truth for the current account

**`current_account`** (Controller/view helper):
- Convenience method that reads `Current.account`
- Available in controllers, views, helpers
- NOT available in models, jobs, or plain Ruby classes
- Syntactic sugar for easier access in views/controllers

Key patterns:
```ruby
# All account-scoped models inherit from AccountRecord
class Document < AccountRecord
  # Automatically scoped to current_account
end

# In controllers - use current_account helper
def index
  @documents = current_account.documents
end

# In models/services - use Current.account
class DocumentService
  def process
    account = Current.account  # Access from anywhere
    account.documents.process_all
  end
end

# Background jobs - explicit account scoping
class ProcessJob < ApplicationJob
  def perform(account)
    ActsAsTenant.with_tenant(account) do
      # The tenant is set for this block; Current.account is still nil
      account.documents.process_all
    end
  end
end
```

### Modular Model Organization

Models use concern modules for organization:
```ruby
# app/models/user.rb
class User < ApplicationRecord
  include Accounts      # Multi-account membership
  include Agreements    # Terms acceptance
  include Authenticatable  # Devise extensions
  include Mentions      # @mention support
  include Notifiable    # Notifications
  include Searchable    # Full-text search
  include Theme         # UI preferences
end

# app/models/account.rb
class Account < ApplicationRecord
  include Billing       # Subscription management (see billing-specialist)
  include Domains       # Custom domains
  include Transfer      # Ownership transfer
  include Types         # Personal vs Team
end
```

## Account Types & Roles

### Account Types
- **Personal** - `personal: true`. When `Jumpstart.config.personal_accounts?` is enabled, `User#create_default_account` creates one for each new user, owned by that user. Otherwise the default account is a team account.
- **Team** - `personal: false`. Can have multiple members with per-account roles.

Use `account.personal?`, `account.team?`, and the `Account.personal` and `Account.team` scopes.

### Owner and Roles

Jumpstart Pro has one account role and a separate owner:

- **Owner** - `Account#owner` (`owner_id`). Not a role. Check it with `account.owner?(user)` or `account_user.account_owner?`. When an account is created, the owner is added as an admin member, and `AccountUser` validation prevents removing the owner's `admin` role.
- **admin** - The only role in `AccountUser::ROLES` (`[:admin]`). Admins manage members, invitations, account settings, and billing.
- **Members without a role** - An `AccountUser` whose `roles` has no `admin: true`. Jumpstart Pro has no `member` role and no `AccountUser::MEMBER` constant.

Roles are stored as booleans in the `roles` JSON column. `AccountUser::Roles` defines a reader, predicate, writer, and scope for each entry in `ROLES`:

```ruby
account_user.admin?        # => true
account_user.admin = true  # casts "1", "true", etc. to a boolean
account_user.active_roles  # => [:admin]
AccountUser.admin          # scope: members with the admin role
account.admins             # users with the admin role on this account
```

Role checking for the current request:

```ruby
Current.account_user          # AccountUser for Current.user in Current.account, or nil
Current.account_admin?        # => true when Current.account_user.admin?
Current.roles                 # => [:admin] or []
Current.account.owner?(Current.user)
```

There is no `current_account_user` helper, no `owner?` method on `AccountUser`, and no `admin_or_owner?` method. Because the owner is always an admin, `Current.account_admin?` covers the owner.

In controllers, use the built-in guards:

- `require_current_account_admin` (from the `Authentication` concern) redirects unless `Current.account_admin?`. Billing and checkout controllers use it.
- `require_account_admin` (in `Accounts::BaseController`) checks the admin role on `@account` rather than `Current.account`.

To add a role, add it to `AccountUser::ROLES` in `app/models/account_user.rb` (for example, `ROLES = [:admin, :editor]`). Do not use a reserved word such as `user` or `account` as a role name. `AccountInvitation` shares the same `ROLES`, and the member and invitation forms list each role as a checkbox.

## Account Invitations

Jumpstart provides invitation workflows for team accounts:

### Sending Invitations

```ruby
# Create an invitation and send the email
invitation = Current.account.account_invitations.new(
  name: params[:name],
  email: params[:email],
  invited_by: current_user,
  admin: false  # or true to invite as an admin
)
invitation.save_and_send_invite
# => false when validation fails (for example, the email was already invited)
```

`save_and_send_invite` saves the invitation and sends `AccountMailer#invite` with `deliver_later`. Calling `save` or `create!` alone does not send the email. `has_secure_token` generates the token used in the invitation URL. `send_invite` resends the email for an existing invitation.

### Accepting Invitations

```ruby
# Find invitation by token
invitation = AccountInvitation.find_by!(token: params[:id])

# Accept invitation
invitation.accept!(current_user)
# Creates an AccountUser with the invitation's roles, destroys the invitation,
# and notifies the account owner and inviter. Returns nil and adds errors
# to the invitation when the AccountUser is invalid.
```

### Key Files

- `lib/jumpstart/app/models/account_invitation.rb` - Invitation model
- `lib/jumpstart/app/controllers/accounts/account_invitations_controller.rb` - Admin actions to create, edit, resend, and delete invitations
- `lib/jumpstart/app/controllers/account_invitations_controller.rb` - Invitee actions to view, accept, and decline an invitation
- `lib/jumpstart/app/views/accounts/account_invitations/` and `lib/jumpstart/app/views/account_invitations/` - Invitation views
- Routes in `config/routes/accounts.rb`

## Account Switching

Users can belong to multiple accounts and switch between them:

Jumpstart Pro has no `switch_account` controller helper. How a switch works depends on the tenancy mode:

| Mode | Switch mechanism |
|------|------------------|
| Subdomain (account has a subdomain) | Link to `root_url(subdomain: account.subdomain)` |
| Path | Link to `root_url(script_name: "/#{account.id}")`; `AccountMiddleware` reads the ID |
| Session cookie (default) | `PATCH /accounts/:id/switch` writes `cookies.signed.permanent[:account_id]` and redirects |

`AccountsController#switch` loads the account with `current_user.accounts.find(params[:id])` in its `set_account` before_action, so a user cannot switch to an account they do not belong to. The new account takes effect on the next request, not the current one.

In views, use the `switch_account_button(account)` helper from `AccountsHelper`. It renders a link for subdomain and path modes and a `PATCH` button to `switch_account_path(account)` for cookie mode:

```erb
<%= switch_account_button(account, return_to: request.path) %>
```

Do not write `session[:account_id]` or assign `Current.account` from a user-supplied ID in a controller. The cookie lookup in `SetCurrentRequestDetails` goes through `current_user.accounts`, and bypassing it skips that membership check.

## Impersonation (Admin Feature)

System admins (users with `admin: true`) can sign in as another user from the Madmin admin area for support. Jumpstart Pro implements this with the `pretender` gem: `Authentication` and `Madmin::ApplicationController` call `impersonates :user`, and `ApplicationCable::Connection` identifies by `true_user`. Jumpstart Pro provides no impersonation guard concern, `impersonating?` helper, `Current.impersonator`, or impersonation log.

### How Impersonation Works

```ruby
# lib/jumpstart/app/controllers/madmin/user/impersonates_controller.rb (Jumpstart Pro)
class Madmin::User::ImpersonatesController < Madmin::ApplicationController
  def create
    user = ::User.find(params[:user_id])
    impersonate_user(user)
    redirect_to main_app.root_path, status: :see_other
  end

  def destroy
    user = current_user
    stop_impersonating_user
    redirect_to main_app.madmin_user_path(user), status: :see_other
  end
end
```

- `impersonate_user(user)` stores the user's ID in `session[:impersonated_user_id]`. `stop_impersonating_user` deletes it.
- While impersonating, `current_user` returns the impersonated user and `true_user` returns the signed-in admin. Both are available in views.
- `Madmin::ApplicationController` authorizes with `true_user&.admin?`, so the admin area stays reachable during impersonation.
- The `application` and `minimal` layouts render `impersonation_banner` (`FlashHelper`), which appears when `current_user != true_user` and shows a "Log out" button that stops impersonating.

Every authorization check that reads `current_user` or `Current.account_user` sees the impersonated user. If that user is an account admin, `require_current_account_admin` lets the impersonating admin through, including on the billing controllers.

### Blocking Sensitive Actions

Add the guard as application code. Compare `current_user` with `true_user`:

```ruby
# app/controllers/concerns/impersonation_guard.rb (application code)
module ImpersonationGuard
  extend ActiveSupport::Concern

  included do
    helper_method :impersonating?
  end

  private

  def impersonating?
    user_signed_in? && current_user != true_user
  end

  def block_during_impersonation
    return unless impersonating?

    redirect_back fallback_location: root_path,
      alert: "This action is disabled while impersonating a user."
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include ImpersonationGuard
end

# Apply it to controllers that change billing, credentials, or account ownership
class Billing::SubscriptionsController < ApplicationController
  before_action :block_during_impersonation, except: [:index, :show, :edit]
end
```

Jumpstart Pro's billing controllers live under `lib/jumpstart/app/controllers/`. To add the `before_action`, copy the controller to the same path under `app/controllers/`, which takes precedence, and keep the copy in sync during upstream merges.

### Logging and Restricting Impersonation

Jumpstart Pro does not log impersonation or restrict its targets. Override `Madmin::User::ImpersonatesController` in `app/controllers/madmin/user/impersonates_controller.rb` to add both:

```ruby
class Madmin::User::ImpersonatesController < Madmin::ApplicationController
  def create
    user = ::User.find(params[:user_id])

    if user.admin?
      redirect_to main_app.madmin_user_path(user), alert: "System admins cannot be impersonated."
      return
    end

    ImpersonationLog.create!(
      impersonator: true_user,
      impersonated_user: user,
      started_at: Time.current,
      ip_address: request.remote_ip
    )
    impersonate_user(user)
    redirect_to main_app.root_path, status: :see_other
  end

  def destroy
    user = current_user
    ImpersonationLog.where(impersonator: true_user, impersonated_user: user, ended_at: nil)
      .update_all(ended_at: Time.current)
    stop_impersonating_user
    redirect_to main_app.madmin_user_path(user), status: :see_other
  end
end

# app/models/impersonation_log.rb (application code)
class ImpersonationLog < ApplicationRecord
  belongs_to :impersonator, class_name: "User"
  belongs_to :impersonated_user, class_name: "User"
end
```

`ImpersonationLog` inherits from `ApplicationRecord`, not `AccountRecord`, because impersonation targets a user rather than an account, and `Madmin::ApplicationController` runs its actions without a tenant.

### Safeguards Checklist

- ✅ Include `ImpersonationGuard` and call `block_during_impersonation` in controllers that change billing, credentials, or account ownership
- ✅ Log each impersonation session with start and end times and the IP address
- ✅ Keep `impersonation_banner` in every layout
- ✅ Refuse to impersonate system admins
- ✅ Check `true_user`, not `current_user`, when an action needs the real signed-in admin

## Authorization (Pundit)

All authorization through Pundit policies. Jumpstart Pro combines Pundit with `acts_as_tenant` for automatic scoping.

### Policy Structure

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  def index?
    true  # All account members can view
  end

  def create?
    account_member?  # Must be account member
  end

  def update?
    account_admin? || record.user_id == user.id  # Admin or owner
  end

  def destroy?
    account_admin?  # Only admins can delete
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # acts_as_tenant already scopes to Current.account
      # Just return the scope - no manual where(account:) needed!
      scope.all
    end
  end
end

# app/policies/application_policy.rb (Jumpstart Pro base)
class ApplicationPolicy
  attr_reader :user, :record, :account, :account_user

  def initialize(user, record)
    @user = user
    @record = record
    @account = Current.account
    @account_user = Current.account_user
  end

  # Helper methods available in all policies
  def account_member?
    account_user.present?
  end

  def account_admin?
    account_user&.admin? || account_user&.owner?
  end

  def account_owner?
    account&.owner_id == user&.id
  end

  class Scope
    attr_reader :user, :scope, :account, :account_user

    def initialize(user, scope)
      @user = user
      @scope = scope
      @account = Current.account
      @account_user = Current.account_user
    end

    def resolve
      # Default: Return all records
      # acts_as_tenant handles account scoping automatically
      scope.all
    end
  end
end
```

Because `acts_as_tenant` scopes AccountRecord models, policy scopes typically return `scope.all`. The scoping happens at the model layer, not the policy layer.

```ruby
# ❌ REDUNDANT: acts_as_tenant already does this
class Scope < ApplicationPolicy::Scope
  def resolve
    scope.where(account: account)  # Unnecessary!
  end
end

# ✅ CORRECT: Let acts_as_tenant handle account scoping
class Scope < ApplicationPolicy::Scope
  def resolve
    scope.all  # Already scoped by acts_as_tenant
  end
end

# ✅ WHEN TO ADD FILTERS: Additional authorization beyond tenancy
class Scope < ApplicationPolicy::Scope
  def resolve
    # acts_as_tenant scopes to account automatically
    # Add role-based filtering on top
    if account_admin?
      scope.all  # Admins see everything in the account
    else
      scope.where(public: true)  # Members only see public records
    end
  end
end
```

### Controller Usage

```ruby
class DocumentsController < ApplicationController
  def index
    authorize Document
    @documents = policy_scope(Document)  # Auto-scoped to current_account
  end

  def show
    @document = Document.find(params[:id])  # Auto-scoped to current_account
    authorize @document
  end

  def create
    @document = Document.new(document_params)
    authorize @document
    # account_id set automatically by acts_as_tenant
    @document.save!
  end

  def update
    @document = Document.find(params[:id])
    authorize @document
    @document.update!(document_params)
  end

  def destroy
    @document = Document.find(params[:id])
    authorize @document
    @document.destroy!
  end
end
```

### View Usage

```ruby
# app/views/documents/index.html.erb
<% if policy(Document).create? %>
  <%= link_to "New Document", new_document_path %>
<% end %>

<% @documents.each do |document| %>
  <h3><%= document.title %></h3>
  <% if policy(document).update? %>
    <%= link_to "Edit", edit_document_path(document) %>
  <% end %>
  <% if policy(document).destroy? %>
    <%= link_to "Delete", document_path(document), method: :delete %>
  <% end %>
<% end %>
```

## Tenant-Aware Background Jobs

Jumpstart Pro does not include a tenant-aware base job class. Two facts determine the tenant context inside a job:

- `Current.account` is nil. Rails resets `Current` attributes around every job, and nothing in Jumpstart Pro sets the account again.
- When `acts_as_tenant` is enabled, the gem stores `ActsAsTenant.current_tenant` with the job at enqueue time and restores it before the job's callbacks run. A job enqueued during a request runs scoped to that request's account. A job enqueued without a tenant (console, rake task, scheduled job) runs without one, and because Jumpstart Pro sets `config.require_tenant = false`, its `AccountRecord` queries return rows from every account instead of raising.

Pass the account to the job and set the tenant explicitly, so the job behaves the same wherever it is enqueued.

### Pattern 1: Explicit tenant in `perform` (RECOMMENDED)

```ruby
class ProcessDocumentsJob < ApplicationJob
  queue_as :default

  def perform(account, document_ids)
    ActsAsTenant.with_tenant(account) do
      account.documents.where(id: document_ids).find_each(&:process!)
    end
  end
end

ProcessDocumentsJob.perform_later(Current.account, [1, 2, 3])
```

ActiveJob serializes the `Account` argument as a GlobalID and loads it again when the job runs. Querying through `account.documents` keeps the query scoped even if the tenant is not set. Omit `ActsAsTenant.with_tenant` in applications that do not enable `acts_as_tenant`.

`ActsAsTenant.with_tenant` does not set `Current.account`. When code called from the job reads `Current.account` (model callbacks, notifiers, services), set both:

```ruby
def perform(account, document_ids)
  Current.set(account: account) do
    ActsAsTenant.with_tenant(account) do
      account.documents.where(id: document_ids).find_each(&:process!)
    end
  end
end
```

### Pattern 2: Application base class for many tenant jobs

When several jobs need the same setup, define a base class in the application. This class is application code and does not exist in Jumpstart Pro:

```ruby
# app/jobs/account_job.rb
class AccountJob < ApplicationJob
  # Subclasses take the account as the first perform argument.
  around_perform do |job, block|
    account = job.arguments.first
    Current.set(account: account) do
      ActsAsTenant.with_tenant(account, &block)
    end
  end
end

class ExportJob < AccountJob
  before_perform :log_start
  after_perform :log_finish

  def perform(account, format)
    Export.generate(format: format)
  end

  private

  def log_start
    Rails.logger.info "Starting export for account #{Current.account.id}"
  end

  def log_finish
    Rails.logger.info "Finished export for account #{Current.account.id}"
  end
end

ExportJob.perform_later(Current.account, "csv")
```

### ActiveJob callbacks and tenant context

ActiveJob runs `before_perform`, `after_perform`, and `around_perform` callbacks in the order they are declared, parent class first. Each callback declared after an `around_perform` runs inside it. In `ExportJob` above, `log_start` and `log_finish` run inside `AccountJob`'s `around_perform`, so `Current.account` and the tenant are both set. A `before_perform` declared before the `around_perform` (earlier in the same class or in a parent class) runs outside it and sees `Current.account` as nil.

With `acts_as_tenant` enabled, a tenant captured at enqueue time is restored before any callback runs, so `ActsAsTenant.current_tenant` is available in every callback of a job enqueued during a request. `Current.account` is not restored.

### Sidekiq workers

For native Sidekiq workers (not ActiveJob), Jumpstart Pro's `config/initializers/acts_as_tenant.rb` requires `acts_as_tenant/sidekiq` when Sidekiq is loaded. That middleware stores the current tenant with each job and runs the worker inside `ActsAsTenant.with_tenant`. The same limits apply: `Current.account` is not set, and a worker enqueued without a tenant runs without one. Pass the account ID and set the tenant explicitly:

```ruby
class DocumentProcessorWorker
  include Sidekiq::Worker

  def perform(account_id, document_id)
    account = Account.find(account_id)
    ActsAsTenant.with_tenant(account) do
      account.documents.find(document_id).process!
    end
  end
end

DocumentProcessorWorker.perform_async(Current.account.id, document.id)
```

## Non-Request Contexts: Mailers, Action Cable, Active Storage

These contexts run outside normal request/response cycles and need explicit account scoping.

### Action Mailers

Mailers delivered with `deliver_later` run in a job, so `Current.account` is nil there. Pass the account and wrap account-scoped queries in `ActsAsTenant.with_tenant`:

```ruby
# app/mailers/account_mailer.rb
class AccountMailer < ApplicationMailer
  def project_notification(account, project)
    ActsAsTenant.with_tenant(account) do
      @account = account
      @project = project
      @team_members = account.users

      mail to: account.owner.email, subject: "Project Update"
    end
  end
end

# Call from controller with account parameter
AccountMailer.project_notification(current_account, @project).deliver_later

# Or set the tenant for every action from params
class ApplicationMailer < ActionMailer::Base
  around_action :with_account_tenant

  private

  def with_account_tenant(&block)
    return yield unless params&.dig(:account)
    ActsAsTenant.with_tenant(params[:account], &block)
  end
end

# Usage with params
class ProjectMailer < ApplicationMailer
  def created
    @project = params[:project]
    mail to: params[:account].owner.email
  end
end

# Call with account in params
ProjectMailer.with(account: current_account, project: @project).created.deliver_later
```

### Action Cable Channels

Jumpstart Pro resolves the account once, when the WebSocket connects, using the same `SetCurrentRequestDetails` lookups as controllers:

```ruby
# app/channels/application_cable/connection.rb (Jumpstart Pro)
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include SetCurrentRequestDetails

    identified_by :current_user, :current_account, :true_user
    impersonates :user

    delegate :params, :session, to: :request

    def connect
      self.current_user = find_verified_user
      set_request_details
      set_fallback_account
      self.current_account = Current.account

      logger.add_tags "ActionCable", "User #{current_user.id}", "Account #{current_account.id}"
    end

    protected

    def find_verified_user
      if (current_user = env["warden"].user(:user))
        current_user
      else
        reject_unauthorized_connection
      end
    end

    def user_signed_in?
      !!current_user
    end

    # Used by set_request_details
    def set_current_tenant(account)
      ActsAsTenant.current_tenant = account
    end
  end
end
```

The user comes from the Devise (Warden) session, and the account comes from the domain, subdomain, signed `account_id` cookie, or fallback account. Rails mounts Action Cable at `/cable` by default, and that path carries no account ID, so `AccountMiddleware` does not select the account for the connection. `SetCurrentRequestDetails` only adds its before_actions to controllers, so `connect` never calls the connection's `set_current_tenant` and does not set the `acts_as_tenant` tenant. Channel code should read the `current_account` identifier, which lives for the whole connection, instead of `Current.account`, which `connect` sets only while it runs.

**Channel-level scoping:** channels read the `current_account` connection identifier. Scope queries through it or wrap them in `ActsAsTenant.with_tenant`, and derive stream names from it rather than from subscription params:

```ruby
class DocumentChannel < ApplicationCable::Channel
  def subscribed
    # current_account comes from the connection, not from client params
    stream_for current_account
  end

  def receive(data)
    document = current_account.documents.find(data["document_id"])
    document.update!(data["attributes"])

    DocumentChannel.broadcast_to(current_account, {document: document, action: "updated"})
  end
end
```

A channel that accepts an account ID from `params` must look it up through `current_user.accounts` so that a client cannot subscribe to another account's stream.

### Active Storage and File Uploads

File uploads in background jobs or mailers need explicit account context:

```ruby
# ❌ DANGEROUS: Uploading files in background job without account context
class ProcessUploadJob < ApplicationJob
  def perform(document_id, file_data)
    # Unscoped if the job was enqueued without a tenant: finds any account's document
    document = Document.find(document_id)
    document.file.attach(file_data)
  end
end

# ✅ SAFE: Set account context before accessing AccountRecord
class ProcessUploadJob < ApplicationJob
  def perform(account, document_id, file_data)
    ActsAsTenant.with_tenant(account) do
      document = account.documents.find(document_id)
      document.file.attach(file_data)

      # ActiveStorage::Blob and ActiveStorage::Attachment
      # are NOT tenant-scoped, but the Document is
    end
  end
end

# Enqueue with the account
ProcessUploadJob.perform_later(current_account, @document.id, file_data)
```

**CRITICAL:** Active Storage's `Blob` and `Attachment` models are NOT tenant-scoped. Only the parent model (Document) enforces tenancy. This means:
- Blobs can be shared across tenants if you're not careful
- Always validate that the parent record belongs to the current account
- Consider using signed URLs with expiration for sensitive files

```ruby
# Validate before serving files
def download
  @document = Document.find(params[:id])  # Auto-scoped to current_account
  authorize @document  # Pundit policy check

  # Generate short-lived signed URL
  redirect_to @document.file.url(expires_in: 5.minutes), allow_other_host: true
end
```

## Routes Organization

Routes split across files in `config/routes/`:
- `accounts.rb` - Account management, switching, invitations
- `billing.rb` - Subscriptions, payments (see billing-specialist)
- `users.rb` - User profiles, settings, auth
- `api.rb` - API endpoints (see api-specialist)

## Common Pitfalls (Jumpstart-Specific)

### 1. Active Storage Blob Sharing (CRITICAL SECURITY ISSUE)

**Problem:** Active Storage `Blob` and `Attachment` models are NOT tenant-scoped, creating risk of cross-tenant file access.

```ruby
# ❌ DANGEROUS: Direct blob access without validation
def download
  blob = ActiveStorage::Blob.find(params[:id])
  redirect_to blob.url  # Any user can access any blob!
end

# ✅ SAFE: Always validate through the parent AccountRecord
def download
  document = Document.find(params[:document_id])  # Auto-scoped to Current.account
  authorize document  # Pundit check
  redirect_to document.file.url(expires_in: 5.minutes)
end

# ❌ DANGEROUS: Uploading in background job without account context
class ProcessUploadJob < ApplicationJob
  def perform(document_id, file_data)
    # Unscoped if the job was enqueued without a tenant: finds any account's document
    document = Document.find(document_id)
    document.file.attach(file_data)
  end
end

# ✅ SAFE: Set account context before accessing AccountRecord
class ProcessUploadJob < ApplicationJob
  def perform(account, document_id, file_data)
    ActsAsTenant.with_tenant(account) do
      document = account.documents.find(document_id)
      document.file.attach(file_data)
    end
  end
end
```

### 2. API Controllers Without a Tenant (COMMON ERROR)

**Problem:** `Api::BaseController` sets `Current.account` from `params[:account_id]` only after the tenant has been set, and it skips the fallback account. Unless domain or subdomain tenancy found an account, `ActsAsTenant.current_tenant` is nil in API actions, so `AccountRecord` queries return every account's rows. Without an `account_id` parameter, `current_account` is nil as well.

```ruby
# ❌ WRONG: Relies on a tenant that API controllers do not set
class Api::V1::ProjectsController < Api::BaseController
  def index
    @projects = Project.all  # No tenant: returns every account's projects
  end
end

# ✅ CORRECT: Require the account and set the tenant for the action
class Api::V1::ProjectsController < Api::BaseController
  # Route: GET /api/v1/accounts/:account_id/projects (account_id is the prefixed ID, acct_...)
  before_action :require_account_tenant

  def index
    @projects = Project.all  # Scoped to current_account
  end

  private

  def require_account_tenant
    return head(:not_found) unless current_account

    set_current_tenant(current_account)
  end
end
```

`Api::BaseController#set_account_from_param` already resolves the account through `current_user.accounts`, so a controller does not need to repeat the lookup. `Current.account_user` is a reader that `Current` computes from `Current.account` and `Current.user`. It is not an attribute, so do not assign it.

### 3. Console Commands Without Account Context (DEVELOPMENT TRAP)

**Problem:** Console queries without a tenant return or change every account's data, and creates fail validation because no account is assigned.

```ruby
# ❌ DANGEROUS: No account context
make console
> Project.create!(title: "Test")  # ActiveRecord::RecordInvalid: Account must exist
> Project.all  # Returns every account's projects

# ✅ SAFE: Set account context first
make console
> account = Account.first
> ActsAsTenant.with_tenant(account) do
>   Project.create!(title: "Test")
> end

# ✅ BETTER: Use fallback tenant for console exploration
make console
> ActsAsTenant.current_tenant = Account.first
> Project.create!(title: "Test")  # Auto-scoped
> Project.all  # Auto-scoped

# ✅ BEST: Create console helper (see Testing section)
make console
> set_account("admin@example.com")
> Project.all  # Auto-scoped
```

### 4. Rake Tasks Without Account Context (PRODUCTION DANGER)

**Problem:** Rake tasks run outside request/response cycle and need explicit scoping.

```ruby
# ❌ DANGEROUS: Global operation on all accounts
namespace :reports do
  task generate: :environment do
    Project.find_each do |project|  # No tenant: queries inside generate_report are unscoped too
      project.generate_report
    end
  end
end

# ✅ SAFE: Iterate through accounts explicitly
namespace :reports do
  task generate: :environment do
    Account.find_each do |account|
      ActsAsTenant.with_tenant(account) do
        Project.find_each do |project|
          project.generate_report
        end
      end
    end
  end
end

# ✅ BETTER: Task scoped to specific account
namespace :reports do
  task :generate, [:account_id] => :environment do |t, args|
    account = Account.find(args[:account_id])
    ActsAsTenant.with_tenant(account) do
      Project.find_each(&:generate_report)
    end
  end
end

# Usage: rails reports:generate[123]
```

### 5. Background Jobs Reading `Current.account`

**Problem:** `Current.account` is nil in every job unless the job sets it. `ActsAsTenant.with_tenant` and the tenant that `acts_as_tenant` restores at enqueue time do not set it. A callback also sees nil when it is declared before the `around_perform` that sets the context.

```ruby
# ❌ WRONG: Nothing sets Current.account in a job
class ExportJob < ApplicationJob
  def perform(account)
    Rails.logger.info "Starting export for #{Current.account.name}"  # NoMethodError on nil
    Export.generate
  end
end

# ❌ WRONG: before_perform declared before the around_perform runs outside it
class ExportJob < ApplicationJob
  before_perform { Rails.logger.info "Starting export for #{Current.account&.name}" }  # nil

  around_perform do |job, block|
    Current.set(account: job.arguments.first, &block)
  end
end

# ✅ CORRECT: Read the account from the arguments, or set Current.account first
class ExportJob < AccountJob  # AccountJob's around_perform sets Current.account and the tenant
  before_perform :log_start  # Declared after the parent's around_perform, so it runs inside it

  def perform(account)
    Export.generate
  end

  private

  def log_start
    Rails.logger.info "Starting export for #{Current.account.name}"
  end
end
```

See "ActiveJob callbacks and tenant context" under Tenant-Aware Background Jobs for the ordering rule.

### 6. Migration Generators Missing Indexes and null: false

**Problem:** Forgetting to add database constraints on account_id.

```ruby
# ❌ INCOMPLETE: Missing index and null constraint
rails g model Project title:string account:references
# Generates: add_reference :projects, :account, foreign_key: true

# ✅ COMPLETE: Use belongs_to with index option
rails g model Project title:string account:belongs_to{index}
# Generates: add_reference :projects, :account, null: false, foreign_key: true, index: true

# ✅ MANUAL MIGRATION: Add both constraints
class CreateProjects < ActiveRecord::Migration[7.0]
  def change
    create_table :projects do |t|
      t.string :title
      t.references :account, null: false, foreign_key: true, index: true
      t.timestamps
    end
  end
end
```

### 7. Fixture Data Without Account Associations

**Problem:** Test fixtures missing account references fail to load when `account_id` is `null: false`, or load as records that belong to no account.

```ruby
# ❌ BREAKS TESTS: Missing account association
# test/fixtures/projects.yml
project_one:
  title: "Test Project"
  # Missing account: reference

# Fixture loading fails with ActiveRecord::NotNullViolation

# ✅ FIXED: Explicit account association
# test/fixtures/projects.yml
project_one:
  title: "Test Project"
  account: one  # References accounts(:one)
```

### Architecture & Multi-tenancy
- ❌ Creating models without inheriting from AccountRecord
- ❌ Using `current_account` in models (use `Current.account` instead)
- ❌ Forgetting `acts_as_tenant` already scopes queries (don't add redundant `where(account:)`)
- ✅ Always inherit from AccountRecord for tenant-scoped models
- ✅ Use `Current.account` in models, `current_account` in controllers/views

### Authorization & Security
- ❌ Bypassing Pundit authorization checks
- ❌ Accessing Active Storage blobs directly without parent record validation
- ✅ Apply Pundit policies consistently
- ✅ Always validate file access through parent AccountRecord

### Background Jobs & Async Operations
- ❌ Relying on `Current.account` in a job without setting it
- ❌ Relying on the tenant captured at enqueue time, which is absent for jobs enqueued from the console, rake tasks, or schedules
- ✅ Pass the account as an argument and set the tenant with `ActsAsTenant.with_tenant(account)`
- ✅ Set `Current.account` with `Current.set` when code called from the job reads it
- ✅ Declare callbacks that read the account after the `around_perform` that sets it

### Development Workflow
- ❌ Running console without `ActsAsTenant.current_tenant` set
- ❌ Creating rake tasks without account iteration
- ❌ Missing account context in seeds
- ✅ Use console helpers to set account context
- ✅ Iterate through accounts in rake tasks
- ✅ Wrap seed data in `ActsAsTenant.with_tenant`

## Best Practices

### Architecture & Data Access
1. **Always scope to current_account** for multi-tenant data
2. **Use AccountRecord** as base class for account-scoped models
3. **Use Current.account in models**, `current_account` helper in controllers/views
4. **Follow concern patterns** for model organization (Billing, Transfer, etc.)

### Authorization
5. **Apply Pundit policies** for all authorization checks
6. **Define policy scopes** to automatically filter data by account
7. **Use policy helpers** like `account_admin?` and `account_member?`

### Testing
8. **Test with fixtures** following Jumpstart patterns in `test/fixtures/`
9. **Use system tests** for Hotwire/Turbo interactions
10. **Test multi-tenancy** by switching accounts in tests

## Testing Multi-Tenancy

### Fixtures and Seeds

Jumpstart Pro provides tenant-aware fixtures for testing:

```ruby
# test/fixtures/accounts.yml
one:
  name: "Acme Corp"
  personal: false

two:
  name: "Jane's Account"
  personal: true
  owner: jane

# test/fixtures/users.yml
account_owner:
  name: "John Doe"
  email: "john@example.com"
  accounts: [one]

jane:
  name: "Jane Smith"
  email: "jane@example.com"
  accounts: [two]

# test/fixtures/projects.yml (AccountRecord model)
project_one:
  title: "Project Alpha"
  account: one  # Belongs to Acme Corp

project_two:
  title: "Project Beta"
  account: two  # Belongs to Jane's Account
```

**CRITICAL:** Always associate fixtures with accounts to prevent test data leaks:

```ruby
# ❌ BAD: No account association
project_orphan:
  title: "Orphan Project"
  # Missing account: - fixture loading fails with ActiveRecord::NotNullViolation

# ✅ GOOD: Explicit account
project_scoped:
  title: "Scoped Project"
  account: one
```

### Unit Tests

Test models with explicit account context:

```ruby
class ProjectTest < ActiveSupport::TestCase
  test "should belong to account" do
    project = projects(:project_one)
    assert_equal accounts(:one), project.account
  end

  test "should scope to current account" do
    ActsAsTenant.with_tenant(accounts(:one)) do
      projects = Project.all
      assert_equal 1, projects.count
      assert_includes projects, projects(:project_one)
      assert_not_includes projects, projects(:project_two)
    end
  end

  test "returns every account's records without account context" do
    # Jumpstart Pro sets config.require_tenant = false, so nothing raises
    all_projects = Project.all
    assert_includes all_projects, projects(:project_one)
    assert_includes all_projects, projects(:project_two)
  end
end
```

### Controller Tests

Controller tests automatically set `Current.account` via `sign_in`:

```ruby
class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:account_owner)
    @account = accounts(:one)
    sign_in @user
    # Current.account automatically set to @user.accounts.first
  end

  test "should get index" do
    get projects_url
    assert_response :success
    # Only sees projects from current_account
  end

  test "should switch accounts" do
    other_account = accounts(:two)
    @user.accounts << other_account  # Add user to second account

    switch_account(other_account)  # Jumpstart Pro test helper: PATCH /accounts/:id/switch
    assert_redirected_to root_path

    get projects_url
    # Now seeing projects from other_account
  end
end
```

### System Tests

System tests with account switching:

```ruby
class ProjectsSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:account_owner)
    @account = accounts(:one)
  end

  test "switching accounts shows different projects" do
    # Signing in selects the fallback account (personal account first)
    sign_in @user
    visit projects_path

    # Should see account one's projects
    assert_selector "h1", text: projects(:project_one).title
    assert_no_selector "h1", text: projects(:project_two).title

    # Switch to account two
    other_account = accounts(:two)
    @user.accounts << other_account
    switch_account(other_account)  # Jumpstart Pro helper in ApplicationSystemTestCase
    visit projects_path

    # Should see account two's projects
    assert_selector "h1", text: projects(:project_two).title
    assert_no_selector "h1", text: projects(:project_one).title
  end
end
```

### Seed Data

Seed files must set account context:

```ruby
# db/seeds.rb
# Create admin user
admin = User.create!(
  name: "Admin User",
  email: "admin@example.com",
  password: "password",
  password_confirmation: "password",
  terms_of_service: true
)

# Create personal account
account = admin.accounts.create!(
  owner: admin,
  name: admin.name,
  personal: true
)

account.account_users.create!(
  user: admin,
  admin: true
)

# Seed account-scoped data
ActsAsTenant.with_tenant(account) do
  Project.create!(title: "Sample Project", description: "Demo project")
  Document.create!(title: "Getting Started", content: "Welcome!")
end

# For team accounts
team = Account.create!(
  owner: admin,
  name: "Team Account",
  personal: false
)

team.account_users.create!(user: admin, admin: true)

ActsAsTenant.with_tenant(team) do
  Project.create!(title: "Team Project")
end
```

### Console Testing

Always wrap console commands with account context:

```ruby
# ❌ DANGEROUS: Global query
make console
> Project.all  # Returns every account's projects

# ✅ SAFE: Set account context
make console
> account = Account.first
> ActsAsTenant.with_tenant(account) do
>   Project.all  # Scoped to account
> end

# Or set fallback for console exploration
> ActsAsTenant.current_tenant = Account.first
> Project.all  # Now works, scoped to fallback tenant
```

**Pro tip:** Create a console helper:

```ruby
# lib/console_helpers.rb
module ConsoleHelpers
  def set_account(account_id_or_email)
    account = account_id_or_email.is_a?(Integer) ?
      Account.find(account_id_or_email) :
      Account.joins(:users).where(users: { email: account_id_or_email }).first

    ActsAsTenant.current_tenant = account
    puts "Set current account to: #{account.name} (#{account.id})"
    account
  end
end

# config/application.rb
console do
  require 'console_helpers'
  include ConsoleHelpers
end

# Usage
make console
> set_account("admin@example.com")
> Project.all  # Auto-scoped
```

## Checklists

### Feature Delivery Checklist

Use this checklist before shipping any feature that involves tenant data:

**Models & Database:**
- [ ] New models inherit from `AccountRecord` (not `ApplicationRecord`)
- [ ] Migrations include `account:belongs_to{index}` or manual `references :account, null: false, index: true`
- [ ] Database seeds wrapped in `ActsAsTenant.with_tenant(account)`
- [ ] Fixtures include `account:` references

**Controllers & Views:**
- [ ] Controllers use `current_account.records` for scoping
- [ ] Pundit policies applied with `authorize` and `policy_scope`
- [ ] Views check permissions with `policy(record).action?`
- [ ] File uploads validated through parent AccountRecord, not direct blob access

**Background Jobs:**
- [ ] Jobs take the account as an argument and wrap tenant work in `ActsAsTenant.with_tenant(account)`
- [ ] Jobs that read `Current.account` set it with `Current.set`
- [ ] Callbacks that read the account are declared after the `around_perform` that sets it
- [ ] Jobs enqueued with `current_account` as an argument

**API Endpoints:**
- [ ] Account-scoped routes nested under `/api/v1/accounts/:account_id/`, where `account_id` is the prefixed account ID
- [ ] Controller responds `:not_found` when `current_account` is nil (missing `account_id`, or an account the user does not belong to)
- [ ] Controller calls `set_current_tenant(current_account)` or scopes queries through `current_account`, because `Api::BaseController` does not set the tenant from `account_id`
- [ ] No `Current.account` or `Current.account_user` assignments from params
- [ ] API documentation includes the `account_id` parameter

**Action Cable Channels:**
- [ ] Channels use the `current_account` connection identifier, not `Current.account`
- [ ] Streams derived from `current_account` (`stream_for current_account`), not from client params
- [ ] Queries scoped through `current_account` or `ActsAsTenant.with_tenant(current_account)`; the tenant is not set in channels
- [ ] Any account ID taken from `params` is looked up through `current_user.accounts`

**Testing:**
- [ ] Unit tests use `ActsAsTenant.with_tenant(accounts(:one))` wrapper
- [ ] Controller tests use `sign_in` to set `Current.account`
- [ ] System tests include account switching scenarios
- [ ] Fixtures have explicit account associations

### Background Job Review Checklist

Review this before deploying any background job:

**Structure:**
- [ ] Takes the account as an argument: `def perform(account, ...)`
- [ ] Wraps tenant work in `ActsAsTenant.with_tenant(account)`, or inherits from an application base class that does
- [ ] Does not assume `Current.account` is set, and sets it with `Current.set` when needed

**Callbacks:**
- [ ] `before_perform` / `after_perform` that read the account are declared after the `around_perform` that sets it
- [ ] Logging includes account identifier for debugging

**Enqueueing:**
- [ ] Enqueued with the account as an argument: `Job.perform_later(current_account, record.id)`
- [ ] Jobs enqueued outside a request (console, rake, schedules) pass the account explicitly
- [ ] No bare model IDs looked up without the account

**Error Handling:**
- [ ] Scopes queries through the account argument, because a missing tenant returns every account's rows (Jumpstart Pro sets `config.require_tenant = false`)
- [ ] Logs errors with account context for debugging
- [ ] Retries don't lose account context

**File Operations:**
- [ ] Active Storage operations wrapped in `ActsAsTenant.with_tenant` block
- [ ] File uploads validate parent record belongs to account
- [ ] Temporary files cleaned up regardless of account

### Multi-Tenancy Security Audit Checklist

Periodic security review for tenant isolation:

**Data Access:**
- [ ] All AccountRecord queries automatically scoped (test by removing `Current.account`)
- [ ] No raw SQL bypassing `acts_as_tenant` scoping
- [ ] No `unscoped` calls on AccountRecord models
- [ ] Cross-account data leaks tested with multiple accounts

**Authorization:**
- [ ] All controller actions have `authorize` or `policy_scope`
- [ ] Policy scopes return `scope.all` (let `acts_as_tenant` handle scoping)
- [ ] No hardcoded account IDs in code
- [ ] Admin actions require proper role checks

**File Access:**
- [ ] Active Storage blobs accessed through parent AccountRecord
- [ ] Signed URLs expire within reasonable time (5-15 minutes)
- [ ] Direct blob downloads blocked in routes
- [ ] File upload validations include account ownership

**Background Processing:**
- [ ] All tenant jobs set the tenant from an account argument
- [ ] No global queries in background jobs
- [ ] Scheduled tasks iterate through accounts explicitly
- [ ] Rake tasks accept `account_id` parameter or iterate all accounts

**API Security:**
- [ ] All API endpoints require account_id in route or params
- [ ] Account membership verified before setting `Current.account`
- [ ] API tokens scoped to specific accounts
- [ ] Rate limiting applied per account, not globally

**Impersonation:**
- [ ] Impersonation logged with start/end timestamps in the `Madmin::User::ImpersonatesController` override
- [ ] Billing/payment actions call `block_during_impersonation` (compares `current_user` with `true_user`)
- [ ] `impersonation_banner` rendered in every layout
- [ ] Cannot impersonate system admins (`user.admin?`)

### Deployment Checklist (Multi-Tenancy Focus)

Before deploying tenant-related changes:

**Database:**
- [ ] Migrations add `null: false` and index on `account_id`
- [ ] No data migrations without account iteration
- [ ] Rollback plan tested with multiple accounts
- [ ] Foreign key constraints in place

**Performance:**
- [ ] Indexes exist on all `account_id` columns
- [ ] N+1 queries resolved with `includes(:account)`
- [ ] Eager loading applied for account associations
- [ ] Query performance tested with large account datasets

**Monitoring:**
- [ ] Error tracking includes account context
- [ ] Metrics grouped by account for multi-tenant insights
- [ ] Alerts configured for cross-tenant data access attempts
- [ ] Audit logs capture account-specific actions

**Rollback Safety:**
- [ ] Code changes backward compatible with current schema
- [ ] Feature flags control tenant-specific features
- [ ] Rollback tested with active account sessions
- [ ] No irreversible cross-account data changes
