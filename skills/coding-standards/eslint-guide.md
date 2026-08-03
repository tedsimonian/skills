# ESLint Guide: Rule-by-Rule Playbook

This guide provides specific solutions for ESLint rules that cannot be auto-fixed. Rules are organized by frequency of occurrence - the most commonly triggered rules appear first.

## Configuration Strategy

**Context-aware overrides** are preferred over inline disables. Configure exceptions in `eslint.config.js`:

```javascript
// eslint.config.js
import baseConfig from '@repo/eslint-config';

export default [
  ...baseConfig,
  // Test files have relaxed rules
  {
    files: ['**/*.test.ts', '**/*.test.tsx', '**/*.spec.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
    },
  },
  // Generated files are ignored
  {
    ignores: ['**/route-tree.gen.ts', '**/*.generated.ts'],
  },
  // Storybook stories have different patterns
  {
    files: ['**/*.stories.tsx'],
    rules: {
      'import/no-default-export': 'off',
    },
  },
];
```

## Commonly Triggered Rules

### `@typescript-eslint/no-explicit-any`

**Why it exists**: `any` defeats TypeScript's type checking, hiding bugs that would otherwise be caught at compile time.

**How to fix**:

```typescript
// BEFORE: any hides the actual type
function processData(data: any): any {
  return data.items.map((item: any) => item.name);
}

// AFTER: Define the actual types
interface DataPayload {
  items: Array<{ name: string; id: number }>;
}

function processData(data: DataPayload): string[] {
  return data.items.map((item) => item.name);
}
```

**When unknown is appropriate**:

```typescript
// Unknown API response - validate before use
async function fetchExternal(url: string): Promise<unknown> {
  const response = await fetch(url);
  return response.json();
}

// Then validate with Zod
const UserSchema = z.object({ name: z.string(), email: z.string().email() });
const user = UserSchema.parse(await fetchExternal('/api/user'));
```

**Legitimate exceptions**:

- Test mocks where type doesn't matter
- Type assertion utilities (configure via eslint.config.js override)

---

### `@typescript-eslint/explicit-function-return-type`

**Why it exists**: Explicit return types document intent, catch accidental returns, and improve IDE performance.

**How to fix**:

```typescript
// BEFORE: Inferred return type
function calculateTotal(items) {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// AFTER: Explicit return type
function calculateTotal(items: CartItem[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}
```

**For React components**:

```typescript
// Explicit React.ReactNode for components
function UserCard({ user }: UserCardProps): React.ReactNode {
  return <div>{user.name}</div>;
}

// For hooks, return the tuple type
function useCounter(initial: number): [number, () => void, () => void] {
  const [count, setCount] = useState(initial);
  return [count, () => setCount((c) => c + 1), () => setCount((c) => c - 1)];
}
```

---

### `@typescript-eslint/no-unused-vars`

**Why it exists**: Unused variables are dead code that confuses readers and may indicate bugs.

**How to fix**:

```typescript
// BEFORE: Unused parameter
function handleEvent(event: MouseEvent, context: AppContext) {
  console.log('clicked');
}

// OPTION 1: Prefix with underscore if intentionally unused
function handleEvent(_event: MouseEvent, context: AppContext) {
  context.track('click');
}

// OPTION 2: Use destructuring to extract what you need
function handleEvent({ target }: MouseEvent, context: AppContext) {
  context.track('click', target);
}

// OPTION 3: Remove if truly unnecessary
function handleEvent(context: AppContext) {
  context.track('click');
}
```

**For React - unused props in spread**:

```typescript
// BEFORE: className unused but in props
function Button({ onClick, className, ...rest }: ButtonProps) {
  return <button onClick={onClick} {...rest} />;
}

// AFTER: Include className in the spread destination
function Button({ onClick, ...rest }: ButtonProps) {
  return <button onClick={onClick} {...rest} />;
}

// OR: Use it
function Button({ onClick, className, ...rest }: ButtonProps) {
  return <button onClick={onClick} className={className} {...rest} />;
}
```

---

### `@typescript-eslint/no-non-null-assertion`

**Why it exists**: `!` bypasses null checks, risking runtime errors when the value actually is null.

**How to fix**:

```typescript
// BEFORE: Assuming array always has elements
const first = items[0]!;

// AFTER: Handle the undefined case
const first = items[0];
if (!first) {
  throw new Error('Expected at least one item');
}

// OR: Provide a default
const first = items[0] ?? defaultItem;

// OR: Use type guard
function hasItems<T>(arr: T[]): arr is [T, ...T[]] {
  return arr.length > 0;
}

if (hasItems(items)) {
  const first = items[0]; // TypeScript knows this exists
}
```

**For DOM elements**:

```typescript
// BEFORE: Assuming element exists
const button = document.getElementById('submit')!;

// AFTER: Type guard with error
const button = document.getElementById('submit');
if (!button) {
  throw new Error('Submit button not found - check HTML');
}
```

---

### `react/no-unescaped-entities`

**Why it exists**: Unescaped `'`, `"`, `<`, `>` in JSX can cause parsing issues or XSS vulnerabilities.

**How to fix**:

```tsx
// BEFORE: Unescaped apostrophe
<p>Don't click here</p>

// AFTER Option 1: Use HTML entity
<p>Don&apos;t click here</p>

// AFTER Option 2: Use curly braces
<p>{"Don't click here"}</p>

// AFTER Option 3: Use template literal
<p>{`Don't click here`}</p>
```

**For quotes**:

```tsx
// BEFORE
<p>Click "here" to continue</p>

// AFTER
<p>Click &quot;here&quot; to continue</p>
// OR
<p>{`Click "here" to continue`}</p>
```

---

### `react-hooks/exhaustive-deps`

**Why it exists**: Missing dependencies cause stale closures, leading to bugs where effects use outdated values.

**How to fix**:

```typescript
// BEFORE: Missing dependency
useEffect(() => {
  fetchUser(userId);
}, []); // userId missing

// AFTER: Include all dependencies
useEffect(() => {
  fetchUser(userId);
}, [userId]);
```

**For callbacks you don't want to trigger re-runs**:

```typescript
// If onSuccess shouldn't trigger re-run, wrap component in memo
// or use useEffectEvent (React 19):
const onFetch = useEffectEvent(() => {
  onSuccess(data);
});

useEffect(() => {
  fetchData().then(onFetch);
}, [fetchData]);
```

**For object/array dependencies**:

```typescript
// BEFORE: Object reference changes every render
useEffect(() => {
  doSomething(options);
}, [options]); // Will re-run every render!

// AFTER: Destructure stable values
const { timeout, retries } = options;
useEffect(() => {
  doSomething({ timeout, retries });
}, [timeout, retries]);
```

---

### `import/no-default-export`

**Why it exists**: Named exports improve refactoring (rename works across files) and prevent import name inconsistency.

**How to fix**:

```typescript
// BEFORE: Default export
export default function Button() { ... }
// Imported as: import Btn from './button' (inconsistent naming)

// AFTER: Named export
export function Button() { ... }
// Imported as: import { Button } from './button' (consistent)
```

**Exceptions configured per-directory**:

- Route or page files, when the framework requires a default export
- Storybook stories
- Config files (vite.config.ts, etc.)

---

### `@typescript-eslint/consistent-type-imports`

**Why it exists**: Type-only imports are erased at runtime, reducing bundle size and avoiding circular dependency issues.

**How to fix**:

```typescript
// BEFORE: Mixed import
import { User, fetchUser } from './user';

// AFTER: Separate type imports
import type { User } from './user';
import { fetchUser } from './user';

// OR: Inline type modifier
import { type User, fetchUser } from './user';
```

---

### `@typescript-eslint/naming-convention`

**Why it exists**: Consistent naming makes code predictable and searchable.

**Standard conventions**:

```typescript
// Interfaces: PascalCase, may have I prefix (check config)
interface UserProfile { ... }

// Types: PascalCase
type ValidationResult = { ... }

// Enums: PascalCase with PascalCase members
enum HttpStatus {
  Ok = 200,
  NotFound = 404,
}

// Variables: camelCase
const userProfile = { ... };

// Constants (true compile-time constants): UPPER_SNAKE_CASE
const MAX_RETRY_COUNT = 3;

// Functions: camelCase
function getUserProfile() { ... }

// React Components: PascalCase
function UserProfile() { ... }

// Boolean variables: is/has/should prefix
const isLoading = true;
const hasPermission = false;
```

---

### `no-console`

**Why it exists**: Console statements are for debugging and shouldn't ship to production.

**How to fix**:

```typescript
// BEFORE: Console for logging
console.log('User logged in', userId);

// AFTER: Use structured logger
logger.info('User logged in', { userId, timestamp: Date.now() });
```

**For development debugging**:

```typescript
// Use environment check
if (import.meta.env.DEV) {
  console.log('Debug:', value);
}

// Or configure logger with debug level
logger.debug('Debug:', { value }); // Only logs in development
```

---

### `@typescript-eslint/no-floating-promises`

**Why it exists**: Unhandled promises silently swallow errors, making bugs invisible.

**How to fix**:

```typescript
// BEFORE: Promise result ignored
fetchData();

// AFTER Option 1: Await it
await fetchData();

// AFTER Option 2: Handle with .catch
fetchData().catch((error) => {
  logger.error('Fetch failed', { error });
});

// AFTER Option 3: Explicitly void (for fire-and-forget)
void fetchData(); // "I know this is async and don't need the result"
```

---

### `prefer-const`

**Why it exists**: Using `const` signals the binding won't change, making code easier to reason about.

**How to fix**:

```typescript
// BEFORE: let but never reassigned
let user = await fetchUser(id);
return user.name;

// AFTER: const
const user = await fetchUser(id);
return user.name;
```

**When let is correct**:

```typescript
// Reassignment happens - let is correct
let retries = 3;
while (retries > 0) {
  try {
    return await fetch(url);
  } catch {
    retries--;
  }
}
```

---

## TypeScript Strict Mode Rules

### `strictNullChecks` errors

**Error**: `Object is possibly 'undefined'`

```typescript
// BEFORE: Assuming property exists
function getLength(arr?: string[]): number {
  return arr.length; // Error: arr might be undefined
}

// AFTER: Guard against undefined
function getLength(arr?: string[]): number {
  return arr?.length ?? 0;
}

// OR: Early return
function getLength(arr?: string[]): number {
  if (!arr) return 0;
  return arr.length;
}
```

### `noUncheckedIndexedAccess` errors

**Error**: `Element implicitly has 'undefined' type`

```typescript
// BEFORE: Assuming index exists
const items = ['a', 'b', 'c'];
const first: string = items[0]; // Error: might be undefined

// AFTER: Handle undefined
const first = items[0];
if (first === undefined) {
  throw new Error('Expected at least one item');
}
// Now first is string, not string | undefined
```

---

## Accessibility Rules

### `jsx-a11y/anchor-is-valid`

**Why it exists**: Links without proper href don't work with keyboard navigation or screen readers.

**How to fix**:

```tsx
// BEFORE: Button behavior with anchor
<a onClick={handleClick}>Click me</a>

// AFTER Option 1: Use button for actions
<button type="button" onClick={handleClick}>Click me</button>

// AFTER Option 2: Real link with href
<a href="/destination" onClick={handleClick}>Click me</a>

// AFTER Option 3: If you must use anchor, add role and keyboard handling
<a
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => e.key === 'Enter' && handleClick()}
>
  Click me
</a>
```

### `jsx-a11y/click-events-have-key-events`

**Why it exists**: Keyboard users can't trigger click-only handlers.

**How to fix**:

```tsx
// BEFORE: Click only
<div onClick={handleClick}>Clickable area</div>

// AFTER: Add keyboard handler
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      handleClick();
    }
  }}
>
  Clickable area
</div>

// BETTER: Just use a button
<button type="button" onClick={handleClick}>
  Clickable area
</button>
```

---

## Complexity Rules

### `complexity` (cyclomatic complexity)

**Why it exists**: High complexity functions are hard to test and maintain.

**How to fix**:

```typescript
// BEFORE: High complexity with many branches
function processOrder(order: Order): Result {
  if (order.type === 'digital') {
    if (order.quantity > 100) {
      if (order.customer.isPremium) {
        // ...20 more nested branches
      }
    }
  }
}

// AFTER: Extract to smaller functions
function processOrder(order: Order): Result {
  const processor = getProcessorForType(order.type);
  const discount = calculateDiscount(order);
  return processor.process(order, discount);
}

function getProcessorForType(type: OrderType): OrderProcessor {
  const processors: Record<OrderType, OrderProcessor> = {
    digital: new DigitalOrderProcessor(),
    physical: new PhysicalOrderProcessor(),
  };
  return processors[type];
}
```

---

## When to Request Config Changes

If you consistently need to disable a rule across a category of files, propose a config update instead of inline disables:

1. **Identify the pattern**: "This rule triggers in all test utility files"
2. **Propose override**: Add to eslint.config.js with file glob
3. **Document rationale**: Why does this category need different rules?
4. **Review as team**: Config changes affect everyone

**Template for proposing changes**:

```markdown
## ESLint Config Change Request

**Rule**: `@typescript-eslint/no-explicit-any`
**Proposed override**: Disable in `**/*.test-utils.ts`
**Rationale**: Test utilities intentionally use `any` for mocking flexibility
**Impact**: ~15 files currently using inline disable
**Alternative considered**: Using `unknown` + type guards (too verbose for test utilities)
```