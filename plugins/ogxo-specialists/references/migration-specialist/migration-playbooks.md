# Common Migration Playbooks

Pre-built migration strategies for frequently encountered technology transitions.

## Next.js Pages Router to App Router

**Key changes:**
- `pages/` directory -> `app/` directory
- `getServerSideProps` / `getStaticProps` -> Server Components + `fetch`
- `_app.tsx` / `_document.tsx` -> `layout.tsx`
- `useRouter` from `next/router` -> `next/navigation`
- Client components need `'use client'` directive

**Migration strategy:**
1. Create `app/` directory alongside existing `pages/`
2. Migrate one route at a time (both can coexist)
3. Start with simple static pages, then dynamic routes
4. Migrate data fetching patterns last (most complex)

## Jest to Vitest

**Key changes:**
- `jest.config.js` -> `vitest.config.ts`
- `jest.fn()` -> `vi.fn()`
- `jest.mock()` -> `vi.mock()`
- `jest.spyOn()` -> `vi.spyOn()`
- `@jest/globals` -> `vitest`

**Codemod approach:**
```bash
# Automated migration
npx vitest-migration-tool 2>/dev/null

# Manual find-replace patterns
# jest.fn() -> vi.fn()
# jest.mock() -> vi.mock()
# jest.spyOn() -> vi.spyOn()
# jest.clearAllMocks() -> vi.clearAllMocks()
# jest.resetAllMocks() -> vi.resetAllMocks()
```

## Database ORM Migration (Sequelize to Prisma, TypeORM to Drizzle)

**Strategy:**
1. Add new ORM alongside existing one
2. Create schema definition in new ORM matching existing database
3. Migrate one model/table at a time
4. Update queries in service layer to use new ORM
5. Remove old ORM after all queries migrated
6. Run full integration test suite at each step

## Node.js Major Version Upgrade

**Key steps:**
1. Check `.nvmrc` / `.node-version` / `engines` in package.json
2. Review Node.js changelog for breaking changes
3. Update CI/CD pipeline configuration
4. Test with `npx check-node-version` or `nvm use <target>`
5. Update native dependencies (`node-gyp` rebuilds)
6. Check for deprecated APIs (`--pending-deprecation` flag)
