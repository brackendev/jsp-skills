---
name: account-scoping
description: Multi-tenancy checklist that MUST activate when user mentions "create model", "new controller", "add resource", "scaffold", "rails g model", "rails g controller", "rails g resource", "rails g scaffold", "generate model", "build controller", "background job", or any Rails resource generation. Prevents tenant isolation bugs. Activates proactively whenever new Rails resources are discussed.
allowed-tools: Read, Grep, Glob
user-invocable: false
---

# Account Scoping Checklist

Automatic checklist for Jumpstart Pro multi-tenancy requirements when creating models, controllers, or background jobs.

## When This Activates

- "new model", "create model", "rails generate model", "rails g model"
- "new controller", "create controller", "rails generate controller", "rails g controller"
- "scaffold", "rails generate scaffold", "rails g scaffold", "rails g resource"
- "background job", "create job", "rails generate job", "rails g job"
- Any Rails resource generation

## Critical Rule

**Multi-tenancy is non-negotiable in Jumpstart Pro.**

Every tenant-specific resource MUST be scoped to accounts. Skipping this breaks tenant isolation and creates security vulnerabilities.

---

## Model Checklist

When creating a new model:

### ✅ 1. Inherit from AccountRecord

```ruby
# ✅ Correct
class Document < AccountRecord
  belongs_to :account
end

# ❌ Wrong
class Document < ApplicationRecord
end
```

**Why:** `AccountRecord` automatically scopes queries to `Current.account`

### ✅ 2. Add account:references Migration

```ruby
# db/migrate/xxx_create_documents.rb
class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :title
      t.text :content

      t.timestamps
    end
  end
end
```

**Required attributes:**
- `null: false` - Account ID is mandatory
- `foreign_key: true` - Enforces referential integrity
- `index: true` - Performance for tenant-scoped queries

### ✅ 3. Add Account Association in Model

```ruby
class Document < AccountRecord
  belongs_to :account

  # Your model logic here
end
```

### ✅ 4. Create Fixture with Account

```yaml
# test/fixtures/documents.yml
one:
  account: one  # References fixtures/accounts.yml
  title: "Test Document"
  content: "Test content"
```

**Why:** Tests need valid account associations to pass

### ✅ 5. Use switch_account in Tests

```ruby
# test/models/document_test.rb
class DocumentTest < ActiveSupport::TestCase
  test "scopes to correct account" do
    account_one = accounts(:one)
    account_two = accounts(:two)

    # Switch to account one
    switch_account(account_one)
    documents_one = Document.all

    # Switch to account two
    switch_account(account_two)
    documents_two = Document.all

    # Verify isolation
    assert_not_equal documents_one.pluck(:id), documents_two.pluck(:id)
  end
end
```

**Why:** `switch_account(@account)` helper sets `Current.account` for test context. Required for testing tenant-scoped queries.

---

## Controller Checklist

When creating a new controller:

### ✅ 1. Scope Queries to current_account

```ruby
# ✅ Correct
class DocumentsController < ApplicationController
  def index
    @documents = current_account.documents
  end

  def show
    @document = current_account.documents.find(params[:id])
  end
end

# ❌ Wrong - Leaks data across tenants
class DocumentsController < ApplicationController
  def index
    @documents = Document.all  # NO!
  end

  def show
    @document = Document.find(params[:id])  # NO!
  end
end
```

### ✅ 2. Create Pundit Policy

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  def index?
    true  # All account members can list documents
  end

  def show?
    record.account_id == user.current_account.id
  end

  def create?
    user.admin? || user.owner?
  end

  def update?
    user.admin? || user.owner?
  end

  def destroy?
    user.owner?
  end
end
```

### ✅ 3. Authorize in Controller

```ruby
class DocumentsController < ApplicationController
  def show
    @document = current_account.documents.find(params[:id])
    authorize @document  # Calls DocumentPolicy#show?
  end

  def create
    @document = current_account.documents.build(document_params)
    authorize @document  # Calls DocumentPolicy#create?

    if @document.save
      redirect_to @document
    else
      render :new
    end
  end
end
```

---

## Background Job Checklist

When creating a background job:

### ✅ 1. Pass account_id as Argument

```ruby
# ✅ Correct
class ProcessDocumentJob < ApplicationJob
  queue_as :default

  def perform(document_id, account_id)
    AccountRecord.with_account(account_id) do
      document = Document.find(document_id)
      # Process document
    end
  end
end

# Enqueue with account_id
ProcessDocumentJob.perform_later(document.id, document.account_id)
```

### ✅ 2. Use AccountRecord.with_account

```ruby
def perform(document_id, account_id)
  AccountRecord.with_account(account_id) do
    # Everything inside this block is scoped to the account
    document = Document.find(document_id)
    # ... process ...
  end
end
```

**Why:** Background jobs run outside request context. `Current.account` is not set. Must explicitly scope.

### ✅ 3. Test Job Scoping

```ruby
# test/jobs/process_document_job_test.rb
class ProcessDocumentJobTest < ActiveJob::TestCase
  test "processes document for correct account" do
    document = documents(:one)
    account = accounts(:one)

    ProcessDocumentJob.perform_now(document.id, account.id)

    # Assert job processed document in correct account context
    assert_performed_jobs 1
  end
end
```

---

## Common Anti-Patterns

### ❌ Querying Without Account Scope

```ruby
# ❌ Wrong - Data leakage
Document.where(published: true)
User.find(params[:id])
Document.all

# ✅ Correct - Account scoped
current_account.documents.where(published: true)
current_account.users.find(params[:id])
current_account.documents.all
```

### ❌ Skipping Pundit Authorization

```ruby
# ❌ Wrong - No authorization check
def update
  @document.update(document_params)
end

# ✅ Correct - Authorize first
def update
  authorize @document
  @document.update(document_params)
end
```

### ❌ Missing Account Association

```ruby
# ❌ Wrong - No account reference
class Document < ApplicationRecord
  # No belongs_to :account
end

# ✅ Correct - Account association required
class Document < AccountRecord
  belongs_to :account
end
```

### ❌ Background Jobs Without Account Context

```ruby
# ❌ Wrong - No account scoping
class ProcessDocumentJob < ApplicationJob
  def perform(document_id)
    document = Document.find(document_id)  # NO!
  end
end

# ✅ Correct - Explicit account scoping
class ProcessDocumentJob < ApplicationJob
  def perform(document_id, account_id)
    AccountRecord.with_account(account_id) do
      document = Document.find(document_id)
    end
  end
end
```

---

## Quick Reference

**Every new model needs:**
1. `AccountRecord` inheritance
2. `account:references` migration (null: false, foreign_key: true, index: true)
3. `belongs_to :account` association
4. Fixture with account reference
5. Tests using `switch_account(@account)` helper

**Every new controller needs:**
1. `current_account` scoped queries
2. Pundit policy class
3. `authorize` calls before actions

**Every background job needs:**
1. `account_id` as parameter
2. `AccountRecord.with_account` block
3. Test for account scoping

---

## Verification Commands

**Check for unscoped queries:**
```bash
# Search for potential data leaks
grep -r "Document.all" app/controllers/
grep -r "Document.where" app/controllers/
grep -r "Document.find" app/controllers/
```

**Check for missing authorization:**
```bash
# Search for controllers without authorize calls
grep -L "authorize" app/controllers/*_controller.rb
```

**Check fixtures have accounts:**
```bash
# Check fixture files
grep "account:" test/fixtures/*.yml
```

---

## When to Escalate

For complex multi-tenancy patterns, the `multi-tenancy-specialist` skill activates automatically and covers:
- Cross-account reporting (admin features)
- Complex `Current.account` patterns
- AccountRecord advanced usage
- Custom Pundit policies
- Tenant isolation reviews

---

## Reference Documentation

**Jumpstart Pro multi-tenancy docs:**
https://jumpstartrails.com/docs/accounts

**Key Jumpstart Pro patterns:**
- AccountRecord: `app/models/account_record.rb`
- Current: `app/models/current.rb`
- Example policies: `app/policies/`
- Example models: `app/models/` (check existing models for patterns)
