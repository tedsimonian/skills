# Checkly Reference

Checkly monitors **production health** by running a curated subset of E2E tests on a schedule from global locations. Checks are promoted Playwright tests, not separate tests.

## Architecture

```
Playwright E2E Tests (20-30 per app)
  └─ Promote critical flows (rewrite for Checkly runtime) → Checkly Checks (5-15 per app)
     Non-promoted: edge cases, setup-heavy, multi-step flows → Stay as E2E only
```

## File Structure

```
monitoring/
├── checkly.config.ts
├── api-health.check.ts
├── homepage.browser.check.ts
├── login-flow.browser.check.ts
├── checkout.browser.check.ts
└── alert-channels.ts
```

## Configuration

```typescript
// monitoring/checkly.config.ts
import { defineConfig } from 'checkly'
import { Frequency } from 'checkly/constructs'

export default defineConfig({
  projectName: 'Production Monitoring',
  logicalId: 'monorepo-monitoring',
  repoUrl: 'https://github.com/org/monorepo',
  checks: {
    activated: true,
    muted: false,
    runtimeId: '2025.01',
    frequency: Frequency.EVERY_5M,
    locations: ['us-east-1', 'eu-west-1', 'ap-southeast-1'],
    tags: ['production'],
    checkMatch: '**/*.check.ts',
    browserChecks: {
      frequency: Frequency.EVERY_15M,
      testMatch: '**/*.browser.check.ts',
    },
  },
  cli: { runLocation: 'us-east-1', reporters: ['list'] },
})
```

## API Check Template

```typescript
// monitoring/api-health.check.ts
import { ApiCheck, AssertionBuilder } from 'checkly/constructs'

const check = new ApiCheck('api-health', {
  name: 'API Health Check',
  request: {
    method: 'GET',
    url: 'https://api.example.com/health',
    assertions: [
      AssertionBuilder.statusCode().equals(200),
      AssertionBuilder.jsonBody('$.status').equals('ok'),
      AssertionBuilder.responseTime().lessThan(2000),
    ],
  },
  tags: ['api', 'health'],
})
```

## Browser Check Template

```typescript
// monitoring/login-flow.browser.check.ts
import { test, expect } from '@playwright/test'

test('login flow completes successfully', async ({ page }) => {
  await page.goto('https://app.example.com/login')
  await page.getByLabel('Email').fill(process.env.CHECKLY_USER!)
  await page.getByLabel('Password').fill(process.env.CHECKLY_PASS!)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL('**/dashboard')
  await expect(page.locator('h1')).toHaveText('Dashboard')
})
```

**Key differences from E2E tests:** Hardcoded production URLs (not baseURL), env vars for credentials, no Page Object Model (self-contained), no lifecycle hooks, no storageState (fresh each run).

## Check Groups & Alert Channels

```typescript
// monitoring/alert-channels.ts
import { SlackAlertChannel, EmailAlertChannel } from 'checkly/constructs'

export const slackChannel = new SlackAlertChannel('slack-eng', {
  webhookUrl: 'https://hooks.slack.com/services/...',
  sendFailure: true, sendRecovery: true, sendDegraded: false,
})

export const emailChannel = new EmailAlertChannel('email-oncall', {
  address: 'oncall@example.com', sendFailure: true, sendRecovery: true,
})
```

## Playwright Check Suites (Zero-Duplication)

Tag critical E2E tests: `test('@critical checkout flow', async ({ page }) => { ... })`

Configure `playwrightChecks` in `checkly.config.ts` to reference your `playwright.config.ts` and filter on `@critical` tag, so the same test runs in CI and in Checkly.

## Heartbeat Checks

For long-running/cron Inngest functions: final step POSTs to a Checkly heartbeat URL. If missed within expected period, Checkly alerts.

## Deployment

```bash
npx checkly test      # Preview
npx checkly deploy    # Deploy to Checkly cloud
npx checkly deploy --force  # CI/CD
```
