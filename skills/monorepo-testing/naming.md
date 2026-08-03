# Naming Conventions - Definitive Reference

## File Extensions (Exhaustive)

| Extension | Purpose | Runner | Environment | Contains JSX? |
|-----------|---------|--------|-------------|---------------|
| `.test.ts` | Unit test - pure logic, no DOM | Vitest | Node.js | **Never** |
| `.test.tsx` | Unit test - server-side JSX (SSR, server components) | Vitest | Node.js | Yes |
| `.browser.test.tsx` | Component test - renders UI in real browser | Vitest Browser Mode | Real Chromium | Yes |
| `.browser.test.ts` | Browser test - DOM APIs, no React | Vitest Browser Mode | Real Chromium | No |
| `.stories.tsx` | Storybook story + interaction test | Storybook (via addon-vitest) | Real Chromium | Yes |
| `.integration.test.ts` | Integration test - crosses boundaries | Vitest | Node.js | **Never** |
| `.e2e.test.ts` | End-to-end browser test | Playwright | Playwright browsers | No (Playwright API) |
| `.api.test.ts` | End-to-end API test - HTTP requests | Playwright (request ctx) | Node.js | No |
| `.setup.ts` | Playwright global setup (auth etc.) | Playwright | Playwright | No |
| `.page.ts` | Page Object Model | Imported by `.e2e.test.ts` | - | No |
| `.fixture.ts` | Typed fixture/factory file | Imported by tests | - | No |
| `.contract.ts` | Federation/API contract test | Vitest | Node.js | No |
| `.bench.ts` | Benchmark | Vitest (`vitest bench`) | Node.js | No |
| `.check.ts` | Checkly API monitoring check | Checkly runtime | Checkly cloud | No |
| `.browser.check.ts` | Checkly browser monitoring check | Checkly + Playwright | Checkly cloud | No |

> **Key insight:** `.tsx` = "uses JSX syntax", NOT "runs in browser". The `.browser.` prefix = "needs real browser".

## Directory Names

| Directory | Location | Purpose | Contains |
|-----------|----------|---------|----------|
| `tests/` | Package/app root | Non-colocated tests | Subdirectories below |
| `tests/integration/` | Under `tests/` | Integration tests | `*.integration.test.ts` |
| `tests/contracts/` | Under `tests/` | Federation contract tests | `*.contract.ts` |
| `tests/e2e/` | Under `tests/` (apps only) | E2E tests | `*.e2e.test.ts` + `pages/` |
| `tests/e2e/pages/` | Under `tests/e2e/` | Page Object Models | `*.page.ts` |
| `tests/fixtures/` | Under `tests/` | Shared test data | `*.fixture.ts`, JSON, SQL |
| `tests/generated/` | Under `tests/` | Generated test helpers | GraphQL codegen output |
| `.storybook/` | Package root (UI packages) | Storybook config | `main.ts`, `preview.ts`, `vitest.setup.ts` |
| `monitoring/` | Monorepo root | Checkly production checks | `*.check.ts`, `checkly.config.ts` |
| `packages/vitest-config/` | Monorepo root | Shared Vitest configs | `base.ts`, `react-browser.ts` |
| `packages/testing/` | Monorepo root (optional) | Shared test utilities | `mocks/`, `fixtures/`, `factories/` |

> **Why `tests/` and not `__tests__/`:** `__tests__/` is a Jest-ism. `tests/` is naturally excluded from TS compilation via `include: ["src/**/*"]`, doesn't require special bundler exclusion, and avoids leaking into production bundles via directory-entry builds (e.g., `tsup src`).

## Colocation Strategy

| File Type | Location | Reasoning |
|-----------|----------|-----------|
| Unit `.test.ts` | **Colocated** next to source | One-hop: `hash.ts` → `hash.test.ts` |
| Server JSX `.test.tsx` | **Colocated** next to source | `Invoice.tsx` → `Invoice.test.tsx` |
| Component `.browser.test.tsx` | **Colocated** next to component | Test is about that one component |
| Stories `.stories.tsx` | **Colocated** next to component | Storybook convention; aids discovery |
| Integration `.integration.test.ts` | **Centralized** `tests/integration/` | Different setup (DB, MSW), different parallelism |
| Contract `.contract.ts` | **Centralized** `tests/contracts/` | Package-level concern |
| E2E `.e2e.test.ts` | **Centralized** `tests/e2e/` | App-level concern; needs page objects, auth |
| Benchmarks `.bench.ts` | **Colocated** next to source | Benchmarks a specific function |
| Fixtures | **Centralized** `tests/fixtures/` | Shared across test files |
| Mocks | **Centralized** `tests/mocks/` or `src/test/mocks/` | Shared across test files |

## Test Case Naming

Describe **observable behavior**, not implementation:

```typescript
// ❌ Bad: describes implementation
it('calls fetchUser with correct ID', () => {})
it('sets isLoading to true', () => {})

// ✅ Good: describes behavior
it('returns user data when user exists', () => {})
it('displays loading spinner during fetch', () => {})
it('disables submit button when form is invalid', () => {})
```

Use `describe` for context, `it` for expectations. Together they read as sentences:
`describe('hashPassword') → it('returns a string different from the input')`.
