# Quick Reference

Fast lookup table for coding standards decisions.

## Standards at a Glance

| Topic       | Standard                                                  |
| ----------- | --------------------------------------------------------- |
| Types       | Maximum explicitness, strict mode                         |
| Docs        | Full TSDoc, update when behavior changes                  |
| Imports     | Grouped order, absolute (@/) preferred, .js extensions    |
| Errors      | Result for logic, try-catch for I/O, boundaries for React |
| Performance | Profile first, trust React Compiler                       |
| State       | Query for server, useState for UI                         |
| Testing     | Integration-focused trophy                                |
| Security    | Boundary validation, multi-layer secrets defense          |
| Review      | Role-based, automate the automatable                      |
| Deps        | Blessed list + evaluation matrix                          |

## Import Order

```typescript
// 1. Built-in / Node modules
import { readFile } from 'node:fs/promises';

// 2. External packages
import { z } from 'zod';

// 3. Internal aliases (@/)
import { Button } from '@/components/ui/button.js';

// 4. Relative imports
import { validateInput } from './validation.js';
```

## File Naming

| Type | Convention | Example |
|------|------------|---------|
| Files/folders | kebab-case | `user-profile.tsx` |
| Components | PascalCase | `UserProfile` |
| Functions/hooks | camelCase | `useAuth`, `formatDate` |
| Constants | UPPER_SNAKE | `MAX_RETRIES` |
| Boolean vars | is/has/should | `isLoading`, `hasPermission` |

## Configuration Files

```bash
# Use .ts or .mjs extensions
eslint.config.ts          # or .mjs
prettier.config.ts        # or .mjs
vitest.config.ts
vite.config.ts

# Use .mjs for tools without .ts support
lint-staged.config.mjs
commitlint.config.mjs
```

## Error Handling Patterns

| Error Type              | Pattern             | Example                    |
| ----------------------- | ------------------- | -------------------------- |
| Business logic failures | Result/Either types | Validation, business rules |
| I/O operations          | try-catch           | Network, file system       |
| React rendering         | Error boundaries    | Component failures         |

## Testing Trophy

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

## Required ESM Extensions

```typescript
// CORRECT: Use .js extension for TypeScript files
import { formatDate } from './utils.js';
import type { User } from './types.js';

// INCORRECT: Missing extension
import { formatDate } from './utils';
```

## Null Handling

```typescript
// CORRECT: Nullish coalescing preserves falsy values
const count = response.count ?? 0;

// INCORRECT: OR operator treats 0 as falsy
const count = response.count || 0;
```

## React Patterns

```typescript
// Server state: TanStack Query
const { data: user } = useQuery({ queryKey: ['user', id], queryFn });

// UI state: useState
const [isOpen, setIsOpen] = useState(false);

// Cross-cutting: Context
const { theme } = useTheme();
```

## Security Checklist

- [ ] Input validation at all entry points (Zod)
- [ ] No raw SQL or string interpolation
- [ ] Authorization checks on protected resources
- [ ] No hardcoded secrets
- [ ] Rate limiting on auth endpoints
- [ ] CSRF protection for state-changing requests

## Adding Dependencies

1. Check [blessed-stack.md](blessed-stack.md)
2. If blessed: proceed
3. If not: complete evaluation matrix + ADR

**Evaluation Matrix**:
- Bundle size impact < threshold
- Weekly downloads > 10k
- Last update within 6 months
- Compatible license (MIT, Apache, BSD)
- No critical security advisories
- TypeScript support (native or @types)
