# Code Patterns Reference

This document provides copy-paste patterns for common scenarios. Each pattern follows our coding standards.

## Component Patterns

### Standard Component Structure

````typescript
/**
 * Copyright 2024 Company Inc. All rights reserved.
 * SPDX-License-Identifier: UNLICENSED
 */

import type { VariantProps } from 'class-variance-authority';
import { cva } from 'class-variance-authority';
import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

/**
 * Card component for displaying grouped content with optional header and footer.
 *
 * Supports multiple visual variants and can be made interactive with click handlers.
 * Uses compound component pattern for flexible composition.
 *
 * @example
 * ```tsx
 * <Card variant="elevated">
 *   <Card.Header>
 *     <Card.Title>Settings</Card.Title>
 *   </Card.Header>
 *   <Card.Content>
 *     <p>Card content here</p>
 *   </Card.Content>
 * </Card>
 * ```
 */

const cardVariants = cva('rounded-lg border bg-card text-card-foreground', {
  variants: {
    variant: {
      default: 'border-border',
      elevated: 'border-transparent shadow-lg',
      ghost: 'border-transparent bg-transparent',
      interactive: 'border-border cursor-pointer hover:bg-accent transition-colors',
    },
    padding: {
      none: '',
      sm: 'p-4',
      default: 'p-6',
      lg: 'p-8',
    },
  },
  defaultVariants: {
    variant: 'default',
    padding: 'default',
  },
});

export interface CardProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof cardVariants> {
  /** Content to render inside the card */
  children: ReactNode;
  /** Whether the card is in a loading state */
  isLoading?: boolean;
}

/**
 * Root card container component.
 *
 * @param props - Card properties
 * @returns Card element with applied variants
 */
export function Card({
  className,
  variant,
  padding,
  children,
  isLoading = false,
  ...props
}: CardProps): ReactNode {
  return (
    <div
      className={cn(cardVariants({ variant, padding }), isLoading && 'animate-pulse', className)}
      {...props}
    >
      {children}
    </div>
  );
}

Card.displayName = 'Card';

// Compound components
export interface CardHeaderProps extends React.HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
}

function CardHeader({ className, children, ...props }: CardHeaderProps): ReactNode {
  return (
    <div className={cn('flex flex-col space-y-1.5 pb-4', className)} {...props}>
      {children}
    </div>
  );
}

CardHeader.displayName = 'Card.Header';
Card.Header = CardHeader;

function CardTitle({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLHeadingElement> & { children: ReactNode }): ReactNode {
  return (
    <h3 className={cn('text-lg font-semibold leading-none tracking-tight', className)} {...props}>
      {children}
    </h3>
  );
}

CardTitle.displayName = 'Card.Title';
Card.Title = CardTitle;

function CardContent({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement> & { children: ReactNode }): ReactNode {
  return (
    <div className={cn('', className)} {...props}>
      {children}
    </div>
  );
}

CardContent.displayName = 'Card.Content';
Card.Content = CardContent;
````

### Custom Hook Pattern

````typescript
/**
 * Hook for managing clipboard operations with copy feedback.
 *
 * Provides a simple interface for copying text to clipboard with
 * automatic state management for showing copy confirmation.
 *
 * @param options - Configuration options
 * @param options.timeout - Duration in ms to show copied state (default: 2000)
 * @returns Object with copied state and copy function
 *
 * @example
 * ```tsx
 * function ShareButton({ url }: { url: string }) {
 *   const { copied, copy } = useClipboard({ timeout: 3000 });
 *
 *   return (
 *     <button onClick={() => copy(url)}>
 *       {copied ? 'Copied!' : 'Copy Link'}
 *     </button>
 *   );
 * }
 * ```
 */
export interface UseClipboardOptions {
  /** Duration in milliseconds to show copied state */
  timeout?: number;
}

export interface UseClipboardResult {
  /** Whether content was recently copied */
  copied: boolean;
  /** Function to copy text to clipboard */
  copy: (text: string) => Promise<void>;
  /** Function to reset copied state */
  reset: () => void;
}

export function useClipboard(options: UseClipboardOptions = {}): UseClipboardResult {
  const { timeout = 2000 } = options;
  const [copied, setCopied] = useState(false);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const reset = useCallback((): void => {
    setCopied(false);
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }
  }, []);

  const copy = useCallback(
    async (text: string): Promise<void> => {
      try {
        await navigator.clipboard.writeText(text);
        setCopied(true);

        if (timeoutRef.current) {
          clearTimeout(timeoutRef.current);
        }

        timeoutRef.current = setTimeout(() => {
          setCopied(false);
        }, timeout);
      } catch (error) {
        console.error('Failed to copy to clipboard:', error);
        throw error;
      }
    },
    [timeout],
  );

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  return { copied, copy, reset };
}
````

---

## Data Loading Patterns

The mechanism belongs to whichever framework the project uses.
These are the shapes that survive the choice.

### Load, Then Render

Resolve data before the component that needs it renders, and let the component assume the data exists.
A component that branches on `data === undefined` on every line is doing the loading state's job.

```tsx
/**
 * The boundary owns loading and error. The leaf owns rendering.
 */
export function UserScreen({ userId }: { userId: string }): JSX.Element {
  return (
    <ErrorBoundary fallback={<UserError />}>
      <Suspense fallback={<UserSkeleton />}>
        <UserProfile userId={userId} />
      </Suspense>
    </ErrorBoundary>
  );
}

function UserProfile({ userId }: { userId: string }): JSX.Element {
  // The data layer guarantees this resolved. No undefined checks needed.
  const user = useUser(userId);
  return <h1>{user.displayName}</h1>;
}
```

### Parse At The Boundary

Validate the response where it enters the app.
Everything downstream then works with a known shape rather than a hopeful cast.

```typescript
import { z } from 'zod';

const userSchema = z.object({
  id: z.string().uuid(),
  displayName: z.string(),
  email: z.string().email(),
  createdAt: z.coerce.date(),
});

export type User = z.infer<typeof userSchema>;

/**
 * Fetches a user and validates the payload before it reaches the app.
 *
 * @param id - User identifier
 * @returns The parsed user
 * @throws {ZodError} When the response does not match the schema
 */
export async function fetchUser(id: string): Promise<User> {
  const response = await fetch(`/api/users/${id}`);

  if (!response.ok) {
    throw new HttpError(response.status, `Failed to load user ${id}`);
  }

  return userSchema.parse(await response.json());
}
```

**Why**: a bad payload fails once, at the edge, with a precise error.
Without this it fails later, somewhere in the UI, as `undefined is not an object`.

### Invalidate, Do Not Hand-Patch

After a mutation, invalidate the affected cache entries and let the read path re-run.

```typescript
/**
 * Correct: state comes back from the server.
 */
async function onRename(id: string, name: string): Promise<void> {
  await renameUser(id, name);
  await cache.invalidate(['user', id]);
}

/**
 * Incorrect: the client guesses what the server did.
 * Any field the server also touched (updatedAt, slug, audit trail) is now wrong.
 */
async function onRenameBad(id: string, name: string): Promise<void> {
  await renameUser(id, name);
  cache.set(['user', id], (prev) => ({ ...prev, displayName: name }));
}
```

Optimistic updates are the one exception, and they must roll back on failure.

---

## Form Patterns

### Schema-Validated Form

One schema drives the types, the client validation, and the server validation.
Whichever form library the project uses, this is the shape to aim for.

```tsx
/**
 * User settings form with schema validation and server submission.
 */
import { z } from 'zod';

const settingsSchema = z.object({
  displayName: z.string().min(1, 'Display name is required').max(80),
  email: z.string().email('Enter a valid email address'),
  marketingOptIn: z.boolean(),
});

type SettingsValues = z.infer<typeof settingsSchema>;

export function SettingsForm({ initial, onSave }: SettingsFormProps): JSX.Element {
  const [values, setValues] = useState<SettingsValues>(initial);
  const [errors, setErrors] = useState<Partial<Record<keyof SettingsValues, string>>>({});
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();

    const parsed = settingsSchema.safeParse(values);

    if (!parsed.success) {
      setErrors(toFieldErrors(parsed.error));
      return;
    }

    setSubmitting(true);

    try {
      await onSave(parsed.data);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <TextField
        label="Display name"
        value={values.displayName}
        error={errors.displayName}
        onChange={(displayName) => setValues({ ...values, displayName })}
      />
      <button type="submit" disabled={submitting}>
        {submitting ? 'Saving...' : 'Save'}
      </button>
    </form>
  );
}
```

**Rules that hold regardless of library**:

- The schema is the single source of truth.
  Never hand-write a type that duplicates it, derive it with `z.infer`.
- Validate on the server too.
  Client validation is a user-experience feature, not a security boundary.
- Disable submit while in flight, and say so in the label.
  A double-submitted form is a duplicated record.
- Associate every error with its field for screen readers, not just a summary at the top.
- `noValidate` on the form, so your messages win over the browser's.

---


## Error Handling Patterns

### Result Type

```typescript
/**
 * Result type for operations that can fail.
 */
export type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E };

/**
 * Creates a successful result.
 */
export function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

/**
 * Creates a failure result.
 */
export function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

/**
 * Unwraps a result, throwing if it's an error.
 */
export function unwrap<T, E>(result: Result<T, E>): T {
  if (result.ok) {
    return result.value;
  }
  throw result.error;
}

// Usage example
interface ValidationError {
  code: string;
  message: string;
  field?: string;
}

function validateEmail(email: string): Result<string, ValidationError> {
  const trimmed = email.trim().toLowerCase();

  if (!trimmed) {
    return err({ code: 'REQUIRED', message: 'Email is required', field: 'email' });
  }

  if (!trimmed.includes('@')) {
    return err({ code: 'INVALID_FORMAT', message: 'Invalid email format', field: 'email' });
  }

  return ok(trimmed);
}

// In component
const result = validateEmail(input);
if (!result.ok) {
  setError(result.error.message);
  return;
}
const email = result.value; // Type-safe string
```

---

## Observability Patterns

### Structured Logger Setup

```typescript
/**
 * Application logger with structured output.
 */
import pino from 'pino';

const isProduction = process.env.NODE_ENV === 'production';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? (isProduction ? 'info' : 'debug'),
  formatters: {
    level: (label) => ({ level: label }),
  },
  // Redact sensitive fields
  redact: {
    paths: ['password', 'token', 'apiKey', 'authorization', '*.password', '*.token'],
    censor: '[REDACTED]',
  },
  // Pretty print in development
  transport: isProduction
    ? undefined
    : {
        target: 'pino-pretty',
        options: {
          colorize: true,
        },
      },
});

/**
 * Creates a child logger with request context.
 *
 * @param requestId - Request correlation ID
 * @returns Logger with bound context
 */
export function createRequestLogger(requestId: string) {
  return logger.child({ requestId });
}
```

### Request Tracing Middleware

```typescript
/**
 * Middleware for request tracing and logging.
 */
import { trace, context, SpanStatusCode } from '@opentelemetry/api';

import { createRequestLogger } from '@/lib/logger';

/**
 * Creates tracing middleware for HTTP requests.
 */
export function tracingMiddleware() {
  const tracer = trace.getTracer('http-server');

  return async (req: Request, next: () => Promise<Response>): Promise<Response> => {
    const requestId = req.headers.get('x-request-id') ?? crypto.randomUUID();
    const logger = createRequestLogger(requestId);

    return tracer.startActiveSpan(`${req.method} ${new URL(req.url).pathname}`, async (span) => {
      const startTime = performance.now();

      try {
        span.setAttributes({
          'http.method': req.method,
          'http.url': req.url,
          'http.request_id': requestId,
        });

        const response = await next();

        span.setAttributes({
          'http.status_code': response.status,
        });

        logger.info(
          {
            method: req.method,
            url: req.url,
            status: response.status,
            duration: Math.round(performance.now() - startTime),
          },
          'Request completed',
        );

        return response;
      } catch (error) {
        span.setStatus({ code: SpanStatusCode.ERROR });
        span.recordException(error as Error);

        logger.error(
          {
            method: req.method,
            url: req.url,
            error,
            duration: Math.round(performance.now() - startTime),
          },
          'Request failed',
        );

        throw error;
      } finally {
        span.end();
      }
    });
  };
}
```

---

## Testing Patterns

### Component Integration Test

```typescript
/**
 * Integration tests for UserProfile component.
 */
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';

import { UserProfile } from './user-profile';
import { renderWithProviders } from '@/test/utils';

const server = setupServer();

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('UserProfile', () => {
  describe('when user data loads successfully', () => {
    it('displays user information', async () => {
      server.use(
        http.get('/api/users/:id', () => {
          return HttpResponse.json({
            id: '123',
            name: 'John Doe',
            email: 'john@example.com',
          });
        })
      );

      renderWithProviders(<UserProfile userId="123" />);

      expect(await screen.findByText('John Doe')).toBeInTheDocument();
      expect(screen.getByText('john@example.com')).toBeInTheDocument();
    });
  });

  describe('when user clicks edit', () => {
    it('shows edit form with current values', async () => {
      const user = userEvent.setup();

      server.use(
        http.get('/api/users/:id', () => {
          return HttpResponse.json({
            id: '123',
            name: 'John Doe',
            email: 'john@example.com',
          });
        })
      );

      renderWithProviders(<UserProfile userId="123" />);

      await user.click(await screen.findByRole('button', { name: /edit/i }));

      expect(screen.getByLabelText('Name')).toHaveValue('John Doe');
      expect(screen.getByLabelText('Email')).toHaveValue('john@example.com');
    });
  });

  describe('when API returns error', () => {
    it('displays error message', async () => {
      server.use(
        http.get('/api/users/:id', () => {
          return HttpResponse.json({ message: 'User not found' }, { status: 404 });
        })
      );

      renderWithProviders(<UserProfile userId="nonexistent" />);

      expect(await screen.findByRole('alert')).toHaveTextContent(/error/i);
    });
  });
});
```

### Service Unit Test

Depend on an interface, not on the database client.
The unit test then needs no mocking framework knowledge of your ORM, and the service stays portable.

```typescript
/**
 * Unit tests for the user service.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { createUserService } from './user-service.js';
import type { UserRepository } from './user-repository.js';

function createRepositoryStub(): UserRepository {
  return {
    findById: vi.fn(),
    update: vi.fn(),
  };
}

describe('userService.getUser', () => {
  let repository: UserRepository;
  let service: ReturnType<typeof createUserService>;

  beforeEach(() => {
    repository = createRepositoryStub();
    service = createUserService({ repository });
  });

  it('returns the user when one exists', async () => {
    const user = { id: '123', email: 'test@example.com', displayName: 'Test' };
    vi.mocked(repository.findById).mockResolvedValue(user);

    await expect(service.getUser('123')).resolves.toEqual(user);
    expect(repository.findById).toHaveBeenCalledWith('123');
  });

  it('returns null when no user exists', async () => {
    vi.mocked(repository.findById).mockResolvedValue(null);

    await expect(service.getUser('123')).resolves.toBeNull();
  });

  it('rejects an identifier that is not a UUID', async () => {
    await expect(service.getUser('not-a-uuid')).rejects.toThrow();
    expect(repository.findById).not.toHaveBeenCalled();
  });
});
```

**Why this shape**: the assertions describe behavior the service promises, not the SQL it happens to emit.
Swapping the ORM leaves these tests untouched.
See [service-layer.md](service-layer.md) for how the boundary is drawn.
