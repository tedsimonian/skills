---
name: monorepo-testing
description: >
  Use this skill when writing, configuring, or reviewing tests in the TypeScript monorepo.
  Covers Vitest (unit, browser, integration), Storybook (UI component stories),
  Playwright (E2E, API), Checkly (production monitoring), and Inngest workflow testing.
  Includes naming conventions, config patterns, CI/CD setup, and gotchas.
  Trigger on: creating test files, configuring test runners, writing stories,
  setting up CI pipelines, debugging test failures, or adding new packages.
version: 1.1.0
scope: Vitest 4.x · Storybook 9 · Playwright 1.50+ · Checkly · TypeScript · mise / Node.js
---

# Monorepo Testing Skill

## Quick Decision: "How Do I Test This?"

```
Does it render UI / use JSX?
├─ NO → Does it cross a service boundary (DB, HTTP, queue)?
│        ├─ NO → .test.ts (Vitest Node)
│        └─ YES → .integration.test.ts (Vitest Node) → see VITEST.md §Integration
│
└─ YES → Does it need a real browser (DOM events, client state, browser APIs)?
         ├─ NO → .test.tsx (Vitest Node - SSR, server components, email templates)
         └─ YES → Is it a shared UI library component?
                  ├─ YES → .stories.tsx (Storybook + addon-vitest) → see STORYBOOK.md
                  └─ NO  → .browser.test.tsx (Vitest Browser Mode) → see VITEST.md §Browser

Is this a critical user-facing flow?
├─ Browser flow → .e2e.test.ts (Playwright) → see PLAYWRIGHT.md
├─ API-only    → .api.test.ts (Playwright request) → see PLAYWRIGHT.md §API
└─ Should it be monitored in prod? → .check.ts (Checkly) → see CHECKLY.md
```

## File Extension Quick Reference

| Extension | Runner | Environment | Colocated? |
|-----------|--------|-------------|------------|
| `.test.ts` | Vitest | Node.js | ✅ next to source |
| `.test.tsx` | Vitest | Node.js (JSX/SSR) | ✅ next to source |
| `.browser.test.tsx` | Vitest Browser | Real Chromium | ✅ next to source |
| `.stories.tsx` | Storybook + addon-vitest | Real Chromium | ✅ next to component |
| `.integration.test.ts` | Vitest | Node.js | ❌ `tests/integration/` |
| `.e2e.test.ts` | Playwright | Playwright browsers | ❌ `tests/e2e/` |
| `.api.test.ts` | Playwright (request) | Node.js | ❌ `tests/e2e/` |
| `.check.ts` | Checkly | Checkly cloud | ❌ `monitoring/` |
| `.browser.check.ts` | Checkly + Playwright | Checkly cloud | ❌ `monitoring/` |
| `.contract.ts` | Vitest | Node.js | ❌ `tests/contracts/` |
| `.bench.ts` | Vitest Bench | Node.js | ✅ next to source |

> **The `.tsx` extension means "uses JSX syntax", NOT "needs a browser."** The `.browser.` prefix signals "needs a real browser."

## Inviolable Rules

1. **File extension = runtime.** `.test.ts` → Node, `.browser.test.tsx` → real browser. Never mix.
2. **One tool per boundary.** Unit=Vitest, Component=Vitest Browser/Storybook, Integration=Vitest, E2E=Playwright, Monitoring=Checkly.
3. **Colocated tests use the source filename.** `hash.ts` → `hash.test.ts`. Integration/E2E tests are centralized in `tests/`.
4. **Use `tests/` not `__tests__/`.** Avoids leaking into production bundles.
5. **Page Objects are mandatory for E2E.** No inline selectors in `.e2e.test.ts` files.
6. **Integration tests use `fileParallelism: false`** when they share a database.
7. **Root vitest.config.ts is NOT a project.** It only defines `projects` globs and root-only options (coverage, reporters).
8. **Coverage thresholds are per-package**, set in each package's `vitest.config.ts`.
9. **E2E tests are capped at 20-30 per app.** More than that → push to unit/integration layer.
10. **Checkly checks are promoted E2E tests**, not separate tests. They monitor critical production flows.

## Reference Files

Read these on-demand based on the task:

| File | Read when... |
|------|-------------|
| [naming.md](./naming.md) | Creating new test files, setting up directory structure, reviewing naming |
| [vitest.md](./vitest.md) | Writing unit/browser/integration tests, configuring Vitest projects |
| [storybook.md](./storybook.md) | Writing stories, setting up Storybook + addon-vitest |
| [playwright.md](./playwright.md) | Writing E2E tests, API tests, Page Objects, auth setup |
| [checkly.md](./checkly.md) | Setting up production monitoring, writing checks |
| [inngest.md](./inngest.md) | Testing Inngest durable workflows |
| [ci.md](./ci.md) | Setting up GitHub Actions, mise tasks, caching, sharding |
| [gotchas.md](./gotchas.md) | Debugging failures, diagnosing flakiness, common pitfalls |
| [review.md](./review.md) | Auditing a repo for standards compliance, reviewing test setup |

## Coverage Thresholds by Package Type

| Package Type | Statements | Branches | Functions | Lines |
|--------------|------------|----------|-----------|-------|
| Server Utils | 80% | 80% | 80% | 80% |
| UI Components | - | - | - | - (stories provide coverage) |
| GraphQL API | 75% | 70% | 75% | 75% |
| Full-Stack App | 60% | 60% | 60% | 60% |
| CLI | 70% | 70% | 70% | 70% |

## Test Type Matrix by Package

| Package Type | Unit | Browser | Storybook | Integration | E2E | Contract | Monitoring |
|-------------|------|---------|-----------|-------------|-----|----------|------------|
| Server-side utility lib | ✅ | - | - | ✅ | - | - | - |
| React UI component lib | - | - | ✅ | - | - | - | - |
| GraphQL API subgraph | ✅ | - | - | ✅ | - | ✅ | ✅ |
| Full-stack app (TanStack Start) | ✅ | ✅ | - | ✅ | ✅ | - | ✅ |
| Client-only SPA | ✅ | ✅ | - | - | ✅ | - | ✅ |
| CLI tool | ✅ | - | - | ✅ | - | - | - |

## Speed-Confidence Spectrum

| Layer | Speed | Tool |
|-------|-------|------|
| Unit `.test.ts` | ~1ms/test | Vitest Node |
| Server JSX `.test.tsx` | ~5-20ms/test | Vitest Node |
| Component `.browser.test.tsx` | ~50ms/test | Vitest Browser / Storybook |
| Integration `.integration.test.ts` | ~100-500ms/test | Vitest Node |
| E2E `.e2e.test.ts` | ~2-10s/test | Playwright |
| Monitoring `.check.ts` | Every 5-15 min | Checkly |

**Rule of thumb:** If a server-utils package has 200 unit tests and 0 integration tests, it's undertested at the boundary. If an app has 200 E2E tests and 0 unit tests, it's overtested at the wrong layer.

## New Package Setup Checklist

1. Create `vitest.config.ts` - use `defineProject()` (single-project) or `defineConfig()` with `projects` (multi-project)
2. Verify root config discovers it via `projects` glob
3. Create `playwright.config.ts` (apps only, if E2E needed)
4. Create `tests/` directory with `integration/` and/or `e2e/` subdirectories
5. Add per-app `mise.toml` (apps only)
6. Update `tsconfig.build.json` - exclude test files from production builds
7. Install per-project devDependencies
8. Write a smoke test and verify it runs: `mise run test:unit -- --project <name>`
9. Add Inngest test infrastructure if applicable

## Scripts

Helper scripts are in `scripts/`:
- `scaffold-vitest-config.sh` - generate vitest.config.ts for common package types
- `scaffold-playwright-config.sh` - generate playwright.config.ts for an app
- `scaffold-test-file.sh` - create a test file with the correct template for any extension
- `audit-testing-setup.sh` - automated compliance audit (run before manual review)

## Reviewing a Repo

To audit a repo or package against these standards, read [review.md](./review.md). The review has four phases:

1. **Automated scan** - run `scripts/audit-testing-setup.sh <repo-root>` to catch ~30 machine-detectable violations
2. **Manual checklist** - walk through 70+ checks across naming, config, patterns, CI, and quality
3. **Coverage gap analysis** - verify each package has the right test types for its package type
4. **Report** - produce a structured findings document with severity, evidence, and action plan

When asked to "review testing", "audit tests", or "check test setup", start with Phase 1 (the script) and then proceed through the manual checklist, focusing on sections relevant to the package types present.
