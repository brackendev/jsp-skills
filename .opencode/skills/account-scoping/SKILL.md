---
name: account-scoping
description: 'Jumpstart Pro multi-tenancy checklist. Use whenever the user creates or generates a Rails model, controller, resource, scaffold, or background job (including rails g generators), even when tenancy is not mentioned. Prevents tenant isolation bugs.'
allowed-tools: Read, Grep, Glob
user-invocable: false
---

# Account Scoping Checklist

Fast checklist for Jumpstart Pro multi-tenancy when generating a model, controller, or background job. The `multi-tenancy-specialist` skill carries the full patterns (the `Current.account` request lifecycle, account switching, impersonation, background-job tenant context, and Pundit policy and scope design). This checklist is the quick gate at generation time.

## Critical rule

Every tenant-specific resource is scoped to an account. Skipping account scoping breaks tenant isolation and creates a security vulnerability.

## New model

1. Inherit from `AccountRecord` (not `ApplicationRecord`), which scopes queries to `Current.account` through `acts_as_tenant`.
2. Add the account reference in the migration: `t.references :account, null: false, foreign_key: true, index: true`.
3. Add a fixture with an account (`account: one`, referencing `test/fixtures/accounts.yml`).
4. Test isolation with the `switch_account(account)` helper, asserting one account cannot see another's records.

```ruby
class Document < AccountRecord
end
```

Models that are genuinely global (`User`, `Plan`) are the exception.

## New controller

1. Scope every query through `current_account` (`current_account.documents.find(...)`), never `Document.find` or `Document.all`.
2. Add a Pundit policy and call `authorize` (or `policy_scope`) in each action. See `multi-tenancy-specialist` for the Jumpstart Pro policy and scope patterns (`account_member?`, `account_admin?`, `account_owner?`).

```ruby
def show
  @document = current_account.documents.find(params[:id])
  authorize @document
end
```

## New background job

1. Pass the account as a `perform` argument and enqueue with `current_account`.
2. Wrap the body in `ActsAsTenant.with_tenant(account)` and query through the account. `Current.account` is nil in a job. A job enqueued without a tenant (console, rake task, schedule) runs unscoped, and because Jumpstart Pro sets `config.require_tenant = false`, its `AccountRecord` queries return every account's rows instead of raising.

```ruby
class ProcessDocumentJob < ApplicationJob
  def perform(account, document_id)
    ActsAsTenant.with_tenant(account) do
      account.documents.find(document_id).process!
    end
  end
end

ProcessDocumentJob.perform_later(current_account, document.id)
```

## Verification

```bash
# Unscoped model queries can leak across accounts (replace Document with your model)
grep -rn "Document.all" app/controllers/
grep -rn "Document.where" app/controllers/
grep -rn "Document.find" app/controllers/

# Controllers missing an authorization call
grep -L "authorize" app/controllers/*_controller.rb

# Fixtures should reference an account
grep -rn "account:" test/fixtures/*.yml
```

## When to escalate

For the `Current.account` request lifecycle, account switching and impersonation, mailer and Action Cable scoping, cross-account reporting, or Pundit policy and scope design, defer to the `multi-tenancy-specialist` skill.
