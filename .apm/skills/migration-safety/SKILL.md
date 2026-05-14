---
name: migration-safety
description: Migration review checklist that MUST activate when user mentions "create migration", "add migration", "modify migration", "rails generate migration", "add column", "add index", "change table", "remove column", "schema change", or "database migration". Reviews for zero-downtime patterns, index requirements, and rollback safety. Activates proactively for all migration work.
allowed-tools: Read, Grep, Glob
user-invocable: false
---

# Migration Safety Check

Reviews migrations for zero-downtime patterns, index requirements, and rollback safety.

## When This Activates

- "migration", "create migration", "rails generate migration", "rails g migration"
- "add column", "remove column", "change column", "rename column"
- "add index", "remove index", "create table", "change table"
- "db/migrate", "schema change"
- Any database schema modifications

## Critical Rule

**Migrations must be production-safe with zero downtime.**

Unsafe migrations cause outages. Always follow zero-downtime patterns.

---

## Pre-Flight Checklist

Before writing a migration, verify:

### ✅ 1. Account Reference Required?

If creating a tenant-specific table:

```ruby
create_table :documents do |t|
  t.references :account, null: false, foreign_key: true, index: true
  # ... other columns
end
```

**Required:**
- `null: false` - Every record must have account
- `foreign_key: true` - Enforces referential integrity
- `index: true` - Performance for account-scoped queries

### ✅ 2. Rollback Safety

Every migration must be reversible:

```ruby
# ✅ Correct - Reversible
def change
  add_column :documents, :published, :boolean, default: false
end

# ❌ Wrong - Not automatically reversible
def change
  execute "UPDATE documents SET published = true"
end

# ✅ Correct - Explicit up/down
def up
  execute "UPDATE documents SET published = true"
end

def down
  execute "UPDATE documents SET published = false"
end
```

### ✅ 3. Default Values for NOT NULL

Adding `null: false` requires a default or backfill:

```ruby
# ✅ Correct - Default provided
add_column :documents, :status, :string, null: false, default: 'draft'

# ❌ Wrong - null: false without default
add_column :documents, :status, :string, null: false
```

---

## Zero-Downtime Patterns

### Adding NOT NULL Columns (3-Step Process)

**Step 1: Add column (nullable)**
```ruby
class AddStatusToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :status, :string, default: 'draft'
  end
end
```

**Step 2: Backfill data** (separate PR)
```ruby
class BackfillDocumentStatus < ActiveRecord::Migration[8.1]
  def up
    Document.in_batches.update_all(status: 'draft')
  end

  def down
    # No-op or reverse if needed
  end
end
```

**Step 3: Add NOT NULL constraint** (separate PR)
```ruby
class AddNotNullToDocumentStatus < ActiveRecord::Migration[8.1]
  def change
    change_column_null :documents, :status, false
  end
end
```

**Why 3 steps?** Prevents locking tables and allows rollback at each stage.

### Removing Columns (2-Step Process)

**Step 1: Ignore column in model** (deploy first)
```ruby
# app/models/document.rb
class Document < AccountRecord
  self.ignored_columns = [:old_field]
end
```

**Step 2: Remove column** (deploy after step 1 is live)
```ruby
class RemoveOldFieldFromDocuments < ActiveRecord::Migration[8.1]
  def change
    remove_column :documents, :old_field, :string
  end
end
```

**Why 2 steps?** Prevents errors if old code tries to access removed column.

### Adding Indexes

**Safe pattern:**
```ruby
# ✅ Correct - Concurrent index (no table lock)
def change
  add_index :documents, :account_id, algorithm: :concurrently
end

# Must disable DDL transaction for concurrent index
disable_ddl_transaction!
```

**For large tables,** always use `algorithm: :concurrently` to avoid locking.

### Renaming Columns (3-Step Process)

**Step 1: Add new column**
```ruby
add_column :documents, :new_name, :string
```

**Step 2: Dual-write to both columns** (application code)
```ruby
def title=(value)
  self.new_name = value
  super
end
```

**Step 3: Remove old column** (after dual-write deployed)
```ruby
remove_column :documents, :old_name
```

---

## Multi-Database Awareness

Jumpstart Pro uses 4 databases:

1. **Primary** - Application data
2. **Cache** - SolidCache (rarely migrate)
3. **Queue** - SolidQueue (rarely migrate)
4. **Cable** - SolidCable (rarely migrate)

**Most migrations affect Primary only.**

**If migrating non-primary databases:**
```ruby
class MigrateCacheDatabase < ActiveRecord::Migration[8.1]
  def change
    # Specify database
    on: :cache do
      create_table :custom_cache_entries do |t|
        # ...
      end
    end
  end
end
```

---

## Index Checklist

### Always Index Foreign Keys

```ruby
# ✅ Correct - Foreign keys indexed
t.references :account, null: false, foreign_key: true, index: true
t.references :user, null: false, foreign_key: true, index: true

# ❌ Wrong - Missing index
t.references :account, null: false, foreign_key: true
```

### Index Frequently Queried Columns

Common columns to index:
- `account_id` (always)
- Status columns (`status`, `published`)
- Timestamp columns if queried (`created_at`, `updated_at`)
- UUID columns

```ruby
add_index :documents, [:account_id, :status]
add_index :documents, [:account_id, :published_at]
```

### Composite Indexes

For queries like `WHERE account_id = ? AND status = ?`:

```ruby
# ✅ Correct - Composite index (most specific first)
add_index :documents, [:account_id, :status]

# ❌ Wrong - Separate indexes less efficient
add_index :documents, :account_id
add_index :documents, :status
```

**Order matters:** Most selective column first (usually `account_id`).

---

## Foreign Key Constraints

Always add foreign keys for referential integrity:

```ruby
# ✅ Correct - With foreign key
t.references :account, null: false, foreign_key: true, index: true

# ❌ Wrong - No constraint (orphaned records possible)
t.references :account, null: false, index: true
```

**On delete behavior:**
```ruby
# Cascade delete (delete children when parent deleted)
t.references :account, null: false, foreign_key: { on_delete: :cascade }

# Nullify (set to NULL when parent deleted)
t.references :author, foreign_key: { on_delete: :nullify }
```

**For Jumpstart Pro:** Usually use cascade for account associations.

---

## Data Migration Safety

### Use Batches for Large Updates

```ruby
# ✅ Correct - Batched updates
def up
  Document.in_batches.update_all(status: 'draft')
end

# ❌ Wrong - Single transaction (locks table)
def up
  Document.update_all(status: 'draft')
end
```

### Disable Transactions for Long Operations

```ruby
class BackfillDocumentStatus < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Document.in_batches.update_all(status: 'draft')
  end
end
```

### Check for Existing Data

```ruby
def up
  # Safe even if run multiple times
  Document.where(status: nil).in_batches.update_all(status: 'draft')
end
```

---

## Common Anti-Patterns

### ❌ Adding NOT NULL Without Default

```ruby
# ❌ Wrong - Fails on existing rows
add_column :documents, :status, :string, null: false

# ✅ Correct - Provide default
add_column :documents, :status, :string, null: false, default: 'draft'
```

### ❌ Changing Column Type

```ruby
# ❌ Wrong - Data loss risk
change_column :documents, :status, :integer

# ✅ Correct - Add new column, migrate, remove old
# (Use 3-step process: add, migrate data, remove)
```

### ❌ Removing Columns Immediately

```ruby
# ❌ Wrong - Running code may reference column
remove_column :documents, :old_field

# ✅ Correct - Ignore first, then remove
# 1. Add to ignored_columns
# 2. Deploy
# 3. Remove column in separate migration
```

### ❌ Missing Index on Foreign Keys

```ruby
# ❌ Wrong - Slow queries
t.references :account, null: false, foreign_key: true

# ✅ Correct - Indexed
t.references :account, null: false, foreign_key: true, index: true
```

---

## Testing Migrations

### Test Up Migration

```bash
make migrate
```

### Test Rollback

```bash
make rails ARGS="db:rollback"
```

### Test Idempotency

```bash
# Run twice to ensure it's safe to re-run
make migrate
make migrate
```

### Run Full Test Suite

```bash
make test-all
```

---

## Verification Checklist

Before deploying a migration:

- [ ] **Account reference** added if tenant-specific table
- [ ] **NOT NULL columns** have defaults or backfill
- [ ] **Foreign keys** defined for all references
- [ ] **Indexes** added for foreign keys and frequently queried columns
- [ ] **Rollback tested** successfully
- [ ] **Zero-downtime** patterns followed (multi-step for breaking changes)
- [ ] **Tests pass** after migration
- [ ] **Data migration** uses batches for large tables

---

## When to Escalate

For complex migrations, the `database-specialist` skill activates automatically and covers:
- Multi-database migrations (Cache, Queue, Cable)
- Complex data migrations
- Query performance optimization
- Zero-downtime migration strategies
- Database constraints and triggers

---

## Reference Documentation

**Jumpstart Pro migrations:**
Check existing migrations in `db/migrate/` for patterns

**Multi-database configuration:**
See `config/database.yml` in the JSP upstream

**Migration patterns:**
See the architecture section of the JSP upstream `CLAUDE.md`

**Rails migration guides:**
https://guides.rubyonrails.org/active_record_migrations.html

**Zero-downtime migrations:**
https://github.com/ankane/strong_migrations (referenced patterns)
