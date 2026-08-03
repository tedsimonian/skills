---
name: coding-standards
description: Ensures enterprise-grade coding standards, company golden paths and blessed technologies for fullstack TypeScript projects. Use when writing code, reviewing architecture, setting up monorepos, configuring tooling, or addressing ESLint issues. Covers React, TanStack, GraphQL, Bun, Docker, Vite, security, performance, and strict TypeScript patterns.
---

# Coding Standards & Golden Path

This skill ensures code follows enterprise-grade standards while maintaining pragmatic development velocity. The approach is **Pragmatic Enterprise**: apply enterprise patterns where they add clear value, favor documentation over unnecessary abstraction, and keep solutions focused on actual requirements.

## Core Philosophy

**Why these standards exist**: Every standard here serves a purpose - either preventing real bugs we've encountered, improving developer experience, or ensuring maintainability at scale. When a standard seems burdensome, understand the "why" before seeking an exception.

**Type Safety as Foundation**: TypeScript's strict mode is non-negotiable because type errors caught at compile time are dramatically cheaper than runtime errors in production. The brief friction of explicit types pays dividends in refactoring confidence and self-documenting code.

**Trust but Verify**: We trust validated data internally and focus defensive coding at system boundaries. This avoids the performance overhead and code noise of redundant validation while maintaining security where it matters.

## Technology Tiers

Technologies are categorized into four tiers. See [blessed-stack.md](blessed-stack.md) for the complete list with rationale.

| Tier            | Meaning                           | Process                           |
| --------------- | --------------------------------- | --------------------------------- |
| **Required**    | Must use for this domain          | No alternatives without ADR       |
| **Preferred**   | Default choice, proven at scale   | Use unless specific reason not to |
| **Allowed**     | Acceptable for specific use cases | Document why in PR                |
| **Discouraged** | Avoid, legacy or superseded       | Requires team review + ADR        |

**Key Required Technologies**:

- Runtime: **Bun** (prefer Bun-native APIs like `Bun.serve`, `Bun.file`, `bun:sqlite`)
- Framework: **TanStack Start** with TanStack Router
- Styling: **Tailwind CSS** with **class-variance-authority (CVA)** for variants
- State: **TanStack Query** for server state, local useState for UI
- Forms: **TanStack Form**
- Database: **Drizzle ORM**
- GraphQL: **Apollo Federation** with GraphQL Codegen
- Auth: Self-hosted with **better-auth** or **Lucia**
- i18n: **i18next** / react-i18next

## TypeScript Standards

### Maximum Type Explicitness

Every function parameter, return type, and generic must be explicitly typed. IDE performance impact is acceptable for the safety and documentation benefits.

```typescript
// CORRECT: Explicit types everywhere
export function calculateDiscount(price: number, discountPercent: number, options: DiscountOptions): DiscountResult {
  // ...
}

// INCORRECT: Relying on inference
export function calculateDiscount(price, discountPercent, options) {
  // ...
}
```

**Why**: Explicit types serve as documentation, catch errors at boundaries, and make refactoring safe. When a function signature changes, TypeScript tells you every call site that needs updating.

### TSDoc Documentation

Full TSDoc documentation is required for all functions. This applies to both exported APIs and internal functions.

````typescript
/**
 * Calculates the discounted price applying percentage and cap limits.
 *
 * Handles edge cases where discount exceeds price by returning zero
 * rather than negative values. Currency rounding follows banker's
 * rounding (round half to even) for financial accuracy.
 *
 * @param price - Original price in cents (integer)
 * @param discountPercent - Discount as decimal (0.15 for 15%)
 * @param options - Additional configuration
 * @param options.maxDiscount - Cap on maximum discount in cents
 * @param options.roundingMode - Override default banker's rounding
 * @returns Calculated discount details including savings amount
 * @throws {InvalidPriceError} When price is negative
 *
 * @example
 * ```ts
 * const result = calculateDiscount(10000, 0.15, { maxDiscount: 1000 });
 * // result.finalPrice === 9000
 * ```
 */
````

**When to update**: Documentation MUST be updated whenever function behavior changes. Outdated docs are worse than no docs.

### Strict Null Handling

Use optional chaining (`?.`) and nullish coalescing (`??`) extensively. Never use `||` for defaults when the value could be `0` or `''`.

```typescript
// CORRECT: Nullish coalescing preserves falsy values
const count = response.count ?? 0;
const name = user?.profile?.displayName ?? 'Anonymous';

// INCORRECT: OR operator treats 0 and '' as falsy
const count = response.count || 0; // Bug: count of 0 becomes 0
```

### Import Organization

Strict grouped ordering with blank lines between groups:

```typescript
// 1. Built-in / Node modules
import { readFile } from 'node:fs/promises';
import path from 'node:path';

// 2. External packages
import { z } from 'zod';
import { useMutation } from '@tanstack/react-query';

// 3. Internal aliases (@/)
import { Button } from '@/components/ui/button.js';
import { useAuth } from '@/hooks/use-auth.js';

// 4. Relative imports (same feature/directory)
import { validateInput } from './validation.js';
import type { FormState } from './types.js';
```

### ESM Import Extensions - Critical Requirement

**REQUIRED**: All TypeScript imports of local files MUST include the `.js` extension (not `.ts`). This is non-negotiable for ESM compatibility.

```typescript
// CORRECT: Use .js extension for TypeScript files
import { formatDate } from './utils.js';
import type { User } from './types.js';
import { Button } from '@/components/button.js';

// INCORRECT: Missing extension
import { formatDate } from './utils';
import type { User } from './types';
import { Button } from '@/components/button';

// INCORRECT: Using .ts extension
import { formatDate } from './utils.ts';
```

**Why this is required**:

1. **ES Modules Specification**: ESM requires explicit file extensions. The JavaScript output from TypeScript compilation will have `.js` extensions, not `.ts`.

2. **Runtime Compatibility**: Node.js ESM resolution requires extensions. Without them, imports fail at runtime with `ERR_MODULE_NOT_FOUND`.

3. **Build-Free Execution**: With `verbatimModuleSyntax`, TypeScript doesn't rewrite import paths. Your `.ts` source must match what will work in the compiled `.js` output.

4. **Library Consumer Compatibility**: If you publish packages, missing extensions break for downstream consumers using ESM.

**What happens without extensions**:

```bash
# Runtime error when running compiled code
Error [ERR_MODULE_NOT_FOUND]: Cannot find module './utils'
  imported from /path/to/compiled/file.js
```

**TypeScript Configuration** (`tsconfig.json`):

```json
{
  "compilerOptions": {
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "verbatimModuleSyntax": true // Enforces correct import syntax
  }
}
```

The `verbatimModuleSyntax: true` setting prevents TypeScript from silently accepting incorrect import syntax and ensures you catch issues during development. See the [TypeScript documentation on verbatimModuleSyntax](https://www.typescriptlang.org/tsconfig/verbatimModuleSyntax.html) and [choosing compiler options](https://www.typescriptlang.org/docs/handbook/modules/guides/choosing-compiler-options.html) for details.

**VSCode Auto-Import Configuration**:

Create or update `.vscode/settings.json`:

```json
{
  "typescript.preferences.importModuleSpecifierEnding": "js",
  "typescript.preferences.importModuleSpecifier": "non-relative",
  "javascript.preferences.importModuleSpecifierEnding": "js"
}
```

This configures VSCode's TypeScript language server to automatically add `.js` extensions when using auto-import (Cmd+. or Ctrl+.).

**ESLint Enforcement**:

The `import-x/extensions` rule enforces this requirement:

```javascript
// eslint.config.mjs
export default [
  {
    rules: {
      'import-x/extensions': [
        'error',
        'ignorePackages',
        {
          js: 'always',
          jsx: 'always',
          ts: 'always',
          tsx: 'always',
        },
      ],
    },
  },
];
```

With this rule:

- ✅ ESLint auto-fix (`eslint --fix`) will add missing `.js` extensions
- ❌ Commits with missing extensions will be caught by pre-commit hooks
- 🔍 IDE integration will show inline errors for missing extensions

**Exception**: External package imports (from `node_modules`) should NOT include extensions:

```typescript
// CORRECT: No extension for external packages
import { z } from 'zod';
import React from 'react';

// INCORRECT: Extensions on external packages
import { z } from 'zod.js';
```

The `ignorePackages` option in the ESLint rule handles this automatically.

### Type Issues with Third-Party Libraries

When encountering incorrect or missing types from external libraries, use TypeScript module augmentation:

```typescript
// src/types/library-overrides.d.ts
declare module 'problematic-library' {
  export interface FixedInterface {
    correctedProperty: string;
  }
}
```

**Why module augmentation**: It's type-safe, doesn't require build changes, and clearly documents the override. Submit upstream PR when possible.

## Error Handling

Use a **hybrid approach** matching the error type to the handling pattern:

| Error Type              | Pattern             | Example                    |
| ----------------------- | ------------------- | -------------------------- |
| Business logic failures | Result/Either types | Validation, business rules |
| I/O operations          | try-catch           | Network, file system       |
| React rendering         | Error boundaries    | Component failures         |

```typescript
// Business logic: Result type
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

function validateOrder(order: Order): Result<ValidatedOrder, ValidationError> {
  if (order.items.length === 0) {
    return { ok: false, error: { code: 'EMPTY_ORDER', message: 'Order must have items' } };
  }
  return { ok: true, value: order as ValidatedOrder };
}

// I/O: try-catch
async function fetchUser(id: string): Promise<User> {
  try {
    const response = await fetch(`/api/users/${id}`);
    if (!response.ok) throw new NetworkError(response.status);
    return response.json();
  } catch (error) {
    logger.error('Failed to fetch user', { id, error });
    throw error;
  }
}
```

## React Patterns

### Profile-First Performance

Trust React Compiler for memoization. Manual `useMemo`, `useCallback`, and `React.memo` are code smells unless profiler data shows a problem.

```typescript
// INCORRECT: Premature memoization
const MemoizedComponent = React.memo(({ data }) => {
  const processed = useMemo(() => data.map(transform), [data]);
  const handleClick = useCallback(() => onClick(data.id), [data.id, onClick]);
  // ...
});

// CORRECT: Let React Compiler handle it
function Component({ data }) {
  const processed = data.map(transform);
  const handleClick = () => onClick(data.id);
  // ...
}
```

**When to manually optimize**: Only after React DevTools Profiler shows the specific component causing jank. Document the profiler findings in a comment.

### Server State Separation

- **TanStack Query**: All server/remote state
- **useState/useReducer**: UI-only ephemeral state (form inputs, toggles)
- **Context**: Cross-cutting concerns (theme, auth, i18n)

Never duplicate server state in local state. Never put UI state in Query cache.

### Async UI Patterns

Use React Suspense for loading states and Error Boundaries for error states:

```tsx
// Route-level handling preferred
export function Route() {
  return (
    <ErrorBoundary fallback={<ErrorDisplay />}>
      <Suspense fallback={<Loading />}>
        <UserProfile />
      </Suspense>
    </ErrorBoundary>
  );
}

// Component assumes data exists
function UserProfile() {
  const user = useSuspenseQuery(userQuery);
  return <div>{user.name}</div>;
}
```

### TanStack Start Data Loading

Server functions are the primary data loading mechanism:

```typescript
// Server function for data fetching
const getUser = createServerFn('GET', async (id: string) => {
  const user = await db.query.users.findFirst({ where: eq(users.id, id) });
  if (!user) throw notFound();
  return user;
});

// Route loader uses server function
export const Route = createFileRoute('/users/$id')({
  loader: ({ params }) => getUser(params.id),
});

// TanStack Query wraps server functions for mutations and refetching
const mutation = useMutation({
  mutationFn: (data) => updateUser(data),
  onSuccess: () => queryClient.invalidateQueries({ queryKey: ['user'] }),
});
```

**For comprehensive TanStack Start patterns**, see [tanstack-start.md](tanstack-start.md) which covers:

- Project structure and organization
- Server function patterns and validation
- Routing, layouts, and error boundaries
- Data fetching with TanStack Query integration
- Forms with TanStack Form
- Authentication and security
- Performance optimization
- Testing strategies
- Deployment and operations
- Common patterns and real-world examples

## File Organization

### Naming Conventions

- **Files and folders**: kebab-case (`user-profile.tsx`, `use-auth.ts`)
- **Components**: PascalCase (`UserProfile`, `AuthProvider`)
- **Functions/hooks**: camelCase (`useAuth`, `formatDate`)
- **Constants**: UPPER_SNAKE_CASE for true constants (`MAX_RETRIES`)

### Configuration File Extensions

**REQUIRED**: All tooling configuration files MUST use `.ts` extensions (or `.mjs` for pure ESM), never `.js` or `.json` when TypeScript is available.

```bash
# CORRECT: Use .ts or .mjs extensions
eslint.config.ts          # or eslint.config.mjs
prettier.config.ts        # or prettier.config.mjs
commitlint.config.ts      # or commitlint.config.mjs
lint-staged.config.ts     # or lint-staged.config.mjs
knip.config.ts            # or knip.config.mjs
vitest.config.ts
vite.config.ts

# INCORRECT: Avoid .js or .json for configs
eslint.config.js
prettier.config.js
.prettierrc.json
.eslintrc.json
```

**Why TypeScript configs are preferred**:

1. **Type Safety**: IDE autocomplete and type checking catch configuration errors before runtime
2. **Refactoring**: Renaming rules or options is caught by TypeScript
3. **Documentation**: Hover over any option for inline JSDoc documentation
4. **Validation**: Invalid configuration values are caught at dev time, not in CI
5. **Imports**: Can import shared configuration pieces with full type safety

**ESM Module Format** (`.mjs` or `type: "module"` in package.json):

When using ESM, config files should use `.mjs` extension OR use `.ts` that compiles to ESM:

```typescript
// eslint.config.ts (or .mjs)
import { createConfig } from '@repo/eslint-config';

export default createConfig({
  copyrightHolder: 'Acme Inc',
  tsconfigRootDir: import.meta.dirname,
});
```

**Benefits of `.ts` over `.mjs`**:

```typescript
// eslint.config.ts
import type { Config } from 'eslint'; // ← Type imports work
import { rules } from './shared-rules.js'; // ← Can share configs with types

const config: Config = {
  // ← Full type checking
  rules: {
    'no-console': 'error', // ← Autocomplete for rule names
    // @ts-expect-error - shows invalid configuration
    'invalid-rule': 'error', // ← TypeScript catches this
  },
};

export default config;
```

**Migration from JSON to TypeScript**:

```bash
# Before (limited, no type safety)
.prettierrc.json

# After (typed, composable)
prettier.config.ts
```

```typescript
// prettier.config.ts
import type { Config } from 'prettier';

const config: Config = {
  semi: true,
  singleQuote: true,
  trailingComma: 'all',
  printWidth: 100,
};

export default config;
```

**Tooling Support Matrix**:

| Tool        | .ts Support | .mjs Support | Recommended |
| ----------- | ----------- | ------------ | ----------- |
| ESLint 9+   | ✅          | ✅           | `.ts`       |
| Prettier 3+ | ✅          | ✅           | `.ts`       |
| Vitest      | ✅          | ✅           | `.ts`       |
| Vite        | ✅          | ✅           | `.ts`       |
| lint-staged | ❌          | ✅           | `.mjs`      |
| Knip        | ✅          | ✅           | `.ts`       |
| Commitlint  | ❌          | ✅           | `.mjs`      |

**Note**: Some tools like `lint-staged` and `commitlint` don't natively support `.ts` configs yet, so use `.mjs` for those until TypeScript support is added.

### Barrel Files (index.ts)

Use barrels **only** when files represent grouped functionality that's used together:

```typescript
// GOOD: Related components exported together
// components/forms/index.ts
export { Input } from './input';
export { Select } from './select';
export { Checkbox } from './checkbox';

// BAD: Barrel just for convenience
// utils/index.ts - don't do this, import directly
```

## Security

See [security.md](security.md) for comprehensive security patterns.

**Key principles**:

- Validate at system boundaries (API endpoints, form submissions)
- Additional validation on critical paths (auth, payments, PII)
- Trust validated data internally
- Allowlists over blocklists
- Fail-closed for security decisions

**Secrets hygiene** (multi-layer defense):

1. Pre-commit hooks (gitleaks) block secrets in commits
2. CI scanning catches anything that slips through
3. Runtime log redaction prevents secrets in logs/errors
4. Never hardcode secrets - always from environment/vault

## Testing Strategy

Follow the **Testing Trophy** approach:

```
        /\
       /E2E\        ← Few: Critical user journeys
      /------\
     /Integra-\     ← Many: API routes, component interactions
    /---tion---\
   /------------\
  /    Unit      \  ← Some: Pure functions, complex logic
 /________________\
```

- **Integration tests** are the foundation
- **Unit tests** for pure functions and complex business logic only
- **E2E tests** for critical flows (checkout, auth)
- Coverage targets are vanity metrics - don't enforce thresholds

## Code Review

**Role-based review** for specialized domains:

| Change Type     | Required Reviewer     |
| --------------- | --------------------- |
| Auth/security   | Security team member  |
| Infrastructure  | Platform team member  |
| Database schema | DBA or senior backend |
| Business logic  | Domain expert         |
| UI/UX           | Design system owner   |

Automate everything possible (lint, types, tests, coverage). Human review focuses on architecture, naming, and business correctness.

## Handling Deviations

### ESLint Conflicts

See [eslint-guide.md](eslint-guide.md) for rule-by-rule guidance.

**Context-aware overrides** in ESLint config preferred over inline disables:

```javascript
// eslint.config.js
export default [
  baseConfig,
  {
    files: ['**/*.test.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off', // Test mocks need flexibility
    },
  },
];
```

### Adding New Dependencies

1. Check blessed list in [blessed-stack.md](blessed-stack.md)
2. If on blessed list: proceed
3. If not: complete evaluation matrix + ADR

**Evaluation Matrix**:

- [ ] Bundle size impact (< X KB threshold)
- [ ] Weekly downloads (> 10k, actively maintained)
- [ ] Last update (within 6 months)
- [ ] License compatibility (MIT, Apache, BSD)
- [ ] Security advisories (none critical/high)
- [ ] TypeScript support (native or @types)

### Hotfix Process

During incidents, reduced requirements apply:

1. Create `hotfix/` branch from production tag
2. Minimal change addressing the issue
3. Fast-track review (single senior approval)
4. Deploy with monitoring
5. **Within 48 hours**: Create ticket to add tests and full review
6. Document in incident postmortem

## Monorepo Setup

See [monorepo-setup.md](monorepo-setup.md) for complete setup guide.

**Structure**:

```
├── apps/
│   ├── api-gateway/          # Long-running services: api-*
│   ├── web-docs/             # Web applications: web-*
│   └── cli-tools/            # CLI applications: cli-*
├── packages/
│   ├── shared-types/         # Zod schemas (source of truth)
│   ├── eslint-config/        # Shared ESLint config
│   └── ui/                   # Shared UI components
├── .devcontainer/            # Dev container config
└── turbo.json                # Turbo orchestration
```

**Key rules**:

- Strict DAG: packages can only depend on packages lower in the graph
- No circular dependencies (validated in CI)
- Workspace protocol for internal dependencies
- Independent versioning with Changesets

## Patterns Reference

See [patterns.md](patterns.md) for detailed code examples covering:

- Component patterns (CVA variants, composition)
- Form handling with TanStack Form
- GraphQL queries and mutations
- Drizzle ORM patterns
- Server function patterns
- Observability setup

## Build & Performance

### Aggressive Optimization

- Maximum tree-shaking enabled
- Route-based code splitting
- Bundle size budgets tracked in dashboard
- Lighthouse CI on every PR (alert, don't block)
- Images: Sharp build-time + CDN (WebP, AVIF, srcset)

### Observability Stack

- Structured JSON logging
- OpenTelemetry tracing
- Correlation IDs on all requests
- Sentry for error tracking
- Metrics dashboards (track everything, alert on regression)

## CI/CD & GitHub Actions

### Workflow Structure

**CRITICAL**: YAML structure matters. Always place `on:` triggers near the top after `name:`.

```yaml
# .github/workflows/ci.yml
# =============================================================================
# [PROJECT] CI Pipeline
# =============================================================================
# Purpose: Run quality checks on every push and PR
# Triggers: push to main, pull requests
# Jobs: lint, type-check, test, build (gated on quality checks)
# =============================================================================

name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### Required Optimizations

| Optimization            | Implementation                       | Impact              |
| ----------------------- | ------------------------------------ | ------------------- |
| **Dependency Caching**  | `actions/cache` for Bun/node_modules | ~30s → ~2s installs |
| **Turbo Caching**       | Cache `.turbo` directory             | Incremental builds  |
| **Concurrency Control** | `cancel-in-progress: true`           | Save CI minutes     |
| **Job Gating**          | Build `needs: [lint, test]`          | Fail fast           |
| **Parallel Jobs**       | Independent jobs run simultaneously  | Faster pipelines    |

### Action Version Policy

**REQUIRED**: Pin to major versions, keep updated via Renovate/Dependabot.

```yaml
# CORRECT: Major version pins
- uses: actions/checkout@v4
- uses: oven-sh/setup-bun@v2
- uses: actions/cache@v4

# INCORRECT: SHA pins without automation, outdated versions
- uses: actions/checkout@abcdef123 # Hard to track
- uses: actions/checkout@v3 # Outdated
```

### Caching Pattern

```yaml
- name: Cache Bun dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.bun/install/cache
      node_modules
      **/node_modules
    key: bun-${{ runner.os }}-${{ hashFiles('**/bun.lockb') }}
    restore-keys: |
      bun-${{ runner.os }}-

- name: Cache Turbo
  uses: actions/cache@v4
  with:
    path: .turbo
    key: turbo-${{ runner.os }}-${{ github.sha }}
    restore-keys: |
      turbo-${{ runner.os }}-
```

### Documentation Standard

Every workflow file MUST include a header comment block explaining:

- Purpose of the workflow
- Trigger conditions
- Job structure and dependencies
- Any special requirements or notes

## Quick Reference

| Topic       | Standard                                                  |
| ----------- | --------------------------------------------------------- |
| Types       | Maximum explicitness, strict mode                         |
| Docs        | Full TSDoc, update when behavior changes                  |
| Imports     | Grouped order, absolute (@/) preferred                    |
| Errors      | Result for logic, try-catch for I/O, boundaries for React |
| Performance | Profile first, trust React Compiler                       |
| State       | Query for server, useState for UI                         |
| Testing     | Integration-focused trophy                                |
| Security    | Boundary validation, multi-layer secrets defense          |
| Review      | Role-based, automate the automatable                      |
| Deps        | Blessed list + evaluation matrix                          |
| CI/CD       | Cached, gated, documented, version-pinned                 |

## Sub-Documents

- [tanstack-start.md](tanstack-start.md) - TanStack Start production patterns and best practices
- [eslint-guide.md](eslint-guide.md) - Rule-by-rule ESLint playbook
- [monorepo-setup.md](monorepo-setup.md) - Monorepo structure and tooling
- [blessed-stack.md](blessed-stack.md) - Complete technology tier list
- [patterns.md](patterns.md) - Code examples and patterns
- [security.md](security.md) - Security patterns and checklists