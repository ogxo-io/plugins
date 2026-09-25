# Migration Patterns

Reusable structural patterns for safe, incremental migrations. Read this when you need the concrete shape of a transition strategy.

## Adapter Pattern (API transitions)

An adapter lets old and new APIs coexist during migration:

```typescript
// Phase 1: adapter delegates to old API
// Phase 2: adapter delegates to new API (converting inputs)
// Phase 3: remove adapter, call new API directly

// adapter.ts
export function fetchData(options: OldOptions | NewOptions) {
  if (isNewOptions(options)) {
    return newApiFetch(options);
  }
  return newApiFetch(convertOptions(options)); // convert old -> new
}
```

## Feature Flag Pattern (gradual rollout)

Migrate component by component behind a flag, so you can revert instantly:

```typescript
const useNewRouter = process.env.USE_NEW_ROUTER === 'true';

if (useNewRouter) {
  return <AppRouterComponent />;   // new
} else {
  return <PagesRouterComponent />; // legacy
}
```

## Strangler Fig Pattern (service/data migrations)

Grow the new system around the old one, then retire the old:

```
Phase 1: new code reads from old + new, writes to both
Phase 2: migrate historical data from old to new
Phase 3: new code reads from new only, writes to both
Phase 4: stop writing to old, remove old code
```

## Database Zero-Downtime Pattern

Never change a column in a single destructive step. Expand, migrate, contract:

```sql
-- Phase 1: add new column (backward compatible)
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;

-- Phase 2: backfill data
UPDATE users SET email_verified = TRUE WHERE verified_at IS NOT NULL;

-- Phase 3: deploy code that reads/writes the new column

-- Phase 4: drop the old column (only after confirming no code references it)
ALTER TABLE users DROP COLUMN verified_at;
```

**Zero-downtime rules:**
- Never rename a column in one step — add new, migrate data, drop old
- Never add a NOT NULL column without a default
- Never drop a column while running code still references it
- Always test against a copy of production data
- Always write a corresponding rollback migration
