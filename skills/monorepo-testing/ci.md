# CI/CD Reference

## Task Execution Order

```
Stage 0: Change detection (dorny/paths-filter)
Stage 1: lint + typecheck + test:unit (parallel, conditional on changes)
Stage 2: test:browser + test:storybook + test:integration (after Stage 1 passes)
Stage 3: test:e2e (after Stage 2, matrix: chromium/firefox/webkit/api)
Post:    coverage merge, chromatic (PR only), checkly deploy (main only)
```

## mise Task Definitions

```toml
# mise.toml (monorepo root)
[tools]
node = '22'

[env]
_.path = ['./node_modules/.bin']

[tasks.install]
run = 'pnpm install --frozen-lockfile'

[tasks.build]
depends = ['install']
run = 'pnpm -r run build'
sources = ['packages/*/src/**', 'apps/*/src/**', 'package.json']
outputs = ['packages/*/dist/**', 'apps/*/dist/**']

[tasks."test:unit"]
run = 'vitest run --exclude "**/*.integration.test.ts"'
description = 'Run all Vitest unit tests (excludes integration)'

[tasks."test:unit:watch"]
run = 'vitest --exclude "**/*.integration.test.ts"'
dir = '{{cwd}}'
description = 'Watch mode - respects current working directory'

[tasks."test:integration"]
run = 'vitest run --exclude "**/*.test.ts" --exclude "!**/*.integration.test.ts"'
env = { DATABASE_URL = "postgresql://postgres:test@localhost:5432/test", INNGEST_DEV = "1" }
description = 'Run integration tests (requires DB + optional Inngest Dev Server)'

[tasks."test:browser"]
run = 'vitest run --project storybook'
description = 'Run Storybook/browser tests'

[tasks."test:e2e"]
run = '''
for app in apps/*/; do
  [ -f "$app/playwright.config.ts" ] && playwright test --config "$app/playwright.config.ts"
done
'''
description = 'Run all E2E tests across apps'

[tasks."test:e2e:web"]
run = 'playwright test --config apps/web/playwright.config.ts'

[tasks."test:all"]
depends = ['test:unit', 'test:integration', 'test:browser', 'test:e2e']
description = 'Run all test categories sequentially'

[tasks."inngest:dev"]
run = 'npx inngest-cli@latest dev --no-discovery -u http://localhost:4000/api/inngest'
description = 'Start Inngest Dev Server for integration testing'
```

## Package.json Scripts (Convenience Wrappers)

**Root:**
```json
{
  "test": "mise run test:all",
  "test:unit": "mise run test:unit",
  "test:integration": "mise run test:integration",
  "test:e2e": "mise run test:e2e",
  "test:bench": "vitest bench",
  "test:coverage": "vitest run --coverage"
}
```

**Per-app:**
```json
{
  "test:unit": "vitest run --project=web/unit",
  "test:browser": "vitest run --project=web/browser",
  "test:integration": "vitest run --project=web/integration",
  "test:e2e": "playwright test",
  "test:e2e:ui": "playwright test --ui"
}
```

Primary entry point is `mise run test:<category>`, not `pnpm run test`.

## GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test
on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  CI: true

jobs:
  # Stage 0: Change detection
  changes:
    name: Detect Changes
    runs-on: ubuntu-latest
    outputs:
      apps: ${{ steps.filter.outputs.apps }}
      packages: ${{ steps.filter.outputs.packages }}
      e2e: ${{ steps.filter.outputs.e2e }}
      ui: ${{ steps.filter.outputs.ui }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            apps:
              - 'apps/**'
            packages:
              - 'packages/**'
            e2e:
              - 'apps/**'
              - 'packages/**'
              - 'e2e/**'
            ui:
              - 'packages/ui/**'

  # Stage 1: Fast checks (parallel)
  lint-and-type:
    runs-on: ubuntu-latest
    needs: [changes]
    if: needs.changes.outputs.apps == 'true' || needs.changes.outputs.packages == 'true'
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: pnpm install --frozen-lockfile
      - run: mise run lint
      - run: mise run typecheck

  unit-tests:
    runs-on: ubuntu-latest
    needs: [changes]
    if: needs.changes.outputs.apps == 'true' || needs.changes.outputs.packages == 'true'
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: pnpm install --frozen-lockfile
      - run: mise run test:unit -- --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage-unit
          path: '**/coverage/lcov.info'
          retention-days: 1

  # Stage 2: Browser + Integration (after unit passes)
  browser-tests:
    needs: [changes, unit-tests]
    if: needs.changes.outputs.apps == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: pnpm install --frozen-lockfile
      - name: Get Playwright version
        run: echo "PLAYWRIGHT_VERSION=$(playwright --version)" >> $GITHUB_ENV
      - name: Cache Playwright browsers
        uses: actions/cache@v4
        id: playwright-cache
        with:
          path: ~/.cache/ms-playwright
          key: ${{ runner.os }}-playwright-${{ env.PLAYWRIGHT_VERSION }}
      - name: Install Playwright browsers
        if: steps.playwright-cache.outputs.cache-hit != 'true'
        run: playwright install chromium --with-deps
      - name: Install Playwright deps (cached)
        if: steps.playwright-cache.outputs.cache-hit == 'true'
        run: playwright install-deps chromium
      - run: mise run test:browser

  integration-tests:
    needs: [changes, unit-tests]
    if: needs.changes.outputs.packages == 'true'
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_PASSWORD: test, POSTGRES_DB: test }
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: pnpm install --frozen-lockfile
      - name: Start Inngest Dev Server
        run: |
          npx inngest-cli@latest dev --no-discovery -u http://localhost:4000/api/inngest &
          until curl -sf http://localhost:8288/health > /dev/null; do sleep 1; done
      - run: mise run test:integration
        env:
          DATABASE_URL: postgresql://postgres:test@localhost:5432/test
          INNGEST_DEV: '1'
          INNGEST_EVENT_KEY: test
          INNGEST_SIGNING_KEY: test

  # Stage 3: E2E (matrix)
  e2e-tests:
    needs: [changes, browser-tests, integration-tests]
    if: needs.changes.outputs.e2e == 'true'
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        project: [chromium, firefox, webkit, api]
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: pnpm install --frozen-lockfile
      - name: Install Playwright browsers
        if: matrix.project != 'api'
        run: playwright install --with-deps ${{ matrix.project }}
      - run: mise run test:e2e -- --project=${{ matrix.project }}
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report-${{ matrix.project }}
          path: '**/playwright-report/'
          retention-days: 7

  # Post: Coverage merge
  coverage:
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests]
    if: always() && needs.unit-tests.result == 'success'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { pattern: 'coverage-*', merge-multiple: true }
      - run: |
          npx nyc merge . coverage/merged.json
          npx nyc report --reporter=lcov --temp-dir=coverage
      - name: PR Coverage Comment
        if: github.event_name == 'pull_request'
        uses: davelosert/vitest-coverage-report-action@v2

  # Post: Checkly deploy (main only)
  monitoring:
    needs: [e2e-tests]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
      - run: pnpm install --frozen-lockfile
      - run: npx checkly deploy --force
        env:
          CHECKLY_API_KEY: ${{ secrets.CHECKLY_API_KEY }}
          CHECKLY_ACCOUNT_ID: ${{ secrets.CHECKLY_ACCOUNT_ID }}
```

## Caching Strategy

| Task | Cacheable? | Why |
|------|-----------|-----|
| build | Yes (sources/outputs) | Deterministic |
| test:unit | Yes (sources/outputs) | Deterministic |
| test:browser | No | Depends on Chromium binary |
| test:integration | No | Depends on external services |
| test:e2e | No | Depends on running app server |

mise has local file-modification-time caching only (no remote). Sufficient for 5-10 package monorepos.

## Branch Protection Rules

**Required:** lint-and-type, unit-tests, browser-tests, integration-tests, e2e-tests (chromium), e2e-tests (api)

**Optional:** chromatic, e2e-tests (firefox), e2e-tests (webkit) - promote to required if cross-browser issues exist.

## Vitest Sharding

When unit tests exceed ~500 or CI > 5 minutes:

```yaml
strategy:
  matrix:
    shard: [1, 2, 3, 4]
steps:
  - run: mise run test:unit -- --shard=${{ matrix.shard }}/4 --coverage
```

Merge sharded coverage in the coverage job with `nyc merge`.
