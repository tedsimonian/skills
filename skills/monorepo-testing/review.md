# Testing Setup Review

Systematic audit of a repo's adherence to the monorepo testing standards. Use this when asked to review, audit, or assess a project's testing setup, or proactively when onboarding to a new codebase.

## How to Use This Review

**Automated first, manual second.** Run `scripts/audit-testing-setup.sh <repo-root>` to catch machine-detectable violations. Then walk through the manual checklist below for issues that require reading and judgment.

**Scope the review.** For a full monorepo, review everything. For a single package, focus on the sections relevant to that package type (see the matrix in SKILL.md).

**Report format.** Produce findings as a categorized list with severity:

- 🔴 **VIOLATION** - Breaks a rule from the skill. Must fix.
- 🟡 **WARNING** - Deviates from best practice. Should fix.
- 🟢 **OK** - Compliant.
- ⚪ **N/A** - Not applicable to this package type.
- 💡 **SUGGESTION** - Not a violation but an improvement opportunity.

---

## Phase 1: Automated Scan

Run the audit script first. It checks ~30 machine-detectable issues:

```bash
./scripts/audit-testing-setup.sh /path/to/repo
```

The script produces a structured report. Review its output before proceeding to the manual checks. Many issues will already be surfaced.

---

## Phase 2: Manual Review Checklist

### 2.1 File Naming & Organization

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| N1 | No `__tests__/` directories anywhere | 🔴 | `find . -type d -name __tests__` |
| N2 | No `.spec.ts` / `.spec.tsx` files (Jest convention) | 🔴 | `find . -name '*.spec.*' -not -path '*/node_modules/*'` |
| N3 | Unit tests colocated next to source files | 🟡 | Spot-check: `hash.ts` has `hash.test.ts` beside it |
| N4 | Integration tests centralized in `tests/integration/` | 🔴 | No `*.integration.test.ts` files inside `src/` |
| N5 | E2E tests centralized in `tests/e2e/` | 🔴 | No `*.e2e.test.ts` files inside `src/` or `app/` |
| N6 | Stories colocated next to components | 🟡 | `Button.stories.tsx` beside `Button.tsx` |
| N7 | `.tsx` extension only used when file contains JSX | 🟡 | No `.test.tsx` files that contain zero JSX imports |
| N8 | `.browser.test.tsx` only used for real browser tests | 🔴 | Files must import from `vitest-browser-react` or `vitest/browser` |
| N9 | `.test.tsx` files are NOT in a browser project's include | 🔴 | Check vitest config `include` globs |
| N10 | Page Object files use `.page.ts` extension | 🟡 | Check `tests/e2e/pages/` |

### 2.2 Vitest Configuration

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| V1 | Every package/app has a `vitest.config.ts` | 🔴 | `ls packages/*/vitest.config.ts apps/*/vitest.config.ts` |
| V2 | Root config uses `projects` array for discovery | 🔴 | Read root `vitest.config.ts` - must have `test.projects` |
| V3 | Root config is NOT itself a project (no `include` at root level) | 🔴 | Root should only define `projects`, `coverage`, `reporters` |
| V4 | Coverage config is ONLY in root (not in project configs) | 🔴 | `grep -r 'coverage' packages/*/vitest.config.ts` should find nothing |
| V5 | Per-package configs use `defineProject()` (single-project) or inline projects | 🔴 | Read each config - not `defineConfig` for single-project packages |
| V6 | Browser projects have `extends: true` when they need parent plugins | 🔴 | Any inline browser project in a `defineConfig` with plugins needs it |
| V7 | Integration projects have `fileParallelism: false` | 🔴 | When tests share a database |
| V8 | Integration projects have adequate timeouts | 🟡 | `testTimeout: 15_000+`, `hookTimeout: 30_000+` for DB-backed |
| V9 | `passWithNoTests: true` is set | 🟡 | Prevents CI failures when a new package has no tests yet |
| V10 | `retry: process.env.CI ? 2 : 0` is set | 🟡 | Zero locally, retries in CI |
| V11 | Project `name` follows `{package}/{type}` convention | 🟡 | e.g., `web/unit`, `web/browser`, `api-users/integration` |
| V12 | No duplicate test discovery (same file matched by multiple projects) | 🔴 | Check that `include` globs don't overlap between projects |
| V13 | `globals: true` is set OR tests use explicit imports | 🟡 | Consistent within the monorepo |
| V14 | Shared base configs exist in `packages/vitest-config/` | 🟡 | `base.ts` and `react-browser.ts` (for 3+ packages) |
| V15 | `storybookTest()` plugin appears in exactly ONE config | 🔴 | Multiple configs with it causes double-running stories |

### 2.3 Playwright Configuration

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| P1 | Apps with E2E tests have `playwright.config.ts` | 🔴 | `ls apps/*/playwright.config.ts` |
| P2 | `forbidOnly: !!process.env.CI` is set | 🔴 | Prevents `.only()` from silently skipping tests in CI |
| P3 | `workers: process.env.CI ? 1 : undefined` | 🟡 | Prevents resource exhaustion |
| P4 | `webServer` is configured | 🟡 | Starts dev server before tests |
| P5 | `trace: 'on-first-retry'` for debugging | 🟡 | Critical for CI failure investigation |
| P6 | Auth setup uses `storageState` pattern | 🟡 | Single login shared across tests |
| P7 | `playwright/.auth/` is in `.gitignore` | 🔴 | Credentials must not be committed |
| P8 | E2E test count is ≤ 30 per app | 🟡 | Count `*.e2e.test.ts` files × tests per file |
| P9 | API tests use separate project with `testMatch: '**/*.api.test.ts'` | 🟡 | No browser needed for API tests |

### 2.4 Page Objects & E2E Patterns

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| E1 | Every E2E test file uses Page Objects | 🔴 | No raw selectors (`page.locator('div.foo')`) in test files |
| E2 | Page Objects do NOT contain assertions | 🔴 | No `expect()` inside `.page.ts` files |
| E3 | Page Objects expose locators as `readonly` properties | 🟡 | Constructor pattern with named locators |
| E4 | Page Objects expose high-level action methods | 🟡 | `goto()`, `submitForm()`, etc. |
| E5 | E2E tests prefer ARIA roles over test IDs | 🟡 | `getByRole` preferred over `getByTestId` |

### 2.5 Storybook Setup

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| S1 | `.storybook/vitest.setup.ts` exists with `setProjectAnnotations` | 🔴 | Required for addon-vitest |
| S2 | Vitest config has `browser.enabled: true` with Playwright provider | 🔴 | Stories require real browser |
| S3 | Only shared UI packages use Storybook (not app-specific components) | 🟡 | App components → Vitest Browser Mode |
| S4 | Interactive components have `play` functions | 🟡 | Buttons, forms, modals, dialogs |
| S5 | Stories have `tags: ['autodocs']` on meta | 🟡 | Enables automatic documentation |

### 2.6 Test Quality

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| Q1 | Test names describe behavior, not implementation | 🟡 | Scan for antipatterns: "calls X", "sets Y to Z", "dispatches ACTION" |
| Q2 | No `any` types in test files | 🟡 | `grep -r ': any' --include='*.test.*'` |
| Q3 | Mocks limited to ≤ 3 per test file | 🟡 | Count `vi.mock()` calls per file |
| Q4 | MSW uses `onUnhandledRequest: 'error'` | 🔴 | Catches missing mock handlers |
| Q5 | `afterEach` resets mocks and handlers | 🔴 | `vi.clearAllMocks()`, `server.resetHandlers()` |
| Q6 | Database tests clean in `beforeEach` (not `afterEach`) | 🟡 | Ensures clean state even after crashes |
| Q7 | Test data uses unique values (`Date.now()`, UUIDs) | 🟡 | Prevents cross-test contamination |
| Q8 | No `@testing-library/react` in browser test files | 🔴 | Must use `vitest-browser-react` instead |
| Q9 | No `screen.getByRole` in browser test files | 🔴 | Must use `page.getByRole` |
| Q10 | No mocking of native browser APIs in browser tests | 🟡 | `matchMedia`, `IntersectionObserver`, etc. are real |

### 2.7 CI/CD Pipeline

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| C1 | CI workflow exists and runs tests | 🔴 | `.github/workflows/test.yml` or similar |
| C2 | Change detection gates jobs (`dorny/paths-filter` or similar) | 🟡 | Prevents running all tests on docs-only changes |
| C3 | Concurrency control cancels stale runs | 🟡 | `concurrency: { cancel-in-progress: true }` |
| C4 | Test stages are ordered: unit → browser/integration → E2E | 🟡 | Fast feedback first |
| C5 | Playwright browsers are cached | 🟡 | `actions/cache` with Playwright version key |
| C6 | Coverage artifacts are uploaded and merged | 🟡 | `actions/upload-artifact` + merge step |
| C7 | E2E failures upload reports as artifacts | 🟡 | `playwright-report/` uploaded on failure |
| C8 | Branch protection requires critical checks | 🟡 | lint, unit, browser, integration, e2e (chromium) |

### 2.8 mise / Task Runner

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| M1 | Root `mise.toml` exists with `env._.path = ['./node_modules/.bin']` | 🔴 | Without this, `vitest`/`playwright` aren't found |
| M2 | `test:unit` task excludes integration tests | 🟡 | `--exclude "**/*.integration.test.ts"` |
| M3 | `test:integration` task sets required env vars (DATABASE_URL, etc.) | 🟡 | Check `[env]` block |
| M4 | No `persistent = true` on test tasks | 🔴 | Causes mise to hang |
| M5 | Watch tasks use `dir = '{{cwd}}'` | 🟡 | Respects current directory |

### 2.9 TypeScript Configuration

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| T1 | `tsconfig.build.json` excludes test files | 🔴 | `exclude: ["**/*.test.*", "**/*.stories.*", "tests/**"]` |
| T2 | `tsconfig.json` includes test files (for IDE support) | 🟡 | Not explicitly excluded |
| T3 | `"types": ["vitest/globals"]` if using `globals: true` | 🟡 | Or explicit imports |

### 2.10 Monitoring (Checkly)

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| K1 | `monitoring/` directory exists (if app has production checks) | 🟡 | With `checkly.config.ts` |
| K2 | Browser checks use hardcoded production URLs | 🟡 | Not `baseURL` from config |
| K3 | Credentials via env vars, not hardcoded | 🔴 | `process.env.CHECKLY_*` |
| K4 | Alert channels configured | 🟡 | Slack, email, or webhook |
| K5 | Heartbeat checks for cron/background functions | 🟡 | If Inngest cron functions exist |

### 2.11 .gitignore

| # | Check | Severity | How to Verify |
|---|-------|----------|---------------|
| G1 | `coverage/` ignored | 🔴 | |
| G2 | `test-results/` ignored | 🔴 | |
| G3 | `playwright-report/` ignored | 🔴 | |
| G4 | `playwright/.auth/` ignored | 🔴 | |
| G5 | `storybook-static/` ignored | 🟡 | |
| G6 | `.checkly/` ignored | 🟡 | |

---

## Phase 3: Coverage Gap Analysis

After checking compliance, assess whether the right tests exist at the right layers.

For each package/app, cross-reference against the test type matrix:

| Package Type | Should have | Check |
|-------------|------------|-------|
| Server-side utility lib | Unit ✅, Integration ✅ | Any `.test.ts`? Any `.integration.test.ts`? |
| React UI component lib | Storybook ✅ | Any `.stories.tsx` with `play` functions? |
| GraphQL API subgraph | Unit ✅, Integration ✅, Contract ✅, Monitoring ✅ | Contract tests for `_service { sdl }` and `_entities`? |
| Full-stack app | Unit ✅, Browser ✅, Integration ✅, E2E ✅, Monitoring ✅ | All layers present? |
| CLI tool | Unit ✅, Integration ✅ | CLI invoked via `execa` in integration tests? |

For each package, note:
- **Undertested boundaries:** e.g., 200 unit tests but 0 integration tests
- **Overtested layers:** e.g., 200 E2E tests and 10 unit tests
- **Missing contract tests** in federated GraphQL subgraphs (BLOCKING)
- **Missing monitoring** for production-facing apps

---

## Phase 4: Produce the Report

Structure the report as:

```markdown
# Testing Setup Review - [Repo Name]

**Date:** YYYY-MM-DD
**Reviewer:** [agent/person]
**Scope:** [full monorepo | specific package(s)]

## Summary

- 🔴 Violations: X
- 🟡 Warnings: Y
- 🟢 Compliant: Z
- 💡 Suggestions: W

## Critical Issues (🔴)

1. **[V4] Coverage config in project configs** - `packages/api-users/vitest.config.ts` line 12 has `coverage: { ... }`. Move to root config.
2. ...

## Warnings (🟡)

1. **[Q1] Test naming** - 14 test cases in `packages/server-utils/` describe implementation rather than behavior.
2. ...

## Suggestions (💡)

1. **Shared base configs** - 4 packages duplicate the same Node config. Extract to `packages/vitest-config/base.ts`.
2. ...

## Coverage Gaps

| Package | Unit | Browser | Integration | E2E | Contract | Monitoring | Status |
|---------|------|---------|-------------|-----|----------|------------|--------|
| server-utils | ✅ 42 | ⚪ | ❌ 0 | ⚪ | ⚪ | ⚪ | 🟡 Missing integration |
| ui | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ✅ Storybook covers |
| api-users | ✅ 28 | ⚪ | ✅ 8 | ⚪ | ❌ 0 | ❌ 0 | 🔴 Missing contracts |
| web | ✅ 15 | ✅ 6 | ✅ 3 | ✅ 12 | ⚪ | ❌ 0 | 🟡 Missing monitoring |

## Recommended Action Plan

1. [Priority 1] Fix violations V4, N1 - blocking issues
2. [Priority 2] Add contract tests for api-users - federation risk
3. [Priority 3] Improve test naming in server-utils
4. ...
```
