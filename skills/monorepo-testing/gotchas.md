# Gotchas, Pitfalls & Reliability

## Vitest Gotchas

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| `defineConfig` in project file | Root-only options (coverage, reporters) silently ignored | Use `defineProject` for per-package configs |
| Dual config files | `vitest.config.ts` ignores `vite.config.ts` entirely | Use `mergeConfig` or a single `vite.config.ts` |
| Root config is not a project | Tests in root are not discovered | Root config only defines projects - it is not itself a project |
| Duplicate test execution | Tests run twice | Ensure `include` patterns exist only in project configs, not root |
| `coverage` in project configs | Coverage options silently ignored | Set all coverage in root config only |
| `extends: true` missing | Browser project lacks parent plugins (`react()`) | Add `extends: true` to inline project definitions needing parent plugins |
| `fileParallelism` confusion | DB tests fail with constraint violations | Set `fileParallelism: false` for projects with shared database |
| `.test.tsx` in wrong project | Server JSX test runs in browser (or vice versa) | `.test.tsx` → Node project's `include`, `.browser.test.tsx` → browser project's `include` |
| `vi.mock` hoisting | Mock declared after import still works (confusing) | Always place `vi.mock()` at top - they are hoisted regardless |
| PWA/SSR plugin interference | Tests crash with plugin errors | Wrap: `!process.env.VITEST && plugin()` |

## Playwright Gotchas

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| `.only()` in CI | Most tests silently skipped | `forbidOnly: !!process.env.CI` |
| `persistent: true` on test task | mise hangs, never completes | Never use `persistent` on test tasks - only for dev/storybook |
| Missing `webServer` | Tests fail with connection refused | Configure `webServer` to start dev server |
| Auth state not saved | Every test logs in from scratch | Use `storageState` with a setup project |
| `playwright/.auth/` committed | Credentials in VCS | Add to `.gitignore` |
| Too many E2E tests | CI > 30 min | Cap at 20-30 per app; push to unit/integration |
| `workers: 1` missing in CI | Resource exhaustion | `workers: process.env.CI ? 1 : undefined` |
| Inline selectors | Tests break on UI changes | Mandate Page Object Model |

## Storybook Gotchas

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| Missing `vitest.setup.ts` | Story annotations not loaded | Create `.storybook/vitest.setup.ts` with `setProjectAnnotations` |
| `storybookTest` without browser mode | Stories fail | Always configure `browser.enabled: true` with Playwright provider |
| App-specific components | Complex mocking required | Use Vitest Browser Mode for app components; Storybook for shared UI only |
| `tags: ['autodocs']` missing | No auto-generated docs | Add to story meta |

## mise Gotchas

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| Missing `env._.path` | `vitest`/`playwright` not found | Add `env._.path = ['./node_modules/.bin']` to root `mise.toml` |
| `depends` on background services | mise waits for dependency to exit | Start background services with `&` + cleanup trap |
| Watch mode through mise | Task exits immediately or hangs | Run `cd apps/web && vitest --watch` directly |
| Task name collisions | Root task shadowed | Use `mise run -C apps/web test:e2e` |

## TypeScript Gotchas

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| Tests in build output | `.test.ts` files in `dist/` | `tsconfig.build.json` with `exclude: ["**/*.test.*", "tests/**"]` |
| `__tests__/` leaking to npm | Test files in package | Use `files` array with `"!**/__tests__"` |
| Type errors in tests | `expect`/`describe` not found | `"types": ["vitest/globals"]` in test tsconfig, or explicit imports |

## Flakiness Root Causes

| Cause | ~Frequency | Mitigation |
|-------|-----------|------------|
| Concurrency / shared state | 45% | Test isolation, unique data (`Date.now()` in emails/IDs), `beforeEach` cleanup |
| Network / external services | 15% | MSW for HTTP, `yoga.fetch()` for GraphQL, no real network in unit/integration |
| Platform / timing | 12% | `vi.useFakeTimers()`, explicit waits in E2E, avoid `setTimeout` assertions |
| Resource exhaustion | 10% | `workers: 1` in CI, `fileParallelism: false` for DB tests |
| Test order dependency | 8% | `sequence.shuffle` to detect, proper isolation to fix |
| Browser state leaks | 5% | `storageState` cleanup, fresh contexts |
| Environment differences | 5% | Docker services in CI, pinned Node.js, consistent OS |

## Retry Strategy

```typescript
retry: process.env.CI ? 2 : 0
```

Zero locally = honest feedback. Two in CI = absorbs transient issues. Tests that consistently need retries must be investigated.

## Test Isolation Patterns

**Database - unique data:**
```typescript
beforeEach(async () => { await db.delete(users) })
it('creates a user', async () => {
  const email = `test-${Date.now()}@example.com`
  // ...
})
```

**MSW - reset after each:**
```typescript
afterEach(() => { server.resetHandlers() })
```

**Timers:**
```typescript
beforeEach(() => { vi.useFakeTimers() })
afterEach(() => { vi.useRealTimers() })
```

## Detecting Order Dependencies

```bash
vitest run --sequence.shuffle
```

If tests fail under shuffle but pass normally → hidden shared mutable state or missing cleanup.

## .gitignore

```gitignore
# Vitest
coverage/
test-results/
.vitest/
.vitest-reports/

# Playwright
playwright-report/
playwright/.auth/
blob-report/

# Storybook
storybook-static/

# Checkly
.checkly/
```
