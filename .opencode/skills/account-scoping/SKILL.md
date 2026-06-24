---
name: account-scoping
description: "Multi-tenancy checklist that MUST activate when user mentions "create model", "new controller", "add resource", "scaffold", "rails g model", "rails g controller", "rails g resource", "rails g scaffold", "generate model", "build controller", "background job", or any Rails resource generation. Prevents tenant isolation bugs. Activates proactively whenever new Rails resources are discussed."
allowed-tools: Read, Grep, Glob
user-invocable: false
---

# Account Scoping Checklist

Fast checklist for Jumpstart Pro multi-tenancy when generating a model, controller, or background job. The `multi-tenancy-specialist` skill carries the full patterns (the `Current.account` request lifecycle, account switching, impersonation, `Account::BaseJob`, and Pundit policy and scope design). This checklist is the quick gate at generation time.

## When This Activates

- "new model", "create model", "rails generate model", "rails g model"
- "new controller", "create controller", "rails generate controller", "rails g controller"
- "scaffold", "rails generate scaffold", "rails g scaffold", "rails g resource"
- "background job", "create job", "rails generate job", "rails g job"
- Any Rails resource generation

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

1. Make `account_id` the first `perform` argument and enqueue with `current_account.id` first.
2. Set account context: inherit from `Account::BaseJob`, or wrap the body in `AccountRecord.with_account(Account.find(account_id))`. A job that loads an `AccountRecord` without account context raises `NoTenantSet`.

```ruby
class ProcessDocumentJob < ApplicationJob
  def perform(account_id, document_id)
    AccountRecord.with_account(Account.find(account_id)) do
      Document.find(document_id).process!
    end
  end
end
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
