---
name: migration-safety
description: 'Jumpstart Pro migration safety checklist that MUST activate when user mentions "create migration", "add migration", "modify migration", "rails generate migration", "add column", "add index", "change table", "remove column", "schema change", or "database migration". Enforces account:references on tenant tables and a zero-downtime safety floor. Activates proactively for all migration work.'
allowed-tools: Read, Grep, Glob
user-invocable: false
---

# Migration Safety Check

Reviews migrations for Jumpstart Pro account scoping and a production-safety floor that prevents data loss and downtime.

## Scope and precedence

This skill carries Jumpstart Pro-specific migration requirements plus a compact safety floor. Resolve choices in this order: (1) the application's own migrations and dependencies, (2) the Jumpstart Pro patterns here, (3) general Rails migration guidance from a companion package such as 37signals-skills when present, (4) conventional Rails defaults. Deep general zero-downtime technique is intentionally not repeated here; this skill keeps only the floor needed to stay safe when installed standalone.

## When This Activates

- "migration", "create migration", "rails generate migration", "rails g migration"
- "add column", "remove column", "change column", "rename column"
- "add index", "remove index", "create table", "change table"
- "db/migrate", "schema change"
- Any database schema modifications

## Jumpstart Pro requirements

### Account reference on tenant tables

A tenant-specific table must carry an indexed, non-null account reference with a foreign key:

```ruby
create_table :documents do |t|
  t.references :account, null: false, foreign_key: true, index: true
  # ... other columns
end
```

`null: false` keeps every record owned by an account, `foreign_key: true` enforces integrity, and the index backs account-scoped queries. Composite indexes lead with `account_id` (for example `add_index :documents, [:account_id, :status]`). Models that are genuinely global (`User`, `Plan`) are the exception.

### Account context in data migrations

Data migrations that touch `AccountRecord` models set account context so `acts_as_tenant` scoping behaves as it does in the application. Iterate per account, batch the work, and keep it idempotent:

```ruby
def up
  Account.find_each do |account|
    Current.set(account: account) do
      account.documents.where(status: nil).in_batches.update_all(status: "draft")
    end
  end
end
```

Running a global query against an `AccountRecord` model without account context risks corrupting or leaking tenant data.

### Multi-database awareness

Jumpstart Pro runs four databases: Primary (application data) plus SolidQueue, SolidCache, and SolidCable. Almost every migration targets Primary. The Solid* databases own their schema under their own `migrations_paths`; do not add application tables to them. Confirm the target database before migrating anything outside Primary. The `database-specialist` skill covers the multi-database configuration in detail.

## Safety floor (do not skip, even standalone)

These prevent data loss and downtime. Treat them as hard requirements, not suggestions:

- **Reversible migrations.** Every migration rolls back cleanly. Use explicit `up`/`down` for anything `change` cannot reverse, such as raw `execute` or a data backfill.
- **Stage breaking changes.** Add a `NOT NULL` column in steps: add it nullable (or with a default), backfill in a separate migration, then add the constraint. Remove a column in steps: add it to `self.ignored_columns` and deploy first, then drop it in a later migration.
- **Concurrent indexes on large tables.** Add indexes with `algorithm: :concurrently` alongside `disable_ddl_transaction!` so the table is not locked.
- **Separate, batched backfills.** Backfill in its own migration using `in_batches`, with `disable_ddl_transaction!` for long runs.
- **Index foreign keys.** Every `references` or foreign-key column is indexed.

`strong_migrations` catches most of these patterns automatically; the `database-specialist` skill documents its configuration.

## Verification

- [ ] Account reference added (indexed, `null: false`, foreign key) for every tenant table
- [ ] Breaking changes staged (no `NOT NULL` without default or backfill; no immediate column drop)
- [ ] Indexes added concurrently on large tables; foreign keys indexed
- [ ] Rollback tested with `make rails ARGS="db:rollback"`
- [ ] Data migrations batched, idempotent, and account-scoped with `Current.set(account:)`
- [ ] Suite passes: `make test-all`

## When to escalate

For multi-database migrations, the Pay gem billing schema, complex data migrations, or query-performance work, the `database-specialist` skill carries the Jumpstart Pro specifics. For deep general zero-downtime technique beyond the floor above, defer to a general Rails migrations guide or a companion package such as 37signals-skills.
