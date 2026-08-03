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

## TanStack Start Patterns

> **For comprehensive TanStack Start patterns**, see [tanstack-start.md](tanstack-start.md) which covers production-ready patterns including:
>
> - Project structure and organization
> - Server functions with context patterns
> - Data fetching and caching strategies
> - Forms and mutations
> - Authentication and security
> - Performance optimization
> - Testing and deployment
>
> The examples below provide quick reference patterns.

### Route with Loader

```typescript
/**
 * User profile route with data loading and error handling.
 */
import { createFileRoute, notFound } from '@tanstack/react-router';

import { getUser } from '@/server/users';
import { UserProfile } from '@/components/user-profile';

export const Route = createFileRoute('/users/$userId')({
  // Loader runs on server, data is serialized to client
  loader: async ({ params }) => {
    const user = await getUser(params.userId);
    if (!user) {
      throw notFound();
    }
    return { user };
  },

  // Component receives typed loader data
  component: UserProfileRoute,

  // Error boundary for this route
  errorComponent: ({ error }) => (
    <div role="alert">
      <h2>Error loading user</h2>
      <pre>{error.message}</pre>
    </div>
  ),

  // Not found handling
  notFoundComponent: () => (
    <div>
      <h2>User not found</h2>
      <p>The requested user does not exist.</p>
    </div>
  ),
});

function UserProfileRoute(): ReactNode {
  const { user } = Route.useLoaderData();
  return <UserProfile user={user} />;
}
```

### Server Function

```typescript
/**
 * Server function for user operations.
 *
 * Runs on the server, callable from client with full type safety.
 */
import { createServerFn } from '@tanstack/start';
import { z } from 'zod';

import { db } from '@/db';
import { users } from '@/db/schema';
import { eq } from 'drizzle-orm';

const GetUserSchema = z.object({
  userId: z.string().uuid(),
});

/**
 * Fetches a user by ID from the database.
 *
 * @param input - Object containing userId
 * @returns User object or null if not found
 * @throws {Error} When database query fails
 */
export const getUser = createServerFn('GET', async (input: z.infer<typeof GetUserSchema>) => {
  const validated = GetUserSchema.parse(input);

  const user = await db.query.users.findFirst({
    where: eq(users.id, validated.userId),
    columns: {
      id: true,
      email: true,
      name: true,
      createdAt: true,
    },
  });

  return user ?? null;
});

const UpdateUserSchema = z.object({
  userId: z.string().uuid(),
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

/**
 * Updates user profile information.
 *
 * @param input - User update data
 * @returns Updated user object
 * @throws {Error} When user not found or validation fails
 */
export const updateUser = createServerFn('POST', async (input: z.infer<typeof UpdateUserSchema>) => {
  const validated = UpdateUserSchema.parse(input);

  const [updated] = await db
    .update(users)
    .set({
      name: validated.name,
      email: validated.email,
      updatedAt: new Date(),
    })
    .where(eq(users.id, validated.userId))
    .returning();

  if (!updated) {
    throw new Error('User not found');
  }

  return updated;
});
```

### TanStack Query with Server Function

```typescript
/**
 * Hook for user data with server function integration.
 */
import { useSuspenseQuery, useMutation, useQueryClient } from '@tanstack/react-query';

import { getUser, updateUser } from '@/server/users';

/**
 * Query options factory for user queries.
 *
 * @param userId - User identifier
 * @returns Query options object
 */
export function userQueryOptions(userId: string) {
  return {
    queryKey: ['user', userId] as const,
    queryFn: () => getUser({ userId }),
    staleTime: 5 * 60 * 1000, // 5 minutes
  };
}

/**
 * Hook to fetch user data with suspense.
 *
 * @param userId - User identifier
 * @returns User data (never null due to suspense)
 */
export function useUser(userId: string) {
  return useSuspenseQuery(userQueryOptions(userId));
}

/**
 * Hook for updating user with optimistic updates.
 *
 * @returns Mutation object with mutate function
 */
export function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: updateUser,
    onMutate: async (newData) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['user', newData.userId] });

      // Snapshot previous value
      const previousUser = queryClient.getQueryData(['user', newData.userId]);

      // Optimistically update
      queryClient.setQueryData(['user', newData.userId], (old: User | undefined) =>
        old ? { ...old, ...newData } : old,
      );

      return { previousUser };
    },
    onError: (_err, newData, context) => {
      // Rollback on error
      if (context?.previousUser) {
        queryClient.setQueryData(['user', newData.userId], context.previousUser);
      }
    },
    onSettled: (_data, _error, variables) => {
      // Refetch after mutation
      queryClient.invalidateQueries({ queryKey: ['user', variables.userId] });
    },
  });
}
```

---

## Form Patterns

### TanStack Form with Zod

```typescript
/**
 * User settings form with validation and server submission.
 */
import { useForm } from '@tanstack/react-form';
import { zodValidator } from '@tanstack/zod-form-adapter';
import { z } from 'zod';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useUpdateUser } from '@/hooks/use-user';

const UserSettingsSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100, 'Name too long'),
  email: z.string().email('Invalid email address'),
  bio: z.string().max(500, 'Bio must be under 500 characters').optional(),
});

type UserSettingsData = z.infer<typeof UserSettingsSchema>;

export interface UserSettingsFormProps {
  /** Current user data for initial values */
  user: { id: string; name: string; email: string; bio?: string };
  /** Callback on successful save */
  onSuccess?: () => void;
}

/**
 * Form for editing user settings.
 *
 * @param props - Form properties
 * @returns Form component
 */
export function UserSettingsForm({ user, onSuccess }: UserSettingsFormProps): ReactNode {
  const updateUser = useUpdateUser();

  const form = useForm({
    defaultValues: {
      name: user.name,
      email: user.email,
      bio: user.bio ?? '',
    } satisfies UserSettingsData,
    onSubmit: async ({ value }) => {
      await updateUser.mutateAsync({
        userId: user.id,
        ...value,
      });
      onSuccess?.();
    },
    validatorAdapter: zodValidator(),
    validators: {
      onChange: UserSettingsSchema,
    },
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        e.stopPropagation();
        form.handleSubmit();
      }}
      className="space-y-4"
    >
      <form.Field name="name">
        {(field) => (
          <div>
            <label htmlFor={field.name} className="block text-sm font-medium">
              Name
            </label>
            <Input
              id={field.name}
              value={field.state.value}
              onBlur={field.handleBlur}
              onChange={(e) => field.handleChange(e.target.value)}
              aria-invalid={field.state.meta.errors.length > 0}
            />
            {field.state.meta.errors.map((error) => (
              <p key={error} className="text-sm text-red-500 mt-1">
                {error}
              </p>
            ))}
          </div>
        )}
      </form.Field>

      <form.Field name="email">
        {(field) => (
          <div>
            <label htmlFor={field.name} className="block text-sm font-medium">
              Email
            </label>
            <Input
              id={field.name}
              type="email"
              value={field.state.value}
              onBlur={field.handleBlur}
              onChange={(e) => field.handleChange(e.target.value)}
              aria-invalid={field.state.meta.errors.length > 0}
            />
            {field.state.meta.errors.map((error) => (
              <p key={error} className="text-sm text-red-500 mt-1">
                {error}
              </p>
            ))}
          </div>
        )}
      </form.Field>

      <form.Field name="bio">
        {(field) => (
          <div>
            <label htmlFor={field.name} className="block text-sm font-medium">
              Bio
            </label>
            <textarea
              id={field.name}
              value={field.state.value}
              onBlur={field.handleBlur}
              onChange={(e) => field.handleChange(e.target.value)}
              className="w-full rounded-md border px-3 py-2"
              rows={3}
            />
            <p className="text-sm text-muted-foreground mt-1">
              {field.state.value.length}/500 characters
            </p>
          </div>
        )}
      </form.Field>

      <form.Subscribe selector={(state) => [state.canSubmit, state.isSubmitting]}>
        {([canSubmit, isSubmitting]) => (
          <Button type="submit" disabled={!canSubmit || isSubmitting}>
            {isSubmitting ? 'Saving...' : 'Save Changes'}
          </Button>
        )}
      </form.Subscribe>
    </form>
  );
}
```

---

## Drizzle ORM Patterns

### Schema Definition

```typescript
/**
 * Database schema for user and related tables.
 */
import { relations } from 'drizzle-orm';
import { index, pgTable, serial, text, timestamp, uuid, varchar } from 'drizzle-orm/pg-core';

export const users = pgTable(
  'users',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    email: varchar('email', { length: 255 }).notNull().unique(),
    name: varchar('name', { length: 100 }).notNull(),
    avatarUrl: text('avatar_url'),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    emailIdx: index('users_email_idx').on(table.email),
    createdAtIdx: index('users_created_at_idx').on(table.createdAt),
  }),
);

export const posts = pgTable(
  'posts',
  {
    id: serial('id').primaryKey(),
    title: varchar('title', { length: 255 }).notNull(),
    content: text('content').notNull(),
    authorId: uuid('author_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    publishedAt: timestamp('published_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    authorIdx: index('posts_author_idx').on(table.authorId),
    publishedIdx: index('posts_published_idx').on(table.publishedAt),
  }),
);

// Relations for query builder
export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, {
    fields: [posts.authorId],
    references: [users.id],
  }),
}));
```

### Query Patterns

```typescript
/**
 * Database query utilities for posts.
 */
import { and, desc, eq, isNotNull, sql } from 'drizzle-orm';

import { db } from '@/db';
import { posts, users } from '@/db/schema';

/**
 * Fetches paginated published posts with author information.
 *
 * @param options - Pagination options
 * @param options.page - Page number (1-indexed)
 * @param options.limit - Posts per page
 * @returns Posts with author and total count
 */
export async function getPublishedPosts(options: { page: number; limit: number }): Promise<{
  posts: Array<{
    id: number;
    title: string;
    content: string;
    publishedAt: Date;
    author: { id: string; name: string };
  }>;
  total: number;
}> {
  const { page, limit } = options;
  const offset = (page - 1) * limit;

  const [postsResult, countResult] = await Promise.all([
    db.query.posts.findMany({
      where: isNotNull(posts.publishedAt),
      orderBy: desc(posts.publishedAt),
      limit,
      offset,
      with: {
        author: {
          columns: {
            id: true,
            name: true,
          },
        },
      },
    }),
    db
      .select({ count: sql<number>`count(*)` })
      .from(posts)
      .where(isNotNull(posts.publishedAt)),
  ]);

  return {
    posts: postsResult.map((post) => ({
      id: post.id,
      title: post.title,
      content: post.content,
      publishedAt: post.publishedAt!,
      author: post.author,
    })),
    total: countResult[0]?.count ?? 0,
  };
}

/**
 * Creates a new post for a user.
 *
 * @param data - Post data
 * @returns Created post
 */
export async function createPost(data: {
  title: string;
  content: string;
  authorId: string;
  publish?: boolean;
}): Promise<typeof posts.$inferSelect> {
  const [post] = await db
    .insert(posts)
    .values({
      title: data.title,
      content: data.content,
      authorId: data.authorId,
      publishedAt: data.publish ? new Date() : null,
    })
    .returning();

  return post!;
}
```

---

## GraphQL Patterns

### Schema Definition (Federation)

```graphql
# users-subgraph/schema.graphql
extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key", "@shareable"])

type Query {
  user(id: ID!): User
  users(first: Int, after: String): UserConnection!
  me: User
}

type User @key(fields: "id") {
  id: ID!
  email: String!
  name: String!
  avatarUrl: String
  createdAt: DateTime!
}

type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  node: User!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

### Resolver Pattern

```typescript
/**
 * GraphQL resolvers for user queries.
 */
import type { Resolvers } from '@/generated/graphql';
import { getUser, getUsers, getCurrentUser } from '@/services/user-service';

export const resolvers: Resolvers = {
  Query: {
    user: async (_parent, { id }, context) => {
      context.logger.info({ userId: id }, 'Fetching user');
      return getUser(id);
    },

    users: async (_parent, { first, after }, context) => {
      const limit = Math.min(first ?? 20, 100);
      return getUsers({ limit, cursor: after ?? undefined });
    },

    me: async (_parent, _args, context) => {
      if (!context.userId) {
        return null;
      }
      return getCurrentUser(context.userId);
    },
  },

  User: {
    __resolveReference: async (reference) => {
      return getUser(reference.id);
    },
  },
};
```

### Client Query with Codegen Types

```typescript
/**
 * GraphQL queries for user data.
 */
import { gql } from '@apollo/client';

import type { GetUserQuery, GetUserQueryVariables } from '@/generated/graphql';
import { useQuery } from '@apollo/client';

const GET_USER = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      email
      name
      avatarUrl
      createdAt
    }
  }
`;

/**
 * Hook to fetch user by ID.
 *
 * @param userId - User identifier
 * @returns Query result with typed data
 */
export function useUserQuery(userId: string) {
  return useQuery<GetUserQuery, GetUserQueryVariables>(GET_USER, {
    variables: { id: userId },
  });
}
```

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
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';

import { UserProfile } from './user-profile';
import { QueryClientProvider } from '@tanstack/react-query';
import { createTestQueryClient } from '@/test/utils';

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

      render(
        <QueryClientProvider client={createTestQueryClient()}>
          <UserProfile userId="123" />
        </QueryClientProvider>
      );

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

      render(
        <QueryClientProvider client={createTestQueryClient()}>
          <UserProfile userId="123" />
        </QueryClientProvider>
      );

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

      render(
        <QueryClientProvider client={createTestQueryClient()}>
          <UserProfile userId="nonexistent" />
        </QueryClientProvider>
      );

      expect(await screen.findByRole('alert')).toHaveTextContent(/error/i);
    });
  });
});
```

### Server Function Unit Test

```typescript
/**
 * Unit tests for user server functions.
 */
import { describe, expect, it, vi, beforeEach } from 'vitest';

import { getUser, updateUser } from './user';
import { db } from '@/db';

vi.mock('@/db', () => ({
  db: {
    query: {
      users: {
        findFirst: vi.fn(),
      },
    },
    update: vi.fn(() => ({
      set: vi.fn(() => ({
        where: vi.fn(() => ({
          returning: vi.fn(),
        })),
      })),
    })),
  },
}));

describe('getUser', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns user when found', async () => {
    const mockUser = { id: '123', email: 'test@example.com', name: 'Test' };
    vi.mocked(db.query.users.findFirst).mockResolvedValue(mockUser);

    const result = await getUser({ userId: '123' });

    expect(result).toEqual(mockUser);
    expect(db.query.users.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.anything(),
      }),
    );
  });

  it('returns null when user not found', async () => {
    vi.mocked(db.query.users.findFirst).mockResolvedValue(undefined);

    const result = await getUser({ userId: 'nonexistent' });

    expect(result).toBeNull();
  });

  it('throws on invalid UUID', async () => {
    await expect(getUser({ userId: 'not-a-uuid' })).rejects.toThrow();
  });
});
```