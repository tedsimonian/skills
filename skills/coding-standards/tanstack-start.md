# TanStack Start: Production Patterns & Best Practices

This guide provides comprehensive patterns for building high-performance TanStack Start applications. It covers architecture, conventions, integrations, and production-ready patterns based on real-world experience.

## Table of Contents

- [Philosophy & Approach](#philosophy--approach)
- [Project Structure](#project-structure)
- [Server Functions](#server-functions)
- [Routing & Layouts](#routing--layouts)
- [Data Fetching & Caching](#data-fetching--caching)
- [Forms & Mutations](#forms--mutations)
- [Type Safety](#type-safety)
- [Authentication & Security](#authentication--security)
- [Performance Optimization](#performance-optimization)
- [Testing Strategy](#testing-strategy)
- [Deployment & Operations](#deployment--operations)
- [Common Patterns](#common-patterns)

---

## Philosophy & Approach

TanStack Start is a full-stack React framework focused on:

1. **Type Safety First**: End-to-end type safety from database to UI
2. **Server-First**: Leverage server capabilities, progressively enhance client
3. **Performance by Default**: Full SSR, intelligent caching, optimal loading patterns
4. **Developer Experience**: Great DX without compromising production quality

**Core Principles**:

- Use server functions for all data access and mutations
- Keep server and client code clearly separated
- Leverage TanStack Query for optimal caching and state management
- Explicit context passing over implicit dependencies
- Feature-based organization over layer-based

---

## Project Structure

### Recommended Directory Layout

```
apps/your-app/
├── src/
│   ├── routes/                    # File-based routing
│   │   ├── __root.tsx            # Root layout
│   │   ├── index.tsx             # Home route
│   │   ├── auth/                 # Auth feature routes
│   │   │   ├── login.tsx
│   │   │   ├── register.tsx
│   │   │   └── auth.server.ts    # Auth server functions
│   │   └── users/                # Users feature routes
│   │       ├── $userId/
│   │       │   ├── index.tsx
│   │       │   ├── edit.tsx
│   │       │   └── user-detail.server.ts
│   │       ├── index.tsx
│   │       └── users.server.ts
│   │
│   ├── features/                  # Feature-based modules
│   │   ├── auth/
│   │   │   ├── components/       # Auth-specific components
│   │   │   ├── hooks/            # Auth-specific hooks
│   │   │   ├── types.ts          # Auth types
│   │   │   ├── schemas.ts        # Zod validation schemas
│   │   │   └── index.ts          # Public API
│   │   └── users/
│   │       ├── components/
│   │       ├── hooks/
│   │       ├── types.ts
│   │       ├── schemas.ts
│   │       └── index.ts
│   │
│   ├── services/                  # Business logic layer
│   │   ├── auth-service.ts
│   │   ├── user-service.ts
│   │   └── email-service.ts
│   │
│   ├── lib/                       # Shared utilities
│   │   ├── db.ts                 # Database client
│   │   ├── cache.ts              # Cache utilities
│   │   ├── env.ts                # Environment config
│   │   └── utils.ts              # General utilities
│   │
│   ├── shared/                    # Shared across server/client
│   │   ├── types.ts              # Cross-feature types
│   │   ├── schemas.ts            # Shared Zod schemas
│   │   ├── constants.ts          # Constants
│   │   └── errors.ts             # Error definitions
│   │
│   ├── components/                # Global UI components
│   │   ├── ui/                   # Shadcn/UI components
│   │   └── layout/               # Layout components
│   │
│   └── router.tsx                # Router configuration
│
├── public/                        # Static assets
└── .env                          # Environment variables
```

### Key Organizational Principles

**Feature-Based Structure**:

```typescript
// ✅ CORRECT: Feature co-location
features/auth/
  ├── components/login-form.tsx
  ├── hooks/use-auth.ts
  ├── types.ts
  ├── schemas.ts
  └── index.ts

// ❌ INCORRECT: Layer-based structure
src/
  ├── components/login-form.tsx
  ├── hooks/use-auth.ts
  └── types/auth-types.ts
```

**Server Function Placement**:

- **Co-located with routes**: For route-specific server functions
- **Feature directories**: For feature-specific server logic
- **Services layer**: For reusable business logic

```typescript
// Route-level server function
// routes/users/$userId/user-detail.server.ts
export const getUserDetail = createServerFn('GET', async (ctx: Context, userId: string) => {
  return userService.getById(ctx, userId);
});

// Feature-level server function
// features/auth/auth.server.ts
export const login = createServerFn('POST', async (ctx: Context, credentials: LoginCredentials) => {
  return authService.login(ctx, credentials);
});

// Service layer (pure business logic)
// services/user-service.ts
export const userService = {
  getById: async (ctx: Context, id: string) => {
    const db = ctx.db;
    return db.selectFrom('users').where('id', '=', id).selectAll().executeTakeFirst();
  },
};
```

---

## Server Functions

### Server Function Patterns

**Basic Structure**:

```typescript
// users/users.server.ts
import { createServerFn } from '@tanstack/start';
import { z } from 'zod';
import type { Context } from '~/lib/types.js';
import { userService } from '~/services/user-service.js';

// Schema definition
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
});

type CreateUserInput = z.infer<typeof CreateUserSchema>;

// Server function with explicit context
export const createUser = createServerFn('POST', async (ctx: Context, input: CreateUserInput) => {
  // Validate input
  const validated = CreateUserSchema.parse(input);

  // Call service layer
  const user = await userService.create(ctx, validated);

  // Return standard envelope
  return {
    success: true,
    data: user,
    error: null,
  };
});
```

**Context Pattern**:

```typescript
// lib/types.ts
import type { Kysely } from 'kysely';
import type { Database } from '~/lib/db-types.js';

export interface Context {
  db: Kysely<Database>;
  userId?: string;
  user?: User;
  cache: LRUCache;
}

// lib/context.ts
import { LRUCache } from 'lru-cache';
import { db } from '~/lib/db.js';

// Global cache instance
const cache = new LRUCache({ max: 500 });

export function createContext(userId?: string): Context {
  return {
    db,
    userId,
    cache,
  };
}
```

### Validation Strategy

**Shared Schemas Approach**:

```typescript
// shared/schemas.ts - Single source of truth
import { z } from 'zod';

export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().min(2).max(100),
  role: z.enum(['user', 'admin']),
});

export const CreateUserSchema = UserSchema.omit({ id: true });
export const UpdateUserSchema = UserSchema.partial().required({ id: true });

export type User = z.infer<typeof UserSchema>;
export type CreateUserInput = z.infer<typeof CreateUserSchema>;
export type UpdateUserInput = z.infer<typeof UpdateUserSchema>;
```

**Server Function with Validation**:

```typescript
// routes/users/users.server.ts
import { CreateUserSchema } from '~/shared/schemas.js';

export const createUser = createServerFn('POST', async (ctx: Context, input: unknown) => {
  // Validate at server boundary
  const validated = CreateUserSchema.parse(input);

  // Business logic assumes validated data
  const user = await userService.create(ctx, validated);

  return {
    success: true,
    data: user,
    error: null,
  };
});
```

### Response Envelope Pattern

**Standard Response Shape**:

```typescript
// shared/types.ts
export type ApiResponse<T> = { success: true; data: T; error: null } | { success: false; data: null; error: ApiError };

export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

// Server function implementation
export const getUser = createServerFn('GET', async (ctx: Context, id: string) => {
  try {
    const user = await userService.getById(ctx, id);

    if (!user) {
      return {
        success: false,
        data: null,
        error: {
          code: 'USER_NOT_FOUND',
          message: 'User not found',
        },
      };
    }

    return {
      success: true,
      data: user,
      error: null,
    };
  } catch (error) {
    return {
      success: false,
      data: null,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch user',
        details: { original: error },
      },
    };
  }
});
```

---

## Routing & Layouts

### Layout Data Fetching

**Layouts should fetch shared data** needed across multiple child routes:

```typescript
// routes/__root.tsx
import { createRootRoute, Outlet } from '@tanstack/react-router';
import { getCurrentUser } from './auth/auth.server.js';

export const Route = createRootRoute({
  loader: async ({ context }) => {
    // Fetch data needed by all routes
    const user = await getCurrentUser(context);

    return {
      user,
    };
  },
  component: RootLayout,
});

function RootLayout() {
  const { user } = Route.useLoaderData();

  return (
    <div>
      <Header user={user} />
      <main>
        <Outlet />
      </main>
      <Footer />
    </div>
  );
}
```

### Route Organization

**Co-Located Feature Modules**:

```
routes/users/$userId/
├── index.tsx              # Main route component
├── edit.tsx              # Edit route
├── components/           # Route-specific components
│   ├── user-profile.tsx
│   └── user-stats.tsx
├── user-detail.server.ts # Server functions
└── types.ts              # Route-specific types
```

**Route File Pattern**:

```typescript
// routes/users/$userId/index.tsx
import { createFileRoute } from '@tanstack/react-router';
import { getUserDetail } from './user-detail.server.js';
import { UserProfile } from './components/user-profile.js';

// Search params with type safety
const searchSchema = z.object({
  tab: z.enum(['profile', 'settings', 'activity']).optional(),
  page: z.number().optional(),
});

export const Route = createFileRoute('/users/$userId')({
  // Validate search params
  validateSearch: searchSchema,

  // Load data
  loader: async ({ context, params }) => {
    const result = await getUserDetail(context, params.userId);

    if (!result.success) {
      throw new Error(result.error.message);
    }

    return result.data;
  },

  // Route component
  component: UserDetailPage,
});

function UserDetailPage() {
  const user = Route.useLoaderData();
  const { tab = 'profile' } = Route.useSearch();

  return (
    <div>
      <UserProfile user={user} activeTab={tab} />
    </div>
  );
}
```

### Error Boundaries

**Hybrid Error Handling Strategy**:

```typescript
// routes/__root.tsx - Global error boundary
export const Route = createRootRoute({
  errorComponent: ({ error }) => (
    <DefaultErrorBoundary error={error} />
  ),
});

// routes/users/$userId/index.tsx - Route-specific errors
export const Route = createFileRoute('/users/$userId')({
  errorComponent: ({ error }) => {
    // Handle known errors
    if (error.message === 'USER_NOT_FOUND') {
      return <UserNotFound />;
    }

    if (error.message === 'FORBIDDEN') {
      return <Forbidden />;
    }

    // Let unknown errors bubble to layout
    throw error;
  },
});
```

---

## Data Fetching & Caching

### TanStack Query Integration

**Use ensureQueryData for SSR + Client Consistency**:

```typescript
// routes/users/index.tsx
import { createFileRoute } from '@tanstack/react-router';
import { useSuspenseQuery } from '@tanstack/react-query';
import { getUsers } from './users.server.js';

export const Route = createFileRoute('/users')({
  loader: async ({ context }) => {
    // Ensure data in query cache for SSR
    await context.queryClient.ensureQueryData({
      queryKey: ['users'],
      queryFn: () => getUsers(context),
    });
  },
  component: UsersPage,
});

function UsersPage() {
  // Same query key - uses cached data from loader
  const { data } = useSuspenseQuery({
    queryKey: ['users'],
    queryFn: () => getUsers(createContext()),
  });

  return <UserList users={data} />;
}
```

### Caching Strategy

**In-Memory LRU Cache**:

```typescript
// lib/cache.ts
import { LRUCache } from 'lru-cache';

export const cache = new LRUCache<string, unknown>({
  max: 500, // Maximum items
  ttl: 1000 * 60 * 5, // 5 minutes
  updateAgeOnGet: true,
  updateAgeOnHas: true,
});

// Cache utility functions
export function getCached<T>(key: string): T | undefined {
  return cache.get(key) as T | undefined;
}

export function setCached<T>(key: string, value: T): void {
  cache.set(key, value);
}

export function invalidateCache(pattern: string): void {
  for (const key of cache.keys()) {
    if (key.includes(pattern)) {
      cache.delete(key);
    }
  }
}
```

**Server Function with Caching**:

```typescript
// services/user-service.ts
export const userService = {
  getById: async (ctx: Context, id: string): Promise<User | null> => {
    const cacheKey = `user:${id}`;

    // Check cache first
    const cached = ctx.cache.get(cacheKey);
    if (cached) {
      return cached as User;
    }

    // Fetch from database
    const user = await ctx.db.selectFrom('users').where('id', '=', id).selectAll().executeTakeFirst();

    // Cache result
    if (user) {
      ctx.cache.set(cacheKey, user);
    }

    return user || null;
  },
};
```

### Stale-While-Revalidate Pattern

```typescript
// Client-side query configuration
const { data } = useQuery({
  queryKey: ['users', userId],
  queryFn: () => getUser(createContext(), userId),
  staleTime: 1000 * 60, // 1 minute
  gcTime: 1000 * 60 * 5, // 5 minutes (formerly cacheTime)
  refetchOnWindowFocus: true,
  refetchOnMount: false,
});
```

### Pagination Pattern

**Server-Side Pagination**:

```typescript
// shared/schemas.ts
export const PaginationSchema = z.object({
  page: z.number().min(1).default(1),
  pageSize: z.number().min(1).max(100).default(20),
  sortBy: z.string().optional(),
  sortOrder: z.enum(['asc', 'desc']).default('asc'),
});

export type PaginationParams = z.infer<typeof PaginationSchema>;

// services/user-service.ts
export const userService = {
  list: async (ctx: Context, params: PaginationParams) => {
    const { page, pageSize, sortBy = 'createdAt', sortOrder } = params;
    const offset = (page - 1) * pageSize;

    // Get total count
    const { count } = await ctx.db.selectFrom('users').select(ctx.db.fn.count('id').as('count')).executeTakeFirst();

    // Get paginated results
    const users = await ctx.db
      .selectFrom('users')
      .selectAll()
      .orderBy(sortBy, sortOrder)
      .limit(pageSize)
      .offset(offset)
      .execute();

    return {
      items: users,
      pagination: {
        page,
        pageSize,
        total: Number(count),
        totalPages: Math.ceil(Number(count) / pageSize),
      },
    };
  },
};
```

---

## Forms & Mutations

### TanStack Form Integration

**Form with Server-Side Validation Fallback**:

```typescript
// features/auth/components/login-form.tsx
import { useForm } from '@tanstack/react-form';
import { zodValidator } from '@tanstack/zod-form-adapter';
import { LoginSchema } from '../schemas.js';
import { login } from '../auth.server.js';

export function LoginForm() {
  const form = useForm({
    defaultValues: {
      email: '',
      password: '',
    },
    validators: {
      // Client-side validation
      onChange: LoginSchema,
    },
    onSubmit: async ({ value }) => {
      const result = await login(createContext(), value);

      if (!result.success) {
        // Handle server validation errors
        form.setError('root', result.error.message);
        return;
      }

      // Redirect on success
      router.navigate({ to: '/dashboard' });
    },
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        form.handleSubmit();
      }}
    >
      <form.Field
        name="email"
        children={(field) => (
          <Input
            value={field.state.value}
            onChange={(e) => field.handleChange(e.target.value)}
            error={field.state.meta.errors[0]}
          />
        )}
      />

      <Button type="submit" disabled={form.state.isSubmitting}>
        {form.state.isSubmitting ? 'Logging in...' : 'Log In'}
      </Button>
    </form>
  );
}
```

### Mutation Pattern

**Always Wait for Server Confirmation**:

```typescript
// features/users/hooks/use-update-user.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { updateUser } from '../users.server.js';

export function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: UpdateUserInput) => updateUser(createContext(), data),

    onSuccess: (result, variables) => {
      if (result.success) {
        // Invalidate affected queries
        queryClient.invalidateQueries({ queryKey: ['users'] });
        queryClient.invalidateQueries({ queryKey: ['user', variables.id] });

        // Show success toast
        toast.success('User updated successfully');
      } else {
        // Show error toast
        toast.error(result.error.message);
      }
    },

    onError: (error) => {
      toast.error('Failed to update user');
      console.error('Update user error:', error);
    },
  });
}
```

---

## Type Safety

### Loader Data Types

**Infer from useLoaderData Generic**:

```typescript
// routes/users/$userId/index.tsx
export const Route = createFileRoute('/users/$userId')({
  loader: async ({ params }) => {
    const result = await getUserDetail(createContext(), params.userId);

    if (!result.success) {
      throw new Error(result.error.message);
    }

    return {
      user: result.data,
      recentActivity: await getRecentActivity(createContext(), params.userId),
    };
  },
  component: UserDetailPage,
});

function UserDetailPage() {
  // Type is inferred from loader return type
  const { user, recentActivity } = Route.useLoaderData();

  // user and recentActivity are fully typed
  return <UserProfile user={user} activity={recentActivity} />;
}
```

### Search Params Type Safety

**TanStack Router Search Param Schemas**:

```typescript
// routes/users/index.tsx
import { z } from 'zod';

const userSearchSchema = z.object({
  page: z.number().catch(1),
  pageSize: z.number().catch(20),
  search: z.string().optional(),
  role: z.enum(['user', 'admin', 'moderator']).optional(),
  sortBy: z.enum(['name', 'email', 'createdAt']).catch('createdAt'),
  sortOrder: z.enum(['asc', 'desc']).catch('asc'),
});

export const Route = createFileRoute('/users')({
  validateSearch: userSearchSchema,

  component: UsersPage,
});

function UsersPage() {
  // Fully typed search params
  const search = Route.useSearch();

  // TypeScript knows all possible properties
  const { page, pageSize, search: query, role, sortBy, sortOrder } = search;
}
```

### Shared Type Organization

**Feature-Local + Shared for Cross-Feature**:

```typescript
// Feature-local types
// features/auth/types.ts
export interface LoginCredentials {
  email: string;
  password: string;
}

export interface AuthSession {
  userId: string;
  expiresAt: Date;
}

// Shared types (used across features)
// shared/types.ts
export interface User {
  id: string;
  email: string;
  name: string;
  role: UserRole;
}

export type UserRole = 'user' | 'admin' | 'moderator';

export interface Context {
  db: Kysely<Database>;
  userId?: string;
  user?: User;
  cache: LRUCache;
}
```

---

## Authentication & Security

### JWT in HTTP-Only Cookies

**Auth Service**:

```typescript
// services/auth-service.ts
import jwt from 'jsonwebtoken';
import { env } from '~/lib/env.js';

export const authService = {
  generateToken: (userId: string): string => {
    return jwt.sign({ userId }, env.server.JWT_SECRET, { expiresIn: '7d' });
  },

  verifyToken: (token: string): { userId: string } | null => {
    try {
      return jwt.verify(token, env.server.JWT_SECRET) as { userId: string };
    } catch {
      return null;
    }
  },

  setAuthCookie: (response: Response, token: string): void => {
    response.headers.set(
      'Set-Cookie',
      `auth_token=${token}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=604800`,
    );
  },
};
```

### CSRF Protection

**SameSite=Strict + Origin Validation**:

```typescript
// middleware/csrf-middleware.ts
export function validateOrigin(request: Request): boolean {
  const origin = request.headers.get('origin');
  const host = request.headers.get('host');

  if (!origin || !host) {
    return false;
  }

  const originUrl = new URL(origin);
  return originUrl.host === host;
}

// Server function with CSRF protection
export const sensitiveAction = createServerFn('POST', async (ctx: Context, data: unknown) => {
  // Validate origin for state-changing operations
  if (!validateOrigin(ctx.request)) {
    return {
      success: false,
      data: null,
      error: { code: 'CSRF_ERROR', message: 'Invalid request origin' },
    };
  }

  // Proceed with action
  // ...
});
```

### Rate Limiting

**Multi-Layer: Edge + App-Level**:

```typescript
// lib/rate-limit.ts
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const redis = Redis.fromEnv();

// General rate limit (100 requests per minute)
export const generalRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(100, '1 m'),
});

// Sensitive endpoints (10 requests per minute)
export const sensitiveRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, '1 m'),
});

// Server function with rate limiting
export const login = createServerFn('POST', async (ctx: Context, credentials: LoginCredentials) => {
  const ip = ctx.request.headers.get('x-forwarded-for') || '127.0.0.1';

  const { success } = await sensitiveRateLimit.limit(ip);

  if (!success) {
    return {
      success: false,
      data: null,
      error: { code: 'RATE_LIMIT', message: 'Too many requests' },
    };
  }

  // Proceed with login
  // ...
});
```

---

## Performance Optimization

### Full SSR Strategy

**All Routes Render on Server**:

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import { TanStackStartVite } from '@tanstack/start/vite';

export default defineConfig({
  plugins: [
    TanStackStartVite({
      ssr: true, // Enable SSR for all routes
    }),
  ],
});
```

### Intelligent Prefetching

**Viewport + Intent-Based Prefetch**:

```typescript
// components/prefetch-link.tsx
import { Link } from '@tanstack/react-router';
import { useQueryClient } from '@tanstack/react-query';
import { useInView } from 'react-intersection-observer';

interface PrefetchLinkProps {
  to: string;
  prefetchQuery: () => Promise<unknown>;
  children: React.ReactNode;
}

export function PrefetchLink({ to, prefetchQuery, children }: PrefetchLinkProps) {
  const queryClient = useQueryClient();
  const [hasStarted, setHasStarted] = useState(false);

  // Prefetch when link enters viewport
  const { ref } = useInView({
    triggerOnce: true,
    onChange: (inView) => {
      if (inView && !hasStarted) {
        setHasStarted(true);
        queryClient.prefetchQuery({
          queryKey: ['route-data', to],
          queryFn: prefetchQuery,
        });
      }
    },
  });

  // Also prefetch on hover intent
  const handleMouseEnter = () => {
    if (!hasStarted) {
      setHasStarted(true);
      queryClient.prefetchQuery({
        queryKey: ['route-data', to],
        queryFn: prefetchQuery,
      });
    }
  };

  return (
    <Link
      to={to}
      ref={ref}
      onMouseEnter={handleMouseEnter}
    >
      {children}
    </Link>
  );
}
```

---

## Testing Strategy

### Test Pyramid Approach

**Many Unit, Some Integration, Few E2E**:

```typescript
// __tests__/unit/user-service.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { userService } from '~/services/user-service.js';

describe('UserService', () => {
  let mockDb: MockKysely;
  let mockCache: MockCache;
  let ctx: Context;

  beforeEach(() => {
    mockDb = createMockDb();
    mockCache = createMockCache();
    ctx = { db: mockDb, cache: mockCache };
  });

  it('should get user by id from cache', async () => {
    const user = { id: '1', email: 'test@example.com', name: 'Test' };
    mockCache.get.mockReturnValue(user);

    const result = await userService.getById(ctx, '1');

    expect(result).toEqual(user);
    expect(mockDb.selectFrom).not.toHaveBeenCalled();
  });

  it('should fetch from db when cache misses', async () => {
    const user = { id: '1', email: 'test@example.com', name: 'Test' };
    mockCache.get.mockReturnValue(undefined);
    mockDb.selectFrom.mockReturnValue({
      where: vi.fn().mockReturnThis(),
      selectAll: vi.fn().mockReturnThis(),
      executeTakeFirst: vi.fn().mockResolvedValue(user),
    });

    const result = await userService.getById(ctx, '1');

    expect(result).toEqual(user);
    expect(mockCache.set).toHaveBeenCalledWith('user:1', user);
  });
});
```

**Integration Tests**:

```typescript
// __tests__/integration/users-api.test.ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { startTestServer, stopTestServer } from '~/test/test-server.js';

describe('Users API Integration', () => {
  let server: TestServer;

  beforeAll(async () => {
    server = await startTestServer();
  });

  afterAll(async () => {
    await stopTestServer(server);
  });

  it('should create and retrieve user', async () => {
    const userData = {
      email: 'newuser@example.com',
      name: 'New User',
    };

    // Create user
    const createResponse = await server.post('/api/users', userData);
    expect(createResponse.status).toBe(200);
    const { data: createdUser } = await createResponse.json();

    // Retrieve user
    const getResponse = await server.get(`/api/users/${createdUser.id}`);
    expect(getResponse.status).toBe(200);
    const { data: retrievedUser } = await getResponse.json();

    expect(retrievedUser).toMatchObject(userData);
  });
});
```

---

## Deployment & Operations

### Deployment Strategy

**Hybrid: Static to CDN, Dynamic to Containers**:

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - '3000:3000'
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - JWT_SECRET=${JWT_SECRET}
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
```

```dockerfile
# Dockerfile
FROM oven/bun:1 AS builder
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

FROM oven/bun:1-slim
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3000
CMD ["bun", "dist/server.js"]
```

### Observability

**OpenTelemetry + Structured Logs + Sentry**:

```typescript
// lib/telemetry.ts
import { trace } from '@opentelemetry/api';
import * as Sentry from '@sentry/node';

const tracer = trace.getTracer('tanstack-start-app');

export function traceServerFn<T>(name: string, fn: () => Promise<T>): Promise<T> {
  return tracer.startActiveSpan(name, async (span) => {
    try {
      const result = await fn();
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.setStatus({ code: SpanStatusCode.ERROR });
      Sentry.captureException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}

// Usage in server function
export const getUserDetail = createServerFn('GET', async (ctx: Context, id: string) => {
  return traceServerFn('getUserDetail', async () => {
    // Add correlation ID to context
    const correlationId = ctx.request.headers.get('x-correlation-id') || generateId();

    logger.info('Fetching user detail', { correlationId, userId: id });

    const user = await userService.getById(ctx, id);

    logger.info('User detail fetched', { correlationId, userId: id });

    return user;
  });
});
```

---

## Common Patterns

### Environment Configuration

**Typed Env with Client/Server Split**:

```typescript
// lib/env.ts
import { z } from 'zod';

const ServerEnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  REDIS_URL: z.string().url().optional(),
});

const ClientEnvSchema = z.object({
  VITE_API_URL: z.string().url(),
  VITE_SENTRY_DSN: z.string().optional(),
});

// Validate at startup
const serverEnv = ServerEnvSchema.parse(process.env);
const clientEnv = ClientEnvSchema.parse(import.meta.env);

export const env = {
  server: serverEnv,
  client: clientEnv,

  // Explicitly mark what's available client-side
  isProduction: serverEnv.NODE_ENV === 'production',
  isDevelopment: serverEnv.NODE_ENV === 'development',
};

// Type-safe access
// ✅ OK: env.server.JWT_SECRET (server-only)
// ✅ OK: env.client.VITE_API_URL (available everywhere)
// ❌ Error: env.server.JWT_SECRET in client code (caught by bundler)
```

### i18n with Namespace Splitting

```typescript
// lib/i18n.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

i18n.use(initReactI18next).init({
  fallbackLng: 'en',
  ns: ['common', 'auth', 'users', 'dashboard'],
  defaultNS: 'common',

  backend: {
    loadPath: '/locales/{{lng}}/{{ns}}.json',
  },

  react: {
    useSuspense: true, // Works with TanStack Start SSR
  },
});

export { i18n };
```

### File Uploads with Presigned URLs

```typescript
// services/upload-service.ts
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({ region: env.server.AWS_REGION });

export const uploadService = {
  getPresignedUrl: async (ctx: Context, filename: string, contentType: string) => {
    const key = `uploads/${ctx.userId}/${Date.now()}-${filename}`;

    const command = new PutObjectCommand({
      Bucket: env.server.S3_BUCKET,
      Key: key,
      ContentType: contentType,
    });

    const url = await getSignedUrl(s3, command, { expiresIn: 3600 });

    return {
      uploadUrl: url,
      fileKey: key,
    };
  },
};
```

### Real-Time with SSE

```typescript
// Server-sent events for notifications
export const subscribeToNotifications = createServerFn('GET', async (ctx: Context) => {
  const stream = new ReadableStream({
    start(controller) {
      const interval = setInterval(async () => {
        const notifications = await getNewNotifications(ctx);

        if (notifications.length > 0) {
          controller.enqueue(`data: ${JSON.stringify(notifications)}\n\n`);
        }
      }, 5000);

      // Cleanup on close
      return () => clearInterval(interval);
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
});
```

---

## Quick Reference

| Aspect               | Pattern                                             |
| -------------------- | --------------------------------------------------- |
| **Structure**        | Feature-based with .server.ts suffix                |
| **Layouts**          | Fetch shared data (user, nav)                       |
| **Server Functions** | Explicit context, envelope response, no prefix      |
| **Validation**       | Shared Zod schemas from /shared                     |
| **Types**            | Feature-local + shared for cross-feature            |
| **Forms**            | TanStack Form + server validation fallback          |
| **Mutations**        | Wait for server confirmation                        |
| **Queries**          | ensureQueryData in loaders                          |
| **Error Boundaries** | Hybrid (layout for unexpected, routes for known)    |
| **Database**         | Kysely with injected client                         |
| **Caching**          | In-memory LRU + TanStack Query                      |
| **Auth**             | JWT in HTTP-only cookies                            |
| **CSRF**             | SameSite=Strict + origin validation                 |
| **Rate Limiting**    | Edge + app-level sensitive endpoints                |
| **Testing**          | Test pyramid (many unit, some integration, few E2E) |
| **Deployment**       | Hybrid (static to CDN, dynamic to containers)       |
| **Monitoring**       | OpenTelemetry + Sentry + structured logs            |
| **i18n**             | i18next with namespace splitting                    |
| **SEO**              | Static in route config + dynamic in loaders         |
| **Jobs**             | External services (Inngest, Trigger.dev)            |
| **Prefetch**         | Viewport + intent-based                             |
| **Pagination**       | Full server-side                                    |
| **Uploads**          | Presigned S3 URLs                                   |
| **Real-time**        | SSE for notifications, polling for data             |
| **Stale Data**       | Background revalidation (stale-while-revalidate)    |

---

## See Also

- [SKILL.md](SKILL.md) - General coding standards
- [security.md](security.md) - Security patterns
- [patterns.md](patterns.md) - Code examples
- [blessed-stack.md](blessed-stack.md) - Technology choices