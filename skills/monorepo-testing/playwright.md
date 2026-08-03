# Playwright Reference

Playwright tests complete user flows in a real browser and API endpoints via request context. Cap at **20-30 E2E tests per app** - more signals over-reliance on E2E.

## Config

```typescript
// apps/web/playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  testMatch: '**/*.e2e.test.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  maxFailures: process.env.CI ? 10 : undefined,

  reporter: [
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results/e2e-results.json' }],
    ...(process.env.CI ? [['github'] as const] : []),
  ],

  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
  },

  projects: [
    { name: 'setup', testMatch: /.*\.setup\.ts/ },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], storageState: 'playwright/.auth/user.json' },
      dependencies: ['setup'],
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'], storageState: 'playwright/.auth/user.json' },
      dependencies: ['setup'],
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'], storageState: 'playwright/.auth/user.json' },
      dependencies: ['setup'],
    },
    {
      name: 'api',
      testMatch: '**/*.api.test.ts',
      use: { baseURL: process.env.API_URL ?? 'http://localhost:4000' },
    },
  ],

  webServer: {
    command: 'pnpm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
})
```

## File Structure

```
apps/web/tests/e2e/
├── auth.setup.ts                # Global auth (runs once)
├── dashboard.e2e.test.ts        # E2E browser tests
├── checkout.e2e.test.ts
├── api/
│   ├── users.api.test.ts        # API-only tests
│   └── health.api.test.ts
└── pages/                       # Page Object Models
    ├── login.page.ts
    ├── dashboard.page.ts
    └── settings.page.ts
```

## Authentication Setup

```typescript
// tests/e2e/auth.setup.ts
import { test as setup, expect } from '@playwright/test'

setup('authenticate as user', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill('test@example.com')
  await page.getByLabel('Password').fill('password')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL('/dashboard')
  await page.context().storageState({ path: 'playwright/.auth/user.json' })
})
```

## Page Object Model (Mandatory)

Every E2E test must use Page Objects. No inline selectors in test files.

```typescript
// tests/e2e/pages/dashboard.page.ts
import type { Page, Locator } from '@playwright/test'

export class DashboardPage {
  readonly heading: Locator
  readonly statsCard: Locator
  readonly filterSelect: Locator
  readonly userMenu: Locator
  readonly logoutButton: Locator

  constructor(private page: Page) {
    this.heading = page.locator('h1')
    this.statsCard = page.getByTestId('stats-card')
    this.filterSelect = page.getByRole('combobox', { name: 'Filter' })
    this.userMenu = page.getByRole('button', { name: 'User menu' })
    this.logoutButton = page.getByRole('menuitem', { name: 'Logout' })
  }

  async goto() { await this.page.goto('/dashboard') }
  async filterBy(value: string) { await this.filterSelect.selectOption(value) }
  async logout() { await this.userMenu.click(); await this.logoutButton.click() }
}
```

```typescript
// tests/e2e/dashboard.e2e.test.ts
import { test, expect } from '@playwright/test'
import { DashboardPage } from './pages/dashboard.page'

test.describe('Dashboard', () => {
  test('displays stats after login', async ({ page }) => {
    const dashboard = new DashboardPage(page)
    await dashboard.goto()
    await expect(dashboard.heading).toHaveText('Dashboard')
    await expect(dashboard.statsCard).toBeVisible()
  })
})
```

**Page Object rules:**
- ✅ Locators as `readonly` properties in constructor
- ✅ High-level actions as methods (`goto()`, `filterBy()`, `logout()`)
- ❌ Never put assertions in Page Objects - assertions belong in test files
- ❌ Never expose raw selector strings

## API Testing (`.api.test.ts`)

Uses Playwright's `request` context, with no browser launched.

```typescript
// tests/e2e/api/users.api.test.ts
import { test, expect } from '@playwright/test'

test.describe('Users API', () => {
  test('GET /api/users returns 200 with user list', async ({ request }) => {
    const response = await request.get('/api/users')
    expect(response.status()).toBe(200)
    const body = await response.json()
    expect(body.users).toBeInstanceOf(Array)
    expect(body.users.length).toBeGreaterThan(0)
  })

  test('POST /api/users creates a new user', async ({ request }) => {
    const response = await request.post('/api/users', {
      data: { email: `e2e-${Date.now()}@test.com`, name: 'E2E Test User' },
    })
    expect(response.status()).toBe(201)
  })
})
```

## Meta-Framework (SSR) Considerations

Applies to any server-rendered React framework.

- Use `webServer` to start the dev server (or `build && preview` in CI)
- Test both the SSR path (full-page load) and the SPA path (client-side navigation)
- Playwright auto-waits for hydration, so no special handling is needed

## Reliability Settings (Non-Optional)

| Setting | Value | Purpose |
|---------|-------|---------|
| `forbidOnly` | `!!process.env.CI` | Prevents `.only()` from skipping tests in CI |
| `maxFailures` | `process.env.CI ? 10 : undefined` | Stops wasting CI minutes |
| `workers` | `process.env.CI ? 1 : undefined` | Prevents exhaustion on 2-vCPU runners |
| `screenshot` | `'only-on-failure'` | Instant visual debugging |
| `video` | `'on-first-retry'` | Captures exact failure sequence |
| `trace` | `'on-first-retry'` | Full network + DOM trace |

## .gitignore

```gitignore
playwright/.auth/
playwright-report/
test-results/
blob-report/
```
