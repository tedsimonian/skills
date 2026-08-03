# Service Layer Patterns

Design patterns for shared business logic services that serve multiple entry points (website, API, CLI).

## Core Philosophy

**Single Source of Truth**: Business logic lives in services, not in resolvers or server functions. Entry points are thin wrappers that:
1. Extract context (authentication, request metadata)
2. Validate input at the boundary
3. Call the appropriate service method
4. Transform the result for the specific consumer

## Service Context Pattern

Every service method receives a context object containing:

```typescript
// packages/core/src/auth/context.ts

export interface ServiceContext {
  /** Authenticated user ID, null if anonymous */
  userId: string | null;

  /** User's display name (for audit logging) */
  userName?: string | null;

  /** User's email (for notifications) */
  userEmail?: string | null;

  /** Request ID for tracing */
  requestId?: string;

  /** Source of the request */
  source: 'website' | 'api' | 'internal';

  /** DataLoaders for batching (per-request) */
  loaders?: DataLoaders;
}

export function createServiceContext(params: {
  userId: string | null;
  userName?: string | null;
  userEmail?: string | null;
  requestId?: string;
  source: 'website' | 'api' | 'internal';
}): ServiceContext {
  return {
    userId: params.userId,
    userName: params.userName,
    userEmail: params.userEmail,
    requestId: params.requestId ?? crypto.randomUUID(),
    source: params.source,
  };
}
```

## Service Structure

```typescript
// packages/core/src/services/user-plugin.service.ts

export class UserPluginService {
  constructor(
    private pluginRepo: PluginRepository,
    private userPluginRepo: UserPluginRepository,
    private releaseRepo: ReleaseRepository
  ) {}

  /**
   * Install a plugin for a user.
   *
   * Business rules:
   * 1. Plugin must exist and be published
   * 2. Plugin must have at least one approved release
   * 3. User cannot install the same plugin twice
   * 4. Increment install counts atomically
   */
  async installPlugin(
    ctx: ServiceContext,
    input: InstallPluginInput
  ): Promise<InstallPluginResult> {
    // Require authentication
    if (!ctx.userId) {
      throw new UnauthorizedError('Authentication required');
    }

    // Validate business rules
    const plugin = await this.pluginRepo.findById(input.pluginId);
    if (!plugin) {
      throw new NotFoundError('Plugin not found', ['pluginId']);
    }
    if (plugin.status !== 'published') {
      throw new ValidationError('Plugin is not available', ['pluginId']);
    }

    // Check for existing installation
    const existing = await this.userPluginRepo.findInstallation(
      ctx.userId,
      input.pluginId
    );
    if (existing?.status === 'active') {
      throw new ConflictError('Plugin is already installed', ['pluginId']);
    }

    // Perform installation in transaction
    return await withTransaction(async (tx) => {
      // ... transactional logic
    });
  }
}
```

## Service Factory Pattern

Create services once at application startup, reuse across requests:

```typescript
// packages/core/src/factory.ts

export interface Services {
  plugin: PluginService;
  userPlugin: UserPluginService;
  review: ReviewService;
  favorite: FavoriteService;
  auth: AuthorizationService;
}

export function createServices(database: Database = db): Services {
  // Create repositories
  const pluginRepo = new PluginRepository(database);
  const userPluginRepo = new UserPluginRepository(database);
  // ... more repos

  // Create authorization service
  const authService = new AuthorizationService(teamMemberRepo);

  // Create business services
  return {
    plugin: new PluginService(pluginRepo, publisherRepo, releaseRepo),
    userPlugin: new UserPluginService(pluginRepo, userPluginRepo, releaseRepo),
    // ... more services
    auth: authService,
  };
}

// Singleton for simple cases
let _services: Services | null = null;

export function getServices(): Services {
  if (!_services) {
    _services = createServices();
  }
  return _services;
}
```

## Entry Point Integration

### Website (TanStack Start)

```typescript
// apps/website/src/server/data/user-plugins.server.ts
import { getServices, createServiceContext, toUserError } from '@plugin-marketplace/core';

export const installPlugin = createServerFn({ method: 'POST' })
  .inputValidator((input: InstallPluginInput) => input)
  .handler(async ({ data }) => {
    const user = await getCurrentUser();
    const ctx = createServiceContext({
      userId: user?.id ?? null,
      userName: user?.name,
      source: 'website',
    });

    try {
      const result = await getServices().userPlugin.installPlugin(ctx, data);
      return { userPlugin: result.userPlugin, userErrors: [] };
    } catch (error) {
      return { userPlugin: null, userErrors: [toUserError(error)] };
    }
  });
```

### GraphQL API

```typescript
// apps/api/src/schema/user-plugin/resolvers/Mutation/pluginInstall.ts
import { getServices, createServiceContext, toUserError } from '@plugin-marketplace/core';

export const pluginInstall: MutationResolvers['pluginInstall'] = async (
  _parent,
  { pluginId, workspaceId },
  ctx
) => {
  const serviceCtx = createServiceContext({
    userId: ctx.userId,
    userName: ctx.userName,
    source: 'api',
  });

  try {
    const result = await getServices().userPlugin.installPlugin(serviceCtx, {
      pluginId,
      workspaceId: workspaceId ?? undefined,
    });
    return { userPlugin: result.userPlugin, userErrors: [] };
  } catch (error) {
    return { userPlugin: null, userErrors: [toUserError(error)] };
  }
};
```

## Authorization Patterns

### Role-Based Access

```typescript
// packages/core/src/auth/authorization.service.ts

const ROLE_HIERARCHY = {
  viewer: 1,
  member: 2,
  admin: 3,
  owner: 4,
} as const;

type Role = keyof typeof ROLE_HIERARCHY;

export class AuthorizationService {
  constructor(private teamMemberRepo: TeamMemberRepository) {}

  async requirePublisherRole(
    userId: string,
    publisherId: string,
    minRole: Role
  ): Promise<void> {
    const member = await this.teamMemberRepo.findByUserAndPublisher(
      userId,
      publisherId
    );

    if (!member) {
      throw new ForbiddenError('You are not a member of this publisher');
    }

    const userLevel = ROLE_HIERARCHY[member.role as Role] ?? 0;
    const requiredLevel = ROLE_HIERARCHY[minRole];

    if (userLevel < requiredLevel) {
      throw new ForbiddenError(
        `This operation requires ${minRole} role. You have ${member.role} role.`
      );
    }
  }
}
```

### Authorization Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| **User-Owned** | Resources owned by user | `getMyPlugins(ctx)` |
| **Role-Based** | Publisher team actions | `requirePublisherRole(userId, publisherId, 'admin')` |
| **Public + Auth** | Browse with personalization | Check ctx.userId for enrichment |

## Error Types

```typescript
// packages/core/src/errors/index.ts

export class UnauthorizedError extends Error {
  readonly code = 'UNAUTHORIZED';
  constructor(message = 'Authentication required') {
    super(message);
  }
}

export class ForbiddenError extends Error {
  readonly code = 'FORBIDDEN';
  constructor(message = 'Insufficient permissions') {
    super(message);
  }
}

export class NotFoundError extends Error {
  readonly code = 'NOT_FOUND';
  constructor(message: string, readonly fields?: string[]) {
    super(message);
  }
}

export class ValidationError extends Error {
  readonly code = 'VALIDATION_ERROR';
  constructor(message: string, readonly fields?: string[]) {
    super(message);
  }
}

export class ConflictError extends Error {
  readonly code = 'CONFLICT';
  constructor(message: string, readonly fields?: string[]) {
    super(message);
  }
}
```

## Transaction Boundaries

Services own their transaction boundaries:

```typescript
// In service method
async installPlugin(ctx: ServiceContext, input: InstallPluginInput) {
  // Validation outside transaction (read-only)
  const plugin = await this.pluginRepo.findById(input.pluginId);
  // ... validate

  // Transaction for writes
  return await withTransaction(async (tx) => {
    const txPluginRepo = new PluginRepository(tx);
    const txUserPluginRepo = new UserPluginRepository(tx);

    // All writes in transaction
    const userPlugin = await txUserPluginRepo.create({...});
    await txPluginRepo.incrementInstallCount(input.pluginId);

    return { userPlugin };
  });
}
```

## Cache Invalidation

Document cache dependencies explicitly:

```typescript
const CACHE_DEPENDENCIES = {
  'plugin:update': ['plugin:{id}', 'marketplace:list', 'publisher:{publisherId}:plugins'],
  'review:create': ['plugin:{pluginId}', 'plugin:{pluginId}:reviews', 'plugin:{pluginId}:stats'],
  'install:create': ['plugin:{pluginId}:stats', 'user:{userId}:plugins'],
};

// In service
async updatePlugin(ctx: ServiceContext, input: UpdatePluginInput) {
  const plugin = await this.pluginRepo.update(input.id, input);

  // Invalidate related caches
  await this.cache.invalidate(`plugin:${input.id}`);
  await this.cache.invalidate(`marketplace:list`);
  await this.cache.invalidate(`publisher:${plugin.publisherId}:plugins`);

  return plugin;
}
```

## Testing Services

```typescript
// __tests__/services/user-plugin.service.test.ts
describe('UserPluginService', () => {
  let service: UserPluginService;
  let mockPluginRepo: MockPluginRepository;
  let mockUserPluginRepo: MockUserPluginRepository;

  beforeEach(() => {
    mockPluginRepo = createMockPluginRepository();
    mockUserPluginRepo = createMockUserPluginRepository();
    service = new UserPluginService(mockPluginRepo, mockUserPluginRepo, mockReleaseRepo);
  });

  describe('installPlugin', () => {
    it('requires authentication', async () => {
      const ctx = createServiceContext({ userId: null, source: 'api' });

      await expect(
        service.installPlugin(ctx, { pluginId: '123' })
      ).rejects.toThrow(UnauthorizedError);
    });

    it('throws NotFoundError for missing plugin', async () => {
      mockPluginRepo.findById.mockResolvedValue(null);
      const ctx = createServiceContext({ userId: 'user-1', source: 'api' });

      await expect(
        service.installPlugin(ctx, { pluginId: '123' })
      ).rejects.toThrow(NotFoundError);
    });
  });
});
```

## Decision Matrix

| Scenario | Where to Put Logic |
|----------|-------------------|
| Business validation | Service layer |
| Input schema validation | Entry point (Zod) |
| Authorization | AuthorizationService |
| Data transformation | Service layer |
| Response formatting | Entry point |
| Caching | Service layer (or repository) |
| Logging/Tracing | Service layer |
