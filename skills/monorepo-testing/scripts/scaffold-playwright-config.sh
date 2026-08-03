#!/usr/bin/env bash
# scaffold-playwright-config.sh - Generate playwright.config.ts for an app
# Usage: ./scaffold-playwright-config.sh <app-path> [--with-api]

set -euo pipefail

TARGET="${1:?Usage: scaffold-playwright-config.sh <app-path> [--with-api]}"
WITH_API="${2:-}"

mkdir -p "$TARGET/tests/e2e/pages" "$TARGET/playwright/.auth"

# Add .gitignore entries
if [ -f "$TARGET/.gitignore" ]; then
  grep -q "playwright/.auth/" "$TARGET/.gitignore" 2>/dev/null || echo -e "\nplaywright/.auth/\nplaywright-report/\ntest-results/\nblob-report/" >> "$TARGET/.gitignore"
fi

if [ "$WITH_API" = "--with-api" ]; then
  mkdir -p "$TARGET/tests/e2e/api"
  API_PROJECT='
    // API tests - no browser, no auth dependency
    {
      name: '\''api'\'',
      testMatch: '\''**/*.api.test.ts'\'',
      use: {
        baseURL: process.env.API_URL ?? '\''http://localhost:4000'\'',
      },
    },'
else
  API_PROJECT=""
fi

cat > "$TARGET/playwright.config.ts" << EOF
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
    { name: 'setup', testMatch: /.*\\.setup\\.ts/ },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },${API_PROJECT}
  ],

  webServer: {
    command: 'pnpm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
})
EOF

# Create auth setup template
cat > "$TARGET/tests/e2e/auth.setup.ts" << 'EOF'
import { test as setup, expect } from '@playwright/test'

setup('authenticate as user', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill('test@example.com')
  await page.getByLabel('Password').fill('password')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL('/dashboard')
  await page.context().storageState({ path: 'playwright/.auth/user.json' })
})
EOF

echo "✅ Created playwright.config.ts at $TARGET"
echo "   Created tests/e2e/auth.setup.ts"
[ -n "$API_PROJECT" ] && echo "   Created tests/e2e/api/ for API tests"
