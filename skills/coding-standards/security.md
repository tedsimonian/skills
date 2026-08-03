# Security Patterns

This guide covers security best practices for fullstack TypeScript applications. The approach is **Boundary + Critical Paths**: validate at system boundaries, add extra protection for security-critical paths, and trust validated data internally.

## Core Security Principles

### 1. Defense in Depth

Multiple layers of security ensure that if one layer fails, others still protect the system:

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: Infrastructure (WAF, DDoS protection)         │
├─────────────────────────────────────────────────────────┤
│  Layer 2: Authentication (Identity verification)        │
├─────────────────────────────────────────────────────────┤
│  Layer 3: Authorization (Permission checks)             │
├─────────────────────────────────────────────────────────┤
│  Layer 4: Input Validation (Schema validation)          │
├─────────────────────────────────────────────────────────┤
│  Layer 5: Business Logic (Security-aware code)          │
├─────────────────────────────────────────────────────────┤
│  Layer 6: Data Layer (Encryption, access controls)      │
└─────────────────────────────────────────────────────────┘
```

### 2. Fail-Closed Default

When security decisions are uncertain, deny access:

```typescript
// CORRECT: Fail-closed
function hasPermission(user: User | null, resource: Resource): boolean {
  if (!user) return false; // No user = no access
  if (!user.permissions) return false; // Missing permissions = no access
  return user.permissions.includes(resource.requiredPermission);
}

// INCORRECT: Fail-open
function hasPermission(user: User | null, resource: Resource): boolean {
  if (!user) return true; // Dangerous!
  return user.permissions?.includes(resource.requiredPermission) ?? true; // Dangerous!
}
```

### 3. Principle of Least Privilege

Grant minimum necessary permissions:

```typescript
// Database queries: Select only needed columns
const user = await db.query.users.findFirst({
  where: eq(users.id, userId),
  columns: {
    id: true,
    name: true,
    email: true,
    // Don't select: passwordHash, apiKey, etc.
  },
});

// API responses: Don't leak internal data
function serializeUser(user: FullUser): PublicUser {
  return {
    id: user.id,
    name: user.name,
    avatarUrl: user.avatarUrl,
    // Exclude: email, createdAt, internal flags
  };
}
```

---

## Input Validation

### Validation at System Boundaries

Validate all external input at entry points:

```typescript
import { z } from 'zod';

// Define strict schemas
const CreateUserSchema = z.object({
  email: z.string().email().toLowerCase().trim(),
  name: z.string().min(1).max(100).trim(),
  password: z
    .string()
    .min(12, 'Password must be at least 12 characters')
    .regex(/[A-Z]/, 'Password must contain uppercase')
    .regex(/[a-z]/, 'Password must contain lowercase')
    .regex(/[0-9]/, 'Password must contain number'),
});

// Validate at API boundary
export const createUser = createServerFn('POST', async (input: unknown) => {
  // Parse validates and transforms
  const validated = CreateUserSchema.parse(input);

  // After this point, validated data is trusted
  return userService.create(validated);
});
```

### Allowlists Over Blocklists

Specify what IS allowed rather than what ISN'T:

```typescript
// CORRECT: Allowlist approach
const AllowedFileTypes = z.enum(['image/png', 'image/jpeg', 'image/webp']);

function validateUpload(file: File): boolean {
  const result = AllowedFileTypes.safeParse(file.type);
  return result.success;
}

// INCORRECT: Blocklist approach (can miss dangerous types)
const BlockedTypes = ['application/x-executable', 'text/html'];

function validateUpload(file: File): boolean {
  return !BlockedTypes.includes(file.type); // Misses many dangerous types
}
```

### URL Validation

```typescript
const SafeUrlSchema = z.string().refine(
  (url) => {
    try {
      const parsed = new URL(url);
      // Only allow specific protocols
      return ['http:', 'https:'].includes(parsed.protocol);
    } catch {
      return false;
    }
  },
  { message: 'Invalid URL' },
);

// For internal redirects, validate against allowlist
const AllowedRedirectHosts = ['app.example.com', 'docs.example.com'];

function validateRedirect(url: string): boolean {
  try {
    const parsed = new URL(url);
    return AllowedRedirectHosts.includes(parsed.host);
  } catch {
    return false;
  }
}
```

---

## Authentication

### Session Management

```typescript
import { betterAuth } from 'better-auth';

export const auth = betterAuth({
  database: db,
  session: {
    expiresIn: 60 * 60 * 24 * 7, // 7 days
    updateAge: 60 * 60 * 24, // Update session daily
    cookieCache: {
      enabled: true,
      maxAge: 60 * 5, // 5 minute cookie cache
    },
  },
  advanced: {
    // Use secure cookies
    useSecureCookies: process.env.NODE_ENV === 'production',
    // Strict same-site
    cookieSameSite: 'strict',
  },
});
```

### Secure Password Handling

Never log, serialize, or expose passwords:

```typescript
// Redact passwords from all logging
const logger = pino({
  redact: {
    paths: ['password', '*.password', 'body.password', 'req.body.password'],
    censor: '[REDACTED]',
  },
});

// Hash passwords with strong algorithm
import { hash, verify } from '@node-rs/argon2';

async function hashPassword(password: string): Promise<string> {
  return hash(password, {
    memoryCost: 65536, // 64 MB
    timeCost: 3,
    parallelism: 4,
  });
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return verify(hash, password);
}
```

### Rate Limiting

```typescript
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'), // 10 requests per minute
  analytics: true,
});

async function authMiddleware(req: Request): Promise<Response | null> {
  const ip = req.headers.get('x-forwarded-for') ?? '127.0.0.1';
  const { success, limit, remaining, reset } = await ratelimit.limit(ip);

  if (!success) {
    return new Response('Too Many Requests', {
      status: 429,
      headers: {
        'X-RateLimit-Limit': limit.toString(),
        'X-RateLimit-Remaining': remaining.toString(),
        'X-RateLimit-Reset': reset.toString(),
        'Retry-After': Math.ceil((reset - Date.now()) / 1000).toString(),
      },
    });
  }

  return null; // Continue to handler
}
```

---

## Authorization

### Permission Checks

```typescript
import { z } from 'zod';

// Define permissions as typed constants
const Permission = {
  USER_READ: 'user:read',
  USER_WRITE: 'user:write',
  ADMIN: 'admin',
} as const;

type Permission = (typeof Permission)[keyof typeof Permission];

interface AuthContext {
  userId: string;
  permissions: Permission[];
}

function requirePermission(ctx: AuthContext, required: Permission): void {
  if (!ctx.permissions.includes(required) && !ctx.permissions.includes(Permission.ADMIN)) {
    throw new ForbiddenError(`Missing permission: ${required}`);
  }
}

// Usage in server function
export const updateUser = createServerFn('POST', async (input: unknown, ctx: AuthContext) => {
  requirePermission(ctx, Permission.USER_WRITE);

  const data = UpdateUserSchema.parse(input);
  return userService.update(data);
});
```

### Resource-Level Authorization

Check access to specific resources, not just actions:

```typescript
async function getDocument(ctx: AuthContext, documentId: string): Promise<Document> {
  const document = await db.query.documents.findFirst({
    where: eq(documents.id, documentId),
  });

  if (!document) {
    throw new NotFoundError('Document not found');
  }

  // Check ownership or explicit access
  const hasAccess = document.ownerId === ctx.userId || (await hasDocumentAccess(ctx.userId, documentId));

  if (!hasAccess) {
    // Don't reveal existence - same error as not found
    throw new NotFoundError('Document not found');
  }

  return document;
}
```

---

## Secrets Management

### Multi-Layer Defense

1. **Pre-commit**: Block secrets before they enter git
2. **CI**: Scan for any that slip through
3. **Runtime**: Redact from logs and errors

### Gitleaks Installation & Configuration

**Gitleaks** is a secret scanning tool that prevents credentials from being committed to git. Use the `gitleaks-secret-scanner` npm package for a Node.js/Bun native experience.

#### Installation

Install as a dev dependency in your monorepo root:

```bash
bun add -d gitleaks-secret-scanner
```

Add a package.json script to run gitleaks:

```json
{
  "scripts": {
    "gitleaks": "gitleaks-secret-scanner"
  }
}
```

#### Configuration File

Create a `.gitleaks.toml` file in your repository root:

```toml
# .gitleaks.toml
title = "Gitleaks Configuration"

# Extend the base configuration
[extend]
useDefault = true

# Custom rules for your organization
[[rules]]
id = "generic-api-key"
description = "Generic API Key"
regex = '''(?i)(api[_-]?key|apikey|api[_-]?token)[\s]*[=:]["']?([a-zA-Z0-9_\-]{20,})["']?'''
keywords = [
  "apikey",
  "api_key",
  "api-key",
  "api_token",
]

[[rules]]
id = "jwt-token"
description = "JWT Token"
regex = '''eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'''

[[rules]]
id = "database-url"
description = "Database Connection String"
regex = '''(?i)(postgres|mysql|mongodb|redis)://[^\s'"]{10,}'''
keywords = [
  "postgres://",
  "mysql://",
  "mongodb://",
  "redis://",
]

# Allowlist patterns (files/paths to ignore)
[allowlist]
description = "Global allowlist"
paths = [
  '''^\.git/''',
  '''(.*?)(jpg|gif|doc|pdf|bin|svg|socket)$''',
  '''(go|bun)\.sum$''',
  '''(pnpm-)?lock\.(yaml|json)$''',
  '''\.content-collections/generated/''',
]

# Allowlist for test fixtures and example data
[[allowlist.regexes]]
description = "Ignore test fixtures"
regex = '''(?i)(test|spec|fixture|example|mock|dummy)[_-]?(key|token|secret)'''

[[allowlist.regexes]]
description = "Ignore placeholder values"
regex = '''(?i)(your[_-]?|my[_-]?|example[_-]?)(api[_-]?key|token|secret|password)'''

[[allowlist.regexes]]
description = "Ignore safe example values"
regex = '''(xxx+|yyy+|zzz+|000+|123+|abc+|test+|demo+)'''

# Allowlist for specific commits (useful for initial scan)
# [[allowlist.commits]]
# description = "Initial repository setup"
# commitid = "abc123def456"
```

#### Usage

Scan the entire repository for secrets:

```bash
bun gitleaks
# or: pnpm gitleaks
```

Scan since a specific commit:

```bash
gitleaks-secret-scanner --log-opts="HEAD~1..HEAD"
```

Protect mode (scan uncommitted changes):

```bash
gitleaks-secret-scanner protect --staged
```

#### Pre-commit Hook Integration

**Recommended: Using lint-staged** (runs in parallel with other checks):

```javascript
// lint-staged.config.mjs
/** @type {import('lint-staged').Configuration} */
const config = {
  '*': [
    'prettier --ignore-unknown --loglevel=warn --no-editorconfig --write',
    'bunx gitleaks-secret-scanner protect --staged --no-banner',
  ],
  '*.md': 'remark --output --silently-ignore --',
  '*.{js,jsx,ts,tsx}': 'eslint --cache --fix',
};

export default config;
```

Then in `.husky/pre-commit`:

```bash
#!/usr/bin/env sh

# Run lint-staged for formatting, linting, and secret scanning
bunx lint-staged
```

**Alternative: Direct Husky integration** (runs separately):

```bash
#!/usr/bin/env sh

# Run lint-staged for formatting and linting
bunx lint-staged

# Run gitleaks on staged changes
bunx gitleaks-secret-scanner protect --staged --no-banner
```

#### CI Integration

```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Full history for comprehensive scan

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

```typescript
// Runtime redaction
const sensitiveFields = ['password', 'token', 'apiKey', 'secret', 'authorization', 'cookie', 'session'];

function redactSensitive(obj: unknown): unknown {
  if (typeof obj !== 'object' || obj === null) return obj;

  if (Array.isArray(obj)) {
    return obj.map(redactSensitive);
  }

  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    if (sensitiveFields.some((field) => key.toLowerCase().includes(field))) {
      result[key] = '[REDACTED]';
    } else {
      result[key] = redactSensitive(value);
    }
  }
  return result;
}
```

### Environment Variables

```typescript
import { z } from 'zod';

// Validate environment at startup
const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  DATABASE_URL: z.string().url(),
  SESSION_SECRET: z.string().min(32),
  // Don't provide defaults for required secrets
});

// Fail fast if invalid
const env = EnvSchema.parse(process.env);

// Export typed env
export { env };
```

---

## XSS Prevention

### React's Built-in Protection

React escapes content by default:

```tsx
// SAFE: React escapes the content
function UserGreeting({ name }: { name: string }) {
  return <p>Hello, {name}</p>; // <script> in name is escaped
}
```

### Dangerous Patterns to Avoid

```tsx
// DANGEROUS: Bypasses React's escaping
function UnsafeContent({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />; // XSS risk!
}

// SAFE: Use a sanitization library if HTML is required
import DOMPurify from 'dompurify';

function SafeContent({ html }: { html: string }) {
  const sanitized = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'a'],
    ALLOWED_ATTR: ['href', 'target', 'rel'],
  });
  return <div dangerouslySetInnerHTML={{ __html: sanitized }} />;
}
```

### Content Security Policy

```typescript
// Set CSP headers
const cspHeader = {
  'Content-Security-Policy': [
    "default-src 'self'",
    "script-src 'self' 'strict-dynamic'",
    "style-src 'self' 'unsafe-inline'", // Required for Tailwind
    "img-src 'self' data: https:",
    "font-src 'self'",
    "connect-src 'self' https://api.example.com",
    "frame-ancestors 'none'",
    "form-action 'self'",
    "base-uri 'self'",
  ].join('; '),
};
```

---

## SQL Injection Prevention

### Let The Query Builder Parameterize

Any mainstream ORM or query builder parameterizes by default.
Use its query API rather than assembling SQL strings.
The examples below use one query-builder syntax, but the rule is universal:

```typescript
// SAFE: Parameterized query
const user = await db.query.users.findFirst({
  where: eq(users.email, email), // email is safely parameterized
});

// SAFE: Even with dynamic conditions
const users = await db.query.users.findMany({
  where: and(eq(users.status, status), name ? like(users.name, `%${name}%`) : undefined),
});
```

### Raw SQL Safety

If raw SQL is needed, use parameterized queries:

```typescript
// SAFE: Parameterized raw query, values passed as bound parameters
const result = await db.execute(sql`SELECT * FROM users WHERE email = ${email} AND status = ${status}`);

// DANGEROUS: String concatenation
const result = await db.execute(
  sql.raw(`SELECT * FROM users WHERE email = '${email}'`), // SQL injection!
);
```

---

## CSRF Protection

### SameSite Cookies

```typescript
// Cookie configuration
const sessionCookie = {
  name: 'session',
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict' as const, // Prevents CSRF in modern browsers
  path: '/',
  maxAge: 60 * 60 * 24 * 7, // 7 days
};
```

### Double-Submit Pattern for APIs

```typescript
// For non-cookie auth (API tokens), include in header
const csrfToken = generateSecureToken();

// Set in cookie
response.headers.set('Set-Cookie', `csrf=${csrfToken}; SameSite=Strict; Secure`);

// Require in header for state-changing requests
function validateCsrf(request: Request): boolean {
  const cookieToken = parseCookies(request.headers.get('cookie')).csrf;
  const headerToken = request.headers.get('X-CSRF-Token');

  return cookieToken === headerToken && cookieToken !== undefined;
}
```

---

## GraphQL Security

Applies only if the project exposes a GraphQL API.
GraphQL adds attack surface that REST does not have, because the client composes the query.
The option names below are one server implementation's, but every GraphQL server has equivalents.

### Query Depth Limiting

```typescript
import depthLimit from 'graphql-depth-limit';

const server = new ApolloServer({
  schema,
  validationRules: [depthLimit(10)], // Max 10 levels deep
});
```

### Query Complexity Analysis

```typescript
import { createComplexityLimitRule } from 'graphql-validation-complexity';

const complexityLimit = createComplexityLimitRule(1000, {
  onCost: (cost) => {
    logger.debug({ cost }, 'GraphQL query complexity');
  },
  formatErrorMessage: (cost) => `Query complexity ${cost} exceeds maximum allowed complexity of 1000`,
});

const server = new ApolloServer({
  schema,
  validationRules: [depthLimit(10), complexityLimit],
});
```

### Disable Introspection in Production

```typescript
const server = new ApolloServer({
  schema,
  introspection: process.env.NODE_ENV !== 'production',
});
```

---

## File Upload Security

```typescript
import { z } from 'zod';

// Strict file validation
const FileUploadSchema = z.object({
  file: z
    .custom<File>((val) => val instanceof File, 'Invalid file')
    .refine(
      (file) => {
        // Size limit: 10MB
        if (file.size > 10 * 1024 * 1024) return false;

        // Allowlist MIME types
        const allowedTypes = ['image/png', 'image/jpeg', 'image/webp'];
        return allowedTypes.includes(file.type);
      },
      { message: 'File must be PNG, JPEG, or WebP under 10MB' },
    ),
});

async function handleUpload(file: File): Promise<string> {
  // Validate
  FileUploadSchema.parse({ file });

  // Generate safe filename (never use user input)
  const ext = file.type.split('/')[1];
  const filename = `${crypto.randomUUID()}.${ext}`;

  // Store in isolated location
  const path = `uploads/${filename}`;
  await Bun.write(path, file);

  return filename;
}
```

---

## Security Headers

```typescript
const securityHeaders = {
  // Prevent clickjacking
  'X-Frame-Options': 'DENY',

  // Prevent MIME sniffing
  'X-Content-Type-Options': 'nosniff',

  // Enable XSS filter
  'X-XSS-Protection': '1; mode=block',

  // Control referrer information
  'Referrer-Policy': 'strict-origin-when-cross-origin',

  // Permission policy
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',

  // HSTS (after ensuring HTTPS works)
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
};

function addSecurityHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(securityHeaders)) {
    headers.set(key, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
```

---

## Dependency Security

### Automated Scanning

```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 0 * * *' # Daily

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Audit dependencies
        run: pnpm audit --audit-level=high
        continue-on-error: true

      - name: Check for vulnerable dependencies
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

### Lock File Integrity

Always commit lock files and verify in CI:

```yaml
- name: Install dependencies
  run: pnpm install --frozen-lockfile # Fails if lock file doesn't match
```

---

## Docker Security

### Minimal Production Images

```dockerfile
# Build stage
FROM oven/bun:1 AS builder
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile --production=false
COPY . .
RUN bun run build

# Production stage
FROM gcr.io/distroless/nodejs22-debian12

# Don't run as root
USER nonroot

WORKDIR /app
COPY --from=builder --chown=nonroot:nonroot /app/dist ./dist
COPY --from=builder --chown=nonroot:nonroot /app/node_modules ./node_modules

# No shell, minimal attack surface
EXPOSE 3000
CMD ["dist/index.js"]
```

### Image Scanning

```yaml
# CI pipeline
- name: Build image
  run: docker build -t app:${{ github.sha }} .

- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'app:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1' # Fail on critical/high
```

---

## Security Checklist

### Code Review Security Checks

- [ ] Input validation at all entry points
- [ ] No raw SQL or string interpolation for queries
- [ ] No `dangerouslySetInnerHTML` without sanitization
- [ ] Sensitive data not logged or exposed in errors
- [ ] Authorization checks on all protected resources
- [ ] No hardcoded secrets or credentials
- [ ] File uploads validated (type, size, name)
- [ ] URLs validated against allowlist for redirects
- [ ] Rate limiting on authentication endpoints
- [ ] CSRF protection for state-changing requests

### Pre-Deployment Checklist

- [ ] Security headers configured
- [ ] CSP policy in place
- [ ] HTTPS enforced
- [ ] Cookies marked Secure and HttpOnly
- [ ] Dependencies audited
- [ ] Docker image scanned
- [ ] Secrets management verified
- [ ] Logging configured without sensitive data
- [ ] Error messages don't leak internal details
- [ ] Introspection disabled in GraphQL (production)