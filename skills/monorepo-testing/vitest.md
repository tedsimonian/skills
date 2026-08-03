# Vitest Reference

Vitest handles **everything except E2E and production monitoring**: unit, server JSX, browser components, integration, visual regression, benchmarks, Storybook stories, and contracts.

## Root Config (root-only options)

```typescript
// vitest.config.ts (monorepo root)
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // Root-only options (silently ignored in project configs)
    reporters: process.env.CI
      ? ['default', 'json', 'github-actions', 'junit']
      : ['default'],
    outputFile: process.env.CI
      ? { json: './test-results/results.json', junit: './test-results/junit.xml' }
      : undefined,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      include: ['**/src/**/*.{ts,tsx}'],
      exclude: [
        '**/*.test.{ts,tsx}', '**/*.browser.test.{ts,tsx}',
        '**/*.integration.test.ts', '**/*.stories.tsx', '**/*.bench.ts',
        '**/*.contract.ts', '**/*.e2e.test.ts', '**/*.page.ts',
        '**/*.fixture.ts', '**/*.check.ts', '**/generated/**', '**/index.ts',
      ],
    },
    projects: [
      'apps/*/vitest.config.ts',
      'packages/*/vitest.config.ts',
    ],
  },
})
```

## Shared Base Configs

```typescript
// packages/vitest-config/base.ts
import { defineConfig } from 'vitest/config'
import tsconfigPaths from 'vite-tsconfig-paths'

export function createNodeConfig(overrides?: {
  include?: string[]; exclude?: string[]; setupFiles?: string[]
}) {
  return defineConfig({
    plugins: [tsconfigPaths()],
    test: {
      globals: true,
      passWithNoTests: true,
      retry: process.env.CI ? 2 : 0,
      include: overrides?.include,
      exclude: overrides?.exclude,
      setupFiles: overrides?.setupFiles,
    },
  })
}
```

```typescript
// packages/vitest-config/react-browser.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { playwright } from '@vitest/browser-playwright'
import tsconfigPaths from 'vite-tsconfig-paths'

export function createBrowserConfig(overrides?: {
  include?: string[]; setupFiles?: string[]
}) {
  return defineConfig({
    plugins: [react(), tsconfigPaths()],
    test: {
      globals: true,
      passWithNoTests: true,
      retry: process.env.CI ? 2 : 0,
      include: overrides?.include,
      setupFiles: overrides?.setupFiles,
      browser: {
        enabled: true,
        provider: playwright(),
        instances: [{ browser: 'chromium' }],
      },
    },
  })
}
```

## Config Patterns

### Pattern A - Single-project package (server-utils, CLI)

```typescript
// packages/server-utils/vitest.config.ts
import { createNodeConfig } from '@repo/vitest-config/base'
import { defineProject, mergeConfig } from 'vitest/config'

export default mergeConfig(
  createNodeConfig(),
  defineProject({
    test: {
      name: 'server-utils',
      include: ['src/**/*.test.ts', 'tests/**/*.integration.test.ts'],
      environment: 'node',
    },
  })
)
```

### Pattern B - Multi-project app (unit + browser + integration)

```typescript
// apps/web/vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { playwright } from '@vitest/browser-playwright'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  test: {
    projects: [
      {
        test: {
          name: 'web/unit',
          include: ['app/**/*.test.ts', 'app/**/*.test.tsx'],
          environment: 'node',
          globals: true,
        },
      },
      {
        extends: true, // inherits plugins from parent
        test: {
          name: 'web/browser',
          include: ['app/**/*.browser.test.tsx'],
          globals: true,
          browser: {
            enabled: true,
            provider: playwright(),
            instances: [{ browser: 'chromium' }],
          },
        },
      },
      {
        test: {
          name: 'web/integration',
          include: ['tests/integration/**/*.integration.test.ts'],
          environment: 'node',
          globals: true,
          fileParallelism: false,
          testTimeout: 15_000,
        },
      },
    ],
  },
})
```

### Pattern C - Storybook-driven UI package

```typescript
// packages/ui/vitest.config.ts
import { defineProject } from 'vitest/config'
import { storybookTest } from '@storybook/addon-vitest/vitest-plugin'
import { playwright } from '@vitest/browser-playwright'

export default defineProject({
  plugins: [storybookTest({ renderer: 'react' })],
  test: {
    name: 'ui/storybook',
    include: ['src/**/*.stories.tsx'],
    browser: {
      enabled: true,
      provider: playwright(),
      instances: [{ browser: 'chromium' }],
    },
    setupFiles: ['.storybook/vitest.setup.ts'],
  },
})
```

### Pattern D - GraphQL API subgraph (unit + integration)

```typescript
// packages/api-users/vitest.config.ts
import { defineConfig } from 'vitest/config'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    projects: [
      {
        test: {
          name: 'api-users/unit',
          include: ['src/**/*.test.ts'],
          environment: 'node',
          globals: true,
          setupFiles: ['tests/setup.ts'],
        },
      },
      {
        test: {
          name: 'api-users/integration',
          include: [
            'tests/integration/**/*.integration.test.ts',
            'tests/contracts/**/*.contract.ts',
          ],
          environment: 'node',
          globals: true,
          fileParallelism: false,
          testTimeout: 15_000,
          hookTimeout: 30_000,
          setupFiles: ['tests/setup.ts', 'tests/setup-db.ts'],
        },
      },
    ],
  },
})
```

## Unit Tests (`.test.ts`)

Pure functions, utilities, state machines, data transformations, validation. Node.js, no DOM, no JSX.

```typescript
// hash.test.ts - colocated next to hash.ts
import { describe, it, expect } from 'vitest'
import { hashPassword, verifyPassword } from './hash'

describe('hashPassword', () => {
  it('returns a string different from the input', () => {
    const result = hashPassword('my-secret')
    expect(result).toBeTypeOf('string')
    expect(result).not.toBe('my-secret')
  })

  it('produces different hashes for different inputs', () => {
    expect(hashPassword('a')).not.toBe(hashPassword('b'))
  })
})
```

**DO:** Test edge cases (null, undefined, empty, boundary values). Use `vi.useFakeTimers()` for time-dependent logic. Assert return values and thrown errors.

**DON'T:** Import React/JSX. Mock more than 3 dependencies. Test private internals. Use `any` in test files.

## Server-Side JSX Tests (`.test.tsx`)

SSR output, server components, route loaders, email/PDF templates, og:image generators. Runs in Node.js: JSX transpiled but no DOM.

```typescript
// InvoiceEmail.test.tsx - Node.js, no browser
import { describe, it, expect } from 'vitest'
import { render } from '@react-email/render'
import { InvoiceEmail } from './InvoiceEmail'

describe('InvoiceEmail', () => {
  it('includes the user name in the greeting', async () => {
    const html = await render(<InvoiceEmail userName="Alice" />)
    expect(html).toContain('Welcome, Alice')
  })
})
```

**When to choose `.test.tsx` vs `.browser.test.tsx`:** Does the test need a real DOM (click events, scroll, focus, IntersectionObserver, client state, hooks with effects)? → `.browser.test.tsx`. Does it test server rendering (renderToString, SSR output, server functions)? → `.test.tsx`.

**Config:** `.test.tsx` runs in the same Node project as `.test.ts`:
```typescript
{ test: { name: 'web/unit', include: ['app/**/*.test.ts', 'app/**/*.test.tsx'], environment: 'node' } }
```

## Browser Component Tests (`.browser.test.tsx`)

React components rendered in real Chromium: interactions, state, DOM APIs, a11y.

```typescript
// DataGrid.browser.test.tsx
import { describe, it, expect } from 'vitest'
import { render } from 'vitest-browser-react'
import { page } from 'vitest/browser'
import { DataGrid } from './DataGrid'

describe('DataGrid', () => {
  it('renders column headers', async () => {
    render(<DataGrid columns={['Name', 'Email']} rows={[]} />)
    await expect.element(page.getByRole('columnheader', { name: 'Name' })).toBeVisible()
  })

  it('sorts by column on header click', async () => {
    const rows = [
      { name: 'Charlie', email: 'c@test.com' },
      { name: 'Alice', email: 'a@test.com' },
    ]
    render(<DataGrid columns={['Name', 'Email']} rows={rows} />)
    await page.getByRole('columnheader', { name: 'Name' }).click()
    await expect.element(page.getByRole('cell').first()).toHaveTextContent('Alice')
  })
})
```

**Critical API differences from jsdom:**
- `await expect.element(locator)` - NOT `expect(element)`
- `page.getByRole()` - NOT `screen.getByRole()`
- `render()` from `vitest-browser-react` - NOT `@testing-library/react`
- Real browser APIs (matchMedia, IntersectionObserver, ResizeObserver) available natively - **never mock them**

## Integration Tests (`.integration.test.ts`)

Cross-boundary: DB queries, GraphQL resolvers (real schema), HTTP middleware, queue interactions.

```typescript
// tests/integration/user.queries.integration.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { createTestYoga } from '../helpers/yoga'
import { db, users } from '../../src/db'

describe('User Queries', () => {
  const yoga = createTestYoga()

  beforeEach(async () => {
    await db.delete(users)
    await db.insert(users).values({
      id: 'user-1', email: `test-${Date.now()}@example.com`, name: 'Test User',
    })
  })

  it('returns user by ID', async () => {
    const response = await yoga.fetch('http://test/graphql', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: UserQueryDocument, variables: { id: 'user-1' } }),
    })
    const result = await response.json()
    expect(result.errors).toBeUndefined()
    expect(result.data.user).toMatchObject({ id: 'user-1', name: 'Test User' })
  })
})
```

**Config:** `fileParallelism: false`, `testTimeout: 15_000`, `hookTimeout: 30_000`, `setupFiles: ['tests/setup-db.ts']`

**Rules:** Use `yoga.fetch()` for GraphQL. Clean data in `beforeEach` not `afterEach`. Use typed queries from graphql-codegen. Never mock the DB in integration tests.

## Visual Regression (`toMatchScreenshot`)

```typescript
// Button.browser.test.tsx
it('matches screenshot - default variant', async () => {
  render(<Button>Click me</Button>)
  await expect(page.getByRole('button')).toMatchScreenshot('button-default.png')
})
```

Screenshots stored in `__screenshots__/` adjacent to test. Update with `vitest run --update`.

## Benchmarks (`.bench.ts`)

```typescript
// hash.bench.ts
import { bench, describe } from 'vitest'
import { hashPassword } from './hash'

describe('hashPassword', () => {
  bench('hashes a short password', () => { hashPassword('short') })
  bench('hashes a long password', () => { hashPassword('a'.repeat(1000)) })
})
```

Run separately: `vitest bench`. Never included in normal `vitest run`.

## Setup Files

```typescript
// tests/setup.ts - runs before each test file
import { afterEach, vi } from 'vitest'

afterEach(() => {
  vi.clearAllMocks()
  vi.restoreAllMocks()
  vi.useRealTimers()
})
```

```typescript
// tests/setup-db.ts - for integration tests with database
import { beforeAll, afterAll } from 'vitest'
import { db, migrateUp, migrateDown } from '../src/db'

beforeAll(async () => { await migrateUp() })
afterAll(async () => { await migrateDown(); await db.$client.end() })
```

## Mocking

**MSW for HTTP:** Standard for all test environments (Node + browser).

```typescript
// src/test/mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('https://api.stripe.com/v1/customers/:id', ({ params }) => {
    return HttpResponse.json({ id: params.id, email: 'customer@example.com' })
  }),
]
```

```typescript
// tests/setup.ts - MSW integration
import { server } from '../src/test/mocks/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

`onUnhandledRequest: 'error'` is critical. It fails tests on unexpected HTTP requests.

**`vi.mock()` for internal modules:**
```typescript
vi.mock('../email/send', () => ({
  sendEmail: vi.fn().mockResolvedValue({ success: true }),
}))
```

## Database Isolation Pattern

```typescript
// tests/setup-db.ts - transaction rollback (faster than truncate)
beforeAll(async () => { await db.execute(sql`BEGIN`) })
beforeEach(async () => { await db.execute(sql`SAVEPOINT test_savepoint`) })
afterEach(async () => { await db.execute(sql`ROLLBACK TO SAVEPOINT test_savepoint`) })
afterAll(async () => { await db.execute(sql`ROLLBACK`); await db.$client.end() })
```

## Dependencies

**Root:** `vitest` (≥4.0), `@vitest/coverage-v8`, `@vitest/browser`, `@vitest/browser-playwright`

**Per UI project:** `vitest-browser-react`, `@storybook/addon-vitest`, `@storybook/test`

**Per API project:** `msw`, `@inngest/test` (if applicable)

**TypeScript:** `tsconfig.json` includes all files (IDE + Vitest). `tsconfig.build.json` excludes `**/*.test.*`, `**/*.stories.*`, `tests/**`.
