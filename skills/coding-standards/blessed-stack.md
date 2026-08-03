# Blessed Technology Stack

This document defines the approved technologies organized by tier. Use the **Latest Stable** policy: always use the latest stable version, managed via Renovate/Dependabot.

## Tier Definitions

| Tier            | Meaning                                            | Adding New Deps            |
| --------------- | -------------------------------------------------- | -------------------------- |
| **Required**    | Must use for this domain. No alternatives.         | N/A - already decided      |
| **Preferred**   | Default choice. Use unless specific reason not to. | Just use it                |
| **Allowed**     | Acceptable for specific use cases.                 | Document why in PR         |
| **Discouraged** | Avoid. Legacy or superseded.                       | Requires ADR + team review |

---

## Runtime & Package Management

| Technology      | Tier        | Notes                                   |
| --------------- | ----------- | --------------------------------------- |
| **Bun**         | Required    | Primary runtime. Use Bun-native APIs.   |
| **Node.js 22+** | Allowed     | Only when Bun doesn't support a feature |
| **bun**         | Required    | Package manager for monorepos           |
| pnpm/npm/yarn   | Discouraged | pnpm handles workspaces better          |

### Bun-Native APIs to Prefer

```typescript
// File operations
import { file } from 'bun';
const content = await Bun.file('path.txt').text();

// HTTP server
Bun.serve({
  port: 3000,
  fetch(req) {
    return new Response('Hello');
  },
});

// SQLite
import { Database } from 'bun:sqlite';
const db = new Database('app.db');

// Shell commands
import { $ } from 'bun';
await $`ls -la`;

// WebSocket (built-in, no library needed)
// Test runner (bun test)
```

---

## Frontend Framework

| Technology          | Tier        | Notes                                       |
| ------------------- | ----------- | ------------------------------------------- |
| **TanStack Start**  | Required    | SSR React framework with file-based routing |
| **TanStack Router** | Required    | Type-safe routing (comes with Start)        |
| **React 19**        | Required    | With React Compiler enabled                 |
| Next.js             | Discouraged | Only for specific Vercel deployments        |
| Remix               | Discouraged | TanStack Start preferred                    |

---

## Styling

| Technology                   | Tier        | Notes                               |
| ---------------------------- | ----------- | ----------------------------------- |
| **Tailwind CSS 4**           | Required    | Utility-first CSS                   |
| **class-variance-authority** | Required    | Type-safe variants                  |
| **tailwind-merge**           | Required    | Class conflict resolution           |
| CSS Modules                  | Allowed     | Escape hatch for complex animations |
| styled-components            | Discouraged | Runtime overhead, use Tailwind      |
| Emotion                      | Discouraged | Same as styled-components           |
| Sass/SCSS                    | Discouraged | Tailwind handles everything         |

### CVA Pattern

```typescript
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md font-medium transition-colors',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        outline: 'border border-input bg-background hover:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 px-3',
        lg: 'h-11 px-8',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

function Button({ className, variant, size, ...props }: ButtonProps) {
  return <button className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}
```

---

## State Management

| Technology         | Tier        | Notes                                      |
| ------------------ | ----------- | ------------------------------------------ |
| **TanStack Query** | Required    | Server state management                    |
| **React useState** | Required    | UI-only local state                        |
| **React Context**  | Preferred   | Cross-cutting concerns (theme, auth)       |
| **Xstate**         | Preferred   | Complex state dependent actions and events |
| Zustand            | Discouraged | Complex client-side state                  |
| Redux              | Discouraged | Too much boilerplate                       |
| MobX               | Discouraged | Magic makes debugging hard                 |
| Recoil             | Discouraged | Experimental, uncertain future             |

### Server State Separation Pattern

```typescript
// Server state: TanStack Query
const { data: user } = useQuery({
  queryKey: ['user', userId],
  queryFn: () => getUser(userId),
});

// UI state: useState
const [isModalOpen, setModalOpen] = useState(false);

// Cross-cutting: Context
const { theme, setTheme } = useTheme();
```

---

## Forms

| Technology        | Tier        | Notes                         |
| ----------------- | ----------- | ----------------------------- |
| **TanStack Form** | Required    | Type-safe forms               |
| **Zod**           | Required    | Schema validation             |
| React Hook Form   | Allowed     | If already in codebase        |
| Formik            | Discouraged | TanStack Form is better typed |

---

## Data Fetching & APIs

| Technology            | Tier      | Notes                                          |
| --------------------- | --------- | ---------------------------------------------- |
| **GraphQL**           | Required  | API query language                             |
| **Apollo Federation** | Required  | Schema composition                             |
| **GraphQL Codegen**   | Required  | Type generation                                |
| **urql**              | Preferred | Lighter GraphQL client                         |
| Apollo Client         | Allowed   | For specific use case or existing old projects |
| REST                  | Allowed   | For third-party integrations                   |
| tRPC                  | Allowed   | Internal services only                         |

### GraphQL Schema Evolution

Use `@deprecated` directive, never remove fields:

```graphql
type User {
  id: ID!
  name: String!
  fullName: String!
  displayName: String @deprecated(reason: "Use fullName instead")
}
```

---

## Database

| Technology      | Tier        | Notes                    |
| --------------- | ----------- | ------------------------ |
| **Drizzle ORM** | Required    | Type-safe SQL            |
| **Drizzle Kit** | Required    | Migrations               |
| **PostgreSQL**  | Required    | Primary database         |
| **bun:sqlite**  | Preferred   | Local/embedded SQLite    |
| Prisma          | Allowed     | Existing projects        |
| Kysely          | Allowed     | When Drizzle doesn't fit |
| TypeORM         | Discouraged | Too much magic           |
| Sequelize       | Discouraged | Poor TypeScript support  |

### Drizzle Pattern

```typescript
import { pgTable, serial, text, timestamp } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: text('email').notNull().unique(),
  name: text('name').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
});

// Query with type safety
const user = await db.query.users.findFirst({
  where: eq(users.email, email),
});
```

---

## Authentication

| Technology      | Tier        | Notes                      |
| --------------- | ----------- | -------------------------- |
| **better-auth** | Preferred   | Self-hosted, full-featured |
| Lucia           | Allowed     | Lightweight alternative    |
| Auth0           | Discouraged | Enterprise requirements    |
| Clerk           | Discouraged | Quick MVP                  |
| NextAuth        | Discouraged | Use better-auth            |
| Passport.js     | Discouraged | Dated patterns             |

---

## Testing

| Technology          | Tier        | Notes                     |
| ------------------- | ----------- | ------------------------- |
| **Vitest**          | Required    | Test runner               |
| **Testing Library** | Required    | React testing             |
| **MSW**             | Required    | API mocking               |
| **Playwright**      | Required    | E2E testing               |
| Jest                | Allowed     | Existing projects         |
| Cypress             | Allowed     | Existing projects         |
| Enzyme              | Discouraged | Testing Library preferred |

### Testing Trophy Approach

```typescript
// Integration test (most common)
import { render, screen, userEvent } from '@testing-library/react';
import { server } from '@/mocks/server';
import { http, HttpResponse } from 'msw';

test('user can submit form and see success message', async () => {
  server.use(
    http.post('/api/submit', () => HttpResponse.json({ success: true }))
  );

  render(<SubmitForm />);
  await userEvent.type(screen.getByLabelText('Email'), 'test@example.com');
  await userEvent.click(screen.getByRole('button', { name: 'Submit' }));

  expect(await screen.findByText('Success!')).toBeInTheDocument();
});

// Unit test (pure logic only)
import { calculateDiscount } from './pricing';

test('applies percentage discount correctly', () => {
  expect(calculateDiscount(100, 0.1)).toBe(90);
});
```

---

## Build Tools

| Technology    | Tier        | Notes                   |
| ------------- | ----------- | ----------------------- |
| **Vite**      | Required    | Dev server and bundler  |
| **tsdown**    | Required    | Better tsup alternative |
| **Turborepo** | Required    | Monorepo orchestration  |
| tsup          | Allowed     | Existing projects       |
| esbuild       | Allowed     | Direct use when needed  |
| Rollup        | Allowed     | Complex library builds  |
| webpack       | Discouraged | Vite is faster          |

---

## Observability

| Technology        | Tier        | Notes                            |
| ----------------- | ----------- | -------------------------------- |
| **OpenTelemetry** | Required    | Distributed tracing              |
| **Sentry**        | Required    | Error tracking                   |
| **Pino**          | Required    | Structured logging               |
| **Prometheus**    | Preferred   | Metrics collection               |
| **Grafana**       | Preferred   | Dashboards                       |
| DataDog           | Discouraged | Expensive enterprise alternative |
| Winston           | Discouraged | Pino is faster                   |

### Logging Pattern

```typescript
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  redact: ['password', 'token', 'apiKey', 'authorization'],
});

// Usage
logger.info({ userId, action: 'login' }, 'User logged in');
logger.error({ error, requestId }, 'Request failed');
```

---

## Feature Flags

| Technology            | Tier        | Notes                   |
| --------------------- | ----------- | ----------------------- |
| **growthbook**        | Required    | Full-featured           |
| Environment variables | Allowed     | Simple on/off flags     |
| Unleash               | Discouraged | Self-hosted alternative |
| ConfigCat             | Discouraged | Simpler needs           |
| Custom solution       | Discouraged | Use a service           |

---

## Internationalization

| Technology        | Tier     | Notes                  |
| ----------------- | -------- | ---------------------- |
| **i18next**       | Required | i18n framework         |
| **react-i18next** | Required | React bindings         |
| **Intl API**      | Required | Date/number formatting |
| react-intl        | Allowed  | If already in codebase |
| LinguiJS          | Allowed  | Extraction workflows   |

---

## UI Components

| Technology      | Tier        | Notes                                     |
| --------------- | ----------- | ----------------------------------------- |
| **shadcn/ui**   | Required    | Copy-paste components                     |
| **Base UI**     | Required    | Accessible primitives                     |
| **React-Icons** | Required    | Multi library SVG icons                   |
| Radix UI        | Allowed     | Alternative to base-ui, existing projects |
| Headless UI     | Allowed     | Radix alternative                         |
| MUI             | Discouraged | Too opinionated                           |
| Chakra UI       | Discouraged | Use Radix + Tailwind                      |
| Ant Design      | Discouraged | Bundle size, styling conflicts            |

---

## Documentation

| Technology    | Tier        | Notes                   |
| ------------- | ----------- | ----------------------- |
| **Storybook** | Required    | Component documentation |
| **MDX**       | Required    | Rich documentation      |
| **TypeDoc**   | Preferred   | API documentation       |
| Docusaurus    | Allowed     | Standalone docs sites   |
| Styleguidist  | Discouraged | Storybook is better     |

---

## Real-Time

| Technology                | Tier        | Notes                           |
| ------------------------- | ----------- | ------------------------------- |
| **GraphQL Subscriptions** | Required    | Real-time data                  |
| SSE                       | Allowed     | Server-to-client only           |
| Apollo Subscriptions      | Allowed     | Subscription client             |
| Pusher                    | Allowed     | Managed service needs           |
| Socket.io                 | Discouraged | GraphQL subscriptions preferred |
| ws                        | Discouraged | Use Bun native or Apollo        |

---

## Image/Asset Processing

| Technology    | Tier        | Notes                   |
| ------------- | ----------- | ----------------------- |
| **Sharp**     | Required    | Build-time optimization |
| **WebP/AVIF** | Required    | Modern formats          |
| **CDN**       | Required    | Edge delivery           |
| Cloudinary    | Discouraged | On-the-fly transforms   |
| imgix         | Discouraged | Alternative CDN         |

---

## Containerization

| Technology     | Tier      | Notes                        |
| -------------- | --------- | ---------------------------- |
| **Docker**     | Required  | Containerization             |
| **Distroless** | Preferred | Production base images       |
| **Alpine**     | Allowed   | When distroless doesn't work |
| **Trivy**      | Required  | Security scanning            |
| Podman         | Allowed   | Docker alternative           |

### Docker Best Practices

```dockerfile
# Multi-stage build
FROM oven/bun:1 AS builder
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

# Production image
FROM gcr.io/distroless/nodejs22-debian12
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

# Non-root user (distroless uses nonroot by default)
USER nonroot

EXPOSE 3000
CMD ["dist/index.js"]
```

---

## Adding New Technologies

### Evaluation Matrix

Before adding a dependency not on the blessed list:

| Criterion            | Check                                   |
| -------------------- | --------------------------------------- |
| **Bundle Impact**    | < defined budget threshold              |
| **Weekly Downloads** | > 10,000 (actively used)                |
| **Last Update**      | Within 6 months                         |
| **License**          | MIT, Apache-2.0, BSD (compatible)       |
| **Security**         | No critical/high advisories             |
| **TypeScript**       | Native types or @types available        |
| **Maintenance**      | Multiple maintainers, responsive issues |

### ADR Template

```markdown
# ADR-XXX: Adding [Package Name]

## Status

Proposed / Accepted / Deprecated

## Context

Why do we need this? What problem does it solve?

## Decision

We will use [package] because...

## Evaluation

- Bundle size: +X KB (Y% of budget)
- Downloads: X/week
- Last update: YYYY-MM-DD
- License: MIT
- Security: No advisories
- TypeScript: Native
- Alternatives considered: A, B, C

## Consequences

- Positive: ...
- Negative: ...
- Neutral: ...

## Migration Path (if replacing existing tech)

1. Step 1
2. Step 2
```

---

## Deprecation Process

When moving technology from Allowed/Preferred to Discouraged:

1. **Announce**: Team communication with rationale
2. **Document**: Update this file with deprecation date
3. **Migrate**: Create migration guide
4. **Timeline**: Set removal date (usually 2 quarters)
5. **Lint**: Add ESLint rule to warn on imports
6. **Remove**: After timeline, remove from codebase