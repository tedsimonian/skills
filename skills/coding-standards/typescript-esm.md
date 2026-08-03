# TypeScript ESM Import Extensions

**REQUIRED**: All TypeScript imports of local files MUST include the `.js` extension (not `.ts`). This is non-negotiable for ESM compatibility.

## Correct vs Incorrect

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

## Why This Is Required

1. **ES Modules Specification**: ESM requires explicit file extensions. The JavaScript output from TypeScript compilation will have `.js` extensions, not `.ts`.

2. **Runtime Compatibility**: Node.js ESM resolution requires extensions. Without them, imports fail at runtime with `ERR_MODULE_NOT_FOUND`.

3. **Build-Free Execution**: With `verbatimModuleSyntax`, TypeScript doesn't rewrite import paths. Your `.ts` source must match what will work in the compiled `.js` output.

4. **Library Consumer Compatibility**: If you publish packages, missing extensions break for downstream consumers using ESM.

## What Happens Without Extensions

```bash
Error [ERR_MODULE_NOT_FOUND]: Cannot find module './utils'
  imported from /path/to/compiled/file.js
```

## TypeScript Configuration

```json
{
  "compilerOptions": {
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "verbatimModuleSyntax": true
  }
}
```

The `verbatimModuleSyntax: true` setting prevents TypeScript from silently accepting incorrect import syntax. See the [TypeScript documentation on verbatimModuleSyntax](https://www.typescriptlang.org/tsconfig/verbatimModuleSyntax.html) for details.

## VSCode Auto-Import Configuration

Create or update `.vscode/settings.json`:

```json
{
  "typescript.preferences.importModuleSpecifierEnding": "js",
  "typescript.preferences.importModuleSpecifier": "non-relative",
  "javascript.preferences.importModuleSpecifierEnding": "js"
}
```

This configures VSCode to automatically add `.js` extensions when using auto-import.

## ESLint Enforcement

The `import-x/extensions` rule enforces this requirement:

```javascript
export default [
  {
    rules: {
      'import-x/extensions': [
        'error',
        'ignorePackages',
        { js: 'always', jsx: 'always', ts: 'always', tsx: 'always' }
      ]
    }
  }
];
```

With this rule:
- ESLint auto-fix (`eslint --fix`) will add missing `.js` extensions
- Commits with missing extensions will be caught by pre-commit hooks
- IDE integration will show inline errors for missing extensions

## Exception: External Packages

External package imports (from `node_modules`) should NOT include extensions:

```typescript
// CORRECT: No extension for external packages
import { z } from 'zod';
import React from 'react';

// INCORRECT: Extensions on external packages
import { z } from 'zod.js';
```

The `ignorePackages` option in the ESLint rule handles this automatically.

## Validation Script

Run the import validator to check for missing extensions:

```bash
bun run .claude/skills/coding-standards/scripts/check-imports.ts [path]
```
